# OC — OpenCaching Development Environment

Dev VM with one Docker Compose stack per service, all on a shared `oc` network
and one MariaDB. Nginx Proxy Manager routes by hostname.

| Stack | Image | Routed as |
|-------|-------|-----------|
| oc3 | shinsenter/php:8.2-fpm-apache | `oc3.<domain>` → oc3:80 |
| oc4 | shinsenter/php:8.4-fpm-apache | `oc4.<domain>` → oc4:80 |
| oc5 | node:22-alpine | `oc5.<domain>` → oc5:3000 |
| oc6 | oven/bun:1 | `oc6.<domain>` → oc6:3000 |
| okapi | shinsenter/php:8.2-fpm-apache | `okapi.<domain>` → okapi:80 |
| mariadb | mariadb:10.11 | not exposed |
| npm | jc21/nginx-proxy-manager | ports 80, 443, 81 (admin) |
| dockge | louislam/dockge | port 5001 (stacks dashboard) |

## Layout

- `stacks/<name>/docker-compose.yml`: the compose files, deployed to `/opt/stacks/<name>/`.
  They read `DB_PASSWORD`, `REPO_BASE` and `DOMAIN_SUFFIX` from a `.env` next to them,
  which the playbook writes on the VM (never committed).
- `ansible/deploy.yml`: builds the VM from scratch. It installs Docker, clones the app repos
  into `/opt/repos/` (read-only https), copies the stacks, writes app configs, imports the
  DB dump and sets up the proxy routes.
- `scripts/test-deploy.sh`: smoke test for all apps. `scripts/sync-js-to-oc4.sh` copies shared JS from oc5 to oc4.

The app source is bind-mounted from `/opt/repos/<app>`, so a code change needs only a pull and a restart.

## Full rebuild (wipes the DB)

The playbook expects a clean VM. It generates a new DB password and re-imports the dump.

```bash
cd ansible
ansible-playbook -i inventory.ini deploy.yml -e "db_dump_file=/path/to/dump.sql.gz"
```

On an existing VM, first run `docker compose down -v` in every `/opt/stacks/*` and remove
`/opt/stacks` and `/opt/repos`.

## Code deploy

```bash
ssh oc3.baiti.net "sudo git -C /opt/repos/oc5 pull && sudo docker restart oc5-oc5-1"
./scripts/test-deploy.sh all
```

See `CLAUDE.md` for the working rules (edit only on the Mac, oc4/oc5 dual maintenance, sessions).
