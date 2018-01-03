#
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
echo "=================================================="
echo "$BASH_SOURCE : Bootstrapping commandline preferences and basic security on $HOSTNAME"
echo '
  Basic security = yum updates and cron, firewalld, and fail2ban for sshd
'
echo "=================================================="

function pausemax { read -t $1 -p "$2 Wait $1 seconds, or press any key to continue ..." ; }

echo "bash preferences ..."

  [ -f .bashrc ] || touch .bashrc
  sed -ir 's!^alias \(rm\|cp\|mv\).*!!' ~/.bashrc

  printf '
# Avoid darkblue because some of use use darkblue background for powershell shells
LS_COLORS=$LS_COLORS:"di=0;32:" ; export LS_COLORS
alias nw='tmux new-window'
set chris
' > ~/bashrc_chrisprofile

  [ ! -f ~/bashrc_chrisprofile ] || grep -q "set chris" .bashrc || cat bashrc_chrisprofile >> .bashrc

echo "Yum updates..."
  yum -y update
  yum -y upgrade yum

echo "Command line tools..."
   yum -y install yum-utils yum-cron
   yum -y install tmux vim zip unzip 
  echo 'syntax on
colorscheme blue
' > ~/.vimrc

echo "sshd keepalive..."
  sed -i \
      -e 's/^#*TCPKeepAlive .*$/TCPKeepAlive yes/' \
      -e 's/^#*ClientAliveInterval .*$/ClientAliveInterval 120/' \
      -e 's/^#*ClientAliveCountMax .*$/ClientAliveCountMax 1000/' \
      /etc/ssh/sshd_config

echo "Firewall and fail2ban for sshd ..."
  #firewall for just the ports we want. and because fail2ban on Centos assumes you are using firewalld
  yum -y install firewalld
  systemctl enable firewalld.service
  systemctl start firewalld.service

  # fail2ban
  yum -y install epel-release fail2ban  
  cat > jail.local <<"EOF"
#
[DEFAULT]
bantime = 7200

[sshd]
enabled = true

EOF

  mv jail.local /etc/fail2ban/
  chown root:root /etc/fail2ban/jail.local
  systemctl enable fail2ban
  systemctl start fail2ban

  systemctl restart firewalld.service

  fail2ban-client status
  fail2ban-client status sshd

  systemctl status firewalld
  firewall-cmd --list-all


echo Powershell...
type -P powershell || yum -y install https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-rc/powershell-6.0.0_rc-1.rhel.7.x86_64.rpm

echo "----------------------------------------------------------------------------"
echo "Bootstrapped: yum, cli preferences, sshd config, firewalld and fail2ban"
echo "----------------------------------------------------------------------------"
