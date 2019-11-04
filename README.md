# Bash and Powershell scripts to Bootstrap a remote VM for web hosting

## Centos7 - Nginx - WordPress

- *Start* with `bootstrap-ssh.sh.ps1 <superuser>@<remoteip> [<rsa_id_path>] [<andinstall>] `
  - This script runs in either of powershell or bash, on Windows, macOs and linux.
  - It will 
    - Connect to your remote VM
    - Run `yum upgrade`, and install `tmux`, `cron` & `yum-utils`
    - if $andinstall is true, then call `centos-bootstrap-vm.sh` && `centos-nginx-php-wp.sh`

    - Note that `centos-nginx-php-wp.sh` is *semi-automated:* 
      you have to be at the console to 
      - answer the mysql_secure_installation questions
  	  - run the WordPress installation in your browser

- *Consider* centos-nginx-ssl.sh

- *Use* reset-mariadb-password.sh if you break the root mysql login

- *Use* wordpress-switch-to-https.sql when you are confident that you can browse to the site on https
