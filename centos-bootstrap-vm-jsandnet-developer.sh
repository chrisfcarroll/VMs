# centos-bootstrap-vm-jsandnet-developer.sh
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
	git config --global user.email "iom1@warringtonsoftware.co.uk"
	git config --global user.name "iom1"

	# TODOremovethefollowingline	
	# TODOsave bitbucket credentials for scriptrunner lb@warringtonsoftware.co.uk

echo "----------------------------------------------------------------------------"
	# echo "Getting and installing PostgreSQL Server..."
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
	# 	nuget sources add -Name LB -Source http://nuget.legalbricks.co.uk/nuget/LegalBricks/ -UserName "$lbscriptsnugetusername" -Password "$lbscriptsnugetpassword"	

echo "----------------------------------------------------------------------------"
echo "getting dotnet core 2"
	sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
	sudo sh -c 'echo -e "[packages-microsoft-com-prod]\nname=packages-microsoft-com-prod \nbaseurl=https://packages.microsoft.com/yumrepos/microsoft-rhel7.3-prod\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/dotnetdev.repo'
	sudo yum install libunwind libicu	ln -s /usr/local/share/dotnet/dotnet /usr/bin/
	sudo yum update
	sudo yum install dotnet-sdk-2.0.0	
	echo "confirming dotnet runs:"
	dotnet new console -o helloworld
	rm -rf helloworld


echo "----------------------------------------------------------------------------"
echo "Setting firewall rules"
echo ""

if [ "$lb__Postgres__Host" == "localhost" ] || [[ "$lb__Postgres__Host" == *"127.0.0"* ]] ;  then 
	firewall-cmd --permanent --zone=public --add-service=postgresql
fi

if [[ "$deploywhat" == *"http-1000"* ]] ; then
	cat > http-1000.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Http at 1000</short>
  <description>Http at 1000</description>
  <port protocol="tcp" port="1000"/>
</service>
EOF
	ls http-*.*
  mv http-1000.xml /usr/lib/firewalld/services/
	firewall-cmd --permanent --zone=public --add-service=http-1000
else echo "(not opening firewall for http-1000)"
fi


if [[ "$deploywhat" == *"eventstore"* ]] ; then
	cat > eventstore-standardports.xml <<EOF
<?xml version="1.0" encoding="utf-8"?>
<service>
  <short>Eventstore</short>
  <description>Http API at 2113 and TCP API at 1113</description>
  <port protocol="tcp" port="1113"/>
  <port protocol="tcp" port="2113"/>
</service>
EOF
	ls eventstore-standardports.xml
  mv eventstore-standardports.xml /usr/lib/firewalld/services/
	firewall-cmd --permanent --zone=public --add-service=eventstore-standardports
else echo "(not opening firewall for eventstore)"
fi

systemctl restart firewalld.service
#firewall-cmd --reload


# do it again because I'm not sure it all works:
echo "----------------------------------------------------------------------------"
echo "Confirming security settings : fail2ban jails"
echo ""
fail2ban-client status
fail2ban-client status sshd

echo "----------------------------------------------------------------------------"
echo "Confirming security settings : firewall rules"
echo ""
systemctl status firewalld
firewall-cmd --list-all

echo "----------------------------------------------------------------------------"
echo "Ready to run."
echo "----------------------------------------------------------------------------"


  # nginx ----------------------------------------------------------------------------
  yum -y install nginx
  [ -f /etc/nginx/nginx.conf.orig ] || cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig

  [ -z "$(cat /etc/nginx/nginx.conf | grep '^\s*server')" ] || pausemax 5 "NGINX manual config required: remove the server {} section from /etc/nginx/nginx.conf." 

  if [ ! -f /etc/nginx/conf.d/nginx-kestrel-on-5003.conf ] ; then 
    cat > nginx-kestrel-on-5003.conf <<"EOF"
server {
    listen                      80 http2 default;
    server_name ec2-54-72-9-204.eu-west-1.compute.amazonaws.com localhost;
    location / {
        proxy_pass              http://localhost:5003;
        # The default minimum configuration required for ASP.NET Core
        proxy_cache_bypass      $http_upgrade;
        proxy_redirect          off;
        proxy_set_header        Host $host;
        proxy_http_version      1.1; # Kestrel only speaks HTTP 1.1?
        proxy_set_header        Upgrade $http_upgrade;
        proxy_set_header        Connection keep-alive;
        client_max_body_size    10m;
        client_body_buffer_size 128k;
        proxy_connect_timeout   90;
        proxy_send_timeout      90;
        proxy_read_timeout      90;
        proxy_buffers           32 4k;
    }
}
EOF
    cp nginx-kestrel-on-5003.conf /etc/nginx/conf.d
	  setsebool -P httpd_can_network_connect 1 #otherwise nginx can't proxy to our kestrel
		nginx -t 
		nginx -s reload    
 		firewall-cmd --permanent --zone=public --add-service=http		
		systemctl restart firewalld.service
	fi
	end of nginx ----------------------------------------------------------------------------
