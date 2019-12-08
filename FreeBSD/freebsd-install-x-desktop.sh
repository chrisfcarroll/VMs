export ASSUME_ALWAYS_YES=YES

desktop=${1:-cinnamon}
echo "
  Please wait several minutes for $desktop to download and install ...
  "
if [ "$desktop" = "xfce4" ] ; then
  pkg install xfce4 xfce4-thunar
  #echo "exec xfce4-session" > $HOME/.xinitrc
elif [ "$desktop" = "gnome3" ] ; then 
  pkg install gnome-desktop3 gedit gnome-backgrounds \
        gnome-control-center gnome-keyring nautilus \
        gnome-icon-theme gnome-themes gnome-tweeks mousetweaks
  #echo "exec gnome-session" > $HOME/.xinitrc
else
  pkg install cinnamon
  #echo cinnamon-session > $HOME/.xinitrc
fi

doas sysrc -f /boot/loader.conf kern.vty=vt​
doas sysrc -f /etc/sysctl.conf vfs.usermount=1​
doas sysrc dbus_enable="YES" hald_enable="YES" gdm_enable="YES" gnome_enable="YES"​ snd_driver_load="YES"

pkg install font-adobe-100 font-adobe-utopia
pkg install firefox xpdf


if [ ! -d /usr/local/share/icons/Papirus ] ; then 
  wget -O- https://git.io/papirus-icon-theme-install | env DESTDIR="/usr/local/share/icons" sh
else
  echo "Papirus icon theme already present"
fi

sed  -i '' 's!^#X11Forwarding no!X11Forwarding yes!'  /etc/ssh/sshd_config
/etc/rc.d/sshd restart

if grep "/proc" /etc/fstab ; then
  echo "doing /etc/fstab" 
  echo "" >> /etc/fstab
  echo "proc  /proc   procfs   rw    0   0" >> /etc/fstab
  echo "" >> /etc/fstab
  echo "fdesc   /dev/fd   fdescfs   rw,auto,late    0   0" >> /etc/fstab
else
  echo "/etc/fstab done 2"
fi
