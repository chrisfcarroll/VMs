#
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
echo "=================================================="
echo "$BASH_SOURCE : Installing $* "
echo "On $HOSTNAME"
echo "=================================================="

function pausemax { read -t $1 -p "$2 Wait $1 seconds, or press any key to continue ..." ; }

echo "bash preferences"
printf '
LS_COLORS=$LS_COLORS:"di=0;32:" ; export LS_COLORS
set chris
' > ~/.bashrc_chrisprofile
	[ -f .bashrc ] || touch .bashrc
	[ ! -f bashrc_chrisprofile ] || grep -q "set chris" .bashrc || cat bashrc_chrisprofile >> .bashrc

echo "getting updates and tools"
	yum -y update
	yum -y upgrade yum
 	yum install -y yum-utils
 	yum install -y yum-cron
 	yum -y install screen # screen will save your sanity. https://duckduckgo.com/?q=why+use+linux+screen+for+remote+session&t=opera&ia=web
	yum -y install vim

	#firewall for just the ports we want. and because fail2ban on Centos assumes you are using firewalld
	systemctl enable firewalld.service
	systemctl start firewalld.service

	# fail2ban: We've had 1000 automated attempts per hour at root login
	yum -y install epel-release #prerequisite for fail2ban
	yum -y install fail2ban  
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


type -P powershell || yum -y install https://github.com/PowerShell/PowerShell/releases/download/v6.0.0-rc/powershell-6.0.0_rc-1.rhel.7.x86_64.rpm

echo "----------------------------------------------------------------------------"
echo "Setting firewall rules"
echo ""

systemctl restart firewalld.service


# do it again because I'm not sure it all works:
echo "----------------------------------------------------------------------------"
echo "Confirming security settings : fail2ban jails"
echo ""
fail2ban-client status
fail2ban-client status sshd

echo "----------------------------------------------------------------------------"
echo "Confirming security settings : firewall rules"
echo ""
systemctl status firewalld
firewall-cmd --list-all

echo "----------------------------------------------------------------------------"
echo "Ready to run."
echo "----------------------------------------------------------------------------"
