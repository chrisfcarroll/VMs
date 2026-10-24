# Migrate a WordPress site from the old CentOS server to a new Rocky server

```
../Rocky/bootstrap-ssh.sh.ps1 <[user@]newhost> -andinstall [-domain www.example.com]   # 1. provision the new server
./wp-extract.sh.ps1 <[user@]oldhost>                                                    # 2. copy the old site off
./wp-load.sh.ps1 <[user@]newhost> ./migrate/wordpress-migrate-....tar.gz [-url https://www.example.com]   # 3. load it
```

All scripts run in either bash or PowerShell. `user` must be root or able to sudo.
If either server's ssh isn't on port 22, add `-port <n>` to each script that connects to it. Without `-port` the scripts use `$SSH_PORT`
if set, and otherwise ssh's own default (`Port` for the host in `~/.ssh/config`, or 22). The old and new servers often use different
ports, so per-host `~/.ssh/config` entries or `-port` are safer here than one `SSH_PORT` for both.

## What gets moved, and why the SQL alone isn't enough

| Where it lives | What | Moved? |
|---|---|---|
| database | posts, pages, comments, users & passwords, settings, menus, widgets, theme customisations, *which* theme & plugins are active, plugin settings | yes |
| `wp-content/` | the theme & plugin *code*, media uploads, translations | yes, except caches |
| `wp-config.php` | DB credentials, salts, `$table_prefix`, custom constants | only `$table_prefix`. Custom constants are listed for you to review |
| WordPress core | `wp-admin/`, `wp-includes/` | no. The new server's newer core is kept and the database schema is upgraded |

## wp-extract.sh.ps1 <[user@]oldhost> [-webroot /usr/share/nginx/html] [-outdir ./migrate] [-port 22]

Runs `wp-extract-on-server.sh` on the old server. It doesn't change the old server and doesn't need the MariaDB root
password: it dumps with the credentials in `wp-config.php`. You get one `wordpress-migrate-<host>-<time>.tar.gz` holding
`database.sql`, `wp-content/`, `wp-config.php` and `site-info.txt` (urls, versions, theme, active plugins).
**The archive contains passwords and hashes. Keep it private.**

## wp-load.sh.ps1 <[user@]newhost> <archive> [-url https://www.example.com] [-port 22]

Runs `wp-load-on-server.sh` on the new server, which must already be set up by `../Rocky`. It:

1. backs up the new site, so `../Rocky/backup-restore.sh.ps1` can undo the load
2. replaces the database with the old one, under the new server's DB credentials, and sets the old `$table_prefix`
3. replaces `wp-content`, and **quarantines** into `/root/wp-migrate-quarantine-*`:
   - php files in `uploads/`. They are never legitimate there, and they're the usual sign of a hacked site
   - `object-cache.php`, `advanced-cache.php`, `db.php` drop-ins, which need memcached/redis etc. and would crash the site
4. rewrites the old site's `http://` and `https://` urls everywhere (serialized data safe, guids untouched) to `-url`,
   or by default to the url the new server was set up with
5. upgrades the database schema, re-applies SELinux lockdown, and runs `wordpress-update`: backup, update all plugins, themes
   and translations, verify checksums
6. checks the home page answers, and lists plugins & themes with their status

## Doing a cutover

- **Rehearse first.** Provision the new server with no domain, or a temporary one, then extract and load. Browse it at
  that address and check it. Repeat as often as you like: each load starts from a fresh copy.
- **Cut over.** Freeze changes on the old site (no new posts or comments), extract and load again with
  `-url https://www.yourdomain`, then point DNS at the new server and run
  `sudo ~/rocky-wordpress/rocky-nginx-ssl.sh www.yourdomain` on it to get the certificate.
- Log in with the **old** site's usernames and passwords. The admin created during provisioning is replaced along with the database.

## Things to check after loading

- **Old plugins on new PHP.** The old server ran PHP 5.4 to 7.x; the new one runs 8.x. Plugins that are still maintained get
  updated during the load. Abandoned, premium or custom plugins don't. If the site shows an error, check
  `/var/log/php-fpm/error.log` and deactivate the culprit:
  `sudo -u wordpress /usr/local/bin/wp --path=/var/www/wordpress --skip-plugins plugin deactivate <name>`
- **Checksum warnings** from `wordpress-update` mean plugin files differ from wordpress.org. That's expected for premium
  plugins, and suspicious for anything else. Reinstall the plugin: `wp plugin install <name> --force`
- **`wp-fail2ban`**, installed by the old CentOS scripts, is no longer needed (Rocky's fail2ban reads nginx logs). You can deactivate it.
- **Caching or security plugins** that write outside `uploads` won't work with lockdown on. See `../Rocky/README.md`.
