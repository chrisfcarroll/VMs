export ASSUME_ALWAYS_YES=YES

desktop=${1:-gnome3}
echo "
  Please wait several minutes for xorg and $desktop to download and install ...
  "
pkg install xorg

if [ "$desktop" = "xfce4" ] ; then
  pkg install xfce4 xfce4-thunar
  grep "xfce4-session" $HOME/.xinitrc || echo "exec xfce4-session" > $HOME/.xinitrc

elif [ "$desktop" = "gnome3" ] ; then 
  pkg install gdm gnome-desktop3 gedit gnome-backgrounds \
        gnome-control-center gnome-keyring nautilus \
        gnome-icon-theme gnome-themes gnome-tweeks mousetweaks
  sysrc gdm_enable="YES" gnome_enable="YES"​  
  grep "gnome-session" $HOME/.xinitrc || echo "exec gnome-session" > $HOME/.xinitrc
  
else
  pkg install slim cinnamon
  sysrc slim_enable="YES" gnome_enable="YES"​  
  grep "cinnamon-session" $HOME/.xinitrc || echo "exec cinnamon-session" > $HOME/.xinitrc
fi

sysrc dbus_enable="YES" hald_enable="YES" snd_driver_load="YES"
grep 'kern.vty=vt' /boot/loader.conf || printf '\nkern.vty=vt' >> /boot/loader.conf
grep vfs.usermount=1​ /etc/sysctl.conf || printf '\nvfs.usermount=1​' >> /etc/sysctl.conf

pkg install firefox xpdf


if [ ! -d /usr/local/share/icons/Papirus ] ; then 
  wget -O- https://git.io/papirus-icon-theme-install | env DESTDIR="/usr/local/share/icons" sh
else
  echo "Papirus icon theme already present"
fi

if grep '^X11Forwarding yes' /etc/ssh/sshd_config ; then
  echo 'X11Forwarding enabled'
else 
  sed  -i '' 's!^#X11Forwarding no!X11Forwarding yes!'  /etc/ssh/sshd_config
  /etc/rc.d/sshd restart
fi

if grep "/proc" /etc/fstab ; then
  echo "/etc/fstab done"
else
  echo "doing /etc/fstab" 
  printf "\nproc  \t\t/proc \tprocfs \trw \t0 \t0" >> /etc/fstab
  printf "\nfdesc \t\t/dev/fd \tfdescfs \trw,auto,late 0 \t0\n" >> /etc/fstab
fi
