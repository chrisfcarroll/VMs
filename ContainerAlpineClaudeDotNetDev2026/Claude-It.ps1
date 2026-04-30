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

.PARAMETER WorkDirToMount
    Host directory path to mount as /vmrepos in the container. Resolved from ~/WorkDirToMount by default.

.PARAMETER imageDir
    Directory containing Dockerfiles. Used with -buildImage to locate the Dockerfile.
    Default: ~/Repos/Dockerfiles

.PARAMETER claudeSaveDir
    Host directory for storing Claude configuration and state volumes.
    Default: ~/WorkDirToMount/claude-home

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
    [string]$WorkDirToMount ,
    [string]$claudeSaveDir  ,
    [string]$image          = "alpine-claude-dotnet-dev",
    [switch]$buildImage     = $false,
    [string]$imageDir       ,
    [string[]]$portsMap     = @("3000:3000","3001:3001"),
    [string]$agentName      = "AgentC",
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
if (-not $sWorkDirToMount) {
    $sWorkDirToMount = Read-Host "Enter path to the working directory you want to mount in the container.
    This is the working directory you are asking Claude to work in, so it should contain the git repos you want to work on."
    if(-not $sWorkDirToMount -or -not (Test-Path -Path $sWorkDirToMount -EA Silent)) {
        Write-Warning "The specified WorkDirToMount does not exist: $sWorkDirToMount"
        exit 1
    }
}

if ($buildImage -and -not $sImageDir) {
    $sImageDir = Read-Host "Enter path to Dockerfiles directory"
    if(-not $sImageDir -or -not (Test-Path -Path $sImageDir/$image -EA Silent)) {
        Write-Warning "You asked to build the image, but the Dockerfile does not exist: $sImageDir/$image"
        exit 1
    }
}
if (-not $sImage) {
    $sImage = Read-Host "Specify an image to run."
    if(-not $sImage) {
        Write-Warning "No image specified. Please specify an image to run from the list above."
        exit 1
    }
}


if (-not $sClaudeSaveDir) {
    $sClaudeSaveDir = Read-Host "Enter path to save Claude data. Otherwise we will default to ~/claude-savesessions"
    $sClaudeSaveDir = $sClaudeSaveDir,"~/claude-savesessions" | Where { -not [string]::IsNullOrWhiteSpace($_) } | Select -First 1
    if(-not (Test-Path -Path $sClaudeSaveDir)) {
        New-Item -Path $sClaudeSaveDir -ItemType Directory
    }
}

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
elseif ($buildImage -and -not (Test-Path -Path "$sImageDir/$image/Dockerfile")) {
    Write-Warning "You asked for buildImage, but Dockerfile not found at: $sImageDir/$image/Dockerfile"
    exit 1

}elseif (-not $buildImage -and -not ($validImages | where { $_ -and $_.StartsWith($image) } | Select -First 1)) {
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
$onBehalfOf= $env:GIT_AUTHOR_NAME,$env:GIT_COMMITTER_NAME,"$(git config --get user.name)" | Select -First 1
$gitAuthorName= "$agentName for $onBehalfOf"
$gitAuthorEmail = $env:GIT_AUTHOR_EMAIL,"$(git config --get user.email)" | Select -First 1


if($buildImage){
    docker build $sImageDir/$image -t "$($image):latest" ;
}

if($portsMap.Count -gt 2){
    Write-Warning "This script only handles two port mappings. Extra mappings will be ignored."
}

if($portsMap.Count -lt 2){
    $portsMap = $portsMap,"3000:3000","3001:3001" | Select -First 2
}


if($sWorkDirToMount -ne (Resolve-Path $sWorkDirToMount -EA Silent).Path){
    Write-Verbose "    WorkDirToMount: $(Resolve-Path $sWorkDirToMount -EA Silent).Path"
}
if($sClaudeSaveDir -ne (Resolve-Path $sClaudeSaveDir -EA Silent).Path){
    Write-Verbose "    ClaudeSaveDir: $(Resolve-Path $sClaudeSaveDir -EA Silent).Path"
}

@"
    docker run -it -p $($portsMap[0]) -p $($portsMap[1]) `
                -e GIT_AUTHOR_NAME=`"$gitAuthorName`" `
                -e GIT_AUTHOR_EMAIL=`"$gitAuthorEmail`" `
                -v `"$sWorkDirToMount`:/vmrepos`" `
                -v `"$sClaudeSaveDir/.claude`:/home/$agentNameLower`/.claude`" `
                -v `"$sClaudeSaveDir/.claude.json`:/home/$agentNameLower`/.claude.json`" `
            $image`:latest
"@

if($dryRun){
    exit 0
}

docker run -it -p $($portsMap[0]) -p $($portsMap[1]) `
            -e GIT_AUTHOR_NAME="$gitAuthorName" `
            -e GIT_AUTHOR_EMAIL="$gitAuthorEmail" `
            -v "$sWorkDirToMount`:/vmrepos" `
            -v "$sClaudeSaveDir/.claude:/home/$agentNameLower/.claude" `
            -v "$sClaudeSaveDir/.claude.json:/home/$agentNameLower/.claude.json" `
    $image`:latest
