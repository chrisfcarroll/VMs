pkg_add -v pkgin
pkgin -y install xorg
pkgin -y install nano
pkgin -y install fam
pkgin -y install hal
pkgin -y install mate-desktop mate-notification-daemon mate-terminal mate-panel mate-session-manager mate-icon-theme mate-control-center mate-power-manager mate-utils mate-calc caja 
pkgin -y install atril gvfs-goa gvfs-google gvfs-nfs gvfs-smb
cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d/
cp /usr/pkg/share/examples/rc.d/hal /etc/rc.d/
touch rc.conf
echo "
# mate desktop
rpcbind=YES
famd=YES 
dbus=YES 
hal=YES
" >> /etc/rc.conf 
echo mate-session >> /root/.xinitrc
echo mate-session >> /home/youruser/.xinitrc
pkgin -y install firefox libreoffice