` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target,                                      #\
       [string]$rsa_id_path = "",                                                        #\
       [switch]$andinstall,                                                              #\
       [string]$domain = "",                                                             #\
       [string]$email = ""                                                               #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

# Usage: bootstrap-ssh.sh.ps1 <[user@]host> [<public_key_path>] [-andinstall] [-domain <www.example.com>] [-email <you@example.com>]
#
#  - copies your ssh public key to the server and checks key login works
#  - copies the server-side *.sh scripts to ~/rocky-wordpress/ and runs, in a tmux session called bootstrap:
#      rocky-bootstrap-vm.sh       : updates, automatic updates, ssh keys-only, firewall, fail2ban
#      dnf-nginx-php-mariadb-wp.sh : (only with -andinstall) nginx, php, mariadb, WordPress, https, backups
#  - user may be root, or a sudo-capable user such as the 'rocky' user of Rocky cloud images
#  - domain defaults to host, if host looks like a DNS name

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

cd "$(dirname "$0")" || exit 1
target=$1 ; shift
rsa_id_path="" ; andinstall="" ; domain="" ; email=""
while [[ $# -gt 0 ]] ; do
  case $1 in
    -andinstall|--andinstall|andinstall|1) andinstall=1 ;;
    -domain|--domain) domain=$2 ; shift ;;
    -email|--email)   email=$2 ; shift ;;
    -rsa_id_path|--rsa_id_path) rsa_id_path=$2 ; shift ;;
    -*) target="" ;;
    *) rsa_id_path=$1 ;;
  esac
  shift
done

if [[ ! "$target" =~ ^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$ ]] ; then
  echo "
  Usage: $0 <[user@]host> [<public_key_path>] [-andinstall] [-domain <www.example.com>] [-email <you@example.com>]
  "
  exit 1
fi
host=${target#*@}
[[ $target == *@* ]] && user=${target%%@*} || user=$USER
[[ -z $domain && $host == *.*[A-Za-z]* ]] && domain=$host
[[ -z $domain || $domain =~ ^[A-Za-z0-9.-]+$ ]] || { echo "bad domain $domain" ; exit 1 ; }
[[ -z $email || $email =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$ ]] || { echo "bad email $email" ; exit 1 ; }
[[ -n $rsa_id_path ]] || for k in ~/.ssh/id_ed25519.pub ~/.ssh/id_ecdsa.pub ~/.ssh/id_rsa.pub ; do
  [[ -f $k ]] && { rsa_id_path=$k ; break ; }
done
[[ -f $rsa_id_path ]] || { echo "No public key found. Create one with: ssh-keygen -t ed25519" ; exit 1 ; }
[[ $user == root ]] && sudo="" || sudo="sudo"

ssh-copy-id -i "$rsa_id_path" $target
ssh -o BatchMode=yes $target true && keyok=1 || keyok=0
[[ $keyok == 1 ]] || echo "WARNING: ssh key login didn't work, so ssh password logins will be left ON"

ssh $target "mkdir -p rocky-wordpress"
scp *.sh $target:rocky-wordpress/
ssh $target "sed -i 's/\r$//' rocky-wordpress/*.sh ; chmod u+x rocky-wordpress/*.sh ; $sudo dnf -y install tmux"

cmd="cd ~/rocky-wordpress && $sudo env KEYAUTH_VERIFIED=$keyok ./rocky-bootstrap-vm.sh"
[[ $andinstall ]] && cmd="$cmd && $sudo ./dnf-nginx-php-mariadb-wp.sh '$domain' '$email'"
ssh $target "tmux new-session -d -s bootstrap \"( $cmd ) 2>&1 | tee -a ~/rocky-wordpress/bootstrap.log ; echo Finished. ; read -p 'Press enter to close'\""

echo "
  Bootstrapping is running on $host in tmux session 'bootstrap'. It takes several minutes.
  Watch it with:   ssh $target -t tmux attach -t bootstrap
  The log is in:   ~/rocky-wordpress/bootstrap.log
"

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

Push-Location $PSScriptRoot
try {
  if(-not ($target -match "^([A-Za-z0-9._-]+@)?[A-Za-z0-9.-]+$") )
    { throw "$target doesn't look like a valid [user@]host" }
  $hostpart = $target -replace '^.*@',''
  $user = if($target -match '@'){ $target.Split('@')[0] } elseif($env:USER){ $env:USER } else { $env:USERNAME }
  if(-not $domain -and $hostpart -match '\..*[A-Za-z]'){ $domain = $hostpart }
  if($domain -and -not ($domain -match '^[A-Za-z0-9.-]+$')){ throw "bad domain $domain" }
  if($email -and -not ($email -match '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$')){ throw "bad email $email" }
  if(-not $rsa_id_path){
    $rsa_id_path = @("~/.ssh/id_ed25519.pub","~/.ssh/id_ecdsa.pub","~/.ssh/id_rsa.pub") | ?{ Test-Path $_ } | Select-Object -First 1
  }
  if(-not $rsa_id_path -or -not (Test-Path $rsa_id_path))
    { throw "No public key found. Create one with: ssh-keygen -t ed25519" }
  $sudo = if($user -eq "root"){ "" } else { "sudo" }

  $key = (Get-Content $rsa_id_path -Raw).Trim()
  ssh $target "umask 077; mkdir -p ~/.ssh; grep -qF '$key' ~/.ssh/authorized_keys 2>/dev/null || echo '$key' >> ~/.ssh/authorized_keys"
  ssh -o BatchMode=yes $target true
  $keyok = if($LASTEXITCODE -eq 0){ 1 } else { 0 }
  if(-not $keyok){ Write-Warning "ssh key login didn't work, so ssh password logins will be left ON" }

  ssh $target "mkdir -p rocky-wordpress"
  $files = Get-ChildItem *.sh | %{ $_.Name }
  scp @files "${target}:rocky-wordpress/"
  ssh $target "sed -i 's/\r$//' rocky-wordpress/*.sh ; chmod u+x rocky-wordpress/*.sh ; $sudo dnf -y install tmux"

  $cmd = "cd ~/rocky-wordpress && $sudo env KEYAUTH_VERIFIED=$keyok ./rocky-bootstrap-vm.sh"
  if($andinstall){ $cmd = "$cmd && $sudo ./dnf-nginx-php-mariadb-wp.sh '$domain' '$email'" }
  ssh $target "tmux new-session -d -s bootstrap `"( $cmd ) 2>&1 | tee -a ~/rocky-wordpress/bootstrap.log ; echo Finished. ; read -p 'Press enter to close'`""

  "
  Bootstrapping is running on $hostpart in tmux session 'bootstrap'. It takes several minutes.
  Watch it with:   ssh $target -t tmux attach -t bootstrap
  The log is in:   ~/rocky-wordpress/bootstrap.log
  "
} finally { Pop-Location }

# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities

echo "Done"
