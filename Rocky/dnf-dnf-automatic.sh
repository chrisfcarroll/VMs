# dnf-automatic replaces yum-cron. Apply all updates daily and reboot when a kernel/glibc/systemd update needs it.
dnf install -y dnf-automatic
conf=/etc/dnf/automatic.conf
sed -i 's/^apply_updates *=.*/apply_updates = yes/' $conf
if grep -q '^#* *reboot *=' $conf
  then sed -i 's/^#* *reboot *=.*/reboot = when-needed/' $conf
  else sed -i '/^\[commands\]/a reboot = when-needed' $conf
fi
systemctl enable --now dnf-automatic.timer
systemctl list-timers dnf-automatic.timer --no-pager
