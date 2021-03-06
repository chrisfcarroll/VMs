[ `whoami` = root ] \
  || ( echo 'Not running as root, so cannot do pkg_add installs' && exit 1 ) || exit 1

echo "uncommenting PKG_PATH in root profile"
PKG_PATH="http://cdn.NetBSD.org/pub/pkgsrc/packages/NetBSD/$(uname -p)/$(uname -r|cut -f '1 2' -d.|cut -f 1 -d_)/All"
sed -i 's!^#export PKG_PATH!export PKG_PATH!' $HOME/.profile

which pkgin || echo 'ERROR: pkgin not found. Install it as part of the initial system installation.'

pkgin update
if [ $? -gt 0 ] ; then 
  echo "Pkgin error. Consider ftping base.tgz to manually extract libcrypto.12 ?"
  ftp http://ftp.netbsd.org/pub/NetBSD/NetBSD-8.1/amd64/binary/sets/base.tgz
fi

echo "
crontab for vulnerabilities file
"
grep "# Download vulnerabilities file" /var/cron/tabs/root || echo '
# Download vulnerabilities file
0 3 * * * /usr/pkg/sbin/pkg_admin fetch-pkg-vulnerabilities >/dev/null 2>&1
# Audit the installed packages and email results to root
9 3 * * * /usr/pkg/sbin/pkg_admin audit |mail -s "Installed package audit result" \
      root >/dev/null 2>&1
' >> /var/cron/tabs/root

echo "
Pkg : change 8.0 to 8.1
"
[ ! -f /usr/pkg/etc/pkgin/repositories.conf.orig ] && cp /usr/pkg/etc/pkgin/repositories.conf /usr/pkg/etc/pkgin/repositories.conf.orig
sed -i 's!https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/8.0/All!https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/8.1/All!' /usr/pkg/etc/pkgin/repositories.conf
grep -E ^https://  /usr/pkg/etc/pkgin/repositories.conf \
    || echo "https://cdn.netbsd.org/pub/pkgsrc/packages/NetBSD/\$arch/8.1/All" \
       > /usr/pkg/etc/pkgin/repositories.conf 


if [ ! -d /usr/pkgsrc ] ; then 
  echo "
  Getting pkgsrc may take half an hour on a fast machine ...
  "
  ftp -v ftp://ftp.NetBSD.org/pub/pkgsrc/pkgsrc-2019Q3/pkgsrc.tar.gz
  echo "untarring ..."
  tar -xzf pkgsrc.tar.gz -C /usr
  [ -d /usr/pkgsrc ] && rm pkgsrc.tar.gz 
else 
  echo "pkgsrc already present"
  ls -ld /usr/pkgsrc
fi
