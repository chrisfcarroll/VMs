# Reset lost mariadb root login back to unix_socket authentication (MariaDB 10.4+ default)
if [[ -z $1 ]] ; then
  systemctl stop mariadb
  read -p "Waiting for mariadb to stop ..." -t 5
  mysqld_safe --skip-grant-tables --skip-networking &
  read -p "Waiting for mariadb to start..." -t 5
fi

mariadb --execute="FLUSH PRIVILEGES; ALTER USER root@localhost IDENTIFIED VIA unix_socket;"
pkill mariadbd || pkill mysqld
rm -f .my.cnf
read -p "Waiting for mariadb to stop ..." -t 5
systemctl start mariadb
