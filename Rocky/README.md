# Bash Scripts to Bootstrap a Rocky Linux VM for Web Hosting

A port of [../CentOs](../CentOs) from `yum` to `dnf`, for Rocky Linux 9 / 10.

Use `bootstrap-ssh.sh.ps1 <superuser>@<remoteip> [<rsa_id_path>]`

After which you will have nginx hosting WordPress on your VM!

You will also have the following services and cron jobs running, which should make you production-ready for a blog site:
  -firewall
  -fail2ban
  -automatic dnf updates (`dnf-automatic`, which replaces `yum-cron`)
  -see `crontab.txt` for restarts and daily backups with deletion at age 21 days

## Prerequisites

- an internet-connected VM running `Rocky Linux` (or at least, that uses `dnf` and the RHEL/EPEL repositories)
- credentials for the initial connection to the VM from your commandline
- ability to browse to your wordpress website to complete the WordPress installation

## Installing Nginx & WordPress on Rocky

- *Start* with `bootstrap-ssh.sh.ps1 <superuser>@<remoteip> [<rsa_id_path>] [<andinstall>] `
  - This script runs in either of powershell or bash, on Windows, macOs and linux.
  - It will
    - Connect to your remote VM
    - Copy your public key to the VM, for passwordless login
    - Run `dnf upgrade`, and install `tmux`, `cronie`, `dnf-automatic` & `dnf-plugins-core`
    - if `$andinstall` is true, then call `rocky-bootstrap-vm.sh` && `dnf-nginx-php-mariadb-wp.sh`
      in a tmux session. Attach with `ssh <superuser>@<remoteip> -t tmux attach -t bootstrap-install`

    - Note that `dnf-nginx-php-mariadb-wp.sh` is *semi-automated:*
      you have to be at the console to
      - answer the mariadb-secure-installation questions
      - run the WordPress installation in your browser

### Optional
- *Consider* rocky-nginx-ssl.sh
- *Use* reset-mariadb-password.sh if you break the root mariadb login
- *Use* wordpress-switch-to-https.sql when you are confident that you can browse to the site on https

## Differences from the CentOS scripts

- `yum` → `dnf`; `yum-cron` → `dnf-automatic`; `yum-utils` → `dnf-plugins-core`; `php-mysql` → `php-mysqlnd`
- `epel-release` is installed before `fail2ban` (fail2ban is in EPEL)
- php-fpm listens on a unix socket (`/run/php-fpm/www.sock`), so nginx uses the `php-fpm` upstream Rocky ships
- SELinux is enforcing on Rocky: WordPress files are relabelled and `wp-content` is made writable
- WordPress and the wp-fail2ban plugin are fetched as *latest* rather than pinned old versions
- WordPress fail2ban jails read `/var/log/secure` (RHEL) not `/var/log/auth.log` (Debian)
- the `.sql` files are now UTF-8 so that the `mariadb` client can read them
