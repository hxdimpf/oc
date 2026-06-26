#!/usr/bin/env bash
set -euo pipefail
# ============================================================================
# OC bootstrap — one command to deploy the entire opencaching dev stack.
#
# Usage:
#   git clone git@github.com:hxdimpf/oc.git && cd OC
#   ./bootstrap.sh your-domain-suffix.net
#
# What it does:
#   1. Clones OC3, OC4, OC5, okapi repos (dev-hx branch) into ../ if missing
#   2. Writes /opt/stacks/{npm,mariadb,oc3,oc4,oc5,okapi,dockge}
#   3. Generates all configs with your domain and random DB password
#   4. Starts all 7 stacks
#   5. Configures NPM proxy routes via API
#
# After it finishes, visit:
#   http://oc3.SUFFIX
#   http://oc4.SUFFIX
#   http://oc5.SUFFIX
#   http://oc6.SUFFIX
#   http://okapi.SUFFIX
#   http://oc3.SUFFIX:81   (NPM admin: admin@example.com / changeme)
#   http://oc3.SUFFIX:5001 (Dockge)
# ============================================================================

DOMAIN_SUFFIX="${1:-}"
if [ -z "$DOMAIN_SUFFIX" ]; then
    echo "Usage: $0 <domain-suffix> [github-org] [branch]"
    echo "  e.g. $0 baiti.net hxdimpf dev-hx"
    echo "  gives: oc3.baiti.net, oc4.baiti.net, oc5.baiti.net, okapi.baiti.net"
    echo ""
    echo "Defaults:"
    echo "  github-org: hxdimpf"
    echo "  branch:     dev-hx"
    exit 1
fi

GITHUB_ORG="${2:-hxdimpf}"
BRANCH="${3:-dev-hx}"

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="/opt/repos"

OC3_DOMAIN="oc3.$DOMAIN_SUFFIX"
OC4_DOMAIN="oc4.$DOMAIN_SUFFIX"
OC5_DOMAIN="oc5.$DOMAIN_SUFFIX"
OC6_DOMAIN="oc6.$DOMAIN_SUFFIX"
OKAPI_DOMAIN="okapi.$DOMAIN_SUFFIX"

echo "============================================"
echo " OC Bootstrap"
echo " Domain: $DOMAIN_SUFFIX"
echo " GitHub: $GITHUB_ORG  Branch: $BRANCH"
echo " $OC3_DOMAIN / $OC4_DOMAIN / $OC5_DOMAIN / $OKAPI_DOMAIN"
echo "============================================"

# ── 1. Clone repos ─────────────────────────────────────────────────

mkdir -p "$REPO_DIR"

for repo in OC3 OC4 oc5 oc6 okapi; do
    dir="${REPO_DIR}/${repo,,}"
    lower=$(echo "$repo" | tr '[:upper:]' '[:lower:]')

    if [ -d "$dir/.git" ]; then
        echo "[$lower] already cloned — pulling $BRANCH"
        git -C "$dir" fetch origin
        git -C "$dir" checkout "$BRANCH" 2>/dev/null || true
        git -C "$dir" pull origin "$BRANCH" --ff-only 2>/dev/null || true
    else
        echo "[$lower] cloning..."
        # Try HTTPS first (works without SSH key for public repos), fall back to SSH
        git clone -b "$BRANCH" "https://github.com/${GITHUB_ORG}/$repo.git" "$dir" 2>/dev/null || \
            git clone -b "$BRANCH" "git@github.com:${GITHUB_ORG}/$repo.git" "$dir"
    fi
done

# ── 2. Docker pre-reqs ─────────────────────────────────────────────

if ! command -v docker &>/dev/null; then
    echo "Installing Docker..."
    sudo apt-get update -qq && sudo apt-get install -y -qq docker.io git curl
    sudo systemctl enable --now docker
fi

if ! docker compose version &>/dev/null 2>&1; then
    echo "Installing Docker Compose plugin..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/debian/gpg | \
        sudo tee /etc/apt/keyrings/docker.asc > /dev/null
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] \
        https://download.docker.com/linux/debian trixie stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq
    # Remove conflicting Debian package first, then install Docker's
    sudo dpkg --force-all -r docker-buildx 2>/dev/null || true
    sudo apt-get install -y -qq docker-compose-plugin docker-buildx-plugin
fi

# ── 3. Network ─────────────────────────────────────────────────────

docker network create oc 2>/dev/null || true
echo "[network] oc ready"

# ── 4. Write stacks ───────────────────────────────────────────────

DBPASS=$(openssl rand -hex 16)
STACKS=/opt/stacks
sudo mkdir -p "$STACKS"/{npm,mariadb,oc3,oc4,oc5,oc6,okapi,dockge}

echo "[stacks] writing compose files..."

# npm
cat | sudo tee "$STACKS/npm/docker-compose.yml" > /dev/null << COMPOSE
name: npm
services:
  nginx-proxy-manager:
    image: jc21/nginx-proxy-manager:latest
    restart: unless-stopped
    ports: ["80:80","443:443","81:81"]
    volumes:
      - npm_data:/data
      - npm_letsencrypt:/etc/letsencrypt
    networks: [oc]
volumes:
  npm_data:
  npm_letsencrypt:
networks:
  oc:
    external: true
COMPOSE

# mariadb
cat | sudo tee "$STACKS/mariadb/docker-compose.yml" > /dev/null << COMPOSE
name: mariadb
services:
  db:
    image: mariadb:10.11
    restart: unless-stopped
    environment:
      MARIADB_ROOT_PASSWORD: $DBPASS
      MARIADB_DATABASE: oc
      MARIADB_USER: oc
      MARIADB_PASSWORD: $DBPASS
    volumes: [mariadb_data:/var/lib/mysql]
    networks: [oc]
    healthcheck:
      test: ["CMD","healthcheck.sh","--connect","--innodb_initialized"]
      interval: 10s
      timeout: 5s
      retries: 5
volumes:
  mariadb_data:
networks:
  oc:
    external: true
COMPOSE
echo "$DBPASS" | sudo tee "$STACKS/mariadb/.dbpass" > /dev/null
sudo chmod 600 "$STACKS/mariadb/.dbpass"

# oc3
cat | sudo tee "$STACKS/oc3/docker-compose.yml" > /dev/null << COMPOSE
name: oc3
services:
  oc3:
    image: shinsenter/php:8.2-fpm-apache
    restart: unless-stopped
    volumes: ["${REPO_DIR}/oc3:/var/www/html"]
    environment:
      OC_DB_HOST: db
      OC_DB_NAME: oc
      OC_DB_USER: oc
      OC_DB_PASS: $DBPASS
    expose: ["80"]
    networks: [oc]
networks:
  oc:
    external: true
COMPOSE

# oc4
cat | sudo tee "$STACKS/oc4/docker-compose.yml" > /dev/null << COMPOSE
name: oc4
services:
  oc4:
    image: shinsenter/php:8.4-fpm-apache
    restart: unless-stopped
    volumes: ["${REPO_DIR}/oc4:/var/www/html"]
    environment:
      APACHE_DOCUMENT_ROOT: /var/www/html/public
      APP_ENV: dev
      APP_DEBUG: 1
      DATABASE_URL: mysql://oc:${DBPASS}@db:3306/oc?serverVersion=mariadb-10.11.16
    expose: ["80"]
    networks: [oc]
networks:
  oc:
    external: true
COMPOSE

# oc5
cat | sudo tee "$STACKS/oc5/docker-compose.yml" > /dev/null << COMPOSE
name: oc5
services:
  oc5:
    image: node:22-alpine
    restart: unless-stopped
    working_dir: /app
    volumes: ["${REPO_DIR}/oc5:/app"]
    command: sh -c "npm install --silent && exec node app.js"
    environment:
      PORT: 3000
      DATABASE_URL: mysql://oc:${DBPASS}@db:3306/oc
      NODE_ENV: development
    expose: ["3000"]
    networks: [oc]
networks:
  oc:
    external: true
COMPOSE

# oc6
cat | sudo tee "$STACKS/oc6/docker-compose.yml" > /dev/null << COMPOSE
name: oc6
services:
  oc6:
    image: oven/bun:1
    restart: unless-stopped
    working_dir: /app
    volumes: ["${REPO_DIR}/oc6:/app"]
    command: sh -c "bun install --silent && exec bun run src/server.ts"
    environment:
      PORT: 3000
      DATABASE_URL: mysql://oc:${DBPASS}@db:3306/oc
      NODE_ENV: development
    expose: ["3000"]
    networks: [oc]
networks:
  oc:
    external: true
COMPOSE

# okapi
cat | sudo tee "$STACKS/okapi/docker-compose.yml" > /dev/null << COMPOSE
name: okapi
services:
  okapi:
    image: shinsenter/php:8.2-fpm-apache
    restart: unless-stopped
    volumes: ["${REPO_DIR}/okapi:/var/www/html"]
    environment:
      APACHE_DOCUMENT_ROOT: /var/www/html/okapi
      OKAPI_STANDALONE: 1
      OKAPI_DB_HOST: db
      OKAPI_DB_NAME: oc
      OKAPI_DB_USER: oc
      OKAPI_DB_PASS: $DBPASS
    expose: ["80"]
    networks: [oc]
networks:
  oc:
    external: true
COMPOSE

# dockge
cat | sudo tee "$STACKS/dockge/docker-compose.yml" > /dev/null << COMPOSE
name: dockge
services:
  dockge:
    image: louislam/dockge:latest
    restart: unless-stopped
    ports: ["5001:5001"]
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - dockge_data:/app/data
      - /opt/stacks:/opt/stacks:ro
    environment:
      DOCKGE_STACKS_DIR: /opt/stacks
    networks: [oc]
volumes:
  dockge_data:
networks:
  oc:
    external: true
COMPOSE

# ── 5. Config files ───────────────────────────────────────────────

echo "[config] generating settings files..."

# OC3 settings
REPO_OC3="${REPO_DIR}/oc3"
sudo mkdir -p "$REPO_OC3/var/cache2/labels" "$REPO_OC3/var/cache2/smarty/cache" "$REPO_OC3/var/cache2/smarty/compiled" "$REPO_OC3/images/uploads"
sudo chmod -R 777 "$REPO_OC3/var"

# settings-dev.inc.php (patched from sample)
sudo cp "$REPO_OC3/config2/settings-sample-dev.inc.php" "$REPO_OC3/config2/settings-dev.inc.php"
sudo sed -i "s|require __DIR__ . '/settings-dev.inc.php';|// standalone|" "$REPO_OC3/config2/settings-dev.inc.php"
sudo sed -i "s|opencaching.ddev.site|$OC3_DOMAIN|g" "$REPO_OC3/config2/settings-dev.inc.php"
sudo sed -i "s|try-opencaching.ddev.site|$OC4_DOMAIN|g" "$REPO_OC3/config2/settings-dev.inc.php"
sudo sed -i "s|getenv('DDEV_USER')|'www-data'|g" "$REPO_OC3/config2/settings-dev.inc.php"

# settings.inc.php
cat | sudo tee "$REPO_OC3/config2/settings.inc.php" > /dev/null << SETTINGS
<?php
\$dev_basepath = '/var/www/html/';
\$dev_codepath = '*';
\$dev_baseurl = 'http://$OC3_DOMAIN/';
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
\$opt['page']['domain'] = '$OC3_DOMAIN';
\$opt['page']['https']['mode'] = HTTPS_DISABLED;
\$opt['page']['https']['is_default'] = false;
\$opt['mail']['from'] = 'noreply@test.opencaching.de';
\$opt['mail']['subject'] = '[$OC3_DOMAIN] ';
\$opt['session']['cookiename'] = 'ocdevelopment';
\$opt['session']['domain'] = '.$DOMAIN_SUFFIX';
set_absolute_urls(\$opt, 'http://$OC3_DOMAIN/', 'opencaching.de', 2);
\$opt['new_ui']['domain'] = '$OC4_DOMAIN';
SETTINGS

# OC3 parameters.yml for Doctrine
cat | sudo tee "$REPO_OC3/app/config/parameters.yml" > /dev/null << YML
parameters:
    database_host:     db
    database_port:     ~
    database_name:     oc
    database_user:     oc
    database_password: $DBPASS
    mailer_transport:  smtp
    mailer_host:       localhost
    mailer_port:       1025
    mailer_user:       null
    mailer_password:   null
    mailer_auth_mode:  login
    secret:            ThisTokenIsNotSoSecretChangeIt
    api_secret:        ThisTokenIsNotSoSecretChangeIt
YML

# OC4 .env.local
REPO_OC4="${REPO_DIR}/oc4"
cat | sudo tee "$REPO_OC4/.env.local" > /dev/null << ENV
APP_DEBUG=1
APP_ENV=dev
APP_SECRET=4d60f440e3bcaa3022a86681d24e54a4
DATABASE_URL=mysql://oc:${DBPASS}@db:3306/oc?serverVersion=mariadb-10.11.16
ENV
sudo mkdir -p "$REPO_OC4/var" && sudo chmod -R 777 "$REPO_OC4/var"

# OKAPI var dir
REPO_OKAPI="${REPO_DIR}/okapi"
sudo mkdir -p "$REPO_OKAPI/var/okapi" && sudo chmod -R 777 "$REPO_OKAPI/var"

# ── 6. Start stacks ───────────────────────────────────────────────

echo "[start] bringing up stacks..."

for stack in dockge npm mariadb oc3 oc4 oc5 oc6 okapi; do
    echo "  starting $stack..."
    (cd "$STACKS/$stack" && sudo docker compose up -d --quiet-pull 2>&1) || true
done

# ── 7. Wait for DB ────────────────────────────────────────────────

echo "[wait] waiting for MariaDB to be healthy..."
until sudo docker inspect mariadb-db-1 --format '{{.State.Health.Status}}' 2>/dev/null | grep -q healthy; do
    sleep 2
done
echo "  MariaDB healthy"

# ── 7a. Database bootstrap (schema, static data, stored procs) ──────

DBPASS_FILE="$STACKS/mariadb/.dbpass"
echo "[db] importing base schema and static data..."

# dump_v158.sql is the base schema (committed in the OC3 repo)
sudo docker exec -i mariadb-db-1 mysql -uroot -p$(cat "$DBPASS_FILE") oc \
    < "$REPO_OC3/sql/dump_v158.sql" 2>&1 | grep -v "Warning" | tail -1 || true

# Import all static data files
for f in "$REPO_OC3/sql/static-data/"*.sql; do
    sudo docker exec -i mariadb-db-1 mysql -uroot -p$(cat "$DBPASS_FILE") --force oc < "$f" 2>/dev/null
done
echo "  Schema + static data imported"

# Run maintain.php to install stored procedures and triggers
echo "  Installing stored procedures (waiting for OC3 to be ready)..."
# Wait for OC3 Apache to be up
for i in $(seq 1 30); do
    if sudo docker exec oc3-oc3-1 curl -sI http://localhost/ 2>/dev/null | grep -q "200\|302\|401"; then
        break
    fi
    sleep 2
done
sudo docker exec oc3-oc3-1 php /var/www/html/sql/stored-proc/maintain.php 2>&1 | tail -3 || true
echo "  Stored procedures installed"

# Import sample user (user_id 107469 becomes admin)
if [ -f "$REPO_OC3/sql/user_content_sample.sql" ]; then
    sudo docker exec -i mariadb-db-1 mysql -uroot -p$(cat "$DBPASS_FILE") --force oc \
        < "$REPO_OC3/sql/user_content_sample.sql" 2>/dev/null
    echo "  Sample user imported"
fi

# Grant privileges to app user
sudo docker exec mariadb-db-1 mysql -uroot -p$(cat "$DBPASS_FILE") \
    -e "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP,INDEX,ALTER,CREATE ROUTINE,ALTER ROUTINE,TRIGGER,LOCK TABLES ON oc.* TO 'oc'@'%';" 2>/dev/null || true

echo "[db] database ready"

# ── 7b. Wait for app containers to be ready ────────────────────────

echo "[wait] waiting for app containers..."
sleep 5

echo "[npm] waiting for NPM database to be ready..."
NPM_PATH=""
for i in $(seq 1 60); do
    NPM_DB=$(sudo docker volume ls --format '{{.Name}}' 2>/dev/null | grep npm_data)
    if [ -n "$NPM_DB" ]; then
        NPM_PATH=$(sudo docker volume inspect "$NPM_DB" --format '{{.Mountpoint}}')/database.sqlite
        # Wait for the proxy_host table to exist (NPM creates it on first boot)
        if sudo python3 -c "import sqlite3; sqlite3.connect('$NPM_PATH').execute('SELECT 1 FROM proxy_host')" 2>/dev/null; then
            break
        fi
    fi
    sleep 2
done

if [ -n "$NPM_PATH" ] && [ -f "$NPM_PATH" ]; then
    echo "  NPM database ready, inserting proxy hosts..."
    python3 -c "
import sqlite3, json
db = sqlite3.connect('$NPM_PATH')
hosts = [
    ('oc3', '${OC3_DOMAIN}', 80),
    ('oc4', '${OC4_DOMAIN}', 80),
    ('oc5', '${OC5_DOMAIN}', 3000),
    ('oc6', '${OC6_DOMAIN}', 3000),
    ('okapi', '${OKAPI_DOMAIN}', 80),
]
for host, domain, port in hosts:
    db.execute(
        'INSERT INTO proxy_host (created_on, modified_on, owner_user_id, domain_names, forward_host, forward_port, forward_scheme, enabled, meta, advanced_config) VALUES (datetime(\"now\"), datetime(\"now\"), 1, ?, ?, ?, \"http\", 1, \"{}\", \"\")',
        (json.dumps([domain]), host, port)
    )
db.commit()
print(f'  Inserted {len(hosts)} proxy hosts')
" || true
    # Force NPM to regenerate nginx configs from the database
    echo y | sudo docker exec -i npm-nginx-proxy-manager-1 node scripts/regenerate-config 2>/dev/null || true
    echo "  NPM config regenerated"
else
    echo "  ⚠ NPM database not ready — configure proxy hosts manually at http://$OC3_DOMAIN:81"
    echo "    $OC3_DOMAIN → oc3:80"
    echo "    $OC4_DOMAIN → oc4:80"
    echo "    $OC5_DOMAIN → oc5:3000"
    echo "    $OC6_DOMAIN → oc6:3000"
    echo "    $OKAPI_DOMAIN → okapi:80"
fi

# ── 9. Wait for apps, print summary ────────────────────────────────

echo "[ready] waiting for apps (first boot takes ~30s for npm/composer install)..."
sleep 15

echo ""
echo "============================================"
echo " OC Dev Stack Ready"
echo "============================================"
echo ""
echo "  Apps:"
for host in oc3 oc4 oc5 oc6 okapi; do
    eval "domain=\$$(echo $host | tr '[:lower:]' '[:upper:]')_DOMAIN"
    code=$(curl -sk -o /dev/null -w "%{http_code}" -H "Host: $domain" http://localhost/ 2>/dev/null || echo "---")
    echo "    http://$domain  [$code]"
done
echo ""
echo "  Management:"
echo "    http://$OC3_DOMAIN:81   NPM (admin@example.com / changeme)"
echo "    http://$OC3_DOMAIN:5001 Dockge"
echo ""
echo "  Source repos at $REPO_DIR/"
echo "  DB password saved in $STACKS/mariadb/.dbpass"
echo ""
echo "============================================"
