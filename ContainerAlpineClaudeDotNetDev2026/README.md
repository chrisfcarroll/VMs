# ContainerAlpineClaudeDotNetDev2026

A Docker container image based on Alpine Linux, set up as an interactive development environment with Claude Code, .NET SDKs, and common dev tools. Designed to run Claude as a coding agent against repositories mounted from the host.

## What's in the image

- **Alpine Linux** (latest) with zsh, oh-my-zsh, tmux, vim, ripgrep
- **.NET SDK 8.0 and 10**, Mono
- **Node.js** and npm
- **PowerShell 7.5**
- **Chromium** (headless-capable)
- **Claude Code CLI** (installed via `claude.ai/install.sh`)
- A non-root user `agent1` with passwordless `doas` for `apk`, `npm`, `dotnet`, `pwsh`, and `uv`

On startup, the container launches a tmux session with Claude Code ready to go.

## Directory contents

| File | Purpose |
|---|---|
| `Dockerfile` | Builds the Alpine-based dev image |
| `Claude-It.ps1` | PowerShell launcher script (Windows/macOS/Linux) |
| `claude-it.sh` | Bash launcher script (Linux/macOS) |
| `for-claude-in-a-vm--settings.json` | Example Claude Code settings (bypass permissions, Opus model) |

## Prerequisites

- Docker
- Git
- A Claude Code subscription or `ANTHROPIC_API_KEY`

## Quick start

### Using the PowerShell script

```powershell
# Build and run with defaults
.\Claude-It.ps1 -buildImage

# Run an already-built image
.\Claude-It.ps1
```

### Using the Bash script

```bash
# Build and run with defaults
./claude-it.sh --build-image

# Run an already-built image
./claude-it.sh
```

### Using Docker directly

```bash
docker build . -t alpine-claude-dotnet-dev:latest

docker run -it \
    -p 3000:3000 -p 3001:3001 \
    -e GIT_AUTHOR_NAME="AgentC for $(git config --get user.name)" \
    -e GIT_AUTHOR_EMAIL="$(git config --get user.email)" \
    -v ~/WorkDirToMount:/vmrepos \
    -v ~/claude-home/.claude:/home/agent1/.claude \
    -v ~/claude-home/.claude.json:/home/agent1/.claude.json \
    alpine-claude-dotnet-dev:latest
```

## Volume mounts

The container expects up to three mounts:

| Mount point | Purpose |
|---|---|
| `/vmrepos` | Host directory containing git repos for Claude to work on |
| `/home/agent1/.claude` | Persists Claude credentials, settings, permissions, and memory across runs |
| `/home/agent1/.claude.json` | Persists OAuth session data, MCP configs, and preferences |

Alternatively, pass `-e ANTHROPIC_API_KEY=sk-...` instead of mounting the Claude config files.

## Launcher script options

Both `Claude-It.ps1` and `claude-it.sh` accept the same logical parameters:

| Option | Default | Description |
|---|---|---|
| `--image` / `-image` | `alpine-claude-dotnet-dev` | Docker image name |
| `--build-image` / `-buildImage` | off | Build the image before running |
| `--ports-map` / `-portsMap` | `3000:3000`, `3001:3001` | Port mappings (max 2) |
| `--agent-name` / `-agentName` | `AgentC` | Agent name, used for git attribution |
| `--workdir-to-mount` / `-WorkDirToMount` | `~/WorkDirToMount` | Host path mounted at `/vmrepos` |
| `--image-dir` / `-imageDir` | `~/Repos/Dockerfiles` | Directory containing Dockerfiles |
| `--claude-save-dir` / `-claudeSaveDir` | `~/WorkDirToMount/claude-home` | Host path for Claude state persistence |

The scripts automatically derive the git author name and email from your environment or git config, prefixed with the agent name (e.g. `agentc for Your Name`).
