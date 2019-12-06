which pkgin || echo 'ERROR: pkgin not found. Install it as part of the initial system installation.'

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
elif [ "$desktop" = "gnome - not -working"] ; then 
  pkgin -y remove xfce4 xfce4-thunar
  pkgin -y remove mate-desktop mate-notification-daemon mate-terminal mate-panel 
  pkgin -y remove mate-session-manager mate-icon-theme mate-control-center mate-power-manager 
  pkgin -y remove mate-utils mate-calc caja   
  pkgin -y install gnome
  pkgin -y install alacarte brasero bug-buddy cheese dasher deskbar-applet needs ekiga empathy \
        eog epiphany evince evolution evolution-data-server evolution-exchange evolution-mapi \
        evolution-webcal file-roller gcalctool gconf-editor gdm gedit gio-fam \
        gnome-applets gnome-backgrounds gnome-control-center \
        gnome-desktop gnome-desktop-sharp gnome-doc-utils \
        gnome-games gnome-icon-theme gnome-keyring gnome-mag \
        gnome-media gnome-menus gnome-netstatus gnome-nettool \
        gnome-panel gnome-power-manager gnome-screensaver \
        gnome-session gnome-settings-daemon gnome-sharp \
        gnome-speech gnome-system-monitor gnome-system-tools \
        gnome-terminal gnome-themes gnome-user-docs unpackaged \
        gnome-user-share gnome-utils gok gst-plugins0.10-base \
        gst-plugins0.10-good gst-plugins0.10-pulse gstreamer0.10 \
        gtk2-engines gtkhtml314 gtksourceview2 gucharmap gvfs \
        hamster-applet libgail-gnome libgnomekbd libgnomeprint \
        libgnomeprintui libgtop libgweather liboobs librsvg libsoup24 \
        libwnck metacity mousetweaks nautilus orca seahorse seahorse-plugins \
        sound-juicer swfdec-gnome tomboy totem totem-pl-parser vinagre \
        compilation vino vte yelp zenity \
        gnome-mount aspell-francais aspell-english \
        gst-ffmpeg gst-plugins0.10-x264 gst-plugins0.10-resindvd gst-plugins0.10-a52 gst-plugins0.10-xvid
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
/etc/rc.d/sshd restart

