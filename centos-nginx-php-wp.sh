# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
echo "=================================================="
echo "$BASH_SOURCE $*"
echo "On $HOSTNAME"
echo "=================================================="

yum install -y nginx
mv /etc/nginx.conf /etc/ngix.conf.default

yum install -y php-fpm php-mysql php
cp /etc/php-fpm.conf /etc/php-fpm.conf.default
printf '\n#cgi.fix_pathinfo=0\n' >> /etc/php-fpm.conf
systemctl restart php-fpm

yum install -y wordpress
echo WP installation???
curl https://downloads.wordpress.org/plugin/wp-fail2ban.3.5.3.zip -O
unzip wp-fail2ban.3.5.3.zip
mv wp-fail2ban /usr/share/nginx/html/wp-content/plugins/
rm wp-fail2ban.3.5.3.zip

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

        location / {
        }

        location ~ \.php$ {
          fastcgi_pass  localhost:9000;
          include /etc/nginx/fastcgi.conf;
        }

	    location ~ /\.ht {
            deny all;
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

firewall-cmd --permanent --zone=public --add-service=http
systemctl enable nginx
systemctl start nginx
