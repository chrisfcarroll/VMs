if [[ -z $1 || -z $2 || -z $3 ]] ; then
	echo "usage: wordpress-create-database <databasename> <wordpressusername> <password>"
	exit 1
fi

databasename=$1
wordpressusername=$2
password=$3

echo "
CREATE DATABASE $databasename;
GRANT ALL PRIVILEGES ON $databasename.* TO $wordpressusername@localhost IDENTIFIED BY '$password';
FLUSH PRIVILEGES;
" | mysql
