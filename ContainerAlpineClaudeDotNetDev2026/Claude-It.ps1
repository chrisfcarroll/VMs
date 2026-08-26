#! /usr/bin/env pwsh
<#
.SYNOPSIS
    Launches a Docker container with Alpine Linux, Claude code, and .NET development tools.

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
    Array of port mappings in "host:container" format. 
    Default: @("0:3000","0:3001"), which lets Docker choose the next free host ports to map to ports 3000,3001 in the container
    A maximum of 2 port mappings supported; additional mappings are ignored.

.PARAMETER agentName
    Name of the agent running in the container. Used for Git author attribution and .claude directory naming.
    This must match the USER set in the Dockerfile for your image.
    Default: "Agent1"

.PARAMETER WorkDirToMount
    Host directory path to mount as /repos in the container.
    Default: "."

.PARAMETER imageDir
    Directory containing the Dockerfile. Used with -buildImage to locate the Dockerfile.
    Defaults to the script's own directory.

.PARAMETER claudeSaveDir
    Host directory for storing Claude configuration and state volumes.
    Default: "~/.claude-it-sessions"

.EXAMPLE
    .\Claude-It.ps1
    Runs the default Alpine Claude .NET dev container with default settings, mapping the current 
    directory to /repos

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
#   docker run -it --rm -p $($portsMap[0]) -p $($portsMap[1]) `
#               -e GIT_AUTHOR_NAME=`"$agentName for $(git config --get user.name)`" `
#               -e GIT_AUTHOR_EMAIL=`"$(git config --get user.email)`" `
#               -v "$WorkDirToMount`:/repos" `
#               -v "$claudeSaveDir/.claude:/home/$($agentName.ToLower())/.claude" `
#               -v "$claudeSaveDir/.claude.json:/home/$($agentName.ToLower())/.claude.json" `
#           $image`:latest
#
#   $agentName must be the actual home directory (i.e. the actual user name) inside your container.

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
    [string]$WorkDirToMount = (Resolve-Path '.').Path,
    [string]$claudeSaveDir  = "$HOME/.claude-it-sessions",
    [string]$image          = "alpine-claude-dotnet-dev",
    [switch]$buildImage     = $false,
    [string]$imageDir       = $PSScriptRoot,
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

# Ensure required commands
if (-not (Get-Command docker -EA Silent)) {
    Write-Warning "Docker command not found. Please install Docker and ensure it is in your PATH."
    exit 1
}
if (-not (Get-Command git -EA Silent)) {
    Write-Warning "Git command not found. Please install Git and ensure it is in your PATH."
    exit 1
}


#abbreviations for $script:<varname> which is mutable, unlike the param variables which are read-only. So we can prompt the user for missing values.
$sWorkDirToMount = $WorkDirToMount
$sClaudeSaveDir = $claudeSaveDir
$sImageDir = $imageDir
$sImage = $image
$validImages = (docker images --format "{{.Repository}}:{{.Tag}}")
Write-Verbose ([string]::join("`n", @("    docker images") + $validImages)).ToString()

# Prompt for paths that couldn't be resolved
if ([string]::IsNullOrWhiteSpace($sWorkDirToMount)) {
    $sWorkDirToMount = Read-Host "Enter path to the working directory you want to mount in the container.
    This is the working directory you are asking Claude to work in, so it should contain the git repos you want to work on."
    if(-not $sWorkDirToMount -or -not (Test-Path -Path $sWorkDirToMount -EA Silent)) {
        Write-Warning "The specified WorkDirToMount does not exist: $sWorkDirToMount"
        exit 1
    }
}
$sWorkDirToMount =  (Resolve-Path $sWorkDirToMount).Path

if ($buildImage) {
    $sImageDir = (Resolve-Path $sImageDir).Path
}
if (-not $sImage) {
    $sImage = Read-Host "Specify an image to run."
    if(-not $sImage) {
        Write-Warning "No image specified. Please specify an image to run from the list above."
        exit 1
    }
}

# Create the save dir structure so mounts always work, even on first run.
# The .claude.json mount is a single file: pre-create it so the runtime does not
# create a directory in its place.
New-Item -ItemType Directory -Force -Path "$sClaudeSaveDir/.claude" | Out-Null
if (-not (Test-Path -Path "$sClaudeSaveDir/.claude.json")) {
    Set-Content -Path "$sClaudeSaveDir/.claude.json" -Value '{}'
}
$sClaudeSaveDir=(Resolve-Path $sClaudeSaveDir).Path

# Ensure required paths exist
if (-not (Test-Path -Path $sWorkDirToMount -PathType Container -EA Silent)) {
    Write-Warning "WorkDirToMount directory does not exist: $sWorkDirToMount. 
    Please specify a directory where you have a git repo, or repos, you want Claude to work on."
    exit 1
}

"    Checking $image ..."

if ($buildImage -and -not (Test-Path -Path $sImageDir -PathType Container -EA Silent)) {
    Write-Warning "You asked for buildImage, but ImageDir directory does not exist: $sImageDir"
    exit 1
}
elseif ($buildImage -and -not (Test-Path -Path "$sImageDir/Dockerfile")) {
    Write-Warning "You asked for buildImage, but no Dockerfile found in $sImageDir"
    exit 1

}elseif (-not $buildImage -and -not ($validImages | where { $_ -and ($_ -eq $image -or $_.StartsWith("${image}:")) } | Select -First 1)) {
    Write-Warning "Docker image '$image' does not exist and -buildImage was not specified.
    Either build the image with -buildImage flag or ensure the image is available locally."
    exit 1
}

if (-not (Test-Path -Path $sClaudeSaveDir -PathType Container -EA Silent)) {
    Write-Warning "ClaudeSaveDir directory does not exist: $sClaudeSaveDir.
    Choose somewhere to save your Claude credentials and session data, for instance ~/claude-home.
    This directory will be mounted into the container to preserve your Claude state across runs."
    exit 1
}
#

#
$agentNameLower= $agentName.ToLower()
$onBehalfOf= $env:GIT_AUTHOR_NAME,$env:GIT_COMMITTER_NAME,"$(git config --get user.name)" | Where-Object { $_ } | Select -First 1
$gitAuthorName= "$agentName for $onBehalfOf"
$gitAuthorEmail = $env:GIT_AUTHOR_EMAIL,"$(git config --get user.email)" | Where-Object { $_ } | Select -First 1


if($buildImage){
    docker build "$sImageDir" -t "$image`:latest"
}

if($portsMap.Count -gt 2){
    Write-Warning "This script only handles two port mappings. Extra mappings will be ignored."
}

if($portsMap.Count -lt 2){
    $portsMap = ($portsMap + "0:3000" + "0:3001") | Select -First 2
}


if($sWorkDirToMount -ne (Resolve-Path $sWorkDirToMount -EA Silent).Path){
    Write-Verbose "    WorkDirToMount: $(Resolve-Path $sWorkDirToMount -EA Silent).Path"
}
if($sClaudeSaveDir -ne (Resolve-Path $sClaudeSaveDir -EA Silent).Path){
    Write-Verbose "    ClaudeSaveDir: $(Resolve-Path $sClaudeSaveDir -EA Silent).Path"
}

@"
    docker run -it --rm -p $($portsMap[0]) -p $($portsMap[1]) `
                -e GIT_AUTHOR_NAME=`"$gitAuthorName`" `
                -e GIT_AUTHOR_EMAIL=`"$gitAuthorEmail`" `
                -v `"$sWorkDirToMount`:/repos`" `
                -v `"$sClaudeSaveDir/.claude`:/home/$agentNameLower`/.claude`" `
                -v `"$sClaudeSaveDir/.claude.json`:/home/$agentNameLower`/.claude.json`" `
            $image`:latest
"@

if($dryRun){
    exit 0
}

docker run -it --rm -p $($portsMap[0]) -p $($portsMap[1]) `
            -e GIT_AUTHOR_NAME="$gitAuthorName" `
            -e GIT_AUTHOR_EMAIL="$gitAuthorEmail" `
            -v "$sWorkDirToMount`:/repos" `
            -v "$sClaudeSaveDir/.claude:/home/$agentNameLower/.claude" `
            -v "$sClaudeSaveDir/.claude.json:/home/$agentNameLower/.claude.json" `
    $image`:latest
