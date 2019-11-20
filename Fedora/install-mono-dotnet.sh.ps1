echo "
Install mono"
rpm --import "https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
curl https://download.mono-project.com/repo/centos8-stable.repo | tee /etc/yum.repos.d/mono-centos8-stable.repo
dnf update
dnf -y install mono-devel

echo "
Install dotnet 3. 
* NB as at November 2019 an error in the Fedora & Centos checksums causes this to fail.
* workaround : first, manually download and install 
               https://packages.microsoft.com/fedora/30/prod/netstandard-targeting-pack-2.1.0-x64.rpm
"
rpm --import https://packages.microsoft.com/keys/microsoft.asc
wget -q -O /etc/yum.repos.d/microsoft-prod.repo https://packages.microsoft.com/config/fedora/30/prod.repo
dnf install dotnet-sdk-3.0

