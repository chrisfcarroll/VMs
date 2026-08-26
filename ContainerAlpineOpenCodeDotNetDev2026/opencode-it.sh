#!/usr/bin/env bash
#
# Launches a container with Alpine Linux, OpenCode, and .NET development tools.
#
# Automatically detects and uses whichever container runtime is available:
# Docker (docker) or the Apple container CLI (container). Use --runtime to force one.
#
# Creates and runs a container for development using OpenCode as an agent. The script recognises:
# - Volume mounts for code repositories and OpenCode configuration
# - Git author environment variables or config settings (name and email)
# - Paths to preserve OpenCode configuration and state across container runs
# - Port mappings
#
# The script supports optional image building and port mappings. Container mounts preserve:
# - ~/.local/share/opencode/: Data and auth
#
# Usage:
#   ./opencode-it.sh [OPTIONS]
#
# Options:
#   --work-dir DIR           Host directory path to mount as /repos in the container.
#   --opencode-save-dir DIR  Host directory for storing OpenCode configuration and state volumes.
#   --image NAME             Image name to run. Default: "alpine-opencode-dotnet-dev"
#   --build-image            If specified, builds the image from a Dockerfile before running.
#   --image-dir DIR          Directory containing the Dockerfile. Used with --build-image
#                            (docker runtime). Defaults to this script's own directory.
#   --image-dockerfile FILE  Path to a Dockerfile. Used with --build-image (container runtime).
#   --runtime NAME           Container runtime to use: "docker" or "container".
#                            Default: auto-detected (Apple container preferred on macOS,
#                            docker elsewhere).
#   --ports PORT1 PORT2      Port mappings in "host:container" format. Default: "0:3000" "0:3001"
#                            for docker (0 auto-assigns a free host port, so multiple containers
#                            can run at once without port collisions), "3000:3000" "3001:3001"
#                            for the Apple container runtime.
#                            Maximum of 2 port mappings supported; additional mappings are ignored.
#   --agent-name NAME        Name of the agent running in the container. Used for Git author attribution.
#                            Must match the USER set in the Dockerfile.
#                            Default: "Agent1"
#   --dry-run                Print the run command without executing it.
#   --help                   Show this help message.
#
# Examples:
#   ./opencode-it.sh --work-dir ~/my-repos
#       Runs the default container with a custom work directory.
#
#   ./opencode-it.sh --build-image --image my-custom-image --agent-name "MyAgent" --image-dir ~/Dockerfiles
#       Builds the image first (docker), then runs it with custom agent name.
#
#   ./opencode-it.sh --runtime container --build-image --image-dockerfile ./Dockerfile
#       Forces the Apple container runtime and builds from a Dockerfile path.
#
#   ./opencode-it.sh --ports "8000:3000" "8001:3001"
#       Runs the container with custom port mappings.
#
# Notes:
#   - Git author name and email are automatically captured from environment or git config
#   - The script assumes a supported container runtime and git are installed and available
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

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Absolute path of an existing directory, without realpath (absent on older macOS)
abs_dir() { (CDPATH= cd -- "$1" && pwd); }
abs_file() { echo "$(abs_dir "$(dirname "$1")")/$(basename "$1")"; }

# Defaults
work_dir_to_mount="."
opencode_save_dir="$HOME/.config/opencode-it"
image="alpine-opencode-dotnet-dev"
build_image=false
image_dir="$script_dir"
image_dockerfile=""
runtime=""
ports=()
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
        --image-dockerfile)
            image_dockerfile="$2"
            shift 2
            ;;
        --runtime)
            runtime="$2"
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

# Detect / validate the container runtime
platform=$(uname -s)
case "$runtime" in
    "")
        # Auto-detect: on macOS prefer the Apple container CLI; otherwise prefer docker
        if [[ "$platform" == "Darwin" ]] && command -v container &>/dev/null; then
            runtime="container"
        elif command -v docker &>/dev/null; then
            runtime="docker"
        elif command -v container &>/dev/null; then
            runtime="container"
        else
            echo "Warning: No container runtime found. Please install Docker or the Apple container CLI." >&2
            echo "Docker install guide: https://docs.docker.com/engine/install/" >&2
            echo "Apple container install guide: https://github.com/apple/container/blob/main/docs/tutorials/start-here.md" >&2
            exit 1
        fi
        ;;
    docker|container)
        if ! command -v "$runtime" &>/dev/null; then
            echo "Warning: Requested runtime '$runtime' not found. Please install it and ensure it is in your PATH." >&2
            exit 1
        fi
        ;;
    *)
        echo "Warning: Unknown runtime '$runtime'. Valid values are 'docker' or 'container'." >&2
        exit 1
        ;;
esac
echo "    Using container runtime: $runtime"

# Default ports per runtime: docker supports host port 0 = auto-assign a free port
if [[ ${#ports[@]} -eq 0 ]]; then
    if [[ "$runtime" == "docker" ]]; then
        ports=("0:3000" "0:3001")
    else
        ports=("3000:3000" "3001:3001")
    fi
fi

# Ensure required commands
if ! command -v git &>/dev/null; then
    echo "Warning: Git command not found. Please install Git and ensure it is in your PATH." >&2
    exit 1
fi

# List existing images in a runtime-appropriate way
if [[ "$runtime" == "docker" ]]; then
    valid_images=$(docker images --format "{{.Repository}}:{{.Tag}}")
else
    valid_images=$(container image ls)
fi

# Ensure required paths exist
if [[ ! -d "$work_dir_to_mount" ]]; then
    echo "Warning: work-dir directory does not exist: $work_dir_to_mount." >&2
    echo "Please specify a directory where you have a git repo, or repos, you want OpenCode to work on." >&2
    exit 1
fi
work_dir_to_mount=$(abs_dir "$work_dir_to_mount")

if [[ "$build_image" == true ]]; then
    if [[ "$runtime" == "docker" ]]; then
        if [[ ! -f "$image_dir/Dockerfile" ]]; then
            echo "Warning: You asked to build the image, but no Dockerfile found at: $image_dir/Dockerfile" >&2
            exit 1
        fi
        image_dir=$(abs_dir "$image_dir")
    else
        if [[ -z "$image_dockerfile" ]]; then
            echo "Enter path to your $image Dockerfile:"
            read -r image_dockerfile
        fi
        if [[ -z "$image_dockerfile" || ! -f "$image_dockerfile" ]]; then
            echo "Warning: You asked to build the image, but there is no Dockerfile at: $image_dockerfile" >&2
            exit 1
        fi
        image_dockerfile=$(abs_file "$image_dockerfile")
    fi
fi

# Create the save dir structure so mounts always work, even on first run.
mkdir -p "$opencode_save_dir/.local/share/opencode"
opencode_save_dir=$(abs_dir "$opencode_save_dir")

echo "    Checking $image ..."

if [[ "$build_image" != true ]] && ! echo "$valid_images" | grep -qE "^${image}([: ]|$)"; then
    echo "Warning: $runtime image '$image' does not exist and --build-image was not specified." >&2
    echo "Either build the image with --build-image flag or ensure the image is available locally." >&2
    exit 1
fi

# Git author info
agent_name_lower=$(echo "$agent_name" | tr '[:upper:]' '[:lower:]')
on_behalf_of="${GIT_AUTHOR_NAME:-${GIT_COMMITTER_NAME:-$(git config --get user.name 2>/dev/null || echo "")}}"
git_author_name="$agent_name for $on_behalf_of"
git_author_email="${GIT_AUTHOR_EMAIL:-$(git config --get user.email 2>/dev/null || echo "")}"

# Build image if requested
if [[ "$build_image" == true ]]; then
    if [[ "$runtime" == "docker" ]]; then
        docker build -t "${image}:latest" "$image_dir"
    else
        container build -f "$image_dockerfile" -t "${image}:latest" "$(dirname "$image_dockerfile")"
    fi
fi

# Handle port mappings
if [[ ${#ports[@]} -gt 2 ]]; then
    echo "Warning: This script only handles two port mappings. Extra mappings will be ignored." >&2
fi

# Ensure at least 2 port mappings
if [[ "$runtime" == "docker" ]]; then
    pad_ports=("0:3000" "0:3001")
else
    pad_ports=("3000:3000" "3001:3001")
fi
while [[ ${#ports[@]} -lt 2 ]]; do
    ports+=("${pad_ports[${#ports[@]}]}")
done

# Print the command
cat <<EOF
    $runtime run -it -p ${ports[0]} -p ${ports[1]} \\
                -e GIT_AUTHOR_NAME="$git_author_name" \\
                -e GIT_AUTHOR_EMAIL="$git_author_email" \\
                -v "$work_dir_to_mount:/repos" \\
                -v "$opencode_save_dir/.local/share/opencode:/home/$agent_name_lower/.local/share/opencode" \\
            ${image}:latest
EOF

if [[ "$dry_run" == true ]]; then
    exit 0
fi

"$runtime" run -it -p "${ports[0]}" -p "${ports[1]}" \
            -e GIT_AUTHOR_NAME="$git_author_name" \
            -e GIT_AUTHOR_EMAIL="$git_author_email" \
            -v "$work_dir_to_mount:/repos" \
            -v "$opencode_save_dir/.local/share/opencode:/home/$agent_name_lower/.local/share/opencode" \
    "${image}:latest"
