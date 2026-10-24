` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target,                                      #\
       [Parameter(Mandatory=$true)][string]$archive,                                     #\
       [string]$url = "",                                                                #\
       [int]$port = 0                                                                    #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

# Usage: wp-load.sh.ps1 <[user@]newhost> <wordpress-migrate-....tar.gz> [-url https://www.example.com] [-port <ssh port>]
#
#  Loads an archive made by wp-extract.sh.ps1 into the NEW server, which must already have been
#  set up with: ../Rocky/bootstrap-ssh.sh.ps1 <[user@]newhost> -andinstall
#  The new site is backed up first, so ../Rocky/backup-restore.sh.ps1 can undo it.
#
#  -url : the new site's address. Default: whatever the new server was set up with.
#         The old site's urls in posts, settings, menus etc are rewritten to it.
#  -port : the new server's ssh port, if not 22. Default: $SSH_PORT if set, else ssh's own default (~/.ssh/config Port, or 22).

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

here=$(cd "$(dirname "$0")" && pwd)
target=$1 ; archive=$2 ; shift 2
url="" ; port=""
while [[ $# -gt 0 ]] ; do
  case $1 in
    -url|--url) url=$2 ; shift ;;
    -port|--port) port=$2 ; shift ;;
    *) target="" ;;
  esac
  shift
done
port=${port:-$SSH_PORT}
if [[ ! "$target" =~ ^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$ || ! -f "$archive" \
      || ! ( -z "$url" || "$url" =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?/?$ ) \
      || ! ( -z "$port" || "$port" =~ ^[0-9]{1,5}$ ) ]] ; then
  echo "
  Usage: $0 <[user@]newhost> <wordpress-migrate-....tar.gz> [-url https://www.example.com] [-port <ssh port>]
  "
  exit 1
fi
[[ $target == *@* ]] && user=${target%%@*} || user=$USER
[[ $user == root ]] && sudo="" || sudo="sudo"
name=$(basename "$archive")
sshp=() ; scpp=()
[[ $port ]] && { sshp=(-p "$port") ; scpp=(-P "$port") ; }

scp "${scpp[@]}" "$here/wp-load-on-server.sh" "$archive" "$target:" || exit 1
ssh "${sshp[@]}" -t $target "sed -i 's/\r$//' ~/wp-load-on-server.sh ; $sudo bash ~/wp-load-on-server.sh ~/'$name' '$url' ; rc=\$? ; rm -f ~/wp-load-on-server.sh ~/'$name' ; exit \$rc"

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

if(-not ($target -match "^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$") )
  { throw "$target doesn't look like a valid [user@]host" }
if(-not (Test-Path $archive)){ throw "$archive not found" }
if($url -and -not ($url -match '^https?://[A-Za-z0-9.-]+(:[0-9]+)?/?$')){ throw "-url should look like https://www.example.com" }
if(-not $port -and $env:SSH_PORT){
  if($env:SSH_PORT -notmatch '^[0-9]{1,5}$'){ throw "SSH_PORT should be 1-65535" }
  $port = [int]$env:SSH_PORT
}
if($port -lt 0 -or $port -gt 65535){ throw "-port should be 1-65535" }
$user = if($target -match '@'){ $target.Split('@')[0] } elseif($env:USER){ $env:USER } else { $env:USERNAME }
$sudo = if($user -eq "root"){ "" } else { "sudo" }
$name = Split-Path $archive -Leaf
$sshp = if($port){ @("-p",$port) } else { @() }
$scpp = if($port){ @("-P",$port) } else { @() }

scp @scpp (Join-Path $PSScriptRoot "wp-load-on-server.sh") $archive "${target}:"
if($LASTEXITCODE -ne 0){ throw "Couldn't copy files to $target" }
ssh @sshp -t $target "sed -i 's/\r$//' ~/wp-load-on-server.sh ; $sudo bash ~/wp-load-on-server.sh ~/'$name' '$url' ; rc=`$? ; rm -f ~/wp-load-on-server.sh ~/'$name' ; exit `$rc"

# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities

echo "Done"
