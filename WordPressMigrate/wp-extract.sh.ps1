` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target,                                      #\
       [string]$webroot = "/usr/share/nginx/html",                                       #\
       [string]$outdir = "",                                                             #\
       [int]$port = 0                                                                    #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

# Usage: wp-extract.sh.ps1 <[user@]oldhost> [-webroot /usr/share/nginx/html] [-outdir ./migrate] [-port <ssh port>]
#
#  Connects to the OLD WordPress server (as set up by ../CentOs) and copies back, as one
#  wordpress-migrate-<host>-<time>.tar.gz : the database, wp-content (themes, plugins, media),
#  wp-config.php and a site-info.txt summary. The old server is not changed.
#  Then load it into the new server with wp-load.sh.ps1
#
#  -port: the old server's ssh port, if not 22. Default: $SSH_PORT if set, else ssh's own default (~/.ssh/config Port, or 22).
#  user must be root, or able to sudo. The archive contains secrets: keep it private.

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

here=$(cd "$(dirname "$0")" && pwd)
target=$1 ; shift
webroot=/usr/share/nginx/html ; outdir="" ; port=""
while [[ $# -gt 0 ]] ; do
  case $1 in
    -webroot|--webroot) webroot=$2 ; shift ;;
    -outdir|--outdir)   outdir=$2 ; shift ;;
    -port|--port)       port=$2 ; shift ;;
    *) target="" ;;
  esac
  shift
done
port=${port:-$SSH_PORT}
if [[ ! "$target" =~ ^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$ || ! "$webroot" =~ ^/[A-Za-z0-9._/-]+$ \
      || ! ( -z "$port" || "$port" =~ ^[0-9]{1,5}$ ) ]] ; then
  echo "
  Usage: $0 <[user@]oldhost> [-webroot /usr/share/nginx/html] [-outdir ./migrate] [-port <ssh port>]
  "
  exit 1
fi
host=${target#*@}
[[ $target == *@* ]] && user=${target%%@*} || user=$USER
[[ $user == root ]] && sudo="" || sudo="sudo"
outdir=${outdir:-./migrate}
name=wordpress-migrate-$host-$(date -u +%Y%m%dT%H%M%SZ).tar.gz
remote=/var/tmp/$name
mkdir -p "$outdir" && chmod 700 "$outdir"
sshp=() ; scpp=()
[[ $port ]] && { sshp=(-p "$port") ; scpp=(-P "$port") ; }

scp "${scpp[@]}" "$here/wp-extract-on-server.sh" "$target:wp-extract-on-server.sh" || exit 1
ssh "${sshp[@]}" -t $target "sed -i 's/\r$//' ~/wp-extract-on-server.sh ; $sudo bash ~/wp-extract-on-server.sh '$webroot' '$remote' ; rc=\$? ; rm -f ~/wp-extract-on-server.sh ; exit \$rc" \
  || { echo "Extract failed on $host" ; exit 1 ; }
scp "${scpp[@]}" "$target:$remote" "$outdir/$name" || { echo "Copy back failed. The archive is still on $host at $remote" ; exit 1 ; }
chmod 600 "$outdir/$name"
ssh "${sshp[@]}" $target "$sudo rm -f '$remote'"

echo "
  Extracted to: $outdir/$name
  Next:         wp-load.sh.ps1 <[user@]newhost> $outdir/$name [-url https://www.example.com] [-port <ssh port>]
"

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

if(-not ($target -match "^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$") )
  { throw "$target doesn't look like a valid [user@]host" }
if(-not ($webroot -match "^/[A-Za-z0-9._/-]+$") )
  { throw "$webroot doesn't look like an absolute path" }
if(-not $port -and $env:SSH_PORT){
  if($env:SSH_PORT -notmatch '^[0-9]{1,5}$'){ throw "SSH_PORT should be 1-65535" }
  $port = [int]$env:SSH_PORT
}
if($port -lt 0 -or $port -gt 65535){ throw "-port should be 1-65535" }
$hostpart = $target -replace '^.*@',''
$user = if($target -match '@'){ $target.Split('@')[0] } elseif($env:USER){ $env:USER } else { $env:USERNAME }
$sudo = if($user -eq "root"){ "" } else { "sudo" }
if(-not $outdir){ $outdir = Join-Path "." "migrate" }
$name = "wordpress-migrate-$hostpart-$((Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')).tar.gz"
$remote = "/var/tmp/$name"
New-Item -ItemType Directory -Force $outdir | Out-Null
$sshp = if($port){ @("-p",$port) } else { @() }
$scpp = if($port){ @("-P",$port) } else { @() }

scp @scpp (Join-Path $PSScriptRoot "wp-extract-on-server.sh") "${target}:wp-extract-on-server.sh"
if($LASTEXITCODE -ne 0){ throw "Couldn't copy wp-extract-on-server.sh to $hostpart" }
ssh @sshp -t $target "sed -i 's/\r$//' ~/wp-extract-on-server.sh ; $sudo bash ~/wp-extract-on-server.sh '$webroot' '$remote' ; rc=`$? ; rm -f ~/wp-extract-on-server.sh ; exit `$rc"
if($LASTEXITCODE -ne 0){ throw "Extract failed on $hostpart" }
$local = Join-Path $outdir $name
scp @scpp "${target}:$remote" $local
if($LASTEXITCODE -ne 0){ throw "Copy back failed. The archive is still on $hostpart at $remote" }
ssh @sshp $target "$sudo rm -f '$remote'"

"
  Extracted to: $local
  Next:         wp-load.sh.ps1 <[user@]newhost> $local [-url https://www.example.com] [-port <ssh port>]
"

# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities

echo "Done"
