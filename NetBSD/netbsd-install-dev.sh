echo "
Installing bash vim nano git wget and mozilla-rootcerts
"
pkgin -y install bash vim nano git wget
pkg_add mozilla-rootcerts
mozilla-rootcerts install

[ -f /usr/pkg/bin/python3.7 ] && ln -s /usr/pkg/bin/python3.7 /usr/pkg/bin/python