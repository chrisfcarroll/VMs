# yum-git-psql-npm-dotnet-pwsh.sh
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
function pausemax { read -t $1 -p "$2 Wait $1 seconds, or press any key to continue ..." ; }

# install git
echo "installing and configuring git"
	yum -y install libunwind libicu #prereqs for git, I think
	yum -y install git
	git config --global push.default simple
	#git config --global user.email "..."
	#git config --global user.name "..."

echo "----------------------------------------------------------------------------"
	# echo "Getting and installing PostgreSQL Server 9.6..."
	# echo "TODO: update this to Postgres 10 or later."
	# [ $(which psql) ] || yum -y install https://download.postgresql.org/pub/repos/yum/9.6/redhat/rhel-6-x86_64/pgdg-centos96-9.6-3.noarch.rpm
	# yum -y groupinstall "PostgreSQL Database Server 9.6 PGDG"
	# /usr/pgsql-9.6/bin/postgresql96-setup initdb
	# systemctl start postgresql-9.6.service
	# systemctl enable postgresql-9.6.service
	# yum -y install postgresql

echo "----------------------------------------------------------------------------"
echo "getting npm and newman"
	yum -y install npm
	npm install newman --global

	# 	echo "----------------------------------------------------------------------------"
	# 	echo "getting mono and nuget"
	# 	yum -y install yum-utils
	# 	rpm --import "http://keyserver.ubuntu.com/pks/lookup?op=get&search=0x3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF"
	# 	yum-config-manager --add-repo http://download.mono-project.com/repo/centos/	
	# 	yum -y install mono-complete
	# 	mozroots --import --sync
	# 	curl https://dist.nuget.org/win-x86-commandline/v4.1.0/nuget.exe -o /usr/bin/nuget.exe
	# 	cat > nuget <<EOF
	# #! /usr/bin/bash 
	# mono /usr/bin/nuget.exe $*
	# EOF
	# 	chmod a+x nuget
	# 	mv nuget /usr/bin
	# 	nuget sources add -Name Private -Source http://nuget.privatecouk/nuget/Private/ -UserName "$pscriptsnugetusername" -Password "$pscriptsnugetpassword"	

echo "----------------------------------------------------------------------------"
echo "Powershell..."
	# curl https://packages.microsoft.com/config/rhel/7/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
	# sudo yum install -y powershell

echo "----------------------------------------------------------------------------"
echo "getting dotnet core 3"
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	sudo sh -c 'echo -e "[packages-microsoft-com-prod]\nname=packages-microsoft-com-prod \nbaseurl=https://packages.microsoft.com/yumrepos/microsoft-rhel7.3-prod\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/dotnetdev.repo'
	sudo yum install libunwind libicu
	sudo yum update
	sudo yum install dotnet-sdk-3.0	
	echo "confirming dotnet runs:"
	dotnet new console -o hellodotnetworld
	rm -rf hellodotnetworld
