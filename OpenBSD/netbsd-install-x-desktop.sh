pkg_add gnome
pkg_add gconf-editor gdm gedit \
      gnome-backgrounds gnome-control-center \
      gnome-desktop gnome-doc-utils \
      gnome-icon-theme gnome-keyring \
      gnome-menus \
      gnome-session gnome-settings-daemon  \
      gnome-system-monitor \
      gnome-terminal gnome-user-docs \
      gucharmap gvfs libgnomekbd librsvg \
      mousetweaks nautilus
pkg_add mozilla-fonts font-adobe-75 font-adobe-100 font-adobe-utopia
pkg_add firefox xpdf keepassx

if [ ! -d /usr/local/share/icons/Papirus ] ; then 
  wget -O- https://git.io/papirus-icon-theme-install | env DESTDIR="/usr/local/share/icons" sh
else
  echo "Papirus icon theme already present"
fi

sed  -i 's!^#X11Forwarding no!X11Forwarding yes!'  /etc/ssh/sshd_config
/etc/rc.d/sshd restart

