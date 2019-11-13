[ `whoami` = root ] \
  || ( echo 'Not running as root, so cannot do pkg_add installs' && exit 1 ) || exit 1
PKG_PATH="http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -p)/$(uname -r|cut -f '1 2' -d.|cut -f 1 -d_)/All"
sed -i 's!^#export PKG_PATH!export PKG_PATH!' $HOME/.profile

pkg_add -v pkgin

[ ! -f /usr/pkg/etc/pkgin/repositories.conf.orig ] && cp /usr/pkg/etc/pkgin/repositories.conf /usr/pkg/etc/pkgin/repositories.conf.orig
sed -i 's!https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/8.0/All!https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/8.1/All!' /usr/pkg/etc/pkgin/repositories.conf
grep -E ^https://  /usr/pkg/etc/pkgin/repositories.conf \
    || echo "https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/$arch/8.1/All" \
       > /usr/pkg/etc/pkgin/repositories.conf 

pkgin -y install bash vim nano nmap iftop lsof mhash nbtscan netcat
