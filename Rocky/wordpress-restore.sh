#!/bin/bash
# wordpress-restore <backup.tar.gz> : restore a backup made by wordpress-backup onto this server.
#   The server must already have been set up by dnf-nginx-php-mariadb-wp.sh (nginx, php-fpm, mariadb, wordpress user).
#   Takes a backup of the current site first, and keeps the current files as WEBROOT.before-restore-<time>
#   Installed as /usr/local/sbin/wordpress-restore. To push a local backup to a server and restore it, use backup-restore.sh.ps1
function die { echo "ERROR: $*" >&2 ; exit 1 ; }
[[ $(id -u) == 0 ]] || die "Run me as root, or with sudo"
. /etc/wordpress-site.conf || die "run dnf-nginx-php-mariadb-wp.sh first"
file=$1
[[ -f $file ]] || die "usage: wordpress-restore <backup.tar.gz>"

stamp=$(date -u +%Y%m%dT%H%M%SZ)
tmp=$(mktemp -d /var/tmp/wordpress-restore.XXXXXX) ; trap 'rm -rf "$tmp"' EXIT
echo "Unpacking $file ..."
tar -xzf "$file" -C "$tmp" || die "couldn't unpack $file"
restored=$tmp/${WEBROOT#/}
[[ -f $tmp/database.sql && -f $restored/wp-config.php ]] \
  || die "$file isn't a wordpress-backup of $WEBROOT (no database.sql or ${WEBROOT#/}/wp-config.php)"
cat "$tmp/backup-info.txt"

function wpconfig { sed -n "s/.*define( *'$1', *'\([^']*\)'.*/\1/p" "$restored/wp-config.php" ; }
dbname=$(wpconfig DB_NAME) ; dbuser=$(wpconfig DB_USER) ; dbpass=$(wpconfig DB_PASSWORD)
[[ -n $dbname && -n $dbuser ]] || die "couldn't read DB_NAME and DB_USER from the backup's wp-config.php"

if [[ -f $WEBROOT/wp-config.php ]] ; then
  echo "Backing up the current site first ..."
  /usr/local/sbin/wordpress-backup || die "backup of the current site failed; not restoring"
fi

echo "Database $dbname ..."
mariadb -e "DROP DATABASE IF EXISTS \`$dbname\`" || die "couldn't drop $dbname"
/usr/local/sbin/wordpress-create-database "$dbname" "$dbuser" "$dbpass" || die "couldn't create $dbname"
mariadb "$dbname" < "$tmp/database.sql" || die "database import failed"

echo "Files $WEBROOT ..."
[[ -d $WEBROOT ]] && mv "$WEBROOT" "$WEBROOT.before-restore-$stamp"
mv "$restored" "$WEBROOT" || die "couldn't move restored files into $WEBROOT"
chown -R "$WP_USER": "$WEBROOT"

echo "nginx and letsencrypt config ..."
[[ -d $tmp/etc/letsencrypt && ! -d /etc/letsencrypt/live ]] && cp -a "$tmp/etc/letsencrypt" /etc/
for f in "$tmp"/etc/nginx/conf.d/wordpress.conf "$tmp"/etc/nginx/wordpress-*.conf ; do
  [[ -f $f ]] && cp "$f" "/${f#$tmp/}"
done
restorecon -R "$WEBROOT" /etc/nginx /etc/letsencrypt 2>/dev/null

# reapply lockdown (or not) as recorded in the restored wp-config.php
if grep -q "define( *'DISALLOW_FILE_MODS', *false" "$WEBROOT/wp-config.php"
  then /usr/local/sbin/wordpress-lockdown off
  else /usr/local/sbin/wordpress-lockdown on
fi

if nginx -t ; then systemctl reload nginx ; else echo "WARNING: nginx config test failed, check /etc/nginx/conf.d/wordpress.conf" ; fi
systemctl restart php-fpm

backupdomain=$(sed -n 's/^DOMAIN=//p' "$tmp/backup-info.txt")
echo "
Restored. The previous files are in $WEBROOT.before-restore-$stamp ; delete them when you're happy."
if [[ -n $backupdomain && $backupdomain != "$DOMAIN" ]] ; then echo "
NB: the backup was of $backupdomain but this server is $DOMAIN. If this is a new address for the site:
  - point DNS for $backupdomain here, or
  - run: rocky-nginx-ssl.sh $DOMAIN    (gets a certificate and rewrites WordPress URLs to https://$DOMAIN)"
fi
