<#
.SYNOPSIS
    Launches a Docker container with Alpine Linux, Claude API access, and .NET development tools.

.DESCRIPTION
    Creates and runs a Docker container for development using Claude as an agent. The script recognises:
    - Volume mounts for code repositories and Claude configuration
    - Git author environment variables or config settings (name and email)
    - Paths to preserve Claude credentials, settings, and session data across container runs
    - Port mappings

    The script supports optional image building and port mappings. Container mounts preserve:
    - ~/.claude/: Credentials and settings
    - ~/.claude.json: OAuth session data and MCP configurations

.PARAMETER image
    Docker image name to run. Default: "alpine-claude-dotnet-dev"

.PARAMETER buildImage
    If specified, builds the Docker image from Dockerfile before running the container.
    Default: $false

.PARAMETER portsMap
    Array of port mappings in "host:container" format. Default: @("3000:3000","3001:3001")
    Maximum of 2 port mappings supported; additional mappings are ignored.

.PARAMETER agentName
    Name of the agent running in the container. Used for Git author attribution and .claude directory naming.
    Default: "AgentC"

.PARAMETER RepoMounts
    Host directory path to mount as /vmrepos in the container. Resolved from ~/RepoMounts by default.

.PARAMETER imageDir
    Directory containing Dockerfiles. Used with -buildImage to locate the Dockerfile.
    Default: ~/Repos/Dockerfiles

.PARAMETER claudeSaveDir
    Host directory for storing Claude configuration and state volumes.
    Default: ~/RepoMounts/claude-home

.EXAMPLE
    .\Claude-It.ps1
    Runs the default Alpine Claude .NET dev container with default settings.

.EXAMPLE
    .\Claude-It.ps1 -buildImage -image my-custom-image -agentName "MyAgent"
    Builds the image first, then runs it with custom agent name.

.EXAMPLE
    .\Claude-It.ps1 -portsMap @("8000:3000", "8001:3001")
    Runs the container with custom port mappings.

.NOTES
    - Git author name and email are automatically captured from environment or git config
    - The script assumes Docker and git are installed and available
    - Volume mounts preserve Claude state between container runs
    - Alternatively, use ANTHROPIC_API_KEY environment variable to avoid volume mounts for credentials

.LINK
    https://docs.docker.com/engine/reference/commandline/run/
#>

# Mount these two directories/files as volumes:
#
#   docker run -it -p $($portsMap[0]) -p $($portsMap[1]) `
#               -e GIT_AUTHOR_NAME=`"AgentC for $(git config --get user.name)`" `
#               -e GIT_AUTHOR_EMAIL=`"$(git config --get user.email)`" `
#               -v $VMMounts`:/vmrepos `
#               -v "$claudeSaveDir\claude-home\.claude:/home/agentc/.claude" `
#               -v "$claudeSaveDir\claude-home\.claude.json:/home/agentc/.claude.json" `
#           $image`:latest
#
#   Replace /home/user/ with the actual home directory inside your container (e.g., /root if running as root).

#   What each Claude mount preserves:
#   ┌────────────────┬────────────────────────────────────────────────────────────────┐
#   │     Mount      │                            Contains                            │
#   ├────────────────┼────────────────────────────────────────────────────────────────┤
#   │ ~/.claude/     │ Credentials (.credentials.json), settings, permissions, memory │
#   ├────────────────┼────────────────────────────────────────────────────────────────┤
#   │ ~/.claude.json │ OAuth session data, MCP configs, theme/editor preferences      │
#   └────────────────┴────────────────────────────────────────────────────────────────┘

#   Or use environment variables instead to avoid volume mounts entirely:
#   docker run -it -e ANTHROPIC_API_KEY=your-key your-image
#   The ANTHROPIC_API_KEY env var is the simplest approach if you're using an API key rather than OAuth/subscription login.

[CmdletBinding()]
param (
    [string]$image         = "alpine-claude-dotnet-dev",
    [switch]$buildImage    = $false,
    [string[]]$portsMap    = @("3000:3000","3001:3001"),
    [string]$agentName     = "AgentC",
    [string]$RepoMounts    = (Resolve-Path ~/RepoMounts -EA Silent),
    [string]$imageDir      = (Resolve-Path ~/Repos/Dockerfiles -EA Silent),
    [string]$claudeSaveDir = (Resolve-Path ~/RepoMounts/claude-home -EA Silent),
    [switch]$help          = $false

)

# Handle help request
if ($help) {
    Get-Help $PSCommandPath -Full
    exit 0
}

# Ensure required commands
if (-not (Get-Command docker -EA Silent)) {
    Write-Warning "Docker command not found. Please install Docker and ensure it is in your PATH."
    exit 1
}
if (-not (Get-Command git -EA Silent)) {
    Write-Warning "Git command not found. Please install Git and ensure it is in your PATH."
    exit 1
}

# Ensure required paths exist
if (-not (Test-Path -Path $RepoMounts -PathType Container)) {
    Write-Warning "RepoMounts directory does not exist: $RepoMounts. 
    Please specify a directory where you have a git repo, or repos, you want Claude to work on."
    exit 1
}

if ($buildImage -and -not (Test-Path -Path $imageDir -PathType Container)) {
    Write-Warning "You asked for buildImage, but ImageDir directory does not exist: $imageDir"
    exit 1
}
elseif ($buildImage -and -not (Test-Path -Path "$imageDir/$image/Dockerfile")) {
    Write-Warning "You asked for buildImage, but Dockerfile not found at: $imageDir/$image/Dockerfile"
    exit 1

}elseif (-not $buildImage -and -not (docker image inspect "$($image):latest" 2>$null)) {
    Write-Warning "Docker image '$image:latest' does not exist and -buildImage was not specified.
    Either build the image with -buildImage flag or ensure the image is available locally."
    exit 1
}

if (-not (Test-Path -Path $claudeSaveDir -PathType Container)) {
    Write-Warning "ClaudeSaveDir directory does not exist: $claudeSaveDir. 
    Choose somewhere to save your Claude credentials and session data, for instance ~/claude-home.
    This directory will be mounted into the container to preserve your Claude state across runs."
    exit 1
}
#

#
$agentNameLower= $agentName.ToLower()
$onBehalfOf= $env:GIT_AUTHOR_NAME,$env:GIT_COMMITTER_NAME,"$(git config --get user.name)" | Select -First 1
$gitAuthorName= "$agentNameLower for $onBehalfOf"
$gitAuthorEmail = $env:GIT_AUTHOR_EMAIL,"$(git config --get user.email)" | Select -First 1


if($buildImage -and (Test-Path -Path "$imageDir/$image/Dockerfile")){ 
    docker build $imageDir/$image -t "$($image):latest" ; 
}

if($portsMap.Count -gt 2){ 
    Write-Warning "This script only handles two port mappings. Extra mappings will be ignored."
}

if($portsMap.Count -lt 2){ 
    $portsMap = $portsMap,"3000:3000","3001:3001" | Select -First 2
}

Write-Host @"
    docker run -it -p $($portsMap[0]) -p $($portsMap[1]) `
                -e GIT_AUTHOR_NAME=`"$gitAuthorName`" `
                -e GIT_AUTHOR_EMAIL=`"$gitAuthorEmail`" `
                -v `"$RepoMounts`:/vmrepos`" `
                -v `"$claudeSaveDir/claude-home/.claude`:/home/$agentNameLower`/.claude`" `
                -v `"$claudeSaveDir/claude-home/.claude.json`:/home/$agentNameLower`/.claude.json`" `
            $image`:latest
"@

docker run -it -p $($portsMap[0]) -p $($portsMap[1]) `
            -e GIT_AUTHOR_NAME="$gitAuthorName" `
            -e GIT_AUTHOR_EMAIL="$gitAuthorEmail" `
            -v "$RepoMounts`:/vmrepos" `
            -v "$claudeSaveDir/claude-home/.claude:/home/$agentNameLower/.claude" `
            -v "$claudeSaveDir/claude-home/.claude.json:/home/$agentNameLower/.claude.json" `
    $image`:latest




