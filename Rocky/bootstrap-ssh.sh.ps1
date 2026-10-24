` # \
# PowerShell Param statement : every line must end in #\ except the last line must with <#\
# And, you ___can't use backticks___ in this section                                     #\
param( [Parameter(Mandatory=$true)][string]$target,                                      #\
       [string]$rsa_id_path = (Resolve-Path ~/.ssh/id_rsa.pub).Path,                     #\
       [switch]$andinstall                                                               #\
     )                                                                                  <#\
#^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ `

#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Bash Start ------------------------------------------------------------

target=$1
rsa_id_path=${2:-"~/.ssh/id_rsa.pub"}
andinstall=${3:-1}

ssh-copy-id $target
scp rocky-*.sh dnf-*.sh $target:
ssh $target "dnf -y install tmux"
ssh $target -t "tmux new-session -d -s dnf-bootstrap 'dnf -y upgrade ; dnf -y install dnf-plugins-core dnf-automatic cronie'"

if [[ $andinstall ]] ; then
  echo "Continuing with nginx,php,wp install...

  NB: this process will stall for several minutes waiting for dnf upgrade to complete.
  Attach to it with: ssh $target -t tmux attach -t bootstrap-install
  "
  ssh $target "tmux new-session -d -s bootstrap-install './rocky-bootstrap-vm.sh && ./dnf-nginx-php-mariadb-wp.sh'"
fi

# Bash End --------------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
echo > /dev/null <<"out-null" ###
'@ | out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Powershell Start ----------------------------------------------------#>

if(-not (test-path $rsa_id_path))
  { throw "$rsa_id_path not found" }
if(-not ($target -match "^[A-Za-z0-9\.-]+@[A-Za-z0-9\.-]+$") )
  { throw "$target doesn't look like a valid user@host" }


cat $rsa_id_path | ssh $target "mkdir -p ~/.ssh; cat >> ~/.ssh/authorized_keys"
ls rocky-*.sh,dnf-*.sh | %{
  "Copying $_ ..."
  cat $_ | ssh $target "cat -> $($_.BaseName)$($_.Extension) ; chmod ug+rx $($_.BaseName)$($_.Extension) ; sed -i 's/\r//' *.sh"
}

ssh $target "dnf -y install tmux"
ssh $target -t "tmux new-session -d -s dnf-bootstrap 'dnf -y upgrade ; dnf -y install dnf-plugins-core dnf-automatic cronie'"

if($andinstall){
  "Continuing with nginx,php,wp install...

  NB: this process will stall for several minutes waiting for dnf upgrade to complete.
  Attach to it with: ssh $target -t tmux attach -t bootstrap-install
  "
  ssh $target "tmux new-session -d -s bootstrap-install './rocky-bootstrap-vm.sh && ./dnf-nginx-php-mariadb-wp.sh'"
}

# Powershell End -------------------------------------------------------
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
out-null
#vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# Both Bash and Powershell run the rest but with limited capabilities

echo "Done"
