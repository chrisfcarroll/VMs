#!/usr/bin/env bash
#
# Launches a Docker container with Alpine Linux, OpenCode, and .NET development tools.
#
# Creates and runs a Docker container for development using OpenCode as an agent. The script recognises:
# - Volume mounts for code repositories and OpenCode configuration
# - Git author environment variables or config settings (name and email)
# - Paths to preserve OpenCode configuration and state across container runs
# - Port mappings
#
# The script supports optional image building and port mappings. Container mounts preserve:
# - ~/.config/opencode/: Configuration and state
#
# Usage:
#   ./opencode-it.sh [OPTIONS]
#
# Options:
#   --work-dir DIR           Host directory path to mount as /vmrepos in the container.
#   --opencode-save-dir DIR  Host directory for storing OpenCode configuration and state volumes.
#   --image NAME             Docker image name to run. Default: "alpine-opencode-dotnet-dev"
#   --build-image            If specified, builds the Docker image from Dockerfile before running.
#   --image-dir DIR          Directory containing Dockerfiles. Used with --build-image.
#   --ports PORT1 PORT2      Port mappings in "host:container" format. Default: "3000:3000" "3001:3001"
#                            Maximum of 2 port mappings supported; additional mappings are ignored.
#   --agent-name NAME        Name of the agent running in the container. Used for Git author attribution.
#                            Must match the USER set in the Dockerfile.
#                            Default: "Agent1"
#   --dry-run                Print the docker run command without executing it.
#   --help                   Show this help message.
#
# Examples:
#   ./opencode-it.sh --work-dir ~/my-repos
#       Runs the default container with a custom work directory.
#
#   ./opencode-it.sh --build-image --image my-custom-image --agent-name "MyAgent" --image-dir ~/Dockerfiles
#       Builds the image first, then runs it with custom agent name.
#
#   ./opencode-it.sh --ports "8000:3000" "8001:3001"
#       Runs the container with custom port mappings.
#
# Notes:
#   - Git author name and email are automatically captured from environment or git config
#   - The script assumes Docker and git are installed and available
#   - Volume mounts preserve OpenCode state between container runs
#   - Pass provider-specific API key env vars (e.g. OPENAI_API_KEY) to avoid volume mounts for credentials
#
#   What the OpenCode mount preserves:
#   ┌──────────────────────────┬──────────────────────────────────────────────┐
#   │          Mount           │                   Contains                   │
#   ├──────────────────────────┼──────────────────────────────────────────────┤
#   │ ~/.local/share/opencode/ │ Data and auth (auth.json, etc.)              │
#   └──────────────────────────┴──────────────────────────────────────────────┘

set -euo pipefail

# Defaults
work_dir_to_mount=""
opencode_save_dir=""
image="alpine-opencode-dotnet-dev"
build_image=false
image_dir=""
ports=("3000:3000" "3001:3001")
agent_name="Agent1"
dry_run=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --work-dir)
            work_dir_to_mount="$2"
            shift 2
            ;;
        --opencode-save-dir)
            opencode_save_dir="$2"
            shift 2
            ;;
        --image)
            image="$2"
            shift 2
            ;;
        --build-image)
            build_image=true
            shift
            ;;
        --image-dir)
            image_dir="$2"
            shift 2
            ;;
        --ports)
            ports=()
            shift
            while [[ $# -gt 0 && ! "$1" =~ ^-- ]]; do
                ports+=("$1")
                shift
            done
            ;;
        --agent-name)
            agent_name="$2"
            shift 2
            ;;
        --dry-run)
            dry_run=true
            shift
            ;;
        --help)
            sed -n '2,/^$/{ s/^# \?//; p }' "$0"
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Ensure required commands
if ! command -v docker &>/dev/null; then
    echo "Warning: Docker command not found. Please install Docker and ensure it is in your PATH." >&2
    exit 1
fi
if ! command -v git &>/dev/null; then
    echo "Warning: Git command not found. Please install Git and ensure it is in your PATH." >&2
    exit 1
fi

valid_images=$(docker images --format "{{.Repository}}:{{.Tag}}")

# Prompt for paths that couldn't be resolved
if [[ -z "$work_dir_to_mount" ]]; then
    echo "Enter path to the working directory you want to mount in the container."
    echo "This is the working directory you are asking OpenCode to work in, so it should contain the git repos you want to work on."
    read -r work_dir_to_mount
    if [[ -z "$work_dir_to_mount" || ! -d "$work_dir_to_mount" ]]; then
        echo "Warning: The specified WorkDirToMount does not exist: $work_dir_to_mount" >&2
        exit 1
    fi
fi
work_dir_to_mount=$(realpath "$work_dir_to_mount")

if [[ "$build_image" == true && -z "$image_dir" ]]; then
    echo "Enter path to Dockerfiles directory:"
    read -r image_dir
    if [[ -z "$image_dir" || ! -d "$image_dir/$image" ]]; then
        echo "Warning: You asked to build the image, but the Dockerfile does not exist: $image_dir/$image" >&2
        exit 1
    fi
    image_dir=$(realpath "$image_dir")
fi

if [[ -z "$image" ]]; then
    echo "Specify an image to run:"
    read -r image
    if [[ -z "$image" ]]; then
        echo "Warning: No image specified. Please specify an image to run from the list above." >&2
        exit 1
    fi
fi

if [[ -z "$opencode_save_dir" ]]; then
    echo "Enter path to save OpenCode data. Otherwise we will default to ~/.opencode-it-sessions"
    read -r opencode_save_dir
    if [[ -z "$opencode_save_dir" ]]; then
        opencode_save_dir="$HOME/.opencode-it-sessions"
    fi
    if [[ ! -d "$opencode_save_dir" ]]; then
        mkdir -p "$opencode_save_dir"
    fi
fi
opencode_save_dir=$(realpath "$opencode_save_dir")

# Ensure required paths exist
if [[ ! -d "$work_dir_to_mount" ]]; then
    echo "Warning: WorkDirToMount directory does not exist: $work_dir_to_mount." >&2
    echo "Please specify a directory where you have a git repo, or repos, you want OpenCode to work on." >&2
    exit 1
fi

echo "    Checking $image ..."

if [[ "$build_image" == true && ! -d "$image_dir" ]]; then
    echo "Warning: You asked for buildImage, but ImageDir directory does not exist: $image_dir" >&2
    exit 1
elif [[ "$build_image" == true && ! -f "$image_dir/$image/Dockerfile" ]]; then
    echo "Warning: You asked for buildImage, but Dockerfile not found at: $image_dir/$image/Dockerfile" >&2
    exit 1
elif [[ "$build_image" != true ]] && ! echo "$valid_images" | grep -q "^${image}"; then
    echo "Warning: Docker image '$image' does not exist and --build-image was not specified." >&2
    echo "Either build the image with --build-image flag or ensure the image is available locally." >&2
    exit 1
fi

if [[ ! -d "$opencode_save_dir" ]]; then
    echo "Warning: OpencodeSaveDir directory does not exist: $opencode_save_dir." >&2
    echo "Choose somewhere to save your OpenCode configuration and state, for instance ~/opencode-home." >&2
    echo "This directory will be mounted into the container to preserve your OpenCode state across runs." >&2
    exit 1
fi

# Git author info
agent_name_lower=$(echo "$agent_name" | tr '[:upper:]' '[:lower:]')
on_behalf_of="${GIT_AUTHOR_NAME:-${GIT_COMMITTER_NAME:-$(git config --get user.name 2>/dev/null || echo "")}}"
git_author_name="$agent_name for $on_behalf_of"
git_author_email="${GIT_AUTHOR_EMAIL:-$(git config --get user.email 2>/dev/null || echo "")}"

# Build image if requested
if [[ "$build_image" == true ]]; then
    docker build "$image_dir/$image" -t "${image}:latest"
fi

# Handle port mappings
if [[ ${#ports[@]} -gt 2 ]]; then
    echo "Warning: This script only handles two port mappings. Extra mappings will be ignored." >&2
fi

# Ensure at least 2 port mappings
while [[ ${#ports[@]} -lt 2 ]]; do
    if [[ ${#ports[@]} -eq 0 ]]; then
        ports+=("3000:3000")
    else
        ports+=("3001:3001")
    fi
done

# Print the command
cat <<EOF
    docker run -it -p ${ports[0]} -p ${ports[1]} \\
                -e GIT_AUTHOR_NAME="$git_author_name" \\
                -e GIT_AUTHOR_EMAIL="$git_author_email" \\
                -v "$work_dir_to_mount:/vmrepos" \\
                -v "$opencode_save_dir/.local/share/opencode:/home/$agent_name_lower/.local/share/opencode" \\
            ${image}:latest
EOF

if [[ "$dry_run" == true ]]; then
    exit 0
fi

docker run -it -p "${ports[0]}" -p "${ports[1]}" \
            -e GIT_AUTHOR_NAME="$git_author_name" \
            -e GIT_AUTHOR_EMAIL="$git_author_email" \
            -v "$work_dir_to_mount:/vmrepos" \
            -v "$opencode_save_dir/.local/share/opencode:/home/$agent_name_lower/.local/share/opencode" \
    "${image}:latest"
