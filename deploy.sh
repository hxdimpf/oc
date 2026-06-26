#!/bin/bash
# OC Full Deployment — deterministic, idempotent
set -e

REPO=/opt/repos
STACKS=/opt/stacks
DOMAIN=baiti.net
DBPASS=$(openssl rand -hex 16)
DEPLOY_TIME=$(date -u +%Y%m%d-%H%M%S)

echo "=== OC Deploy $DEPLOY_TIME ==="
echo "Domain: $DOMAIN  DBPASS: ${DBPASS:0:8}..."

# ── Prereqs ──
apt-get update -qq && apt-get install -y -qq docker.io git curl python3 2>/dev/null
systemctl enable --now docker 2>/dev/null

# ── Docker compose plugin ──
if ! docker compose version &>/dev/null; then
  mkdir -p /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/debian/gpg | tee /etc/apt/keyrings/docker.asc >/dev/null
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian trixie stable" > /etc/apt/sources.list.d/docker.list
  apt-get update -qq
  dpkg --force-all -r docker-buildx 2>/dev/null || true
  apt-get install -y -qq docker-compose-plugin docker-buildx-plugin
fi

# ── Composer ──
if ! command -v composer &>/dev/null; then
  curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer 2>/dev/null
fi

# ── Stop all, nuke volumes ──
docker stop $(docker ps -q) 2>/dev/null || true
docker rm $(docker ps -aq) 2>/dev/null || true
docker network rm oc 2>/dev/null || true
for v in $(docker volume ls -q 2>/dev/null); do docker volume rm $v 2>/dev/null || true; done

# ── Network ──
docker network create oc

# ── Clone/update repos ──
mkdir -p $REPO
for repo in OC3 OC4 oc5 oc6 okapi; do
  lower=$(echo $repo | tr '[:upper:]' '[:lower:]')
  if [ -d "$REPO/$lower/.git" ]; then
    (cd $REPO/$lower && git fetch origin && git checkout dev-hx && git pull origin dev-hx --ff-only) &
  else
    git clone -b dev-hx "https://github.com/hxdimpf/$repo.git" "$REPO/$lower" &
  fi
done
wait
echo "Repos ready"

# ── Create stack directories ──
for s in dockge npm mariadb oc3 oc4 oc5 oc6 okapi; do mkdir -p $STACKS/$s; done
echo "$DBPASS" > $STACKS/mariadb/.dbpass
chmod 600 $STACKS/mariadb/.dbpass

# ── Stack compose files ──

cat > $STACKS/dockge/docker-compose.yml << YAML
name: dockge
services:
  dockge:
    image: louislam/dockge:latest
    restart: unless-stopped
    ports:
      - "5001:5001"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - dockge_data:/app/data
      - /opt/stacks:/opt/stacks:ro
    environment:
      DOCKGE_STACKS_DIR: /opt/stacks
    networks:
      - oc
volumes:
  dockge_data:
networks:
  oc:
    external: true
YAML

cat > $STACKS/npm/docker-compose.yml << YAML
name: npm
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "81:81"
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt
    networks:
      - oc
volumes:
  npm_data:
  npm_letsencrypt:
networks:
  oc:
    external: true
YAML

cat > $STACKS/mariadb/docker-compose.yml << YAML
name: mariadb
services:
  db:
    image: mariadb:10.11
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: ${DBPASS}
      MARIADB_DATABASE: oc
      MARIADB_USER: oc
      MARIADB_PASSWORD: ${DBPASS}
    volumes:
      - mariadb_data:/var/lib/mysql
    networks:
      - oc
    healthcheck:
      test: ["CMD", "healthcheck.sh", "--connect", "--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
volumes:
  mariadb_data:
networks:
  oc:
    external: true
YAML

cat > $STACKS/oc3/docker-compose.yml << YAML
name: oc3
services:
  oc3:
    image: shinsenter/php:8.2-fpm-apache
    restart: unless-stopped
    volumes:
      - ${REPO}/oc3:/var/www/html
    environment:
      OC_DB_HOST: db
      OC_DB_NAME: oc
      OC_DB_USER: oc
      OC_DB_PASS: ${DBPASS}
    expose:
      - "80"
    networks:
      - oc
networks:
  oc:
    external: true
YAML

cat > $STACKS/oc4/docker-compose.yml << YAML
name: oc4
services:
  oc4:
    image: shinsenter/php:8.4-fpm-apache
    restart: unless-stopped
    volumes:
      - ${REPO}/oc4:/var/www/html
    environment:
      APACHE_DOCUMENT_ROOT: /var/www/html/public
      APP_ENV: dev
      APP_DEBUG: "1"
      DATABASE_URL: mysql://oc:${DBPASS}@db:3306/oc?serverVersion=mariadb-10.11.16
    expose:
      - "80"
    networks:
      - oc
networks:
  oc:
    external: true
YAML

cat > $STACKS/oc5/docker-compose.yml << YAML
name: oc5
services:
  oc5:
    image: node:22-alpine
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ${REPO}/oc5:/app
    command: sh -c "npm install --silent && exec node app.js"
    environment:
      PORT: "3000"
      DATABASE_URL: mysql://oc:${DBPASS}@db:3306/oc
      NODE_ENV: development
    expose:
      - "3000"
    networks:
      - oc
networks:
  oc:
    external: true
YAML

cat > $STACKS/oc6/docker-compose.yml << YAML
name: oc6
services:
  oc6:
    image: oven/bun:1
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ${REPO}/oc6:/app
    command: sh -c "bun install --silent && exec bun run src/server.ts"
    environment:
      PORT: "3000"
      DATABASE_URL: mysql://oc:${DBPASS}@db:3306/oc
      NODE_ENV: development
    expose:
      - "3000"
    networks:
      - oc
networks:
  oc:
    external: true
YAML

cat > $STACKS/okapi/docker-compose.yml << YAML
name: okapi
services:
  okapi:
    image: shinsenter/php:8.2-fpm-apache
    restart: unless-stopped
    volumes:
      - ${REPO}/okapi:/var/www/html
    environment:
      APACHE_DOCUMENT_ROOT: /var/www/html/okapi
      OKAPI_STANDALONE: "1"
      OKAPI_DB_HOST: db
      OKAPI_DB_NAME: oc
      OKAPI_DB_USER: oc
      OKAPI_DB_PASS: ${DBPASS}
    expose:
      - "80"
    networks:
      - oc
networks:
  oc:
    external: true
YAML

echo "Compose files written"

# ── Source code config ──
mkdir -p $REPO/oc3/var/cache2/labels $REPO/oc3/var/cache2/smarty/cache $REPO/oc3/var/cache2/smarty/compiled $REPO/oc3/images/uploads
chmod -R 777 $REPO/oc3/var

cp $REPO/oc3/config2/settings-sample-dev.inc.php $REPO/oc3/config2/settings-dev.inc.php
sed -i 's|require __DIR__ . .'/'settings-dev.inc.php.;|// standalone|' $REPO/oc3/config2/settings-dev.inc.php
sed -i 's|opencaching.ddev.site|oc3.baiti.net|g' $REPO/oc3/config2/settings-dev.inc.php
sed -i 's|try-opencaching.ddev.site|oc4.baiti.net|g' $REPO/oc3/config2/settings-dev.inc.php
sed -i "s|getenv('DDEV_USER')|'www-data'|g" $REPO/oc3/config2/settings-dev.inc.php

cat > $REPO/oc3/config2/settings.inc.php << PHPEOF
<?php
\$dev_basepath = '/var/www/html/';
\$dev_codepath = '*';
\$dev_baseurl = 'http://oc3.$DOMAIN/';
if (defined('HTTPS_ENABLED')) { \$opt['page']['https']['mode'] = HTTPS_ENABLED; }
\$opt['httpd']['user'] = 'www-data';
\$opt['httpd']['group'] = 'www-data';
\$debug_startpage_news = false;
require __DIR__ . '/settings-dev.inc.php';
\$opt['db']['servername'] = 'db';
\$opt['db']['username'] = 'oc';
\$opt['db']['password'] = '$DBPASS';
\$opt['db']['pconnect'] = false;
\$opt['db']['maintenance_user'] = 'oc';
\$opt['db']['maintenance_password'] = '$DBPASS';
\$opt['db']['placeholder']['db'] = 'oc';
\$opt['db']['placeholder']['tmpdb'] = 'octmp';
\$opt['page']['domain'] = 'oc3.$DOMAIN';
\$opt['page']['https']['mode'] = HTTPS_DISABLED;
\$opt['page']['https']['is_default'] = false;
\$opt['mail']['from'] = 'noreply@test.opencaching.de';
\$opt['mail']['subject'] = '[oc3.$DOMAIN] ';
\$opt['session']['cookiename'] = 'ocdevelopment';
\$opt['session']['domain'] = '.$DOMAIN';
set_absolute_urls(\$opt, 'http://oc3.$DOMAIN/', 'opencaching.de', 2);
\$opt['new_ui']['domain'] = 'oc4.$DOMAIN';
PHPEOF

cat > $REPO/oc3/app/config/parameters.yml << YML
parameters:
    database_host: db
    database_port: ~
    database_name: oc
    database_user: oc
    database_password: ${DBPASS}
    mailer_transport: smtp
    mailer_host: localhost
    mailer_port: 1025
    mailer_user: null
    mailer_password: null
    mailer_auth_mode: login
    secret: ThisTokenIsNotSoSecretChangeIt
    api_secret: ThisTokenIsNotSoSecretChangeIt
YML

cat > $REPO/oc4/.env.local << ENV
APP_DEBUG=1
APP_ENV=dev
APP_SECRET=4d60f440e3bcaa3022a86681d24e54a4
DATABASE_URL=mysql://oc:${DBPASS}@db:3306/oc?serverVersion=mariadb-10.11.16
ENV
mkdir -p $REPO/oc4/var && chmod -R 777 $REPO/oc4/var
mkdir -p $REPO/okapi/var/okapi && chmod -R 777 $REPO/okapi/var

echo "Configs written"

# ── Composer install (on host, before starting containers) ──
echo "composer install..."
cd $REPO/oc3 && composer install -q --no-interaction --optimize-autoloader --ignore-platform-req=ext-gd --ignore-platform-req=ext-mysqli 2>&1 | tail -1
cd $REPO/oc4 && composer install -q --no-interaction --optimize-autoloader 2>&1 | tail -1
cd $REPO/okapi/okapi && composer install -q --no-interaction --optimize-autoloader 2>&1 | tail -1
echo "composer done"

# ── Start all stacks ──
echo "starting stacks..."
for s in dockge npm mariadb oc3 oc4 oc5 oc6 okapi; do
  (cd $STACKS/$s && docker compose up -d --quiet-pull 2>/dev/null)
  echo "  $s started"
done

# ── Wait for MariaDB ──
echo "waiting for DB..."
for i in $(seq 1 60); do
  docker inspect mariadb-db-1 --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy && break
  sleep 2
done
echo "DB: $(docker inspect mariadb-db-1 --format '{{.State.Health.Status}}')"

# ── Import database from dump file ──
if [ -f /tmp/ocde-full.sql ]; then
  echo "importing database..."
  docker exec -i mariadb-db-1 mysql -uroot -p${DBPASS} -e "DROP DATABASE IF EXISTS oc; CREATE DATABASE oc;" 2>/dev/null
  docker cp /tmp/ocde-full.sql mariadb-db-1:/tmp/dump.sql
  docker exec mariadb-db-1 mysql -uroot -p${DBPASS} oc -e "SOURCE /tmp/dump.sql" 2>&1 | grep -v Warning | tail -1
  docker exec mariadb-db-1 mysql -uroot -p${DBPASS} -e "GRANT ALL ON oc.* TO 'oc'@'%';" 2>/dev/null || true
  COUNT=$(docker exec mariadb-db-1 mysql -uroot -p${DBPASS} -N -e "SELECT COUNT(*) FROM oc.caches;" 2>/dev/null)
  echo "  $COUNT caches imported"
elif [ -f $REPO/oc3/sql/dump_v158.sql ]; then
  echo "using base schema..."
  docker exec -i mariadb-db-1 mysql -uroot -p${DBPASS} oc < $REPO/oc3/sql/dump_v158.sql 2>&1 | tail -1
  for f in $REPO/oc3/sql/static-data/*.sql; do
    docker exec -i mariadb-db-1 mysql -uroot -p${DBPASS} --force oc < $f 2>/dev/null
  done
  if [ -f $REPO/oc3/sql/user_content_sample.sql ]; then
    docker exec -i mariadb-db-1 mysql -uroot -p${DBPASS} --force oc < $REPO/oc3/sql/user_content_sample.sql 2>/dev/null
  fi
  # Run maintain.php after OC3 is up
  for i in $(seq 1 30); do
    docker exec oc3-oc3-1 curl -sI http://localhost/ 2>/dev/null | grep -q "200\|302\|401" && break
    sleep 2
  done
  docker exec oc3-oc3-1 php /var/www/html/sql/stored-proc/maintain.php 2>/dev/null || true
fi

# ── NPM routes ──
echo "configuring NPM routes..."
NPM_VOL=$(docker volume ls -q | grep npm_data)
for i in $(seq 1 30); do
  NPM_PATH=$(docker volume inspect $NPM_VOL --format '{{.Mountpoint}}')/database.sqlite
  python3 -c "
import sqlite3
db = sqlite3.connect('$NPM_PATH')
db.execute('SELECT 1 FROM proxy_host')
" 2>/dev/null && break
  sleep 2
done

python3 << PYEOF
import sqlite3, json
import os
path = os.popen("docker volume inspect \$(docker volume ls -q | grep npm_data) --format '{{.Mountpoint}}'").read().strip() + "/database.sqlite"
db = sqlite3.connect(path)
db.execute("DELETE FROM proxy_host")
hosts = [
    ("oc3", "oc3.${DOMAIN}", 80),
    ("oc4", "oc4.${DOMAIN}", 80),
    ("oc5", "oc5.${DOMAIN}", 3000),
    ("oc6", "oc6.${DOMAIN}", 3000),
    ("okapi", "okapi.${DOMAIN}", 80),
]
for host, domain, port in hosts:
    db.execute(
        'INSERT INTO proxy_host (created_on,modified_on,owner_user_id,domain_names,forward_host,forward_port,forward_scheme,enabled,meta,advanced_config) VALUES (datetime("now"),datetime("now"),1,?,?,?,"http",1,"{}","")',
        (json.dumps([domain]), host, port)
    )
db.commit()
print(f"  Inserted {len(hosts)} routes")
PYEOF

echo y | docker exec -i npm-nginx-proxy-manager-1 node scripts/regenerate-config 2>/dev/null | grep -q "Completed" && echo "  NPM config regenerated"

# ── Restart all apps ──
docker restart oc3-oc3-1 oc4-oc4-1 okapi-okapi-1 2>/dev/null || true
sleep 10

# ── Final test ──
echo ""
echo "=== FINAL VERIFICATION ==="
for h in oc3 oc4 oc5 oc6 okapi; do
  code=$(curl -sk -o /dev/null -w "%{http_code}" -H "Host: $h.$DOMAIN" http://localhost/)
  echo "  $h.$DOMAIN: HTTP $code"
done
echo ""
echo "NPM admin: http://oc3.$DOMAIN:81"
echo "Dockge:    http://oc3.$DOMAIN:5001"
echo "DB pass:   $STACKS/mariadb/.dbpass"
echo "=== DEPLOY COMPLETE ==="
