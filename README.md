# OC — OpenCaching Development Environment

Docker Compose stack: OC3 (legacy PHP), OC4 (Symfony), OC5 (Node.js),
OKAPI (shared API), and MariaDB. Routed through Nginx Proxy Manager.

## Quick Start

```bash
# Clone everything
git clone git@github.com:hxdimpf/oc.git
git clone git@github.com:hxdimpf/oc3.git ../oc3
git clone git@github.com:hxdimpf/oc4.git ../oc4
git clone git@github.com:hxdimpf/oc5.git ../oc5
git clone -b oc4-combined git@github.com:hxdimpf/okapi.git ../okapi
cd OC

# Start infrastructure (NPM + Dockge)
cp .env.dist .env
# Edit .env with real passwords
docker compose -f docker-compose.infra.yml up -d

# Start apps
docker compose up -d
```

## Architecture

```
nginx-proxy-manager :80 :443 :81 (admin)
    ├── oc3.baiti.net   →  oc3:80
    ├── oc4.baiti.net   →  oc4:80
    ├── oc5.baiti.net   →  oc5:3000
    ├── oc6.baiti.net   →  oc6:3000
    └── okapi.baiti.net →  okapi:80

dockge :5001 (stacks dashboard)
```

## Services

| Service | Stack | Exposed Port |
|---------|-------|-------------|
| OC3 | PHP 8.2, Smarty | 80 (internal) |
| OC4 | PHP 8.4, Symfony 7.x | 80 (internal) |
| OC5 | Node 22, Express | 3000 (internal) |
| OC6 | Bun, TypeScript, Hono | 3000 (internal) |
| OKAPI | PHP 8.2 | 80 (internal) |
| MariaDB | 10.11 | none |
| NPM | nginx proxy | 80, 443, 81 |
| Dockge | compose GUI | 5001 |

## Routing

Routes are configured in the Nginx Proxy Manager GUI at http://<host>:81.
Point each domain to its service:

- `oc3.baiti.net` → `http://oc3:80`
- `oc4.baiti.net` → `http://oc4:80`
- `oc5.baiti.net` → `http://oc5:3000`
- `okapi.baiti.net` → `http://okapi:80`

## Daily workflow

```bash
cd /var/www/oc/OC
docker compose pull       # latest images
git pull && cd ../oc3 && git pull && cd ../oc4 && git pull && cd ../oc5 && git pull && cd ../okapi && git pull && cd ../OC
docker compose up -d --build
```

Source repos are mounted as volumes — no rebuild needed for code changes,
only `docker compose restart <service>`.
