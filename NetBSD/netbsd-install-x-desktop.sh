desktop=${1:-xfce4}
echo "
  Please wait several minutes for $desktop to download and install ...
  "
if [ "$desktop" = "xfce4" ] ; then
  pkgin -y remove mate-desktop mate-notification-daemon mate-terminal mate-panel 
  pkgin -y remove mate-session-manager mate-icon-theme mate-control-center mate-power-manager 
  pkgin -y remove mate-utils mate-calc caja   
  pkgin -y install xfce4 xfce4-thunar
  echo xfce4-session > /home/$SU_FROM/.xinitrc
else
  pkgin -y remove xfce4 xfce4-thunar
  pkgin -y install mate-desktop mate-notification-daemon mate-terminal mate-panel \
            mate-session-manager mate-icon-theme mate-control-center mate-power-manager \
            mate-utils mate-calc caja 
  echo mate-session > /home/$SU_FROM/.xinitrc
fi
pkgin -y install mozilla-fonts* font-adobe-75* font-adobe-100* font-adobe-utopia*
pkgin -y install firefox xpdf openquicktime keepassx

if [ ! -d /usr/local/share/icons/Papirus ] ; then 
  wget -O- https://git.io/papirus-icon-theme-install | env DESTDIR="/usr/local/share/icons" sh
else
  echo "Papirus icon theme already present"
fi

sed  -i 's!^#X11Forwarding no!X11Forwarding yes!'  /etc/ssh/sshd_config
