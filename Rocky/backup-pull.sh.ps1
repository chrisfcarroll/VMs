` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target,                                      #\
       [string]$localdir = "",                                                           #\
       [switch]$now,                                                                     #\
       [int]$port = 0                                                                    #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

# Usage: backup-pull.sh.ps1 <[user@]host> [<localdir>] [-now] [-port <ssh port>]
#
#  Copies WordPress backups that this machine doesn't already have, from the server's
#  /var/backup/wordpress/ to <localdir> (default ./backups/<host>/) over ssh.
#  -now : take a fresh backup on the server first.
#  -port: the ssh port, if not 22. Default: $SSH_PORT if set, else ssh's own default (~/.ssh/config Port, or 22).
#
#  Pulling, rather than having the server push, means a compromised server holds no
#  credentials that could delete your off-server backups.
#  Schedule it with cron / launchd / Task Scheduler on a machine that's usually on.

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

target=$1 ; shift
localdir="" ; now="" ; port=""
while [[ $# -gt 0 ]] ; do
  case $1 in
    -now|--now) now=1 ;;
    -port|--port) port=$2 ; shift ;;
    -*) target="" ;;
    *) localdir=$1 ;;
  esac
  shift
done
port=${port:-$SSH_PORT}
if [[ ! "$target" =~ ^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$ || ! ( -z "$port" || "$port" =~ ^[0-9]{1,5}$ ) ]] ; then
  echo "
  Usage: $0 <[user@]host> [<localdir>] [-now] [-port <ssh port>]
  "
  exit 1
fi
host=${target#*@}
[[ $target == *@* ]] && user=${target%%@*} || user=$USER
[[ $user == root ]] && sudo="" || sudo="sudo"
localdir=${localdir:-./backups/$host}
remotedir=/var/backup/wordpress
mkdir -p "$localdir" && chmod 700 "$localdir"
sshp=() ; scpp=()
[[ $port ]] && { sshp=(-p "$port") ; scpp=(-P "$port") ; }

[[ $now ]] && ssh "${sshp[@]}" $target "$sudo systemctl start wordpress-backup.service"

for f in $(ssh "${sshp[@]}" $target "ls $remotedir/ | grep '^wordpress-.*\.tar\.gz$'") ; do
  if [[ -f $localdir/$f ]] ; then continue ; fi
  echo "$f"
  scp "${scpp[@]}" -q "$target:$remotedir/$f" "$localdir/$f.partial" && mv "$localdir/$f.partial" "$localdir/$f"
done
echo "Backups of $host in $localdir:"
ls -lt "$localdir" | head -5

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

if(-not ($target -match "^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$") )
  { throw "$target doesn't look like a valid [user@]host" }
if(-not $port -and $env:SSH_PORT){
  if($env:SSH_PORT -notmatch '^[0-9]{1,5}$'){ throw "SSH_PORT should be 1-65535" }
  $port = [int]$env:SSH_PORT
}
if($port -lt 0 -or $port -gt 65535){ throw "-port should be 1-65535" }
$hostpart = $target -replace '^.*@',''
$user = if($target -match '@'){ $target.Split('@')[0] } elseif($env:USER){ $env:USER } else { $env:USERNAME }
$sudo = if($user -eq "root"){ "" } else { "sudo" }
if(-not $localdir){ $localdir = Join-Path (Join-Path "." "backups") $hostpart }
$remotedir = "/var/backup/wordpress"
New-Item -ItemType Directory -Force $localdir | Out-Null
$sshp = if($port){ @("-p",$port) } else { @() }
$scpp = if($port){ @("-P",$port) } else { @() }

if($now){ ssh @sshp $target "$sudo systemctl start wordpress-backup.service" }

ssh @sshp $target "ls $remotedir/" | ?{ $_ -match '^wordpress-.*\.tar\.gz$' } | %{
  $local = Join-Path $localdir $_
  if(-not (Test-Path $local)){
    $_
    scp @scpp -q "${target}:$remotedir/$_" "$local.partial"
    if($LASTEXITCODE -eq 0){ Move-Item "$local.partial" $local }
  }
}
"Backups of $hostpart in ${localdir}:"
Get-ChildItem $localdir | Sort-Object LastWriteTime -Descending | Select-Object -First 5

# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities

echo "Done"
