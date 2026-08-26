# ContainerAlpineOpenCodeDotNetDev2026

A sandbox for agentic AI to safely work, free of permissions interruption. Out of the box, it's set up for opencode:

```
./OpenCode-It.ps1
# or
./opencode-it.sh
# or, on macOS with the Apple container CLI
./container-opencode-it.sh
```

The agent gets work done by having access to the git repos mounted in the container, so it can get, commit and push.

## What's in the image

Edit the dockerfile to taste. It's currently set up with:

- **Alpine Linux 3.23** with zsh, oh-my-zsh, tmux, vim, ripgrep, **.NET SDK 8.0 and 10, and Mono**, **Node.js** and npm, **PowerShell 7.5**
- **OpenCode CLI** (installed via `opencode.ai/install`)
- A **non-root user `agent1`** with passwordless `doas` for installations: `apk`, `dotnet`, `npm`, and `node`
- PowerShell installs from the musl-x64 tarball on x86_64; on other architectures (e.g. arm64) it installs as a dotnet tool with a small compatibility shim, so the image builds on Apple Silicon too

On startup, the container launches a **tmux** session with OpenCode ready to go. Tmux makes it easier for you to reach a terminal whilst OpenCode chugs away.

## Prerequisites

- Docker, Git, an API key for a supported LLM provider (e.g. OpenAI, Google, etc.).

## Quick start

### Using the PowerShell script

```powershell
# Build and run with defaults
.\OpenCode-It.ps1 -buildImage

# Run an already-built image
.\OpenCode-It.ps1
```

### Using the Bash script

```bash
# Build and run with defaults (Dockerfile is found next to the script)
./opencode-it.sh --build-image
# or, on macOS with the Apple container CLI
./container-opencode-it.sh --build-image --image-dockerfile ./Dockerfile

# Run an already-built image
./opencode-it.sh
```

### Using Docker directly

```bash
docker build . -t alpine-opencode-dotnet-dev:latest

docker run -it --rm \
    -p 3000:3000 -p 3001:3001 \
    -e GIT_AUTHOR_NAME="Agent1 for $(git config --get user.name)" \
    -e GIT_AUTHOR_EMAIL="$(git config --get user.email)" \
    -v ~/my-repos:/repos \
    -v ~/.config/opencode-it/.local/share/opencode:/home/agent1/.local/share/opencode \
    alpine-opencode-dotnet-dev:latest
```

## Volume mounts

The container expects up to two mounts:

| Mount point | Purpose |
|---|---|
| `/repos` | Host directory containing git repos for OpenCode to work on |
| `/home/agent1/.local/share/opencode` | Persists OpenCode data and auth (auth.json, etc.) |

Alternatively, pass provider-specific API key environment variables (e.g. `-e OPENAI_API_KEY=sk-...`) instead of mounting the config directory.

## Launcher script options

`OpenCode-It.ps1`, `opencode-it.sh` and `container-opencode-it.sh` accept the same logical parameters:

| Option | Default | Description |
|---|---|---|
| `--image` / `-image` | `alpine-opencode-dotnet-dev` | Image name |
| `--build-image` / `-buildImage` | off | Build the image before running |
| `--runtime` | auto-detect | `docker` or `container` (opencode-it.sh only) |
| `--ports` / `-portsMap` | `0:3000`, `0:3001` (docker); `3000:3000`, `3001:3001` (Apple container) | Port mappings (max 2); host port 0 lets docker auto-assign |
| `--agent-name` / `-agentName` | `Agent1` | Agent name, used for git attribution; must match the Dockerfile USER |
| `--work-dir` / `-WorkDirToMount` | `.` | Host path mounted at `/repos` |
| `--image-dir` / `-imageDir` | script's directory | Directory containing the Dockerfile (docker); the macOS script takes `--image-dockerfile FILE` instead |
| `--opencode-save-dir` / `-opencodeSaveDir` | `~/.config/opencode-it` (bash), `~/.opencode-it-sessions` (PowerShell) | Host path for OpenCode state persistence, created on first run |

The scripts automatically derive the git author name and email from your environment or git config, prefixed with the agent name (e.g. `Agent1 for Your Name`).
