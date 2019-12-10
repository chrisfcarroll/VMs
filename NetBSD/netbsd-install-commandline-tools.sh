which pkgin || echo 'ERROR: pkgin not found. Install it as part of the initial system installation.'
pkgin -yV install tmux doas zsh vim nano nmap mhash nbtscan wget
pkg_add mozilla-rootcerts
mozilla-rootcerts install
[ -f /usr/pkg/bin/python3.7 ] && ln -s /usr/pkg/bin/python3.7 /usr/pkg/bin/python

if [ ! -f /usr/pkg/etc/doas.conf ] ; then
  mkdir -p /usr/pkg/etc/
  echo "permit nopass :wheel"  > /usr/pkg/etc/doas.conf
fi
