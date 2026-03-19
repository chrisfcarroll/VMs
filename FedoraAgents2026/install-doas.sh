#! /bin/sh
sudo dnf install -y opendoas
me=$(whoami)
echo "You are $me"
echo "permit nopass $me cmd zsh
permit nopass $me cmd bash
permit nopass $me cmd dnf
permit nopass $me cmd npm
permit nopass $me cmd dotnet
permit nopass $me cmd uv" | sudo tee -a /etc/doas.conf

