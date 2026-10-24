#!/bin/bash
# wordpress-lockdown on|off|status
#   on  : (default) SELinux makes WordPress's code read-only to the website (php-fpm). Only wp-content/uploads
#         is writable. So an exploited plugin can't plant a backdoor in .php files. Dashboard install & update of
#         plugins/themes/core is turned off; wordpress-update.timer does updates with WP-CLI instead.
#   off : the website can write its own files, so dashboard plugin/theme installs & updates work.
#         Turn lockdown back on when you're done.
#   Installed as /usr/local/sbin/wordpress-lockdown
. /etc/wordpress-site.conf || exit 1
function wp { runuser -u "$WP_USER" -- /usr/local/bin/wp --path="$WEBROOT" --skip-plugins --skip-themes "$@" ; }
function fcontext { semanage fcontext -a -t "$1" "$2" 2>/dev/null || semanage fcontext -m -t "$1" "$2" ; }

case ${1:-status} in
  on)
    fcontext httpd_sys_content_t    "$WEBROOT(/.*)?"
    fcontext httpd_sys_rw_content_t "$WEBROOT/wp-content/uploads(/.*)?"
    runuser -u "$WP_USER" -- mkdir -p "$WEBROOT/wp-content/uploads"
    restorecon -R "$WEBROOT"
    wp config set DISALLOW_FILE_MODS true --raw
    ;;
  off)
    fcontext httpd_sys_rw_content_t "$WEBROOT(/.*)?"
    restorecon -R "$WEBROOT"
    wp config set DISALLOW_FILE_MODS false --raw
    ;;
  status) ;;
  *) echo "usage: wordpress-lockdown on|off|status" ; exit 1 ;;
esac

echo "DISALLOW_FILE_MODS=$(wp config get DISALLOW_FILE_MODS 2>/dev/null)"
ls -Zd "$WEBROOT" "$WEBROOT/wp-content/uploads"
[[ $(getenforce) == Enforcing ]] || echo "WARNING: SELinux is $(getenforce), so lockdown is NOT protecting your files"
