# ContainerAlpineClaudeDotNetDev2026

A sandbox for agentic AI to safely work, free of permissions interruption. Out of the box, it's set up for claude code:

```
./Claude-It.ps1
# or
./docker-claude-it.sh
# or, on macOS with the Apple container CLI
./container-claude-it-macos.sh
```

The agent gets work done by having access to the git repos mounted in the container, so it can get, commit and push.

## What's in the image

Edit the dockerfile to taste. It's currently set up with:

- **Alpine Linux 3.23** with zsh, oh-my-zsh, tmux, vim, ripgrep, **.NET SDK 8.0 and 10, and Mono**, **Node.js** and npm, **PowerShell 7.5**
- **Claude Code CLI** (installed via `claude.ai/install.sh`)
- A **non-root user `agent1`** with passwordless `doas` for installations: `apk`, `dotnet`, `npm`, and `node`
- PowerShell installs from the musl-x64 tarball on x86_64; on other architectures (e.g. arm64) it installs as a dotnet tool with a small compatibility shim, so the image builds on Apple Silicon too

On startup, the container launches a **tmux** session with Claude Code ready to go. Tmux makes it easier for you to reach a terminal whilst Claude chugs away.

## Prerequisites

- Docker, Git, a subscription.

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
# Build and run with defaults (Dockerfile is found next to the script)
./docker-claude-it.sh --build-image
# or, on macOS with the Apple container CLI
./container-claude-it-macos.sh --build-image --image-dockerfile ./Dockerfile

# Run an already-built image
./docker-claude-it.sh
```

### Using Docker directly

```bash
docker build . -t alpine-claude-dotnet-dev:latest

docker run -it --rm \
    -p 3000:3000 -p 3001:3001 \
    -e GIT_AUTHOR_NAME="Agent1 for $(git config --get user.name)" \
    -e GIT_AUTHOR_EMAIL="$(git config --get user.email)" \
    -v ~/my-repos:/repos \
    -v ~/.config/claude-it/.claude:/home/agent1/.claude \
    -v ~/.config/claude-it/.claude.json:/home/agent1/.claude.json \
    alpine-claude-dotnet-dev:latest
```

## Volume mounts

The container expects up to three mounts:

| Mount point | Purpose |
|---|---|
| `/repos` | Host directory containing git repos for Claude to work on |
| `/home/agent1/.claude` | Persists Claude credentials, settings, permissions, and memory across runs |
| `/home/agent1/.claude.json` | Persists OAuth session data, MCP configs, and preferences |

Alternatively, pass `-e ANTHROPIC_API_KEY=sk-...` instead of mounting the Claude config files.

## Launcher script options

`Claude-It.ps1`, `docker-claude-it.sh` and `container-claude-it-macos.sh` accept the same logical parameters:

| Option | Default | Description |
|---|---|---|
| `--image` / `-image` | `alpine-claude-dotnet-dev` | Image name |
| `--build-image` / `-buildImage` | off | Build the image before running |
| `--ports` / `-portsMap` | `0:3000`, `0:3001` (docker); `3000:3000`, `3001:3001` (Apple container) | Port mappings (max 2); host port 0 lets docker auto-assign |
| `--agent-name` / `-agentName` | `Agent1` | Agent name, used for git attribution; must match the Dockerfile USER |
| `--work-dir` / `-WorkDirToMount` | `.` | Host path mounted at `/repos` |
| `--image-dir` / `-imageDir` | script's directory | Directory containing the Dockerfile (docker scripts); the macOS script takes `--image-dockerfile FILE` instead |
| `--claude-save-dir` / `-claudeSaveDir` | `~/.config/claude-it` (bash), `~/.claude-it-sessions` (PowerShell) | Host path for Claude state persistence, created on first run |

The scripts automatically derive the git author name and email from your environment or git config, prefixed with the agent name (e.g. `Agent1 for Your Name`).
