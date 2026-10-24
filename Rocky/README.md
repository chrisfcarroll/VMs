# Bootstrap a Rocky Linux VM to host WordPress, securely

A successor to [../CentOs](../CentOs), for Rocky Linux 9 or 10, from the same starting point: a newly
provisioned server that you can ssh into.

```
./bootstrap-ssh.sh.ps1 <[user@]host> [<public_key_path>] [-andinstall] [-domain www.example.com] [-email you@example.com]
```

runs in either of PowerShell or bash, on Windows, macOS and Linux. `user` can be `root`, or a sudo user such as the `rocky`
user of Rocky cloud images. Without `-andinstall` you get just the secured base server.

With `-andinstall`, and DNS for your domain already pointing at the server, a few minutes later you have WordPress on https,
with nothing left to click through. The admin username is printed; its password is in `/root/wordpress-initial-admin.txt`.

## What you get

| | |
|---|---|
| **Updates** | `dnf-automatic` applies all updates daily and reboots when a kernel update needs it |
| **ssh** | key-only logins (once the bootstrap has confirmed your key works), fail2ban on sshd |
| **Firewall** | firewalld: only ssh, http, https. (Rocky's default open cockpit port is closed) |
| **Web** | nginx → php-fpm (own pool & user) → MariaDB (localhost only). Newest php/nginx/mariadb streams on Rocky 9 |
| **https** | Let's Encrypt via certbot, auto-renewing; http redirects to https; HSTS; TLS 1.2+ per system crypto-policy |
| **WordPress** | installed by WP-CLI before the firewall opens. Daily auto-update of core, plugins, themes with checksum verification |
| **Lockdown** | SELinux makes WordPress's code read-only to the website. Only `wp-content/uploads` is writable, and php there never runs |
| **Brute force** | wp-login.php rate limited; fail2ban bans repeated failed logins; xmlrpc.php blocked; `?author=` enumeration blocked |
| **Backups** | daily to `/var/backup/wordpress`, kept 21 days, and **pulled off-server** with `backup-pull.sh.ps1` |

## Backup and restore

On the server, daily via `wordpress-backup.timer` and also before every update: one `.tar.gz` containing the database dump,
the whole WordPress directory, and the nginx & Let's Encrypt config.

From your own machine (bash or PowerShell):

```
./backup-pull.sh.ps1 <[user@]host> [<localdir>] [-now]          # copies new backups to ./backups/<host>/
./backup-restore.sh.ps1 <[user@]host> <wordpress-...tar.gz>      # puts the site back as it was
```

- Schedule `backup-pull.sh.ps1` with cron, launchd or Task Scheduler. It **pulls**, so the server holds no credentials for
  your backup store, and an attacker who owns the server can't delete your off-server copies.
- To rebuild on a new server: `bootstrap-ssh.sh.ps1 <newhost> -andinstall -domain <yourdomain>`, then `backup-restore.sh.ps1`.
- `wordpress-restore` backs up the current site before restoring, and keeps the replaced files in `/var/www/wordpress.before-restore-*`.
- Backups contain `wp-config.php` (database password, salts) and your TLS private key. Keep the local copies private, e.g. an
  encrypted disk.

## Day to day, on the server

| command | |
|---|---|
| `sudo wordpress-lockdown off` / `on` | allow / disallow plugin & theme installs from the dashboard. Turn it back on afterwards |
| `sudo wordpress-update` | backup + update now (also runs daily). If an update breaks the site, restore the backup it took |
| `sudo wordpress-backup` | backup now |
| `sudo -u wordpress wp --path=/var/www/wordpress ...` | WP-CLI, e.g. `plugin install two-factor --activate` |
| `sudo rocky-wordpress/rocky-nginx-ssl.sh <domain> [email]` | https, if DNS wasn't ready at install time, or to move the site to a new domain |
| `systemctl list-timers` | see `dnf-automatic`, `wordpress-backup`, `wordpress-update`, `wordpress-cron`, `certbot-renew` |

## The scripts

| client side (bash or PowerShell) | |
|---|---|
| `bootstrap-ssh.sh.ps1` | copies your key, then the `*.sh` scripts to `~/rocky-wordpress/`, and runs them in tmux session `bootstrap` |
| `backup-pull.sh.ps1`, `backup-restore.sh.ps1` | see above |

| server side | |
|---|---|
| `rocky-bootstrap-vm.sh` | updates, `dnf-dnf-automatic.sh`, swap on small VMs, sshd hardening, firewalld, fail2ban |
| `dnf-nginx-php-mariadb-wp.sh [domain] [email] [admin]` | the WordPress stack, timers, lockdown, fail2ban jails; calls `rocky-nginx-ssl.sh` |
| `rocky-nginx-ssl.sh` | Let's Encrypt certificate, https-only nginx config, switches WordPress URLs to https |
| `wordpress-{backup,restore,update,lockdown,create-database}.sh` | installed as `/usr/local/sbin/wordpress-*` |
| `reset-mariadb-password.sh` | puts MariaDB root back to unix_socket (passwordless root-shell) login |
| `dnf-nginx-kestrel.sh`, `dnf-git-psql-npm-dotnet-pwsh.sh`, `rocky-firewall-and-fail2ban.sh` | not WordPress: .NET hosting leftovers, ported to dnf |
| `moreconfigs/` | reference copies of CentOS 7 era configs. Not used |

## What changed from the CentOS scripts, and why

**Out of date or end of life**
- CentOS 7 reached end of life in June 2024. `yum` → `dnf`, `yum-cron` → `dnf-automatic`.
- WordPress 4.9.1 (2017) and wp-fail2ban 3.5.3 were pinned. They would no longer run on a supported PHP.
- Rocky 9's default php 8.0, nginx 1.20 and mariadb 10.5 are past upstream EOL, so the newest module streams are enabled.
- `mysql_secure_installation` and a generated root password, which was never actually set → MariaDB root uses unix_socket
  auth, and the hardening SQL runs unattended.
- `listen ... http2` is deprecated in nginx 1.25+. `ssl_prefer_server_ciphers on` with `HIGH:!aNULL:!MD5` and a self-signed
  certificate → Let's Encrypt with TLS 1.2+ and the system crypto-policy. No OCSP stapling, because Let's Encrypt shut
  down OCSP in 2025.
- RSA ssh keys were the default → ed25519 is preferred.
- Cron jobs restarting php-fpm every 2h and mariadb every 2 days → php-fpm `pm.max_requests` recycles workers, swap avoids
  OOM kills, and dnf-automatic reboots after kernel updates.
- `crontab.txt` was documentation only; nothing installed it, so there were no backups → systemd timers.

**Threats the old setup didn't handle**
- *Install hijacking.* The old flow opened port 80 and then waited for you to browse to `setup-config.php`. Bots scan for
  exactly that and can complete the install first with their own database, which gives them code execution. Now WordPress
  is fully installed with a random admin password before the firewall opens.
- *Vulnerable plugins* are the main way WordPress sites get compromised now. Daily unattended updates, with a backup just
  before and checksum verification after.
- *Persistence after a compromise.* The whole webroot was owned and writable by the web server, with `FS_METHOD direct`, so
  any exploit could plant backdoors in `.php` files. Now SELinux keeps code read-only (`wordpress-lockdown`), php won't run
  from uploads, the dashboard code editor is off, and wp-cron runs through php-fpm so it's confined too.
- *Credential stuffing and brute force.* xmlrpc.php `system.multicall` tries hundreds of passwords per request → blocked.
  Logins are rate limited and fail2ban bans failures. This uses nginx's own access log, so the wp-fail2ban plugin and
  syslog plumbing are no longer needed. Consider the
  [Two Factor](https://wordpress.org/plugins/two-factor/) plugin for admin accounts.
- *ssh password guessing.* Password logins are turned off once your key is confirmed to work.
- *Ransomware or a malicious admin deleting backups.* Backups are pulled off-server, not pushed.
- *Fixed bugs.* The CentOS bootstrap called a non-existent `centos-nginx-php-wp.sh`. The ssl script never wrote
  `ssl_certificate` (wrong grep) and generated the key twice. The `.sql` files were UTF-16, which the mysql client can't
  read. A printf quoting bug appended the bash profile on every run. php-fpm's `localhost:9000` doesn't exist on Rocky.
  `/var/log/auth.log` doesn't exist on RHEL.

**Trade-offs to know about**
- Lockdown means plugins can't be installed or updated from the dashboard until you run `wordpress-lockdown off`. Plugins
  that write outside `uploads` (some caching and security plugins) won't work while it's on.
- Blocking xmlrpc.php breaks Jetpack and the WordPress mobile apps. See `/etc/nginx/wordpress-site.conf` to re-enable it.
- Daily plugin auto-updates can occasionally break a site. Restore from the backup taken just before.
- WordPress can't send email until you configure an SMTP plugin, because no mail server is installed.
- The REST API still lists usernames at `/wp-json/wp/v2/users`. With rate limiting and 2FA that is low risk.

## Prerequisites

- an internet-connected VM running Rocky Linux 9 or 10, with SELinux enforcing (the default)
- ssh access as root or a sudo user, and an ssh key pair (`ssh-keygen -t ed25519`)
- for https: a DNS A record for your domain pointing at the VM, and ports 80/443 reachable
