# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
echo "=================================================="
echo "Installing nginx php wp"
echo "=================================================="

echo "nginx..."

  yum install -y nginx
  cp /etc/nginx/nginx.conf nginx.conf.orig
  chown -R nginx:nginx /usr/share/nginx/html

echo 'Mariadb for WordPress...'
  yum install -y mariadb-server mariadb 
  if [[ -f ~/.my.cnf && ! -z $(grep -o 'password=' .my.cnf) ]] ; then
    mariadbpassword=$(grep -o 'password=.*' ~/.my.cnf | sed 's/password=//' )
  else
    echo 'creating mariadb root password...'
    mariadbpassword=$( < /dev/urandom tr -dc [0-z] | tr -d "\\=d'%\`" | head -c25)
    echo "[client]
password=$mariadbpassword" > ~/.my.cnf
    chmod 0600 ~/.my.cnf
  fi
  systemctl enable mariadb
  systemctl start mariadb

echo php...
  yum install -y php-fpm php-mysql php-xml
  cp /etc/php-fpm.conf /etc/php-fpm.conf.orig
  cp /etc/php.ini      /etc/php.ini.orig
  cp /etc/php-fpm.d/www.conf ~/etc_php-fpm.d_www.conf.orig 
  sed -ie 's/^[;]*cgi.fix_pathinfo=./cgi.fix_pathinfo=0/' /etc/php.ini
  sed -ie 's/upload_max_filesize = .*$/upload_max_filesize = 10M/' /etc/php.ini  
  sed -ie 's/= apache/= nginx/' /etc/php-fpm.d/www.conf
  systemctl start php-fpm
  systemctl enable php-fpm

wordpresssource='https://en-gb.wordpress.org/wordpress-4.9.1-en_GB.tar.gz'

echo WordPress from $wordpresssource ...
  yum install -y php-gd
if [ -f /usr/share/nginx/html/wp-activate.php ] ; then echo 'already installed.'
else
  curl $wordpresssource | tar xzv \
    && mv wordpress/* /usr/share/nginx/html/ \
    && rmdir wordpress

  curl https://downloads.wordpress.org/plugin/wp-fail2ban.3.5.3.zip -O \
    && unzip wp-fail2ban.3.5.3.zip \
    && mv wp-fail2ban /usr/share/nginx/html/wp-content/plugins/ \
    && rm wp-fail2ban.3.5.3.zip
fi

echo "nginx config for php..."

cat > /etc/nginx/nginx.conf <<"EOF"
# English Documentation: http://nginx.org/en/docs/
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

# Load dynamic modules. See /usr/share/nginx/README.dynamic.
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
  tcp_nodelay         on;
  keepalive_timeout   65;
  types_hash_max_size 2048;

  include             /etc/nginx/mime.types;
  default_type        application/octet-stream;

  # Load modular configuration files from the /etc/nginx/conf.d directory.
  # See http://nginx.org/en/docs/ngx_core_module.html#include
  # for more information.
  include /etc/nginx/conf.d/*.conf;

  server {
    listen       80 default_server;
    listen       [::]:80 default_server;
    server_name  www.cafe-encounter.net;
    root         /usr/share/nginx/html;
    index index.php index.html;
    client_max_body_size 10M;

    # Load configuration files for the default server block.
    include /etc/nginx/default.d/*.conf;

    location / {
      index index.php index.html index.htm;
      try_files $uri $uri/ /index.php?$args;
    }

    location ~ /\.ht {
      deny all;
    }

    location ~ \.php$ {
        try_files $uri =404;
        fastcgi_pass localhost:9000;
        fastcgi_index index.php;
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        include fastcgi_params;
    }

    error_page 404 /404.html;
        location = /40x.html {
    }

    error_page 500 502 503 504 /50x.html;
        location = /50x.html {
    }

  }

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
#
#        # Load configuration files for the default server block.
#        include /etc/nginx/default.d/*.conf;
#
#        location / {
#        }
#
#        error_page 404 /404.html;
#            location = /40x.html {
#        }
#
#        error_page 500 502 503 504 /50x.html;
#            location = /50x.html {
#        }
#    }

}    
EOF

  systemctl enable nginx
  systemctl start nginx

echo 'Update fail2ban jail.local for nginx, php and WordPress...'

echo '
[nginx-http-auth]
enabled = true

# To use nginx-limit-req jail you should have `ngx_http_limit_req_module`
# and define `limit_req` and `limit_req_zone` as described in nginx documentation
# http://nginx.org/en/docs/http/ngx_http_limit_req_module.html
# or for example see in config/filter.d/nginx-limit-req.conf
[nginx-limit-req]

[nginx-botsearch]
enabled = true

[php-url-fopen]
enabled = true
logpath = %(nginx_access_log)s
' >> /etc/fail2ban/jail.local
fail2ban-client reload

echo '===============================================================
Running mysql_secure_installation interactively before opening firewall ports:
==============================================================='
cat .my.cnf
mysql_secure_installation

firewall-cmd --permanent --zone=public --add-service=http
firewall-cmd --reload

echo 'Installed nginx, php, WordPress'
echo 'Done fail2ban rules and firewall rules fir php and nginx'

curl -i localhost/index.php

ip4=$(ip -o -4 addr list eth0 | awk '{print $4}' | cut -d/ -f1)
ip6=$(ip -o -6 addr list eth0 | awk '{print $4}' | cut -d/ -f1)

while $( curl -sI localhost/index.php | grep -q 'HTTP/1.1 302')
do
  read -p "========================================================
Manual steps for WordPress:
- ./create-wordpress-database databasename wordpressusername password
- Browse to http://$ip4/wp-admin/setup-config.php

After that we can continue to set fail2ban rules for WordPress.
Waiting ....
==============================================================="
done

echo "define('FS_METHOD', 'direct');" >> /usr/share/nginx/html/wp-config.php 

echo '
[wordpress-hard]
enabled = true
filter = wordpress-hard
logpath = /var/log/auth.log
maxretry = 1
port = http,https

[wordpress-soft]
enabled = true
filter = wordpress-soft
logpath = /var/log/auth.log
maxretry = 3
port = http,https
' >> /etc/fail2ban/jail.local
fail2ban-client reload

