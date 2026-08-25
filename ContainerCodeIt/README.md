# ContainerCodeIt

A sandbox for agentic AI to safely work, free of permissions interruption. One image, two agents: **Claude Code** and **OpenCode**. Choose per run:

```bash
./code-it.sh --claude    # or -c (this is the default)
./code-it.sh --opencode  # or -o
# or use the aliases:
./claude-it.sh
./opencode-it.sh
```

```powershell
.\Code-It.ps1 -claude    # or -c (this is the default)
.\Code-It.ps1 -opencode  # or -o
# or use the aliases:
.\Claude-It.ps1
.\OpenCode-It.ps1
```

The agent gets work done by having access to the git repos mounted in the container, so it can get, commit and push.

This directory unifies the earlier `ContainerAlpineClaudeDotNetDev2026` and `ContainerAlpineOpenCodeDotNetDev2026` variants (bash vs powershell, claude vs opencode, Apple containers vs Docker) into one Dockerfile and one launcher per shell.

## Runtime detection (bash)

`code-it.sh` picks a container runtime automatically:

1. On **macOS**, uses the **Apple container CLI** (`container`) if installed
2. Otherwise uses **Docker** if installed
3. Otherwise it exits with a suggestion for the best runtime to install on your platform

Force one with `--runtime docker` or `--runtime container`. The PowerShell version assumes Docker.

## What's in the image

Edit the Dockerfile to taste. It's currently set up with:

- **Alpine Linux** (latest) with zsh, oh-my-zsh, tmux, vim, ripgrep, **.NET SDK 8.0 and 10, and Mono**, **Node.js** and npm, **PowerShell 7**
- **Claude Code CLI** and **OpenCode CLI** — pick one per run with `CODE_AGENT` (the launcher scripts set it from `--claude`/`--opencode`)
- A **non-root user `agent1`** with passwordless `doas` for installations: `apk`, `npm`, `dotnet`, `pwsh`, and `uv`
- PowerShell installs from the musl-x64 tarball on x86_64; on other architectures (e.g. arm64) it installs as a dotnet tool with a small compatibility shim, so the image builds on Apple Silicon too

On startup, the container launches a **tmux** session with the chosen agent ready to go. Tmux makes it easier for you to reach a terminal whilst the agent chugs away.

## Prerequisites

- Docker (or the Apple container CLI on macOS), Git, and a subscription or API key for your chosen agent.

## Quick start

```bash
# Build and run with defaults (Dockerfile is found next to the script)
./code-it.sh --build-image

# Run an already-built image with OpenCode
./code-it.sh -o
```

```powershell
.\Code-It.ps1 -buildImage
.\Code-It.ps1 -o
```

### Using Docker directly

```bash
docker build . -t alpine-code-dotnet-dev:latest

docker run -it --rm \
    -p 3000:3000 -p 3001:3001 \
    -e CODE_AGENT=claude \
    -e GIT_AUTHOR_NAME="Agent1 for $(git config --get user.name)" \
    -e GIT_AUTHOR_EMAIL="$(git config --get user.email)" \
    -v ~/my-repos:/repos \
    -v ~/.config/code-it/.claude:/home/agent1/.claude \
    -v ~/.config/code-it/.claude.json:/home/agent1/.claude.json \
    -v ~/.config/code-it/.local/share/opencode:/home/agent1/.local/share/opencode \
    alpine-code-dotnet-dev:latest
```

## Volume mounts

The launcher scripts keep all agent state under one save dir (default `~/.config/code-it`, created on first run), so you can destroy the container and create a new one without logging in again:

| Mount point | Purpose |
|---|---|
| `/repos` | Host directory containing git repos for the agent to work on |
| `/home/agent1/.claude` | Persists Claude credentials, settings, permissions, and memory |
| `/home/agent1/.claude.json` | Persists Claude OAuth session data, MCP configs, and preferences |
| `/home/agent1/.local/share/opencode` | Persists OpenCode data and auth |

Alternatively, pass `-e ANTHROPIC_API_KEY=sk-...` (claude) or a provider API key env var (opencode) instead of mounting state.

## Launcher script options

`code-it.sh` and `Code-It.ps1` accept the same logical parameters:

| bash | PowerShell | Default | Description |
|---|---|---|---|
| `--claude`, `-c` | `-claude`, `-c` | on | Run Claude Code |
| `--opencode`, `-o` | `-opencode`, `-o` | off | Run OpenCode |
| `--work-dir` | `-WorkDirToMount` | `.` | Host path mounted at `/repos` |
| `--save-dir` | `-saveDir` | `~/.config/code-it` | Host path for agent state persistence |
| `--image` | `-image` | `alpine-code-dotnet-dev` | Image name |
| `--build-image` | `-buildImage` | off | Build the image before running |
| `--dockerfile-dir` | `-dockerfileDir` | script's directory | Directory containing the Dockerfile |
| `--runtime` | (docker only) | auto-detect | `docker` or `container` |
| `--ports` | `-portsMap` | `0:3000` `0:3001` | Port mappings (max 2); host port 0 auto-assigns |
| `--agent-name` | `-agentName` | `Agent1` | Agent name, used for git attribution; must match the Dockerfile USER |
| `--dry-run` | `-dryRun` | off | Print the run command without executing |

The scripts automatically derive the git author name and email from your environment or git config, prefixed with the agent name (e.g. `Agent1 for Your Name`).

## Tests

No container runtime needed — the tests stub `docker`/`container`/`uname` on the PATH and assert on `--dry-run` output, so they run on any machine, not just inside a container:

```bash
# Linux / macOS (runs the bash suite, then the pwsh suite if pwsh is installed)
./tests/run-all-tests.sh
```

```powershell
# Windows (or anywhere with pwsh) — the PowerShell suite alone
pwsh -NoProfile -File tests/Test-CodeIt.ps1
```

- **macOS**: `./tests/run-all-tests.sh` works with the stock bash 3.2; the Apple-container detection paths are exercised via stubs, so neither Docker nor the `container` CLI needs to be installed.
- **Windows**: run the PowerShell suite; the bash suite additionally works under Git Bash or WSL. The suite stubs docker with a `.cmd` shim and only needs `git` and PowerShell 7+.
