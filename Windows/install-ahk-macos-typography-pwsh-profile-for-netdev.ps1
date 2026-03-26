#! pwsh

# === AutoHotKey =============================================================
$startup = Join-Path $env:AppData "Microsoft\Windows\Start Menu\Programs\Startup"
$ahkScriptName="mac-keyboard-and-prefs.ahk"
$ahkscriptTarget= Join-Path $startup $ahkScriptName

if(where.exe AutoHotKey.exe){
    "✅ AutoHotKey installed"
}
else{
    "Installing AutoHotKey ..."
    Invoke-WebRequest `
        https://www.autohotkey.com/download/ahk-v2.exe `
        -OutFile $env:TEMP/ahk-v2.exe
    & $env:TEMP/ahk-v2.exe /silent /user

    # Alternative:
    # winget install 9PLQFDG8HH9D #AutoHotKey from the windows store.
}
$ahkexe=(where.exe AutoHotKey)

if(Test-Path $ahkscriptTarget){
    "✅ AutoHotKey mac-keyboard-and-prefs.ahk installed"
}else{
    "Installing AutoHotKey Script for Mac typogrpahy"

    Invoke-WebRequest `
        "https://gist.githubusercontent.com/chrisfcarroll/f34487d88056e95a2e56b26e47c2ca42/raw/cb38b14965d1ff0dc965e3caf20c1e6bb778f18a/Autohotkey%2520V2%2520for%2520Mac%2520User%2520on%2520Mac%2520or%2520PC%2520keyboard.ahk" `
        -OutFile "$ahkscriptTarget"
}
if(Test-Path $ahkscriptTarget){
    "✅ StartUp shortcut for AutoHotKey mac-keyboard-and-prefs ..."
}else{
    "Creating StartUp shortcut to launch AutoHotKey mac-keyboard-and-prefs ..."
    $lnkPath = Join-Path $startup "$ahkScriptName.lnk"
    $wsh = New-Object -ComObject WScript.Shell
    $lnk = $wsh.CreateShortcut($lnkPath)
    $lnk.TargetPath = $ahkexe
    $lnk.Arguments  = "`"$ahkscriptTarget`""
    $lnk.WorkingDirectory = "%USERPROFILE%"
    $lnk.Save()

}

# ----------------------------------------------------------------------------

# === PowerShell Profile =====================================================

$profileDir=(Split-Path $PROFILE -Parent)

if(-not (Test-Path $PROFILE))
{
    "Installing PowerShell_profile for Dev tools, directories, git, etc."
    mkdir -p $profileDir -EA Silent
    Invoke-WebRequest `
        "https://gist.githubusercontent.com/chrisfcarroll/f3ecb2892f996149ee039d48abb57101/raw/fdcbc67b4b56102361aa7ef664a602d4008b104d/Microsoft.PowerShell_profile.ps1" `
        -OutFile $PROFILE
}
elseif(Select-String -Pattern "f3ecb2892f996149ee039d48abb57101" -Path $PROFILE)
{
    "✅ PowerShell_profile installed from https://gist.githubusercontent.com/chrisfcarroll/f3ecb2892f996149ee039d48abb57101"
}
else
{
    "❓ PowerShell_profile exists. Not Overwriting it." 
}

# ----------------------------------------------------------------------------


# === Dev Tool Installs ======================================================

if(Get-Command dotnet -EA Silent){
    "✅ DotNet CLI installed"
}else{
    Write-Warning "WinGet install DotNet-sdk-10 DotNet-sdk-8 will ask for an Admin user."
    WinGet install DotNet-sdk-10 DotNet-sdk-8
}

if(Get-Command git.exe -EA Silent){
    "✅ Git installed"
}else{
    Write-Warning "WinGet install Git.Git will ask for an Admin user."
    WinGet install Git.Git
}

if(Get-Command sublime_text.exe -EA Silent){
    "✅ SublimeText installed"
}else{
    WinGet install SublimeHQ.SublimeText.4.Portable
}

if(Get-Command code -EA Silent){
    "✅ VS Code installed"
}else{
    winget install Microsoft.VisualStudioCode `
    --override `
    "/mergetasks='!runcode,addcontextmenufiles,addcontextmenufolders,associatewithfiles,addtopath'"
}
# ----------------------------------------------------------------------------
