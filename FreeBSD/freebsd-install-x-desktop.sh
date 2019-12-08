export ASSUME_ALWAYS_YES=YES

desktop=${1:-cinnamon}
echo "
  Please wait several minutes for $desktop to download and install ...
  "
if [ "$desktop" = "xfce4" ] ; then
  pkg install xfce4 xfce4-thunar
  #echo "exec xfce4-session" > $HOME/.xinitrc
elif [ "$desktop" = "gnome3"] ; then 
  pkg install gnome-desktop3 gedit gnome-backgrounds \
        gnome-control-center gnome-keyring nautilus \
        gnome-icon-theme gnome-themes gnome-tweeks mousetweaks
  #echo "exec gnome-session" > $HOME/.xinitrc
else
  pkg install cinnamon
  #echo cinnamon-session > $HOME/.xinitrc
fi
pkg install mozilla-fonts* font-adobe-75* font-adobe-100* font-adobe-utopia*
pkg install firefox xpdf openquicktime keepassx

if [ ! -d /usr/local/share/icons/Papirus ] ; then 
  wget -O- https://git.io/papirus-icon-theme-install | env DESTDIR="/usr/local/share/icons" sh
else
  echo "Papirus icon theme already present"
fi

sed  -i 's!^#X11Forwarding no!X11Forwarding yes!'  /etc/ssh/sshd_config
/etc/rc.d/sshd restart
