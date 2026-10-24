# dnf-git-psql-npm-dotnet-pwsh.sh
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
function pausemax { read -t $1 -p "$2 Wait $1 seconds, or press any key to continue ..." ; }

# install git
echo "installing and configuring git"
	dnf -y install git
	git config --global push.default simple
	#git config --global user.email "..."
	#git config --global user.name "..."

echo "----------------------------------------------------------------------------"
	# echo "Installing PostgreSQL Server from AppStream (dnf module list postgresql for other versions)..."
	# dnf -y install postgresql-server postgresql
	# postgresql-setup --initdb
	# systemctl enable --now postgresql

echo "----------------------------------------------------------------------------"
echo "getting npm and newman"
	# dnf -y install nodejs npm
	# npm install newman --global

echo "----------------------------------------------------------------------------"
echo "Powershell..."
	# rhelversion=$(rpm -E %rhel)
	# curl https://packages.microsoft.com/config/rhel/$rhelversion/prod.repo | sudo tee /etc/yum.repos.d/microsoft.repo
	# sudo dnf install -y powershell

echo "----------------------------------------------------------------------------"
echo "getting dotnet (from Rocky AppStream, no Microsoft repo needed)"
	sudo dnf -y install dotnet-sdk-10.0 || sudo dnf -y install dotnet-sdk-8.0
	echo "confirming dotnet runs:"
	dotnet new console -o hellodotnetworld
	rm -rf hellodotnetworld
