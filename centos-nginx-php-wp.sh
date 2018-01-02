# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
echo "=================================================="
echo "Installing nginx php wp"
echo "=================================================="

echo 'Mariadb for WordPress...'
  if [ -f mariadbpassword ] ; then 
    echo 'using mariadbpassword file in '`pwd`
    mariadbpassword=$(cat mariadbpassword)
  else
    echo 'creating mariadb root password...'
      pwseed="$HOSTNAME $(date --rfc-3339=ns)"
      mariadbpassword=`echo $pwseed | md5sum | sed -e 's!\s!!g' -e 's!-!!g'`
      echo $mariadbpassword >> mariadbpassword
      chmod 0600 mariadbpassword
  fi
  systemctl enable mariadb
  systemctl start mariadb
  echo "
Y
$mariadbpassword
$mariadbpassword
Y
Y
Y
Y
" | mysql_secure_installation


echo nginx...
  yum install -y nginx
  mv /etc/nginx.conf /etc/ngix.conf.default

echo php...
  yum install -y php-fpm php-mysql php
  cp /etc/php-fpm.conf /etc/php-fpm.conf.default
  printf '\n#cgi.fix_pathinfo=0\n' >> /etc/php-fpm.conf
  systemctl restart php-fpm

echo WordPress...
  yum install -y php-gd  mariadb-server mariadb  
if [ -f /usr/share/nginx/html/wp-activate.php ] ; then echo 'already installed.'
else
  curl https://wordpress.org/latest.tar.gz | tar xzv \
    && mv wordpress/* /usr/share/nginx/html/ \
    && rmdir -f wordpress
  curl https://downloads.wordpress.org/plugin/wp-fail2ban.3.5.3.zip -O \
    && unzip wp-fail2ban.3.5.3.zip \
    && mv wp-fail2ban /usr/share/nginx/html/wp-content/plugins/ \
    && rm wp-fail2ban.3.5.3.zip
fi

echo "nginx config for php..."

cat > /etc/nginx.conf <<"EOF"
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
    index index.php index.html

    # Load configuration files for the default server block.
    include /etc/nginx/default.d/*.conf;

    location ~ \.php$ {
      fastcgi_pass  localhost:9000;
      include /etc/nginx/fastcgi.conf;
    }

    location ~ /\.ht {
          deny all;
    }        

    location / {
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

echo >> /etc/fail2ban/jail.local <<"EOF"
[nginx-http-auth]
enabled = true

# To use 'nginx-limit-req' jail you should have `ngx_http_limit_req_module`
# and define `limit_req` and `limit_req_zone` as described in nginx documentation
# http://nginx.org/en/docs/http/ngx_http_limit_req_module.html
# or for example see in 'config/filter.d/nginx-limit-req.conf'
[nginx-limit-req]

[nginx-botsearch]
enabled = true

[php-url-fopen]
enabled = true
logpath = %(nginx_access_log)s

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
EOF

firewall-cmd --permanent --zone=public --add-service=http
