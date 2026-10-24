#
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
echo "=================================================="
echo "$BASH_SOURCE : Bootstrapping commandline preferences and basic security on $HOSTNAME"
echo '
	Basic security = dnf updates and dnf-automatic, firewalld, and fail2ban for sshd
'
echo "=================================================="

function pausemax { read -t $1 -p "$2 Wait $1 seconds, or press any key to continue ..." ; }

echo "bash preferences ..."

	[ -f .bashrc ] || touch .bashrc
  sed -ir 's!^alias \(rm\|cp\|mv\).*!!' ~/.bashrc

  printf '
# Avoid darkblue because some of us use darkblue background for powershell shells
LS_COLORS=$LS_COLORS:"di=0;32:" ; export LS_COLORS
alias nw='tmux new-window'
set chris
' > ~/bashrc_chrisprofile
	[ ! -f ~/bashrc_chrisprofile ] || grep -q "set chris" .bashrc || cat bashrc_chrisprofile >> .bashrc

echo "dnf updates..."
	dnf -y upgrade
echo "Command line tools..."
	dnf -y install dnf-plugins-core dnf-automatic cronie
	dnf -y install tmux vim-enhanced zip unzip tar policycoreutils-python-utils
	echo 'syntax on
colorscheme blue
' > ~/.vimrc

echo "Automatic updates (dnf-automatic replaces yum-cron)..."
	systemctl enable --now dnf-automatic-install.timer
	systemctl enable --now crond

echo "sshd keepalive..."
  sed -i \
      -e 's/^#*ClientAliveInterval .*$/ClientAliveInterval 120/' \
      -e 's/^#*ClientAliveCountMax .*$/ClientAliveCountMax 1000/' \
      /etc/ssh/sshd_config

echo "Firewall and fail2ban for sshd ..."
	#firewall for just the ports we want. and because fail2ban on Rocky assumes you are using firewalld
	dnf -y install firewalld
	systemctl enable firewalld.service
	systemctl start firewalld.service

	# fail2ban comes from EPEL. rsyslog so that sshd & WordPress auth failures land in /var/log/secure
	dnf -y install epel-release
	dnf -y install fail2ban rsyslog
	systemctl enable --now rsyslog
	cat > jail.local <<"EOF"
#
[DEFAULT]
bantime = 7200

[sshd]
enabled = true

EOF

  mv jail.local /etc/fail2ban/
  chown root:root /etc/fail2ban/jail.local
  restorecon /etc/fail2ban/jail.local
	systemctl enable fail2ban
	systemctl start fail2ban

  systemctl restart firewalld.service

  fail2ban-client status
  fail2ban-client status sshd

  systemctl status firewalld
  firewall-cmd --list-all

echo "----------------------------------------------------------------------------"
echo "Bootstrapped: cli preferences, dnf, firewalld and fail2ban"
echo "----------------------------------------------------------------------------"
