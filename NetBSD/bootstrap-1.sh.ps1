` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target,                                      #\
       [string]$rsa_id_path = (Resolve-Path ~/.ssh/id_rsa.pub).Path                      #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

target=$1
rsa_id_path=${2:-"~/.ssh/id_rsa.pub"}

if [[ ! "$target" =~ ^([A-Za-z0-9\\.-]+@)?[A-Za-z0-9\\.-]+$ ]] ; then
  echo "
  Usage: $0 <[targetlogin@]targetmachine>  [ <rsa_id_path> ]
  "
  exit 1
fi
ssh-copy-id $target
scp netbsd-* $target:
ssh $target 'su - root -ic "set -x ; mv /home/\$SU_FROM/*.sh \$HOME/"'

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

if(-not (test-path $rsa_id_path))
  { throw "$rsa_id_path not found" }
if(-not ($target -match "^([A-Za-z0-9\.-]+@)?[A-Za-z0-9\.-]+$") )
  { throw "$target doesn't look like a valid user@host" }


cat $rsa_id_path | ssh $target "mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
Get-ChildItem netbsd-* | %{
  $f="$($_.BaseName)$($_.Extension)"
  "Copying $_ ..."
  cat $_ | ssh $target "cat -> $f ; chmod ug+rx $f ; sed -i 's/\\r//' $f" 
}
ssh $target $cmd
ssh $target 'su - root -ic \"set -x ; mv /home/\$SU_FROM/*.sh \$HOME/\"'

# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities


echo "Done.
***
Note these scripts assume a standard (in 2019 / NetBSD 8.1) install of NetBSD with
these choices made during setup:
***
- network working
- sshd enabled
- pkgin enabled (and optionally, pkgsrc enabled)
- root password is left blank and ssh to root is not possible
- added user as member of wheel"
