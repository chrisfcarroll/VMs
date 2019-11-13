[ `whoami` = root ] \
  || ( echo 'Not running as root, so cannot do pkg_add installs' && exit 1 ) || exit 1
PKG_PATH="http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -p)/$(uname -r|cut -f '1 2' -d.|cut -f 1 -d_)/All"
pkg_add -v pkgin

[ ! -f /usr/pkg/etc/pkgin/repositories.conf.orig ] && cp /usr/pkg/etc/pkgin/repositories.conf /usr/pkg/etc/pkgin/repositories.conf.orig
sed -i 's!https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/8.0/All!https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/8.1/All!' /usr/pkg/etc/pkgin/repositories.conf
grep -E ^https://  /usr/pkg/etc/pkgin/repositories.conf \
    || echo "https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/$arch/8.1/All" \
       > /usr/pkg/etc/pkgin/repositories.conf 

pkgin -y install xfce4 font-adobe-75* font-adobe-100* font-adobe-utopia* xscreensaver fam gvfs xfce4-thunar
echo xfce4-session >> /root/.xinitrc
echo xfce4-session >> /home/$SU_FROM/.xinitrc
ln /home/$SU_FROM/.xinitrc /home/$SU_FROM/.xsession
pkgin -y install firefox xpdf openquicktime mozilla-fonts* keepassx


# cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d/
# cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d/
# cp /usr/pkg/share/examples/rc.d/hal /etc/rc.d/
# echo rpcbind=YES >> /etc/rc.conf
# echo famd=YES >> /etc/rc.conf
# echo dbus=YES >> /etc/rc.conf
# echo hal=YES >> /etc/rc.conf
# /etc/rc.d/rpcbind start
# /etc/rc.d/famd start
# /etc/rc.d/dbus start
# /etc/rc.d/hal start
# pkgin -y install mate-desktop mate-notification-daemon mate-terminal mate-panel mate-session-manager mate-icon-theme mate-control-center mate-power-manager mate-utils mate-calc caja 
# echo mate-session >> /root/.xinitrc
# echo mate-session >> /home/$SU_FROM/.xinitrc
# pkgin -y install firefox libreoffice

# pkgin -y install fam
# pkgin -y install hal
# cp /usr/pkg/share/examples/rc.d/famd /etc/rc.d/
# cp /usr/pkg/share/examples/rc.d/dbus /etc/rc.d/
# cp /usr/pkg/share/examples/rc.d/hal /etc/rc.d/
# touch rc.conf
# echo "
# # mate desktop
# rpcbind=YES
# famd=YES 
# dbus=YES 
# hal=YES
# " >> /etc/rc.conf 
