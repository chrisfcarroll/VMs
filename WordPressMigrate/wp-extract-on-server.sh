#!/bin/bash
# ------------------------------------------------------
# WHEN EDITING THIS FILE ENSURE LINE-ENDINGS=UNIX IS SET
# ------------------------------------------------------
#
# Runs on the OLD server, copied there and run by wp-extract.sh.ps1
# usage: wp-extract-on-server.sh <webroot> <archive.tar.gz>
#
#   Packs into one archive everything needed to recreate the site on a new WordPress install:
#     database.sql   : mysqldump of the WordPress database, using the credentials in wp-config.php
#     wp-content/    : themes, plugins, uploads (media), languages. Caches are left out
#     wp-config.php  : for $table_prefix and any custom constants. (Contains secrets!)
#     site-info.txt  : urls, versions, active theme & plugins, for reference
#   Written for the CentOS 7 servers set up by ../CentOs, but only needs bash, tar and mysqldump.
#
webroot=${1:-/usr/share/nginx/html}
out=$2
function die { echo "ERROR: $*" >&2 ; exit 1 ; }
[[ $(id -u) == 0 ]] || die "Run me as root, or with sudo"
[[ -n $out ]] || die "usage: wp-extract-on-server.sh <webroot> <archive.tar.gz>"
[[ -f $webroot/wp-config.php && -d $webroot/wp-content ]] \
  || die "No WordPress (wp-config.php and wp-content/) in $webroot. Pass the right directory with -webroot"

tmp=$(mktemp -d /var/tmp/wp-extract.XXXXXX) ; chmod 700 "$tmp" ; trap 'rm -rf "$tmp"' EXIT

# Read the DB_ defines with php's own tokenizer, without running wp-config.php, so passwords containing
# quotes or backslashes come out exactly as WordPress sees them. sed is the fallback if there's no php.
cat > "$tmp/wpconfig.php" <<'EOF'
<?php
$want = array('DB_NAME' => '', 'DB_USER' => '', 'DB_PASSWORD' => '', 'DB_HOST' => '');
$seen = array();
$s = array();
foreach (token_get_all(file_get_contents($argv[1])) as $t)
  if (!is_array($t) || !in_array($t[0], array(T_WHITESPACE, T_COMMENT, T_DOC_COMMENT))) $s[] = $t;
for ($i = 0; $i + 4 < count($s); $i++) {
  if (is_array($s[$i]) && $s[$i][0] == T_STRING && strtolower($s[$i][1]) == 'define' && $s[$i+1] === '('
      && is_array($s[$i+2]) && $s[$i+2][0] == T_CONSTANT_ENCAPSED_STRING && $s[$i+3] === ','
      && is_array($s[$i+4]) && $s[$i+4][0] == T_CONSTANT_ENCAPSED_STRING) {
    // a constant string literal has no variables, so eval only unescapes it
    $k = eval('return ' . $s[$i+2][1] . ';');
    if (array_key_exists($k, $want) && !isset($seen[$k])) { $want[$k] = eval('return ' . $s[$i+4][1] . ';'); $seen[$k] = 1; }
  }
}
echo implode("\n", $want), "\n";
EOF
if command -v php >/dev/null && php -r 'exit(function_exists("token_get_all") ? 0 : 1);' ; then
  { IFS= read -r dbname ; IFS= read -r dbuser ; IFS= read -r dbpass ; IFS= read -r dbhost ; } \
    < <(php "$tmp/wpconfig.php" "$webroot/wp-config.php")
else
  function wpconfig { sed -n "s/^[^/#]*define *( *['\"]$1['\"] *, *['\"]\([^'\"]*\)['\"].*/\1/p" "$webroot/wp-config.php" | head -1 ; }
  dbname=$(wpconfig DB_NAME) ; dbuser=$(wpconfig DB_USER) ; dbpass=$(wpconfig DB_PASSWORD) ; dbhost=$(wpconfig DB_HOST)
fi
prefix=$(sed -n "s/^[[:space:]]*\$table_prefix *= *['\"]\([^'\"]*\)['\"].*/\1/p" "$webroot/wp-config.php" | head -1)
[[ -n $dbname && -n $dbuser ]] || die "Couldn't read DB_NAME and DB_USER from $webroot/wp-config.php"
[[ $prefix =~ ^[A-Za-z0-9_]+$ ]] || die "Couldn't read \$table_prefix from $webroot/wp-config.php"

# DB_HOST may be host, host:port, host:/socket or :/socket, as WordPress allows
dbhost=${dbhost:-localhost} ; dbport="" ; dbsocket=""
if [[ $dbhost == *:* ]] ; then
  rest=${dbhost#*:} ; dbhost=${dbhost%%:*} ; dbhost=${dbhost:-localhost}
  [[ $rest == /* ]] && dbsocket=$rest || dbport=$rest
fi
# credentials in a file, not on the command line where ps can see them. --defaults-file, not -extra-file, so that
# a /root/.my.cnf (read after an extra file) can't override the password. In my.cnf quotes, \ and " must be escaped
function cnfquote { local v=${1//\\/\\\\} ; printf '"%s"' "${v//\"/\\\"}" ; }
{
  echo "[client]"
  echo "user=$(cnfquote "$dbuser")"
  echo "password=$(cnfquote "$dbpass")"
  echo "host=$(cnfquote "$dbhost")"
  [[ -n $dbport ]] && echo "port=$dbport"
  [[ -n $dbsocket ]] && echo "socket=$(cnfquote "$dbsocket")"
} > "$tmp/my.cnf"
function sql { mysql --defaults-file="$tmp/my.cnf" -N -B "$dbname" -e "$1" ; }

echo "Dumping database $dbname ..."
mysqldump --defaults-file="$tmp/my.cnf" --single-transaction --quick --default-character-set=utf8mb4 "$dbname" \
  > "$tmp/database.sql" \
  || die "mysqldump failed, as user '$dbuser' to host '$dbhost'${dbport:+ port $dbport}${dbsocket:+ socket $dbsocket} with a ${#dbpass} character password from wp-config.php"
ls -l "$tmp/database.sql"

echo "Site info ..."
{
  echo "extracted_from=$(hostname -f)"
  echo "extracted_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo "webroot=$webroot"
  echo "table_prefix=$prefix"
  echo "wordpress=$(sed -n "s/^\$wp_version = '\(.*\)';/\1/p" "$webroot/wp-includes/version.php")"
  echo "php=$(php -r 'echo PHP_VERSION;' 2>/dev/null)"
  echo "database=$(sql 'SELECT VERSION()')"
  sql "SELECT option_name, option_value FROM ${prefix}options WHERE option_name IN ('siteurl','home','blogname','template','stylesheet','permalink_structure')" \
    | sed 's/\t/=/'
  echo "active_plugins=$(sql "SELECT option_value FROM ${prefix}options WHERE option_name='active_plugins'" | grep -o '"[^"]*\.php"' | tr -d '"' | tr '\n' ' ')"
  echo "wp-content: $(du -sh "$webroot/wp-content" | cut -f1)"
} > "$tmp/site-info.txt"
cat "$tmp/site-info.txt"

echo "Packing wp-content ..."
cp -p "$webroot/wp-config.php" "$tmp/wp-config.php"
# The site is live, so files can change mid-read. GNU tar then exits 1 and the archive is still complete; 2 is fatal
tar -czf "$out" --exclude='wp-content/cache' --exclude='wp-content/upgrade' --exclude='wp-content/*/cache' \
  -C "$tmp" database.sql site-info.txt wp-config.php -C "$webroot" wp-content
rc=$?
(( rc > 1 )) && { rm -f "$out" ; die "tar failed" ; }
(( rc == 1 )) && echo "WARNING: files above changed while being archived (the site is live). Fine for a rehearsal; freeze the site for the cutover"
chmod 600 "$out"
# so that a sudo user can scp it back
[[ -n $SUDO_USER ]] && chown "$SUDO_USER" "$out"
ls -l "$out"
