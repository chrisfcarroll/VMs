#!/usr/bin/env bash
#
# Launches a Docker container with Alpine Linux, Claude code, and .NET development tools.
#
# Creates and runs a Docker container for development using Claude as an agent. The script recognises:
# - Volume mounts for code repositories and Claude configuration
# - Git author environment variables or config settings (name and email)
# - Paths to preserve Claude credentials, settings, and session data across container runs
# - Port mappings
#
# The script supports optional image building and port mappings. Container mounts preserve:
# - ~/.claude/: Credentials and settings
# - ~/.claude.json: OAuth session data and MCP configurations
#
# Usage:
#   ./docker-claude-it.sh [OPTIONS]
#
# Options:
#   --work-dir DIR        Host directory path to mount as /repos in the container.
#                         Defaults to "."
#   --claude-save-dir DIR Host directory for storing Claude configuration and state volumes.
#                         Created if missing. Defaults to ~/.config/claude-it
#   --image NAME          Docker image name to run. Default: "alpine-claude-dotnet-dev"
#   --build-image         If specified, builds the Docker image from Dockerfile before running.
#   --image-dir DIR       Directory containing the Dockerfile. Used with --build-image.
#                         Defaults to this script's own directory.
#   --ports PORT1 PORT2   Port mappings in "host:container" format. Default: "0:3000" "0:3001"
#                         A host port of 0 lets the runtime auto-assign a free host port, so
#                         multiple containers can run at once without port collisions.
#                         Maximum of 2 port mappings supported; additional mappings are ignored.
#   --agent-name NAME     Name of the agent running in the container. Used for Git author attribution
#                         and .claude directory naming. Must match the USER set in the Dockerfile.
#                         Default: "Agent1"
#   --dry-run             Print the docker run command without executing it.
#   --help                Show this help message.
#
# Examples:
#   ./docker-claude-it.sh --work-dir ~/my-repos
#       Runs the default container with a custom work directory.
#
#   ./docker-claude-it.sh --build-image --image my-custom-image --agent-name "MyAgent" --image-dir ~/Dockerfiles
#       Builds the image first, then runs it with custom agent name.
#
#   ./docker-claude-it.sh --ports "8000:3000" "8001:3001"
#       Runs the container with custom port mappings.
#
# Notes:
#   - Git author name and email are automatically captured from environment or git config
#   - The script assumes Docker and git are installed and available
#   - Volume mounts preserve Claude state between container runs
#   - Alternatively, use ANTHROPIC_API_KEY environment variable to avoid volume mounts for credentials
#
#   What each Claude mount preserves:
#   ┌────────────────┬────────────────────────────────────────────────────────────────┐
#   │     Mount      │                            Contains                            │
#   ├────────────────┼────────────────────────────────────────────────────────────────┤
#   │ ~/.claude/     │ Credentials (.credentials.json), settings, permissions, memory │
#   ├────────────────┼────────────────────────────────────────────────────────────────┤
#   │ ~/.claude.json │ OAuth session data, MCP configs, theme/editor preferences      │
#   └────────────────┴────────────────────────────────────────────────────────────────┘

set -euo pipefail

script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Absolute path of an existing directory, without realpath (absent on older macOS)
abs_dir() { (CDPATH= cd -- "$1" && pwd); }

# Defaults
work_dir_to_mount="."
claude_save_dir="$HOME/.config/claude-it"
image="alpine-claude-dotnet-dev"
build_image=false
image_dir="$script_dir"
ports=("0:3000" "0:3001")
agent_name="Agent1"
dry_run=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --work-dir)
            work_dir_to_mount="$2"
            shift 2
            ;;
        --claude-save-dir)
            claude_save_dir="$2"
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

# Ensure required paths exist
if [[ ! -d "$work_dir_to_mount" ]]; then
    echo "Warning: work-dir directory does not exist: $work_dir_to_mount." >&2
    echo "Please specify a directory where you have a git repo, or repos, you want Claude to work on." >&2
    exit 1
fi
work_dir_to_mount=$(abs_dir "$work_dir_to_mount")

if [[ -z "$image" ]]; then
    echo "Specify an image to run:"
    read -r image
    if [[ -z "$image" ]]; then
        echo "Warning: No image specified. Please specify an image to run from the list above." >&2
        exit 1
    fi
fi

# Create the save dir structure so mounts always work, even on first run.
# The .claude.json mount is a single file: pre-create it so the runtime does not
# create a directory in its place.
mkdir -p "$claude_save_dir/.claude"
[[ -f "$claude_save_dir/.claude.json" ]] || echo '{}' > "$claude_save_dir/.claude.json"
claude_save_dir=$(abs_dir "$claude_save_dir")

echo "    Checking $image ..."

if [[ "$build_image" == true && ! -d "$image_dir" ]]; then
    echo "Warning: You asked for buildImage, but ImageDir directory does not exist: $image_dir" >&2
    exit 1
elif [[ "$build_image" == true && ! -f "$image_dir/Dockerfile" ]]; then
    echo "Warning: You asked for buildImage, but Dockerfile not found at: $image_dir/Dockerfile" >&2
    exit 1
elif [[ "$build_image" != true ]] && ! echo "$valid_images" | grep -qE "^${image}([: ]|$)"; then
    echo "Warning: Docker image '$image' does not exist and --build-image was not specified." >&2
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
    image_dir=$(abs_dir "$image_dir")
    docker build -t "${image}:latest" "$image_dir"
fi

# Handle port mappings
if [[ ${#ports[@]} -gt 2 ]]; then
    echo "Warning: This script only handles two port mappings. Extra mappings will be ignored." >&2
fi

# Ensure at least 2 port mappings
while [[ ${#ports[@]} -lt 2 ]]; do
    if [[ ${#ports[@]} -eq 0 ]]; then
        ports+=("0:3000")
    else
        ports+=("0:3001")
    fi
done

# Print the command
cat <<EOF
    docker run -it --rm -p ${ports[0]} -p ${ports[1]} \\
                -e GIT_AUTHOR_NAME="$git_author_name" \\
                -e GIT_AUTHOR_EMAIL="$git_author_email" \\
                -v "$work_dir_to_mount:/repos" \\
                -v "$claude_save_dir/.claude:/home/$agent_name_lower/.claude" \\
                -v "$claude_save_dir/.claude.json:/home/$agent_name_lower/.claude.json" \\
            ${image}:latest
EOF

if [[ "$dry_run" == true ]]; then
    exit 0
fi

docker run -it --rm -p "${ports[0]}" -p "${ports[1]}" \
            -e GIT_AUTHOR_NAME="$git_author_name" \
            -e GIT_AUTHOR_EMAIL="$git_author_email" \
            -v "$work_dir_to_mount:/repos" \
            -v "$claude_save_dir/.claude:/home/$agent_name_lower/.claude" \
            -v "$claude_save_dir/.claude.json:/home/$agent_name_lower/.claude.json" \
    "${image}:latest"
