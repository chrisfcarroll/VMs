echo "
Installing bash vim nano git wget and mozilla-rootcerts
"
env ASSUME_ALWAYS_YES=YES pkg install bash vim nano git wget mozilla-rootcerts
mozilla-rootcerts install

[ -f /usr/pkg/bin/python3.7 ] && ln -s /usr/pkg/bin/python3.7 /usr/pkg/bin/python