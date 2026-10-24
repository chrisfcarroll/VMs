#!/bin/bash
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
# usage: rocky-nginx-ssl.sh [<domain> [<email>]]
#
#   Gets a Let's Encrypt certificate (auto-renewed by certbot-renew.timer), switches nginx to
#   https-only with http redirecting to https, and switches WordPress's URLs to https.
#   DNS for <domain> must already point at this server, and port 80 must be reachable.
#   Defaults come from /etc/wordpress-site.conf, written by dnf-nginx-php-mariadb-wp.sh
#
echo "nginx ssl..."
function die { echo "ERROR: $*" >&2 ; exit 1 ; }
[[ $(id -u) == 0 ]] || die "Run me as root, or with sudo"
. /etc/wordpress-site.conf || die "run dnf-nginx-php-mariadb-wp.sh first"
domain=${1:-$DOMAIN}
email=${2:-$EMAIL}
[[ $domain =~ ^[A-Za-z0-9.-]+$ && $domain =~ [A-Za-z] ]] || die "'$domain' must be a DNS name, not an IP address"

dnf -y install certbot || die "certbot install failed"
mkdir -p /var/www/acme && restorecon -R /var/www/acme

if [[ -n $email ]] ; then account="--email $email --no-eff-email" ; else account="--register-unsafely-without-email" ; fi
certbot certonly --webroot -w /var/www/acme -d "$domain" $account \
  --agree-tos --non-interactive --keep-until-expiring \
  || die "certbot failed. Check that http://$domain/ reaches this server."

mkdir -p /etc/letsencrypt/renewal-hooks/deploy
printf '#!/bin/sh\nsystemctl reload nginx\n' > /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
chmod 755 /etc/letsencrypt/renewal-hooks/deploy/reload-nginx.sh
systemctl enable --now certbot-renew.timer

# nginx 1.25.1+ deprecates 'listen ... http2' in favour of 'http2 on;'
nginxversion=$(nginx -v 2>&1 | sed 's|.*/||')
if [[ $(printf '%s\n' 1.25.1 "$nginxversion" | sort -V | head -1) == 1.25.1 ]]
  then listen443="listen 443 ssl; listen [::]:443 ssl; http2 on;"
  else listen443="listen 443 ssl http2; listen [::]:443 ssl http2;"
fi

echo "nginx config for ssl..."
cp /etc/nginx/conf.d/wordpress.conf /etc/nginx/wordpress.conf.http-only
cat > /etc/nginx/conf.d/wordpress.conf <<EOF
# https. The http-only version this replaced is in /etc/nginx/wordpress.conf.http-only
limit_req_zone \$binary_remote_addr zone=wordpress_login:10m rate=10r/m;
limit_req_status 429;

server {
  listen       80 default_server;
  listen       [::]:80 default_server;
  server_name  _;

  location ^~ /.well-known/acme-challenge/ { root /var/www/acme; default_type text/plain; }
  location / { return 301 https://$domain\$request_uri; }
}

server {
  $listen443
  server_name  $domain;

  ssl_certificate     /etc/letsencrypt/live/$domain/fullchain.pem;
  ssl_certificate_key /etc/letsencrypt/live/$domain/privkey.pem;
  # TLS 1.2+ with ciphers from the system crypto-policy (update-crypto-policies), as Rocky's own nginx.conf does
  ssl_protocols TLSv1.2 TLSv1.3;
  ssl_ciphers PROFILE=SYSTEM;
  ssl_prefer_server_ciphers off;
  ssl_session_cache shared:SSL:10m;
  ssl_session_timeout 1d;
  ssl_session_tickets off;
  # No ssl_stapling: Let's Encrypt stopped running OCSP in 2025

  add_header Strict-Transport-Security "max-age=31536000" always;

  include wordpress-site.conf;
}
EOF
restorecon -R /etc/nginx
if ! nginx -t ; then
  cp /etc/nginx/wordpress.conf.http-only /etc/nginx/conf.d/wordpress.conf
  die "nginx config test failed; reverted to http-only"
fi
systemctl reload nginx

echo "WordPress URLs to https://$domain ..."
function wp { runuser -u $WP_USER -- /usr/local/bin/wp --path="$WEBROOT" --skip-plugins --skip-themes "$@" ; }
oldurl=$(wp option get siteurl)
wp option update home "https://$domain"
wp option update siteurl "https://$domain"
[[ $oldurl == "https://$domain" ]] || wp search-replace "$oldurl" "https://$domain" --skip-columns=guid --report-changed-only
wp config set FORCE_SSL_ADMIN true --raw

sed -i "s/^DOMAIN=.*/DOMAIN=$domain/" /etc/wordpress-site.conf
curl -sI "https://$domain/" | head -1
