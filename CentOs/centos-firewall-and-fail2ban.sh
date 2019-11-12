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
