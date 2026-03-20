#! /bin/sh
sudo dnf install -y python uv node npm dotnet-sdk-10.0
chmod +x /tmp/dotnet-install.sh
/tmp/dotnet-install.sh --version latest
