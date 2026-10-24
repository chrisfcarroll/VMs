#
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
# Run as root (or via sudo) on a newly provisioned Rocky Linux 9 or 10 server.
# Set KEYAUTH_VERIFIED=1 only once you have confirmed you can log in with an ssh key:
# it turns off ssh password logins.
#
echo "=================================================="
echo "$BASH_SOURCE : Bootstrapping commandline preferences and basic security on $HOSTNAME"
echo '
	Basic security = automatic dnf updates & reboots, ssh keys only, firewalld, and fail2ban for sshd
'
echo "=================================================="

scriptdir=$(cd "$(dirname "$0")" && pwd)
function pausemax { read -t $1 -p "$2 Wait $1 seconds, or press any key to continue ..." ; }

[[ $(id -u) == 0 ]] || { echo "Run me as root, or with sudo" ; exit 1 ; }
. /etc/os-release
[[ "$ID $ID_LIKE" == *rhel* ]] || pausemax 10 "This doesn't look like Rocky/RHEL ($PRETTY_NAME)."

echo "bash preferences ..."

	[ -f ~/.bashrc ] || touch ~/.bashrc
  sed -i 's!^alias \(rm\|cp\|mv\).*!!' ~/.bashrc

  cat > ~/bashrc_chrisprofile <<"EOF"

# Avoid darkblue because some of us use darkblue background for powershell shells
LS_COLORS=$LS_COLORS:"di=0;32:" ; export LS_COLORS
alias nw='tmux new-window'
set chris
EOF
	grep -q "set chris" ~/.bashrc || cat ~/bashrc_chrisprofile >> ~/.bashrc

echo "dnf updates..."
	dnf -y upgrade
echo "Command line tools..."
	dnf -y install dnf-plugins-core tmux vim-enhanced zip unzip tar rsync policycoreutils-python-utils
	echo 'syntax on
colorscheme blue
' > ~/.vimrc

echo "Automatic security updates, with reboot when needed ..."
	"$scriptdir/dnf-dnf-automatic.sh"

echo "Swap: a 1GB VM running mariadb + php-fpm will otherwise get processes OOM-killed ..."
  if [[ -z $(swapon --show --noheadings) && $(awk '/MemTotal/{print $2}' /proc/meminfo) -lt 2500000 ]] ; then
    dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none \
      && chmod 600 /swapfile && mkswap /swapfile && swapon /swapfile \
      && echo '/swapfile none swap defaults 0 0' >> /etc/fstab
  fi
  swapon --show

echo "sshd: keepalive, and keys-only logins if KEYAUTH_VERIFIED=1 ..."
  # Rocky 9+ sshd_config starts with Include sshd_config.d/*.conf and the first value set wins,
  # so 01- beats the distro's 50-redhat.conf and cloud-init's 50-cloud-init.conf
  {
    echo "ClientAliveInterval 120"
    echo "ClientAliveCountMax 1000"
    echo "MaxAuthTries 4"
    echo "PermitRootLogin prohibit-password"
    if [[ $KEYAUTH_VERIFIED == 1 ]] ; then
      echo "PasswordAuthentication no"
      echo "KbdInteractiveAuthentication no"
    fi
  } > /etc/ssh/sshd_config.d/01-bootstrap-hardening.conf
  grep -q '^Include /etc/ssh/sshd_config.d/' /etc/ssh/sshd_config \
    || echo "WARNING: sshd_config does not Include sshd_config.d/ so hardening is NOT applied"
  if sshd -t ; then systemctl reload sshd ; else
    echo "WARNING: sshd config test failed, removing hardening drop-in"
    rm /etc/ssh/sshd_config.d/01-bootstrap-hardening.conf
  fi
  [[ $KEYAUTH_VERIFIED == 1 ]] || echo "NB: ssh password logins are still ON. Rerun with KEYAUTH_VERIFIED=1 once ssh keys work."

  # The port(s) sshd really listens on, from its own config. Not the port the client connected to,
  # which may be a NAT/port-forward (e.g. 2222 -> 22). firewalld, SELinux and fail2ban must all agree.
  sshports=$( sshd -T 2>/dev/null | awk '$1=="port"{print $2} $1=="listenaddress"{n=split($2,a,":"); print a[n]}' | sort -un | xargs )
  sshports=${sshports:-22}
  echo "sshd listens on port(s): $sshports"
  for p in $sshports ; do
    [[ $p == 22 ]] && continue
    semanage port -l | grep -qE "^ssh_port_t +tcp +.*\b$p\b" \
      || semanage port -a -t ssh_port_t -p tcp $p 2>/dev/null || semanage port -m -t ssh_port_t -p tcp $p
  done

echo "Firewall and fail2ban for sshd ..."
	#firewall for just the ports we want. and because fail2ban on Rocky assumes you are using firewalld
	dnf -y install firewalld
	systemctl enable --now firewalld.service
	# The default zone allows only port 22 for ssh. Open any other sshd port straight away, runtime and permanent,
	# so new ssh logins aren't locked out
	for p in $sshports ; do
	  [[ $p == 22 ]] && continue
	  firewall-cmd --zone=public --add-port=$p/tcp
	  firewall-cmd --permanent --zone=public --add-port=$p/tcp
	done
	# Rocky opens the cockpit admin console port (9090) by default. Close it.
	firewall-cmd --permanent --zone=public --remove-service=cockpit 2>/dev/null

	# fail2ban comes from EPEL. fail2ban-systemd reads sshd failures from the journal
	dnf -y install epel-release
	dnf -y install fail2ban fail2ban-firewalld fail2ban-systemd
	cat > /etc/fail2ban/jail.local <<EOF
#
[DEFAULT]
bantime = 2h
# repeat offenders get banned for longer each time, up to a week
bantime.increment = true
bantime.maxtime = 1w

[sshd]
enabled = true
backend = systemd
# bans only block the listed ports, so list whichever ports sshd really uses
port = ${sshports// /,}

EOF
  restorecon /etc/fail2ban/jail.local
	systemctl enable fail2ban
	systemctl restart fail2ban

  systemctl restart firewalld.service

  fail2ban-client status
  fail2ban-client status sshd

  systemctl status firewalld --no-pager
  firewall-cmd --list-all

echo "----------------------------------------------------------------------------"
echo "Bootstrapped: cli preferences, dnf-automatic, swap, sshd, firewalld and fail2ban"
echo "----------------------------------------------------------------------------"
