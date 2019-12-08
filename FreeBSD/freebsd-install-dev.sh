env ASSUME_ALWAYS_YES=YES pkg install zsh vim nano git wget 
env ASSUME_ALWAYS_YES=YES pkg install mozilla-rootcerts
mozilla-rootcerts install

[ -f /usr/pkg/bin/python3.7 ] && ln -s /usr/pkg/bin/python3.7 /usr/pkg/bin/python