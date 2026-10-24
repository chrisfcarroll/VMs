#!/bin/bash
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
# Runs on the NEW server, copied there and run by wp-load.sh.ps1
# usage: wp-load-on-server.sh <wordpress-migrate-....tar.gz> [<new-site-url>]
#
#   Loads an archive made by wp-extract into a WordPress set up by ../Rocky (dnf-nginx-php-mariadb-wp.sh):
#   - backs up the new site first
#   - replaces its database with the old one, and its wp-content with the old one
#   - keeps the new WordPress core, wp-config.php credentials & hardening; takes $table_prefix from the old site
#   - rewrites the old site's urls to <new-site-url> (default: the new site's current url)
#   - upgrades the database schema, updates plugins, themes & translations, re-applies SELinux lockdown
#   - quarantines php files in uploads, and cache drop-ins that need software the new server hasn't got
#
function die { echo "ERROR: $*" >&2 ; exit 1 ; }
[[ $(id -u) == 0 ]] || die "Run me as root, or with sudo"
. /etc/wordpress-site.conf || die "This server wasn't set up by Rocky/dnf-nginx-php-mariadb-wp.sh"
function wp { runuser -u "$WP_USER" -- /usr/local/bin/wp --path="$WEBROOT" --skip-plugins --skip-themes "$@" ; }
archive=$1
[[ -f $archive ]] || die "usage: wp-load-on-server.sh <wordpress-migrate-....tar.gz> [<new-site-url>]"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
quarantine=/root/wp-migrate-quarantine-$stamp

newurl=${2:-$(wp option get siteurl)}
newurl=${newurl%/}
[[ $newurl =~ ^https?://[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || die "'$newurl' should look like https://www.example.com"

tmp=$(mktemp -d /var/tmp/wp-load.XXXXXX) ; trap 'rm -rf "$tmp"' EXIT
echo "Unpacking $archive ..."
tar -xzf "$archive" -C "$tmp" || die "couldn't unpack $archive"
[[ -f $tmp/database.sql && -f $tmp/wp-config.php && -d $tmp/wp-content ]] \
  || die "$archive isn't from wp-extract (no database.sql, wp-config.php or wp-content/)"
cat "$tmp/site-info.txt"
prefix=$(sed -n "s/^[[:space:]]*\$table_prefix *= *['\"]\([^'\"]*\)['\"].*/\1/p" "$tmp/wp-config.php" | head -1)
[[ $prefix =~ ^[A-Za-z0-9_]+$ ]] || die "couldn't read \$table_prefix from the old wp-config.php"

echo "
Backing up the new site first. To undo this load: sudo wordpress-restore <that backup>"
/usr/local/sbin/wordpress-backup || die "backup failed; not loading"

echo "Database ..."
dbname=$(wp config get DB_NAME) ; dbuser=$(wp config get DB_USER) ; dbpass=$(wp config get DB_PASSWORD)
[[ -n $dbname && -n $dbuser ]] || die "couldn't read the new site's database settings"
mariadb -e "DROP DATABASE IF EXISTS \`$dbname\`" || die "couldn't drop $dbname"
/usr/local/sbin/wordpress-create-database "$dbname" "$dbuser" "$dbpass" || die "couldn't create $dbname"
mariadb "$dbname" < "$tmp/database.sql" || die "database import failed"
wp config set table_prefix "$prefix" --type=variable

echo "wp-content ..."
rm -rf "$WEBROOT/wp-content"
mv "$tmp/wp-content" "$WEBROOT/wp-content" || die "couldn't move wp-content into place"
chown -R "$WP_USER": "$WEBROOT/wp-content"
mkdir -p "$quarantine" && chmod 700 "$quarantine"
# php in uploads is never legitimate, and is how many hacked sites keep a backdoor. nginx won't run it anyway.
find "$WEBROOT/wp-content/uploads" -type f \( -iname '*.php*' -o -iname '*.phtml' -o -iname '*.phar' \) 2>/dev/null \
  | while read -r f ; do echo "QUARANTINED php in uploads: $f" ; mv "$f" "$quarantine/" ; done
# drop-ins for object caches & db proxies (memcached, redis ...) fatally fail if that software isn't installed
for f in object-cache.php advanced-cache.php db.php ; do
  [[ -f $WEBROOT/wp-content/$f ]] && echo "QUARANTINED drop-in wp-content/$f" && mv "$WEBROOT/wp-content/$f" "$quarantine/"
done
rmdir "$quarantine" 2>/dev/null

echo "URLs -> $newurl ..."
for old in $(printf "%s\n" "$(wp option get siteurl)" "$(wp option get home)" | sort -u) ; do
  oldhost=$(echo "$old" | sed -E 's|^https?://||; s|/.*||')
  for o in "http://$oldhost" "https://$oldhost" ; do
    [[ $o == "$newurl" ]] && continue
    wp search-replace "$o" "$newurl" --all-tables-with-prefix --skip-columns=guid --report-changed-only
  done
done
wp option update siteurl "$newurl"
wp option update home "$newurl"

echo "Upgrade database schema to this WordPress version ..."
wp core update-db
wp rewrite flush
wp cache flush

echo "Lockdown, then update plugins, themes & translations ..."
/usr/local/sbin/wordpress-lockdown on
/usr/local/sbin/wordpress-update

umask 077
cp "$tmp/wp-config.php" /root/wp-config.old-site.php
custom=$(grep -o "define *( *['\"][A-Za-z_]*['\"]" "$tmp/wp-config.php" | sed "s/.*['\"]\([A-Za-z_]*\)['\"]/\1/" \
  | grep -v -x -E 'DB_(NAME|USER|PASSWORD|HOST|CHARSET|COLLATE)|(AUTH|SECURE_AUTH|LOGGED_IN|NONCE)_(KEY|SALT)|ABSPATH|WP_DEBUG|FS_METHOD' | sort -u)
rm -f /root/wordpress-initial-admin.txt

echo "Checking the site responds ..."
host=$(echo "$newurl" | sed -E 's|^https?://||; s|[:/].*||')
code=$(curl -s -o /dev/null -w '%{http_code}' --resolve "$host:80:127.0.0.1" --resolve "$host:443:127.0.0.1" "$newurl/")
wp plugin list --fields=name,status,version,update
wp theme list --fields=name,status,version,update

echo "
==============================================================="
echo "Loaded. $newurl/ answered HTTP $code"
[[ $code == 5* ]] && echo "
A plugin or theme is probably failing on this newer PHP. See /var/log/php-fpm/error.log, then e.g.
  sudo -u $WP_USER /usr/local/bin/wp --path=$WEBROOT --skip-plugins plugin deactivate <name>"
echo "
- Log in with the OLD site's usernames & passwords. The provisioning admin account no longer exists.
- Plugins not on wordpress.org (premium or custom) were not updated: check them by hand."
[[ -d $quarantine ]] && echo "- Quarantined files are in $quarantine. Review, then delete."
[[ -n $custom ]] && echo "- The old wp-config.php set these, which the new one doesn't. Add any you still need
  with: sudo -u $WP_USER /usr/local/bin/wp --path=$WEBROOT config set <NAME> <value> --raw
  (old file kept at /root/wp-config.old-site.php)
$(echo "$custom" | sed 's/^/    /')"
if [[ $newurl != "https://$DOMAIN" ]] ; then
  echo "- When DNS for the real domain points here, run: sudo ~/rocky-wordpress/rocky-nginx-ssl.sh <domain>"
fi
