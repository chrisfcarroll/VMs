<#
.SYNOPSIS
    Launches a Docker container with Alpine Linux, Claude Code AND OpenCode, and .NET development tools.

.DESCRIPTION
    Creates and runs a Docker container for development using Claude Code or OpenCode as an agent.
    (The PowerShell version assumes Docker; the bash version, code-it.sh, also supports the
    Apple container CLI on macOS.)

    The script recognises:
    - Volume mounts for code repositories and agent configuration
    - Git author environment variables or config settings (name and email)
    - Paths to preserve agent credentials, settings, and session data across container runs
    - Port mappings

    The script supports optional image building and port mappings. Container mounts preserve:
    - ~/.local/share/opencode/ : OpenCode data and auth (auth.json, etc.)
    - ~/.claude/               : Claude credentials, settings, permissions, memory
    - ~/.claude.json           : Claude OAuth session data, MCP configs, preferences

.PARAMETER WorkDirToMount
    Host directory path to mount as /repos in the container. Defaults to the current directory.

.PARAMETER opencode
    Run OpenCode in the container (default). Alias: -o

.PARAMETER claude
    Run Claude Code in the container. Alias: -c

.PARAMETER saveDir
    Host directory for storing agent configuration and state volumes. Created if missing.
    Default: ~/.config/code-it

.PARAMETER image
    Docker image name to run. Default: "code-it-alpine-dotnet"

.PARAMETER buildImage
    If specified, builds the Docker image from the Dockerfile before running the container.
    Default: $false

.PARAMETER dockerfileDir
    Directory containing the Dockerfile. Used with -buildImage.
    Defaults to this script's own directory.

.PARAMETER portsMap
    Array of port mappings in "host:container" format. Default: @("0:3000","0:3001")
    A host port of 0 lets Docker auto-assign a free host port, so multiple containers
    can run at once without port collisions.
    Maximum of 2 port mappings supported; additional mappings are ignored.

.PARAMETER agentName
    Name of the agent running in the container. Used for Git author attribution and home
    directory naming. This must match the USER set in the Dockerfile for your image.
    Default: "Agent1"

.PARAMETER dryRun
    Print the docker run command without executing it.

.EXAMPLE
    .\Code-It.ps1 -claude
    Runs Claude Code in the default container mounting the current directory.

.EXAMPLE
    .\Code-It.ps1 -o -WorkDirToMount ~/my-repos
    Runs OpenCode in the default container with a custom work directory.

.EXAMPLE
    .\Code-It.ps1 -buildImage
    Builds the image from the Dockerfile next to this script, then runs it.

.EXAMPLE
    .\Code-It.ps1 -portsMap @("8000:3000", "8001:3001")
    Runs the container with custom port mappings.

.NOTES
    - Git author name and email are automatically captured from environment or git config
    - The script assumes Docker and git are installed and available
    - Volume mounts preserve both Claude and OpenCode state between container runs, so you
      can destroy the container and create a new one without logging in again
    - Alternatively, use ANTHROPIC_API_KEY (claude) or a provider API key env var (opencode)
      to avoid volume mounts for credentials

.LINK
    https://docs.docker.com/engine/reference/commandline/run/
#>

#   What each mount preserves:
#   ┌──────────────────────────┬────────────────────────────────────────────────────────────────┐
#   │          Mount           │                            Contains                            │
#   ├──────────────────────────┼────────────────────────────────────────────────────────────────┤
#   │ ~/.claude/               │ Credentials (.credentials.json), settings, permissions, memory │
#   ├──────────────────────────┼────────────────────────────────────────────────────────────────┤
#   │ ~/.claude.json           │ OAuth session data, MCP configs, theme/editor preferences      │
#   ├──────────────────────────┼────────────────────────────────────────────────────────────────┤
#   │ ~/.local/share/opencode/ │ OpenCode data and auth (auth.json, etc.)                       │
#   └──────────────────────────┴────────────────────────────────────────────────────────────────┘

[CmdletBinding()]
param (
    [string]$WorkDirToMount = (Resolve-Path '.').Path,
    [Alias('c')]
    [switch]$claude         = $false,
    [Alias('o')]
    [switch]$opencode       = $false,
    [string]$saveDir        = "$HOME/.config/code-it",
    [string]$image          = "code-it-alpine-dotnet",
    [switch]$buildImage     = $false,
    [string]$dockerfileDir  = $PSScriptRoot,
    [string[]]$portsMap     = @("0:3000","0:3001"),
    [string]$agentName      = "Agent1",
    [switch]$help           = $false,
    [switch]$dryRun         = $false
)

# Handle help request
if ($help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

# Resolve which agent to run
$codeAgent = if ($claude) { "claude" } else { "opencode" }

# Ensure required commands
if (-not (Get-Command docker -EA Silent)) {
    Write-Warning "Docker command not found. Please install Docker and ensure it is in your PATH."
    exit 1
}
if (-not (Get-Command git -EA Silent)) {
    Write-Warning "Git command not found. Please install Git and ensure it is in your PATH."
    exit 1
}

"    Using code agent: $codeAgent"

$validImages = (docker images --format "{{.Repository}}:{{.Tag}}")
Write-Verbose ([string]::join("`n", @("    docker images") + $validImages)).ToString()

# Ensure required paths exist
if (-not $WorkDirToMount -or -not (Test-Path -Path $WorkDirToMount -PathType Container -EA Silent)) {
    Write-Warning "WorkDirToMount directory does not exist: $WorkDirToMount.
    Please specify a directory where you have a git repo, or repos, you want the agent to work on."
    exit 1
}
$WorkDirToMount = (Resolve-Path $WorkDirToMount).Path

# Create the save dir structure so mounts always work, even on first run.
# The .claude.json mount is a single file: pre-create it so Docker does not
# create a directory in its place.
New-Item -ItemType Directory -Force -Path "$saveDir/.local/share/opencode"
New-Item -ItemType Directory -Force -Path "$saveDir/.claude"
if (-not (Test-Path -Path "$saveDir/.claude.json")) {
    Set-Content -Path "$saveDir/.claude.json" -Value '{}'
}
$saveDir = (Resolve-Path $saveDir).Path

"    Checking $image ..."

if ($buildImage -and -not (Test-Path -Path "$dockerfileDir/Dockerfile")) {
    Write-Warning "You asked for buildImage, but Dockerfile not found in directory: $dockerfileDir"
    exit 1
}
elseif (-not $buildImage -and -not ($validImages | Where-Object { $_ -and $_.StartsWith($image) } | Select-Object -First 1)) {
    Write-Warning "Docker image '$image' does not exist and -buildImage was not specified.
    Either build the image with -buildImage flag or ensure the image is available locally."
    exit 1
}

# Git author info
$agentNameLower = $agentName.ToLower()
$onBehalfOf = $env:GIT_AUTHOR_NAME,$env:GIT_COMMITTER_NAME,"$(git config --get user.name)" | Where-Object { $_ } | Select-Object -First 1
$gitAuthorName = "$agentName for $onBehalfOf"
$gitAuthorEmail = $env:GIT_AUTHOR_EMAIL,"$(git config --get user.email)" | Where-Object { $_ } | Select-Object -First 1

# Build image if requested
if ($buildImage) {
    docker build $dockerfileDir -t "$image`:latest"
}

# Handle port mappings
if ($portsMap.Count -gt 2) {
    Write-Warning "This script only handles two port mappings. Extra mappings will be ignored."
}
if ($portsMap.Count -lt 2) {
    $portsMap = ($portsMap + "0:3000" + "0:3001") | Select-Object -First 2
}

@"
    docker run -it --rm -p $($portsMap[0]) -p $($portsMap[1]) `
                -e CODE_AGENT=`"$codeAgent`" `
                -e GIT_AUTHOR_NAME=`"$gitAuthorName`" `
                -e GIT_AUTHOR_EMAIL=`"$gitAuthorEmail`" `
                -v `"$WorkDirToMount`:/repos`" `
                -v `"$saveDir/.claude`:/home/$agentNameLower/.claude`" `
                -v `"$saveDir/.claude.json`:/home/$agentNameLower/.claude.json`" `
                -v `"$saveDir/.local/share/opencode`:/home/$agentNameLower/.local/share/opencode`" `
            $image`:latest
"@

if ($dryRun) {
    exit 0
}

docker run -it --rm -p $($portsMap[0]) -p $($portsMap[1]) `
            -e CODE_AGENT="$codeAgent" `
            -e GIT_AUTHOR_NAME="$gitAuthorName" `
            -e GIT_AUTHOR_EMAIL="$gitAuthorEmail" `
            -v "$WorkDirToMount`:/repos" `
            -v "$saveDir/.claude:/home/$agentNameLower/.claude" `
            -v "$saveDir/.claude.json:/home/$agentNameLower/.claude.json" `
            -v "$saveDir/.local/share/opencode:/home/$agentNameLower/.local/share/opencode" `
    $image`:latest
