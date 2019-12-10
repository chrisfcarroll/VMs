which pkgin || echo 'ERROR: pkgin not found. Install it as part of the initial system installation.'

desktop=${1:-xfce4}

if [ "$desktop" = "xfce4" ] ; then
  pkgin -y remove mate-desktop mate-notification-daemon mate-terminal mate-panel \
      mate-session-manager mate-icon-theme mate-control-center mate-power-manager \
      mate-utils mate-calc caja
  echo "

    Please go make coffee whilst waiting for $desktop to calculate, download and install ...

    "
  pkgin -yV install xfce4 xfce4-thunar
  echo "exec xfce4-session" > /home/$SU_FROM/.xinitrc

elif [ "$desktop" = "gnome 3 not working on NetBSD"] ; then 
  pkgin -y remove xfce4 xfce4-thunar
  pkgin -y remove mate-desktop mate-notification-daemon mate-terminal mate-panel \
      mate-session-manager mate-icon-theme mate-control-center mate-power-manager \
      mate-utils mate-calc caja   
  echo "

    Please go make coffee whilst waiting for $desktop to calculate, download and install ...

    "
  pkgin -yV install gnome-desktop3 gedit gnome-backgrounds \
        gnome-control-center gnome-keyring nautilus \
        gnome-icon-theme gnome-themes gnome-tweeks mousetweaks
else
  pkgin -y remove xfce4 xfce4-thunar
  echo "

    Please go make coffee whilst waiting for $desktop to calculate, download and install ...

    "
  pkgin -yV install mate-desktop mate-notification-daemon mate-terminal mate-panel \
            mate-session-manager mate-icon-theme mate-control-center mate-power-manager \
            mate-utils mate-calc caja 
  echo "exec mate-session" > /home/$SU_FROM/.xinitrc
fi

pkg_add -y fam dbus hal
cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d
cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d
cp /usr/pkg/share/examples/rc.d/hal /etc/rc.d
grep "rpcbind=YES" /etc/rc.conf || echo rpcbind=YES >> /etc/rc.conf
grep "famd=YES" /etc/rc.conf ||  echo famd=YES >> /etc/rc.conf
grep "dbus=YES" /etc/rc.conf ||  echo dbus=YES >> /etc/rc.conf
grep "hal=YES" /etc/rc.conf ||  echo hal=YES >> /etc/rc.conf
/etc/rc.d/rpcbind start
/etc/rc.d/famd start
/etc/rc.d/dbus start
/etc/rc.d/hal start

pkgin -yV install mozilla-fonts* font-adobe-75* font-adobe-100* font-adobe-utopia*
pkgin -yV install firefox xpdf openquicktime keepassx
pkgin -yV install papirus-icon-theme


echo "
  For a graphical workstation, consider using slim or other login manager, rather than using startx:

  pkgin install slim
  cp /usr/pkg/share/examples/rc.d/slim /etc/rc.d
  grep "slim=YES" /etc/rc.conf || grep "slim=YES" /etc/rc.conf || echo "slim=YES" >> /etc/rc.conf
  ln .xinitrc .xsession

"

sed  -i 's!^#X11Forwarding no!X11Forwarding yes!'  /etc/ssh/sshd_config
/etc/rc.d/sshd restart

