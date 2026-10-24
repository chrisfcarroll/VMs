#!/bin/bash
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
# Runs on the OLD server, copied there and run by wp-extract.sh.ps1
# usage: wp-extract-on-server.sh <webroot> <archive.tar.gz>
#
#   Packs into one archive everything needed to recreate the site on a new WordPress install:
#     database.sql   : mysqldump of the WordPress database, using the credentials in wp-config.php
#     wp-content/    : themes, plugins, uploads (media), languages. Caches are left out
#     wp-config.php  : for $table_prefix and any custom constants. (Contains secrets!)
#     site-info.txt  : urls, versions, active theme & plugins, for reference
#   Written for the CentOS 7 servers set up by ../CentOs, but only needs bash, tar and mysqldump.
#
webroot=${1:-/usr/share/nginx/html}
out=$2
function die { echo "ERROR: $*" >&2 ; exit 1 ; }
[[ $(id -u) == 0 ]] || die "Run me as root, or with sudo"
[[ -n $out ]] || die "usage: wp-extract-on-server.sh <webroot> <archive.tar.gz>"
[[ -f $webroot/wp-config.php && -d $webroot/wp-content ]] \
  || die "No WordPress (wp-config.php and wp-content/) in $webroot. Pass the right directory with -webroot"

function wpconfig { sed -n "s/^[^/#]*define *( *['\"]$1['\"] *, *['\"]\([^'\"]*\)['\"].*/\1/p" "$webroot/wp-config.php" | head -1 ; }
dbname=$(wpconfig DB_NAME) ; dbuser=$(wpconfig DB_USER) ; dbpass=$(wpconfig DB_PASSWORD) ; dbhost=$(wpconfig DB_HOST)
prefix=$(sed -n "s/^[[:space:]]*\$table_prefix *= *['\"]\([^'\"]*\)['\"].*/\1/p" "$webroot/wp-config.php" | head -1)
[[ -n $dbname && -n $dbuser ]] || die "Couldn't read DB_NAME and DB_USER from $webroot/wp-config.php"
[[ $prefix =~ ^[A-Za-z0-9_]+$ ]] || die "Couldn't read \$table_prefix from $webroot/wp-config.php"

tmp=$(mktemp -d /var/tmp/wp-extract.XXXXXX) ; chmod 700 "$tmp" ; trap 'rm -rf "$tmp"' EXIT
# credentials in a file, not on the command line where ps can see them
printf '[client]\nuser=%s\npassword="%s"\nhost=%s\n' "$dbuser" "$dbpass" "${dbhost:-localhost}" > "$tmp/my.cnf"
function sql { mysql --defaults-extra-file="$tmp/my.cnf" -N -B "$dbname" -e "$1" ; }

echo "Dumping database $dbname ..."
mysqldump --defaults-extra-file="$tmp/my.cnf" --single-transaction --quick --default-character-set=utf8mb4 "$dbname" \
  > "$tmp/database.sql" || die "mysqldump failed"
ls -l "$tmp/database.sql"

echo "Site info ..."
{
  echo "extracted_from=$(hostname -f)"
  echo "extracted_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "webroot=$webroot"
  echo "table_prefix=$prefix"
  echo "wordpress=$(sed -n "s/^\$wp_version = '\(.*\)';/\1/p" "$webroot/wp-includes/version.php")"
  echo "php=$(php -r 'echo PHP_VERSION;' 2>/dev/null)"
  echo "database=$(sql 'SELECT VERSION()')"
  sql "SELECT option_name, option_value FROM ${prefix}options WHERE option_name IN ('siteurl','home','blogname','template','stylesheet','permalink_structure')" \
    | sed 's/\t/=/'
  echo "active_plugins=$(sql "SELECT option_value FROM ${prefix}options WHERE option_name='active_plugins'" | grep -o '"[^"]*\.php"' | tr -d '"' | tr '\n' ' ')"
  echo "wp-content: $(du -sh "$webroot/wp-content" | cut -f1)"
} > "$tmp/site-info.txt"
cat "$tmp/site-info.txt"

echo "Packing wp-content ..."
cp -p "$webroot/wp-config.php" "$tmp/wp-config.php"
tar -czf "$out" --exclude='wp-content/cache' --exclude='wp-content/upgrade' --exclude='wp-content/*/cache' \
  -C "$tmp" database.sql site-info.txt wp-config.php -C "$webroot" wp-content \
  || { rm -f "$out" ; die "tar failed" ; }
chmod 600 "$out"
# so that a sudo user can scp it back
[[ -n $SUDO_USER ]] && chown "$SUDO_USER" "$out"
ls -l "$out"
