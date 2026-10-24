#!/bin/bash
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
# usage: dnf-nginx-php-mariadb-wp.sh [<domain> [<admin-email> [<admin-username>]]]
#
#   Installs nginx, php-fpm, mariadb and WordPress, fully unattended, and only opens the
#   firewall once WordPress is installed with a random admin password. (A fresh install left
#   waiting at wp-admin/setup-config.php can be hijacked by bots within minutes.)
#
#   <domain> whose DNS already points here => rocky-nginx-ssl.sh gets a Let's Encrypt certificate.
#   No <domain> => served over http on this server's IP address.
#
#   Also installs WP-CLI, the wordpress-{backup,restore,update,lockdown} commands, and systemd timers
#   for daily backup, daily updates, and wp-cron.
#
echo "=================================================="
echo "Installing nginx php mariadb wp"
echo "=================================================="

scriptdir=$(cd "$(dirname "$0")" && pwd)
function die { echo "ERROR: $*" >&2 ; exit 1 ; }
function randompassword { head -c 64 /dev/urandom | base64 | tr -dc 'A-Za-z0-9' | head -c ${1:-32} ; }
[[ $(id -u) == 0 ]] || die "Run me as root, or with sudo"

[[ -f /etc/wordpress-site.conf ]] && . /etc/wordpress-site.conf
ip4=$(ip -o -4 route get 1.1.1.1 | sed -n 's/.* src \([0-9.]*\).*/\1/p')
DOMAIN=${1:-${DOMAIN:-$ip4}}
EMAIL=${2:-${EMAIL:-}}
adminuser=${3:-${EMAIL%%@*}}
adminuser=${adminuser:-wpadmin}
WEBROOT=${WEBROOT:-/var/www/wordpress}
WP_USER=${WP_USER:-wordpress}
WP_LOCALE=${WP_LOCALE:-en_GB}
BACKUP_DIR=${BACKUP_DIR:-/var/backup/wordpress}
KEEP_DAYS=${KEEP_DAYS:-21}
dbname=wordpress
dbuser=wordpress

[[ $DOMAIN =~ ^[A-Za-z0-9.-]+$ ]] || die "'$DOMAIN' doesn't look like a domain name or IPv4 address"
[[ -z $EMAIL || $EMAIL =~ ^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+$ ]] || die "'$EMAIL' doesn't look like an email address"

cat > /etc/wordpress-site.conf <<EOF
# Read by dnf-nginx-php-mariadb-wp.sh, rocky-nginx-ssl.sh and /usr/local/sbin/wordpress-*
DOMAIN=$DOMAIN
EMAIL=$EMAIL
WEBROOT=$WEBROOT
WP_USER=$WP_USER
WP_LOCALE=$WP_LOCALE
BACKUP_DIR=$BACKUP_DIR
KEEP_DAYS=$KEEP_DAYS
EOF

echo "Choosing the newest supported php, nginx and mariadb streams ..."
  # Rocky 9 defaults are php 8.0, nginx 1.20 & mariadb 10.5, which are all past upstream end-of-life.
  # Rocky 10 has no module streams and this does nothing.
  for m in php nginx mariadb ; do
    stream=$(dnf -q module list "$m" 2>/dev/null | awk -v m="$m" '$1==m {print $2}' | sort -V | tail -1)
    [[ -n $stream ]] && { dnf -y module enable "$m:$stream" || echo "(keeping already-enabled $m stream)" ; }
  done

echo "Packages ..."
  dnf -y install nginx mariadb-server mariadb php-fpm php-cli php-mysqlnd php-gd php-xml php-mbstring php-opcache \
    policycoreutils-python-utils tar rsync || die "package install failed"
  # recommended by WordPress Site Health; names vary between Rocky versions, so don't fail on a missing one
  dnf -y install --setopt=strict=0 php-intl php-pecl-zip php-sodium php-pecl-imagick

echo 'Mariadb, listening on localhost only ...'
  cat > /etc/my.cnf.d/zz-wordpress.cnf <<"EOF"
[mysqld]
bind-address = 127.0.0.1
skip-name-resolve
EOF
  restorecon /etc/my.cnf.d/zz-wordpress.cnf
  systemctl enable mariadb
  systemctl restart mariadb || die "mariadb didn't start"
  # What mariadb-secure-installation does. Root logs in by unix_socket (root's shell login), so needs no password.
  mariadb <<"EOF"
DELETE FROM mysql.global_priv WHERE User='';
DELETE FROM mysql.global_priv WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

echo "WordPress system user, which owns the files and runs the php-fpm pool ..."
  id $WP_USER &>/dev/null || useradd --system --home-dir /var/lib/$WP_USER --create-home --shell /sbin/nologin $WP_USER
  mkdir -p $WEBROOT && chown $WP_USER: $WEBROOT

echo php ...
  cat > /etc/php.d/99-wordpress.ini <<"EOF"
expose_php = Off
cgi.fix_pathinfo = 0
allow_url_include = Off
upload_max_filesize = 32M
post_max_size = 34M
memory_limit = 256M
max_execution_time = 60
session.cookie_httponly = 1
EOF
  cat > /etc/php-fpm.d/wordpress.conf <<EOF
[wordpress]
user = $WP_USER
group = $WP_USER
listen = /run/php-fpm/wordpress.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0660
; ondemand + max_requests keeps memory down & recycles workers, instead of cron restarts of php-fpm
pm = ondemand
pm.max_children = 8
pm.process_idle_timeout = 60s
pm.max_requests = 500
catch_workers_output = yes
security.limit_extensions = .php
php_value[session.save_path] = /var/lib/php/session-$WP_USER
EOF
  mkdir -p /var/lib/php/session-$WP_USER && chown $WP_USER: /var/lib/php/session-$WP_USER && chmod 700 /var/lib/php/session-$WP_USER
  semanage fcontext -a -e /var/lib/php/session /var/lib/php/session-$WP_USER 2>/dev/null
  restorecon -R /var/lib/php /etc/php.d /etc/php-fpm.d
  # the default www pool is unused; stop it holding idle workers
  sed -i 's/^pm = dynamic/pm = ondemand/' /etc/php-fpm.d/www.conf
  systemctl enable php-fpm
  systemctl restart php-fpm || die "php-fpm didn't start"

echo "WP-CLI ..."
  if [[ ! -x /usr/local/bin/wp ]] ; then
    tmp=$(mktemp -d)
    curl -fsSL -o $tmp/wp-cli.phar https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar \
      && echo "$(curl -fsSL https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar.sha512)  $tmp/wp-cli.phar" | sha512sum -c - \
      && install -m 0755 $tmp/wp-cli.phar /usr/local/bin/wp
    rm -rf $tmp
  fi
  [[ -x /usr/local/bin/wp ]] || die "WP-CLI install failed"
  restorecon /usr/local/bin/wp
  function wp { runuser -u $WP_USER -- /usr/local/bin/wp --path="$WEBROOT" --skip-plugins --skip-themes "$@" ; }

echo "WordPress database ..."
  if [[ -f $WEBROOT/wp-config.php ]] ; then dbpass=$(wp config get DB_PASSWORD) ; else dbpass=$(randompassword 32) ; fi
  "$scriptdir/wordpress-create-database.sh" $dbname $dbuser "$dbpass" || die "database creation failed"

echo "WordPress ($WP_LOCALE) ..."
  [[ -f $WEBROOT/wp-includes/version.php ]] || wp core download --locale=$WP_LOCALE || die "wp core download failed"
  if [[ ! -f $WEBROOT/wp-config.php ]] ; then
    wp config create --dbname=$dbname --dbuser=$dbuser --dbpass="$dbpass" --dbhost=localhost --locale=$WP_LOCALE \
      --extra-php <<"EOF" || die "wp config create failed"
/* No theme/plugin code editor in the dashboard */
define( 'DISALLOW_FILE_EDIT', true );
/* wp-cron is run by the wordpress-cron.timer, not on page views */
define( 'DISABLE_WP_CRON', true );
EOF
    chmod 600 $WEBROOT/wp-config.php
  fi
  if ! wp core is-installed 2>/dev/null ; then
    adminpass=$(randompassword 24)
    wp core install --url="http://$DOMAIN" --title="$DOMAIN" --admin_user="$adminuser" \
      --admin_email="${EMAIL:-$adminuser@$DOMAIN}" --admin_password="$adminpass" --skip-email \
      || die "wp core install failed"
    umask 077
    printf 'WordPress admin login for http://%s/wp-admin/\nuser: %s\npassword: %s\nChange the password, then delete this file.\n' \
      "$DOMAIN" "$adminuser" "$adminpass" > /root/wordpress-initial-admin.txt
    umask 022
  fi
  wp core verify-checksums

echo "wordpress-* commands and systemd timers ..."
  for c in backup restore update lockdown create-database ; do
    install -m 0750 "$scriptdir/wordpress-$c.sh" /usr/local/sbin/wordpress-$c
  done
  restorecon /usr/local/sbin/wordpress-*

  cat > /etc/systemd/system/wordpress-backup.service <<"EOF"
[Unit]
Description=Backup WordPress database and files to BACKUP_DIR
After=mariadb.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/wordpress-backup
EOF
  cat > /etc/systemd/system/wordpress-backup.timer <<"EOF"
[Unit]
Description=Daily WordPress backup
[Timer]
OnCalendar=*-*-* 03:15
RandomizedDelaySec=30m
Persistent=true
[Install]
WantedBy=timers.target
EOF
  cat > /etc/systemd/system/wordpress-update.service <<"EOF"
[Unit]
Description=Backup, then update WordPress core, plugins, themes and translations with WP-CLI
After=mariadb.service
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/wordpress-update
EOF
  cat > /etc/systemd/system/wordpress-update.timer <<"EOF"
[Unit]
Description=Daily WordPress update
[Timer]
OnCalendar=*-*-* 04:15
RandomizedDelaySec=30m
Persistent=true
[Install]
WantedBy=timers.target
EOF
  # wp-cron runs plugin code, so request it through nginx & php-fpm where SELinux lockdown applies, not via WP-CLI
  cat > /etc/systemd/system/wordpress-cron.service <<"EOF"
[Unit]
Description=Run due WordPress wp-cron events
After=nginx.service php-fpm.service mariadb.service
[Service]
Type=oneshot
DynamicUser=yes
ExecStart=/bin/sh -c '. /etc/wordpress-site.conf ; curl -fsS -o /dev/null -L --resolve "$${DOMAIN}:80:127.0.0.1" --resolve "$${DOMAIN}:443:127.0.0.1" "http://$${DOMAIN}/wp-cron.php?doing_wp_cron"'
EOF
  cat > /etc/systemd/system/wordpress-cron.timer <<"EOF"
[Unit]
Description=wp-cron every 10 minutes
[Timer]
OnBootSec=5min
OnUnitActiveSec=10min
[Install]
WantedBy=timers.target
EOF
  systemctl daemon-reload
  systemctl enable --now wordpress-backup.timer wordpress-update.timer wordpress-cron.timer

echo "SELinux: lock WordPress code read-only to the website; only uploads are writable ..."
  /usr/local/sbin/wordpress-lockdown on
  # outbound https, for WordPress update checks and plugins calling APIs, e.g. an SMTP or anti-spam plugin
  setsebool -P httpd_can_network_connect on

echo "nginx config for WordPress ..."
  mkdir -p /var/www/acme && restorecon -R /var/www/acme
  [[ -f /etc/nginx/nginx.conf.orig ]] || cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig

  # nginx.conf: the distro default minus its server{} block, which would clash with our default_server
  cat > /etc/nginx/nginx.conf <<"EOF"
# English Documentation: http://nginx.org/en/docs/
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/doc/nginx/README.dynamic.
include /usr/share/nginx/modules/*.conf;

events {
  worker_connections 1024;
}

http {
  log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                    '$status $body_bytes_sent "$http_referer" '
                    '"$http_user_agent" "$http_x_forwarded_for"';

  access_log  /var/log/nginx/access.log  main;

  sendfile            on;
  tcp_nopush          on;
  keepalive_timeout   65;
  types_hash_max_size 4096;
  server_tokens       off;

  include             /etc/nginx/mime.types;
  default_type        application/octet-stream;

  # Load modular configuration files from the /etc/nginx/conf.d directory.
  include /etc/nginx/conf.d/*.conf;
}
EOF

  cat > /etc/nginx/wordpress-php.conf <<"EOF"
# included in the php locations of wordpress-site.conf
try_files $uri =404;
fastcgi_pass unix:/run/php-fpm/wordpress.sock;
fastcgi_index index.php;
include fastcgi_params;
fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
EOF

  cat > /etc/nginx/wordpress-site.conf <<EOF
# WordPress server settings, included in the server{} blocks of conf.d/wordpress.conf
root $WEBROOT;
index index.php;
client_max_body_size 34M;

add_header X-Content-Type-Options "nosniff" always;
add_header X-Frame-Options "SAMEORIGIN" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "camera=(), microphone=(), geolocation=()" always;

# Block ?author=N username enumeration
if (\$args ~* "(^|&)author=[0-9]") { return 403; }

location / {
  try_files \$uri \$uri/ /index.php?\$args;
}

# Never serve dotfiles (.htaccess .git .env ...) or these
location ~ /\. { deny all; }
location ~* ^/(wp-config\.php|wp-config-sample\.php|readme\.html|license\.txt)\$ { deny all; }

# Never execute php that has been uploaded
location ~* ^/wp-content/uploads/.*\.(php|phar|phtml)\$ { deny all; }

# xmlrpc.php is used for password brute-forcing and pingback DDoS. Jetpack and the
# WordPress mobile apps need it: replace 'deny all;' with 'include wordpress-php.conf;' to allow it.
location = /xmlrpc.php { deny all; }

location = /wp-login.php {
  limit_req zone=wordpress_login burst=5 nodelay;
  include wordpress-php.conf;
}

location ~* \.(css|js|mjs|png|jpe?g|gif|webp|avif|svg|ico|woff2?)\$ {
  expires 30d;
  access_log off;
  try_files \$uri =404;
}

location ~ \.php\$ {
  include wordpress-php.conf;
}
EOF

  cat > /etc/nginx/conf.d/wordpress.conf <<EOF
# http only. rocky-nginx-ssl.sh replaces this with an https version.
limit_req_zone \$binary_remote_addr zone=wordpress_login:10m rate=10r/m;
limit_req_status 429;

server {
  listen       80 default_server;
  listen       [::]:80 default_server;
  server_name  $DOMAIN;

  location ^~ /.well-known/acme-challenge/ { root /var/www/acme; default_type text/plain; }

  include wordpress-site.conf;
}
EOF
  restorecon -R /etc/nginx
  nginx -t || die "nginx config test failed"
  systemctl enable nginx
  systemctl restart nginx

echo 'fail2ban for nginx and WordPress logins ...'
  cat > /etc/fail2ban/filter.d/wordpress-login.conf <<"EOF"
# Failed wp-login.php logins return 200 (the form again); successful ones redirect with 302.
# xmlrpc.php is denied by nginx, so anything POSTing to it is a bot.
[Definition]
failregex = ^<HOST> -[^"]*"POST /wp-login\.php[^"]*" 200
            ^<HOST> -[^"]*"POST /xmlrpc\.php
ignoreregex =
EOF
  # backend = auto: these jails read log files, not the journal that fail2ban-systemd defaults to
  cat > /etc/fail2ban/jail.d/wordpress.conf <<"EOF"
[wordpress-login]
enabled  = true
backend  = auto
filter   = wordpress-login
logpath  = /var/log/nginx/access.log
port     = http,https
maxretry = 6
findtime = 10m

[nginx-limit-req]
enabled  = true
backend  = auto

[nginx-botsearch]
enabled  = true
backend  = auto
EOF
  restorecon -R /etc/fail2ban
  systemctl restart fail2ban
  fail2ban-client status

echo "Firewall: open http and https, now that WordPress is installed ..."
  firewall-cmd --permanent --zone=public --add-service=http --add-service=https
  firewall-cmd --reload

if [[ $DOMAIN =~ [A-Za-z] ]] ; then
  echo "Let's Encrypt certificate for $DOMAIN ..."
  "$scriptdir/rocky-nginx-ssl.sh" "$DOMAIN" "$EMAIL" \
    || echo "WARNING: no certificate yet. Once DNS for $DOMAIN points at this server, run: rocky-nginx-ssl.sh $DOMAIN $EMAIL"
fi

curl -sI http://localhost/ -H "Host: $DOMAIN" | head -1

echo "==============================================================="
echo "Installed nginx, php, mariadb, WordPress, fail2ban rules and firewall rules."
[[ -f /root/wordpress-initial-admin.txt ]] && echo "WordPress admin user '$adminuser'. Its password is in: sudo cat /root/wordpress-initial-admin.txt"
echo "
Backups:  daily into $BACKUP_DIR, kept $KEEP_DAYS days. Pull them off-server with backup-pull.sh.ps1
Updates:  daily, by wordpress-update.timer, after a backup.
Lockdown: plugins & themes can only be installed by WP-CLI, or after: wordpress-lockdown off
"
