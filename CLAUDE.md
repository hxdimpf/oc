# CLAUDE.md — OC Docker Stack

## Where to work: ALWAYS on your Mac in ~/src/

**Never edit files on the server** (`ssh baiti@oc3.baiti.net`). The server is deployment target only.
All editing, committing, and pushing happens from your Mac.

### Repos and local paths

| Repo | Local path | What it contains |
|------|-----------|-----------------|
| `hxdimpf/oc` | `~/src/oc` | Playbook, scripts, docs |
| `hxdimpf/oc3` | `~/src/oc3` | Legacy PHP app |
| `hxdimpf/oc4` | `~/src/oc4` | Symfony 7.x frontend |
| `hxdimpf/oc5` | `~/src/oc5` | Node.js/Express frontend |
| `hxdimpf/okapi` | `~/src/okapi` | OKAPI REST API |

### Workflow

**For backend code (PHP, Node.js, templates):**
```
1. cd ~/src/oc5                    # edit locally
2. git add -A && git commit -m "..." && git push origin dev-hx
3. ssh oc3 "sudo git -C /opt/repos/oc5 pull && sudo docker restart oc5-oc5-1"
```

**For shared assets (JS, CSS, vendor, shared/coords):**
The frontend assets live in BOTH repos directly. No separate repo. No mounts.
When you change a shared file, apply the same change to BOTH repos:

| File | OC5 path | OC4 path |
|------|---------|---------|
| JS modules | `oc5/public/js/*.js` | `oc4/public/_frontend/js/*.js` |
| CSS | `oc5/public/css/*.css` | `oc4/public/_frontend/css/*.css` |
| Vendor libs | `oc5/public/vendor/**` | `oc4/public/_frontend/vendor/**` |
| Shared utils | `oc5/public/lib/*.js` | `oc4/public/_frontend/shared/*.js` |

```
1. Edit file in ~/src/oc5/public/js/cache.js      # primary dev target
2. ~/src/oc/scripts/sync-js-to-oc4.sh cache.js     # copies + rewrites asset paths (never plain cp)
3. cd ~/src/oc5 && git add -A && git commit -m "..." && git push origin dev-hx
4. cd ~/src/oc4 && git add -A && git commit -m "..." && git push origin dev-hx
5. Deploy both stacks (see below)
```

**Important:** OC5 uses `public/js/` directly. OC4 uses `public/_frontend/js/`
(matching existing template paths). Content is identical, paths differ.
OC4 templates reference `/_frontend/js/loader.js`, OC5 templates use `/js/loader.js`.
OC5 does NOT serve `/_frontend/*` — templates converted from OC4 must have those paths rewritten.

**Map state:** templates inject no `window.*` globals. Page modules fetch their data and
pass it to the map via `handleWPs(wps, view)` (`initPageMap(wps)` for page maps).

**For Ansible playbook changes:**
```
1. cd ~/src/oc/ansible            # edit playbook or config
2. git add -A && git commit -m "..." && git push origin dev-hx
3. ansible-playbook -i inventory.ini deploy.yml -e "db_dump_file=..."
```

**Never:** edit on the server, commit on the server, push from the server.
**Always:** edit locally → commit → push → deploy via SSH pull + restart.

## Critical Rules (read first, never skip)

### 1. Templates: OC4 Twigs are canonical, OC5 Nunjucks are derived

OC4 and OC5 share the `oc-frontend` repo (standalone git clone, mounted into both containers). Templates must produce IDENTICAL DOM.

**All template changes MUST be made in OC4's Twig files first.**
OC5 Nunjucks files are derived artifacts — never edit them directly.

The ONLY safe way to create an OC5 template from an OC4 template:

```bash
./scripts/convert-twig.sh <oc4-template.twig> <oc5-output.njk>
```

This script handles: `extends`, `parent()`→`super()`, `|trans`→i18n lookup, `|json_encode|raw`→`|safe`.
It does NOT handle `path()` routes, `app.request.locale`, `knp_menu_render`, `"now"|date` — those must be inspected manually.

**Exception: `base.njk` is hand-maintained.** The OC4 Twig `base.html.twig` uses many Symfony-specific
constructs (`app.request.locale`, `path()`, `knp_menu_render()`, `|date("Y")`) that the converter
cannot handle. The OC5 `base.njk` is maintained manually. When the OC4 base template changes,
apply the same change manually to OC5's `base.njk` — do NOT run the converter on it.

**Never write a template from scratch.** Always start from the OC4 Twig original.

### 2. Nunjucks compatibility filters are in app.js

OC5's `app.js` adds Twig-compatible filters:
- `|format('%.1f', value)` — printf-style
- `|number_format(decimals, dec_sep, thou_sep)` — like Twig's number_format
- `range(start, end)` — global function

If a converted template fails with "filter not found", add the filter to `app.js`,
NOT to the template.

### 3. After every deploy, run tests

```bash
./scripts/test-deploy.sh all
```

This checks every page, every asset path, every image directory, and API endpoints.
Zero failures required before declaring "done".

### 4. Image paths

Images live in `public/images/` and are served at `/images/` on both OC4 and OC5.

### 5. The playbook is the source of truth

`ansible/deploy.yml` must produce a working system with no manual fixes.
Every runtime fix must be backported to the playbook.

Deploy command:
```bash
cd ansible
ansible-playbook -i inventory.ini deploy.yml \
  -e "db_dump_file=/path/to/dump.sql.gz" \
  -e "git_user_name=hxdimpf" \
  -e "git_user_email=hxdimpf@gmail.com"
```

## Repos

| Repo | Purpose | Branch |
|------|---------|--------|
| `hxdimpf/oc` | Ansible playbook, deploy scripts | `dev-hx` |
| `hxdimpf/oc3` | Legacy PHP (Symfony 3.x) | `dev-hx` |
| `hxdimpf/oc4` | Symfony 7.x frontend | `dev-hx` |
| `hxdimpf/oc5` | Node.js/Express frontend | `dev-hx` |
| `hxdimpf/okapi` | OKAPI REST API | `dev-hx` |

Local paths: `/Users/baiti/src/oc/`, `/Users/baiti/src/oc3/`, `/Users/baiti/src/oc4/`, `/Users/baiti/src/oc5/`, `/Users/baiti/src/okapi/`

## Infrastructure

Test server: `oc3.baiti.net` (192.168.192.11), SSH user `baiti`.
Docker on test server requires `sudo`.
Stacks at `/opt/stacks/`, repos at `/opt/repos/`.

NPM (Nginx Proxy Manager) routes by Host header:
- oc3.baiti.net → oc3:80
- oc4.baiti.net → oc4:80
- oc5.baiti.net → oc5:3000
- okapi.baiti.net → okapi:80

NPM config lives in SQLite: `/var/lib/docker/volumes/npm_npm_data/_data/database.sqlite`
Regenerate with: `echo y | docker exec -i npm-nginx-proxy-manager-1 node scripts/regenerate-config`

## Session Management

**Three independent stacks, three independent sessions.**

| Stack | Cookie name | Domain |
|-------|------------|--------|
| OC3 | `oc3_session` | none (host-only) |
| OC4 | `oc4_session` | none (host-only) |
| OC5 | `oc5_session` | none (host-only) |

All three validate against `sys_sessions` in the shared MariaDB.
No cross-subdomain cookie sharing. Each stack requires its own login.

**Why:** Chrome blocks cross-subdomain cookies on private IPs (192.168.x.x).
Even with `.baiti.net` domain cookies, the browser refuses to send them.
Independent host-only cookies are the only reliable approach for dev.

Cookie domain is EMPTY STRING in all settings:
- OC3: `$opt['session']['domain'] = '';` in playbook-generated `settings.inc.php`
- OC4: `null` domain in `Auth.php` Cookie constructor
- OC5: no domain parameter in `res.cookie()` call

For production on public DNS with real certificates, cross-subdomain cookies
can be re-enabled by setting domain to `.baiti.net`.

## oc5 specifics

- Express 5, ES modules (`"type": "module"`)
- Nunjucks templates at `public/templates/nunjucks/`
- Shared frontend at `public/_frontend/` (mounted from standalone `hxdimpf/oc-frontend` repo)
- `app.js` has `format`, `number_format` filters and `range()` global
- No helmet (dev env)
- Auth: `oc5_session` cookie → `sys_sessions` validation via `src/auth.js`
- DB: MariaDB via `mariadb` npm package, connection pool in `src/db.js`

## SSL (dev only)

Self-signed wildcard cert for `*.baiti.net` generated by playbook.
NPM's cert management is buggy with self-signed certs — config may need manual
`http_top.conf` with SSL server block. See deploy.yml NPM section for pattern.
