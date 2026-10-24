#!/bin/bash
# Create (or update the password of) a WordPress database and its local-only user. Idempotent.
if [[ -z $1 || -z $2 || -z $3 ]] ; then
	echo "usage: wordpress-create-database <databasename> <wordpressusername> <password>"
	exit 1
fi

databasename=$1
wordpressusername=$2
password=$3

[[ $databasename =~ ^[A-Za-z0-9_]+$ && $wordpressusername =~ ^[A-Za-z0-9_]+$ ]] \
  || { echo "database and user names must be [A-Za-z0-9_]" ; exit 1 ; }
[[ $password != *"'"* && $password != *'\'* ]] || { echo "password must not contain ' or \\" ; exit 1 ; }

mariadb <<EOF
CREATE DATABASE IF NOT EXISTS \`$databasename\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER IF NOT EXISTS '$wordpressusername'@'localhost' IDENTIFIED BY '$password';
ALTER USER '$wordpressusername'@'localhost' IDENTIFIED BY '$password';
GRANT ALL PRIVILEGES ON \`$databasename\`.* TO '$wordpressusername'@'localhost';
FLUSH PRIVILEGES;
EOF
