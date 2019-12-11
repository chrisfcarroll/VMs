which pkgin || echo 'ERROR: pkgin not found. Install it as part of the initial system installation.'

desktop=${1:-xfce4}

if [ "$desktop" = "xfce4" ] ; then
  pkgin -y remove mate
  echo "

    Please go make coffee whilst waiting for $desktop to calculate, download and install ...

    "
  pkgin -yV install xfce4 xfce4-thunar
  echo "exec xfce4-session" > /home/$SU_FROM/.xinitrc

elif [ "$desktop" = "gnome 3 not working on NetBSD"] ; then 
  pkgin -y remove xfce4 xfce4-thunar
  pkgin -y remove mate
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
  pkgin -yV install mate 
  echo "exec mate-session" > /home/$SU_FROM/.xinitrc
fi


# xfce4 shouldn't need any of this
# pkg_add -y dbus fam avahi
# cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d
# cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d
# cp /usr/pkg/share/examples/rc.d/avahidaemon /etc/rc.d
# grep "dbus=YES" /etc/rc.conf ||  echo dbus=YES >> /etc/rc.conf
# grep "famd=YES" /etc/rc.conf ||  echo famd=YES >> /etc/rc.conf
# grep "avahi=YES" /etc/rc.conf ||  echo avahi=YES >> /etc/rc.conf
# /etc/rc.d/dbus onestart
# /etc/rc.d/famd onestart
# /etc/rc.d/avahi onestart


pkgin -yV install mozilla-fonts* font-adobe-75* font-adobe-100* font-adobe-utopia*
pkgin -yV install firefox xpdf openquicktime keepassx
pkgin -yV install papirus-icon-theme


echo "
  For a graphical workstation, consider using slim or other login manager, rather than using startx:

  pkgin install slim
  cp /usr/pkg/share/examples/rc.d/slim /etc/rc.d
  grep "slim=YES" /etc/rc.conf || grep "slim=YES" /etc/rc.conf || echo "slim=YES" >> /etc/rc.conf
  ln .xinitrc .xsession

  Good to know:

  xset q
  xset mouse 3/2 5 # set mouse acceleration = 1.5, threshold = 5 pixels

"

sed  -i 's!^#X11Forwarding no!X11Forwarding yes!'  /etc/ssh/sshd_config
/etc/rc.d/sshd restart

