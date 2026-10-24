#!/bin/bash
# wordpress-update : back up, then update WP-CLI, WordPress core, plugins, themes & translations, then verify checksums.
#   Outdated plugins are how most WordPress sites get compromised, so this runs daily via wordpress-update.timer.
#   If an update breaks the site, restore the backup taken just before:  ls -t $BACKUP_DIR | head
#   Installed as /usr/local/sbin/wordpress-update
. /etc/wordpress-site.conf || exit 1
function wp { runuser -u "$WP_USER" -- /usr/local/bin/wp --path="$WEBROOT" --skip-plugins --skip-themes "$@" ; }

# Skip the backup if the daily backup has only just run
if [[ -z $(find "$BACKUP_DIR" -name 'wordpress-*.tar.gz' -mmin -120 2>/dev/null) ]] ; then
  /usr/local/sbin/wordpress-backup || { echo "Backup failed; not updating" >&2 ; exit 1 ; }
fi

/usr/local/bin/wp cli update --yes --allow-root && restorecon /usr/local/bin/wp

# Lockdown sets DISALLOW_FILE_MODS, which also stops WordPress's own updater. Lift it just for
# WP-CLI. SELinux still stops the website itself writing code, because only this process can.
lockeddown=$(wp config get DISALLOW_FILE_MODS 2>/dev/null)
if [[ $lockeddown == 1 || $lockeddown == true ]] ; then
  trap 'wp config set DISALLOW_FILE_MODS true --raw' EXIT
  wp config set DISALLOW_FILE_MODS false --raw
fi

wp core update
wp core update-db
wp plugin update --all
wp theme update --all
wp language core update
wp language plugin update --all
wp language theme update --all
restorecon -R "$WEBROOT"

wp core verify-checksums || echo "WARNING: WordPress core files don't match wordpress.org checksums. Investigate!" >&2
wp plugin verify-checksums --all || echo "WARNING: some plugin files don't match wordpress.org checksums (premium plugins can't be checked)" >&2
