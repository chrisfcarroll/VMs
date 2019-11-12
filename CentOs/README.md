# Bash Scripts to Bootstrap a VM for Web Hosting

Use `bootstrap-ssh.sh.ps1 <superuser>@<remoteip> [<rsa_id_path>]`

After which you will have nginx hosting WordPress on your VM!

You will also have the following services and cron jobs running, which should make you production-ready for a blog site:
  -firewall
  -fail2ban
  -two-daily restarts of the database, php, fail2ban services
  -daily yum updates
  -daily backups with deletion at age 21 days

## Prerequisites

- an internet-connected VM running `CentOs` (or at least, that uses `yum` and the `CentOs` repositories)
- credentials for the initial connection to the VM from your commandline
- ability to browse to your wordpress website to complete the WordPress installation

## Installing Nginx & WordPress on CentOs

- *Start* with `bootstrap-ssh.sh.ps1 <superuser>@<remoteip> [<rsa_id_path>] [<andinstall>] `  
  - This script runs in either of powershell or bash, on Windows, macOs and linux.
  - It will 
    - Connect to your remote VM
    - Copy your public key to the VM, for passwordless login
    - Run `yum upgrade`, and install `tmux`, `cron` & `yum-utils`
    - if `$andinstall` is true, then call `centos-bootstrap-vm.sh` && `centos-nginx-php-wp.sh`

    - Note that `centos-nginx-php-wp.sh` is *semi-automated:* 
      you have to be at the console to 
      - answer the mysql_secure_installation questions
  	  - run the WordPress installation in your browser

### Optional
- *Consider* centos-nginx-ssl.sh
- *Use* reset-mariadb-password.sh if you break the root mysql login
- *Use* wordpress-switch-to-https.sql when you are confident that you can browse to the site on https
