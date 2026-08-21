<#
.SYNOPSIS
    Launches a Docker container with Alpine Linux, OpenCode, and .NET development tools.

.DESCRIPTION
    Creates and runs a Docker container for development using OpenCode as an agent. The script recognises:
    - Volume mounts for code repositories and OpenCode configuration
    - Git author environment variables or config settings (name and email)
    - Paths to preserve OpenCode configuration and state across container runs
    - Port mappings

    The script supports optional image building and port mappings. Container mounts preserve:
    - ~/.config/opencode/: Configuration and state

.PARAMETER image
    Docker image name to run. Default: "alpine-opencode-dotnet-dev"

.PARAMETER buildImage
    If specified, builds the Docker image from Dockerfile before running the container.
    Default: $false

.PARAMETER portsMap
    Array of port mappings in "host:container" format. Default: @("3000:3000","3001:3001")
    Maximum of 2 port mappings supported; additional mappings are ignored.

.PARAMETER agentName
    Name of the agent running in the container. Used for Git author attribution.
    This must match the USER set in the Dockerfile for your image.
    Default: "Agent1"

.PARAMETER WorkDirToMount
    Host directory path to mount as /vmrepos in the container. Resolved from ~/WorkDirToMount by default.

.PARAMETER imageDir
    Directory containing Dockerfiles. Used with -buildImage to locate the Dockerfile.
    Default: ~/Repos/Dockerfiles

.PARAMETER opencodeSaveDir
    Host directory to look for ./.local/share/opencode directory, for storing OpenCode 
    configuration and state volumes.
    Default: ~

.EXAMPLE
    .\OpenCode-It.ps1
    Runs the default Alpine OpenCode .NET dev container with default settings.

.EXAMPLE
    .\OpenCode-It.ps1 -buildImage -image my-custom-image -agentName "MyAgent"
    Builds the image first, then runs it with custom agent name.

.EXAMPLE
    .\OpenCode-It.ps1 -portsMap @("8000:3000", "8001:3001")
    Runs the container with custom port mappings.

.NOTES
    - Git author name and email are automatically captured from environment or git config
    - The script assumes Docker and git are installed and available
    - Volume mounts preserve OpenCode state between container runs
    - Pass provider-specific API key env vars (e.g. OPENAI_API_KEY) to avoid volume mounts for credentials

.LINK
    https://docs.docker.com/engine/reference/commandline/run/
#>

# Mount the config directory as a volume:
#
#   docker run -it -p $($portsMap[0]) -p $($portsMap[1]) `
#               -e GIT_AUTHOR_NAME=`"$agentName for $(git config --get user.name)`" `
#               -e GIT_AUTHOR_EMAIL=`"$(git config --get user.email)`" `
#               -v $VMMounts`:/vmrepos `
#               -v "$opencodeSaveDir/.local/share/opencode:/home/$agentName/.local/share/opencode" `
#           $image`:latest
#
#   $agentName must be the actual home directory (i.e. the actual user name) inside your container.

#   What the OpenCode mount preserves:
#   ┌──────────────────────────┬──────────────────────────────────────────────┐
#   │          Mount           │                   Contains                   │
#   ├──────────────────────────┼──────────────────────────────────────────────┤
#   │ ~/.config/opencode/      │ Configuration (opencode.json, agents, etc.)  │
#   ├──────────────────────────┼──────────────────────────────────────────────┤
#   │ ~/.local/share/opencode/ │ Data and auth (auth.json, etc.)              │
#   └──────────────────────────┴──────────────────────────────────────────────┘

#   Or use environment variables instead to avoid volume mounts entirely:
#   docker run -it -e OPENAI_API_KEY=your-key your-image
#   Pass a provider-specific API key env var for the simplest approach.

[CmdletBinding()]
param (
    [string]$WorkDirToMount = (Resolve-Path '.').Path,
    [string]$opencodeSaveDir= (Resolve-Path "~/.opencode-it-sessions" -EA Silent).Path  ,
    [string]$image          = "alpine-opencode-dotnet-dev",
    [switch]$buildImage     = $false,
    [string]$imageDir       ,
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
$sOpencodeSaveDir = $opencodeSaveDir
$sImageDir = $imageDir
$sImage = $image
$validImages = (docker images --format "{{.Repository}}:{{.Tag}}")
Write-Verbose ([string]::join("`n", @("    docker images") + $validImages)).ToString()

# Prompt for paths that couldn't be resolved
if ([string]::IsNullOrWhiteSpace($sWorkDirToMount)) {
    $sWorkDirToMount = Read-Host "Enter path to the working directory you want to mount in the container.
    This is the working directory you are asking OpenCode to work in, so it should contain the git repos you want to work on."
    if(-not $sWorkDirToMount -or -not (Test-Path -Path $sWorkDirToMount -EA Silent)) {
        Write-Warning "The specified WorkDirToMount does not exist: $sWorkDirToMount"
        exit 1
    }
}
$sWorkDirToMount =  (Resolve-Path $sWorkDirToMount).Path

if ($buildImage -and -not $sImageDir) {
    $sImageDir = Read-Host "Enter path to Dockerfiles directory"
    if(-not $sImageDir -or -not (Test-Path -Path $sImageDir/Dockerfile -EA Silent)) {
        Write-Warning "You asked to build the image, but the Dockerfile does not exist: $sImageDir/Dockerfile"
        exit 1
    }
    $sImageDir = (Resolve-Path $sImageDir).Path
}
if (-not $sImage) {
    $sImage = Read-Host "Specify an image to run."
    if(-not $sImage) {
        Write-Warning "No image specified. Please specify an image to run from the list above."
        exit 1
    }
}

if (-not $sOpencodeSaveDir) {
    $sOpencodeSaveDir = Read-Host "Enter path to save OpenCode data. Otherwise we will default to ~/.opencode-it-sessions"
    $sOpencodeSaveDir = $sOpencodeSaveDir,"~/.opencode-it-sessions" | Where { -not [string]::IsNullOrWhiteSpace($_) } | Select -First 1
    if(-not (Test-Path -Path $sOpencodeSaveDir)) {
        New-Item -Path $sOpencodeSaveDir -ItemType Directory
    }
}
$sOpencodeSaveDir=(Resolve-Path $sOpencodeSaveDir).Path

# Ensure required paths exist
if (-not (Test-Path -Path $sWorkDirToMount -PathType Container -EA Silent)) {
    Write-Warning "WorkDirToMount directory does not exist: $sWorkDirToMount.
    Please specify a directory where you have a git repo, or repos, you want OpenCode to work on."
    exit 1
}

"    Checking $image ..."

if ($buildImage -and -not (Test-Path -Path $sImageDir -PathType Container -EA Silent)) {
    Write-Warning "You asked for buildImage, but ImageDir directory does not exist: $sImageDir"
    exit 1
}
elseif ($buildImage -and -not (Test-Path -Path "$sImageDir/Dockerfile")) {
    Write-Warning "You asked for buildImage, but no Dockerfile not found in $sImageDir"
    exit 1

}elseif (-not $buildImage -and -not ($validImages | where { $_ -and $_.StartsWith($image) } | Select -First 1)) {
    Write-Warning "Docker image '$image' does not exist and -buildImage was not specified.
    Either build the image with -buildImage flag or ensure the image is available locally."
    exit 1
}

if (-not (Test-Path -Path $sOpencodeSaveDir -PathType Container -EA Silent)) {
    Write-Warning "OpencodeSaveDir directory does not exist: $sOpencodeSaveDir.
    Choose somewhere to save your OpenCode configuration and state, for instance ~/opencode-home.
    This directory will be mounted into the container to preserve your OpenCode state across runs."
    exit 1
}
#

#
$agentNameLower= $agentName.ToLower()
$onBehalfOf= $env:GIT_AUTHOR_NAME,$env:GIT_COMMITTER_NAME,"$(git config --get user.name)" | Select -First 1
$gitAuthorName= "$agentName for $onBehalfOf"
$gitAuthorEmail = $env:GIT_AUTHOR_EMAIL,"$(git config --get user.email)" | Select -First 1


if($buildImage){
    docker build $sImageDir -t "$image`:latest" ;
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
if($sOpencodeSaveDir -ne (Resolve-Path $sOpencodeSaveDir -EA Silent).Path){
    Write-Verbose "    OpencodeSaveDir: $(Resolve-Path $sOpencodeSaveDir -EA Silent).Path"
}

@"
    docker run -it -p $($portsMap[0]) -p $($portsMap[1]) `
                -e GIT_AUTHOR_NAME=`"$gitAuthorName`" `
                -e GIT_AUTHOR_EMAIL=`"$gitAuthorEmail`" `
                -v `"$sWorkDirToMount`:/vmrepos`" `
                -v `"$sOpencodeSaveDir/.local/share/opencode`:/home/$agentNameLower`/.local/share/opencode`" `
            $image`:latest
"@

if($dryRun){
    exit 0
}

docker run -it --rm -p $($portsMap[0]) -p $($portsMap[1]) `
            -e GIT_AUTHOR_NAME="$gitAuthorName" `
            -e GIT_AUTHOR_EMAIL="$gitAuthorEmail" `
            -v "$sWorkDirToMount`:/vmrepos" `
            -v "$sOpencodeSaveDir/.local/share/opencode:/home/$agentNameLower/.local/share/opencode" `
    $image`:latest
