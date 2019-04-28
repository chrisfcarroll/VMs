# nginx ----------------------------------------------------------------------------
yum -y install nginx
[ -f /etc/nginx/nginx.conf.orig ] || cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig

[ -z "$(cat /etc/nginx/nginx.conf | grep '^\s*server')" ] || pausemax 5 "NGINX manual config required: remove the server {} section from /etc/nginx/nginx.conf." 

if [ ! -f /etc/nginx/conf.d/nginx-kestrel-on-5003.conf ] ; then 
    cat > nginx-kestrel-on-5003.conf <<"EOF"
server {
    listen                      80 http2 default;
    server_name ec2-54-72-9-204.eu-west-1.compute.amazonaws.com localhost;
    location / {
        proxy_pass              http://localhost:5003;
        # The default minimum configuration required for ASP.NET Core
        proxy_cache_bypass      $http_upgrade;
        proxy_redirect          off;
        proxy_set_header        Host $host;
        proxy_http_version      1.1; # Kestrel only speaks HTTP 1.1?
        proxy_set_header        Upgrade $http_upgrade;
        proxy_set_header        Connection keep-alive;
        client_max_body_size    10m;
        client_body_buffer_size 128k;
        proxy_connect_timeout   90;
        proxy_send_timeout      90;
        proxy_read_timeout      90;
        proxy_buffers           32 4k;
    }
}
EOF

cp nginx-kestrel-on-5003.conf /etc/nginx/conf.d
setsebool -P httpd_can_network_connect 1 #otherwise nginx can't proxy to our kestrel
nginx -t 
nginx -s reload    
firewall-cmd --permanent --zone=public --add-service=http   
systemctl restart firewalld.service
fi
end of nginx ----------------------------------------------------------------------------
