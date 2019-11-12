# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
echo "nginx ssl..."

mkdir -p /etc/ssl/private && chmod 700 /etc/ssl/private
if [[ -f /etc/ssl/private/nginx-selfsigned.key ]] ; then
  echo "/etc/ssl/private/nginx-selfsigned.key already exists"
else
  openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt
  tmux neww "openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout /etc/ssl/private/nginx-selfsigned.key -out /etc/ssl/certs/nginx-selfsigned.crt"
fi

echo "nginx config for ssl..."

nginxconf=${1:-/etc/nginx/nginx.conf}
domain=${2:-www.cafe-encounter.net}

grep -q '^ *listen 443' $nginxconf || \
  sed -ie \
    "s/listen *80 default_server;/listen 80 default_server;\n    listen 443 http2 ssl;/" \
    $nginxconf
grep -q '^ *listen \[::\]:443' $nginxconf || \
  sed -ie \
    's/listen *\[::\]:80 default_server;/listen \[::\]:80 default_server;\n    listen \[::\]:443 ssl http2 default_server;/' \
    $nginxconf

echo ssl_dhparam
grep -q '^ *ssl_dhparam' $nginxconf || \
  sed -ie \
    "s!server_name *$domain;!server_name  $domain;\n    ssl_dhparam /etc/ssl/certs/dhparam.pem;!" \
    $nginxconf

echo ssl_certificate_key
grep -q '^ *ssl_certificate_key' $nginxconf || \
  sed -ie \
    "s!server_name *$domain;!server_name  $domain;\n    ssl_certificate_key /etc/ssl/private/nginx-selfsigned.key;!" \
    $nginxconf

echo ssl_certificate
grep -q '^ *ssl_certificate_key' $nginxconf || \
  sed -ie \
    "s!server_name *$domain;!server_name  $domain;\n    ssl_certificate /etc/ssl/certs/nginx-selfsigned.crt;!" \
    $nginxconf

echo ssl_session_cache
grep -q '^ *ssl_certificate_key' $nginxconf || \
  sed -ie \
    "s/server_name *$domain;/server_name  $domain;\n    ssl_session_cache shared:SSL:1m;/" \
    $nginxconf

echo ssl_session_timeout
grep -q '^ *ssl_session_timeout' $nginxconf || \
  sed -ie \
    "s/server_name *$domain;/server_name  $domain;\n    ssl_session_timeout  10m;/" \
    $nginxconf

echo ssl_ciphers
grep -q '^ *ssl_ciphers' $nginxconf || \
  sed -ie \
    "s/server_name *$domain;/server_name  $domain;\n    ssl_ciphers HIGH:!aNULL:!MD5;/" \
    $nginxconf

echo ssl_prefer_server_ciphers
grep -q '^ *ssl_prefer_server_ciphers' $nginxconf || \
  sed -ie \
    "s/server_name *$domain;/server_name  $domain;\n    ssl_prefer_server_ciphers on;/" \
    $nginxconf

# Settings for a TLS enabled server.
#
#    server {
#        listen       443 ssl http2 default_server;
#        listen       [::]:443 ssl http2 default_server;
#        server_name  _;
#        root         /usr/share/nginx/html;
#
#        ssl_certificate "/etc/pki/nginx/server.crt";
#        ssl_certificate_key "/etc/pki/nginx/private/server.key";
#        ssl_session_cache shared:SSL:1m;
#        ssl_session_timeout  10m;
#        ssl_ciphers HIGH:!aNULL:!MD5;
#        ssl_prefer_server_ciphers on;
#    }

