#!/bin/bash
# wordpress-backup : database dump + WordPress files + nginx & letsencrypt config, as one .tar.gz in BACKUP_DIR.
#   Deletes backups older than KEEP_DAYS. Prints the new backup's path.
#   Readable by group wheel, so that a sudo-capable admin can pull it off-server with backup-pull.sh.ps1
#   Installed as /usr/local/sbin/wordpress-backup, run daily by wordpress-backup.timer
set -o pipefail
. /etc/wordpress-site.conf || exit 1
umask 027

mkdir -p "$BACKUP_DIR" && chgrp wheel "$BACKUP_DIR" && chmod 750 "$BACKUP_DIR"
stamp=$(date -u +%Y%m%dT%H%M%SZ)
out="$BACKUP_DIR/wordpress-$(hostname -s)-$stamp.tar.gz"
[[ -e $out ]] && out="${out%.tar.gz}-$$.tar.gz"
tmp=$(mktemp -d) ; trap 'rm -rf "$tmp"' EXIT

dbname=$(sed -n "s/.*define( *'DB_NAME', *'\([^']*\)'.*/\1/p" "$WEBROOT/wp-config.php")
[[ -n $dbname ]] || { echo "Can't read DB_NAME from $WEBROOT/wp-config.php" >&2 ; exit 1 ; }

mariadb-dump --single-transaction --quick --routines --triggers --default-character-set=utf8mb4 "$dbname" \
  > "$tmp/database.sql" || { echo "mariadb-dump failed" >&2 ; exit 1 ; }

cat > "$tmp/backup-info.txt" <<EOF
host=$(hostname -f)
date=$stamp
$(cat /etc/wordpress-site.conf)
wordpress=$(sed -n "s/^\$wp_version = '\(.*\)';/\1/p" "$WEBROOT/wp-includes/version.php")
EOF

etcfiles=$(cd / && ls -d etc/nginx/conf.d/wordpress.conf etc/nginx/wordpress-*.conf etc/letsencrypt 2>/dev/null)
tar -czf "$out.partial" -C "$tmp" database.sql backup-info.txt -C / "${WEBROOT#/}" $etcfiles \
  || { rm -f "$out.partial" ; echo "tar failed" >&2 ; exit 1 ; }
mv "$out.partial" "$out" && chgrp wheel "$out"

find "$BACKUP_DIR" -name 'wordpress-*.tar.gz' -mtime +"$KEEP_DAYS" -delete
echo "$out"
