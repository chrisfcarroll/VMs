#!/usr/bin/env bash
set -euo pipefail

# Default paths
DEFAULT_IMAGE="alpine-claude-dotnet-dev"
DEFAULT_PORTS=("3000:3000" "3001:3001")
DEFAULT_AGENT="AgentC"
DEFAULT_WORKDIR="$HOME/WorkDirToMount"
DEFAULT_IMAGEDIR="$HOME/Repos/Dockerfiles"
DEFAULT_CLAUDE_SAVE="$HOME/WorkDirToMount/claude-home"

usage() {
  cat <<EOF
Usage: $0 [options]

Options:
  --image NAME                Docker image name (default: $DEFAULT_IMAGE)
  --build-image               Build image before run
  --ports-map "h:p"           Port mapping; can be repeated (default: ${DEFAULT_PORTS[*]})
  --agent-name NAME           Agent name (default: $DEFAULT_AGENT)
  --workdir-to-mount PATH     Host path for /vmrepos (default: $DEFAULT_WORKDIR)
  --image-dir PATH            Dockerfiles folder (default: $DEFAULT_IMAGEDIR)
  --claude-save-dir PATH      Base host path for .claude and .claude.json (default: $DEFAULT_CLAUDE_SAVE)
  --help                      Show this message
EOF
  exit 1
}

image="$DEFAULT_IMAGE"
build_image=false
ports_map=()
agent_name="$DEFAULT_AGENT"
workdir_to_mount="$DEFAULT_WORKDIR"
image_dir="$DEFAULT_IMAGEDIR"
claude_save_dir="$DEFAULT_CLAUDE_SAVE"

while [[ $# -gt 0 ]]; do
  case $1 in
    --image) image="${2:-}"; shift 2 ;;
    --build-image) build_image=true; shift ;;
    --ports-map) ports_map+=("${2:-}"); shift 2 ;;
    --agent-name) agent_name="${2:-}"; shift 2 ;;
    --workdir-to-mount) workdir_to_mount="${2:-}"; shift 2 ;;
    --image-dir) image_dir="${2:-}"; shift 2 ;;
    --claude-save-dir) claude_save_dir="${2:-}"; shift 2 ;;
    --help) usage ;;
    *) echo "Unknown arg: $1"; usage ;;
  esac
done

if [[ ${#ports_map[@]} -gt 2 ]]; then
  echo "Warning: only two port mappings are used; extra entries will be ignored."
fi

if [[ ${#ports_map[@]} -lt 2 ]]; then
  ports_map=("${ports_map[@]}" "${DEFAULT_PORTS[@]}")
  ports_map=("${ports_map[@]:0:2}")
fi

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required but not found in PATH." >&2
  exit 1
fi
if ! command -v git >/dev/null 2>&1; then
  echo "Git is required but not found in PATH." >&2
  exit 1
fi

# Resolve and validate directories
workdir_to_mount="${workdir_to_mount/#\~/$HOME}"
image_dir="${image_dir/#\~/$HOME}"
claude_save_dir="${claude_save_dir/#\~/$HOME}"

mkdir -p "$workdir_to_mount" "$claude_save_dir"

if [[ ! -d "$workdir_to_mount" ]]; then
  echo "WorkDirToMount does not exist: $workdir_to_mount" >&2
  exit 1
fi

if [[ "$build_image" == true ]]; then
  if [[ ! -d "$image_dir" ]]; then
    echo "ImageDir does not exist: $image_dir" >&2
    exit 1
  fi
  if [[ ! -f "$image_dir/$image/Dockerfile" ]]; then
    echo "Dockerfile not found: $image_dir/$image/Dockerfile" >&2
    exit 1
  fi
else
  if ! docker image inspect "$image:latest" >/dev/null 2>&1; then
    echo "Docker image '$image:latest' not found; use --build-image to build it." >&2
    exit 1
  fi
fi

if [[ ! -d "$claude_save_dir" ]]; then
  echo "Claude save directory does not exist: $claude_save_dir" >&2
  echo "Create it or pass --claude-save-dir to a valid path."
  exit 1
fi

if [[ "$build_image" == true ]]; then
  docker build "$image_dir/$image" -t "$image:latest"
fi

agent_name_lower="$(tr '[:upper:]' '[:lower:]' <<< "$agent_name")"

on_behalf_of="${GIT_AUTHOR_NAME:-}"
on_behalf_of="${on_behalf_of:-${GIT_COMMITTER_NAME:-}}"
on_behalf_of="${on_behalf_of:-$(git config --get user.name 2>/dev/null || true)}"
on_behalf_of="${on_behalf_of:-unknown}"

git_author_name="$agent_name_lower for $on_behalf_of"
git_author_email="${GIT_AUTHOR_EMAIL:-$(git config --get user.email 2>/dev/null || true)}"

if [[ -z "$git_author_email" ]]; then
  git_author_email="unknown@example.com"
fi

claude_home="$claude_save_dir/.claude"
claude_json="$claude_save_dir/.claude.json"
mkdir -p "$claude_home"
touch "$claude_json"

run_cmd=(
  docker run -it
  -p "${ports_map[0]}" -p "${ports_map[1]}"
  -e "GIT_AUTHOR_NAME=$git_author_name"
  -e "GIT_AUTHOR_EMAIL=$git_author_email"
  -v "$workdir_to_mount:/vmrepos"
  -v "$claude_home:/home/$agent_name_lower/.claude"
  -v "$claude_json:/home/$agent_name_lower/.claude.json"
  "$image:latest"
)

cat <<EOF

Executing:
${run_cmd[*]}

EOF

"${run_cmd[@]}"