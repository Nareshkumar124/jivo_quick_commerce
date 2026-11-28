# Production on the same server: plan

**Status (2026-11-28): live at `https://quick.jivo.in` (nginx site file + Let's Encrypt certificate), code `1c7724d`. Cash on delivery only (DL-85). Catalog and policy pages (`/legal/`) loaded; no stores or staff yet. See §6 and §7.** Each further step needs the owner's go-ahead.
**No secret values ever go in this folder.** The repository is public.

Production runs on the same shared server as staging (`138.252.101.117`), **next to** the staging
stack (`jqc.jivo.in`), fully separate from it. All rules R1–R10 in `plan.md` §0 still apply: other
websites and the staging stack must not be disturbed.

## 1. What stays separate from staging

| Item | Staging (today) | Production (new) |
|---|---|---|
| Domain | `jqc.jivo.in` | `quick.jivo.in` (DNS + TLS since 2026-11-27) |
| Settings | `config.settings.staging` | `config.settings.production` |
| Compose project / network | `jqc` / `jqc_net` | `jqcprod` / `jqcprod_net` |
| Volumes | `jqc_*` | `jqcprod_pgdata`, `jqcprod_redisdata`, `jqcprod_miniodata` |
| Folder on server | `/srv/jqc/` | `/srv/jqc-prod/` (same layout: compose, env, src, static, cache, acme, logs, backups) |
| Host ports (127.0.0.1 only) | 18001 web, 19000 MinIO | 18002 web, 19002 MinIO (check free with `ss -tlnp`) |
| nginx file | `jqc.jivo.in.conf` | one new file `quick.jivo.in.conf` (`nginx/` here), zones/maps prefixed `jqcprod_` |
| Database | own Postgres container | own Postgres container, **fresh DB, no demo data** |
| Secrets | `/srv/jqc/env/` | `/srv/jqc-prod/env/`, all **newly generated** (never copied from staging) |
| Razorpay | test keys | **live keys + live webhook secret** |
| OTP test numbers / `seed_demo` | allowed | **refused by settings** |

## 2. What we need from you / Jivo (blockers)

| # | Item | Tracker |
|---|---|---|
| P1 | Production domain name, and its DNS A record pointing to `138.252.101.117` | new |
| P2 | Server capacity OK for a second stack (about 2 vCPU, 4 GB RAM, 40 GB disk more) | D6 |
| P3 | Razorpay **live** account (KYC done), live Key ID + Secret, live webhook + secret | H-23 |
| P4 | SMS: DLT templates approved for order SMS too (login OTP already works) | H-06, T-820 |
| P5 | Firebase **production** project, `google-services.json` for prod app ids, FCM server credentials | D-19 |
| P6 | Google Maps keys: Android key for prod packages + release SHA-1; server key | H-16 |
| P7 | Real catalog: GST/HSN, FSSAI, SAP codes, prices, photos | H-18 |
| P8 | Real store(s): address, delivery area, opening hours, staff accounts | new |
| P9 | Real config: support phone/email, policy and terms URLs, grievance officer | H-05, H-22 |
| P10 | Offsite backup target (where nightly copies go) | D7 |
| P11 | Alert email / Sentry project for production | D8 |
| P12 | Play Store: developer account, app signing upload keys (two people hold them) | release-checklist |
| P13 | Make the GitHub repo private (recommended before launch) | H-03 |

## 3. Steps (in order)

1. **Read-only check of the server:** free ports, disk, RAM, current containers, nginx layout. No changes.
2. **Repo files (DevOps agent, code review):**
   - `deployment/production/compose.prod.yml`: project `jqcprod`, memory limits sized so staging + other sites still fit, log caps.
   - `deployment/production/nginx/<prod-domain>.conf`: single site file, `jqcprod_` names, rate limits, HSTS.
   - `deployment/production/env.example`: list of env names only (no values).
3. **Secrets on the server:** generate fresh `DJANGO_SECRET_KEY`, `JWT_SIGNING_KEY`, `OTP_HASH_KEY`,
   `FIELD_ENCRYPTION_KEYS`, Postgres and MinIO passwords into `/srv/jqc-prod/env/` (mode 600).
   Back up `FIELD_ENCRYPTION_KEYS` separately (offline too) — without it KYC/bank data is lost.
4. **First deploy:** build image from a tagged `main` commit → start postgres/redis/minio → buckets →
   `release` (`check --deploy` must pass) → `migrate` → web, worker, worker-slow, beat.
5. **nginx + TLS:** add the one file (HTTP only), `nginx -t`, reload, `certbot certonly --webroot -d <prod-domain>`,
   enable HTTPS, `nginx -t`, reload. Check every other site (and staging) before and after.
6. **Real data:** load the catalog, create stores and delivery areas, create staff users with MFA.
7. **Backups and monitoring (must be done before launch, not later):** nightly `pg_dump` + MinIO mirror,
   offsite copy, one full restore test; Sentry, uptime check on `/health/ready`, disk/memory alerts.
8. **Apps:** prod flavor builds pointing to the production domain, signed AAB for Play Store.
9. **Smoke test on production:** login with a real OTP, browse, COD order to delivery, online payment, refund.
10. **Go live** only after `docs/release-checklist.md` is fully ticked.

## 4. Updates and rollback

- Update: pre-deploy DB dump → new image → `release` (migrate) → restart web/workers; only one beat at a time.
- Rollback app: run the previous image tag (migrations are additive).
- Staging updates and production updates are separate commands on separate compose projects; never run one for the other.
- Remove production: remove its nginx symlink, `nginx -t`, reload, `docker compose -p jqcprod down`. Staging and other sites untouched.

## 5. Risks

- **Shared server:** production, staging and other sites share CPU, RAM and disk (swap was already half used in Nov).
  Memory limits and alerts are required. Later, production should move to its own server or a managed DB.
- **Mixing up staging and production:** different folder, project name, ports and domain; every command names the project explicitly.
- **Backups on the same disk are not enough:** the offsite copy (P10) is required before launch.

## 6. What was done on the server (2026-11-26)

**Status: the app is running in cash-on-delivery-only mode** (`ONLINE_PAYMENTS_ENABLED=false`,
DL-85, approved by the owner). It is reachable only on `127.0.0.1:18002`: no nginx, no certbot,
no domain yet (P1). Empty database, no demo data. Staging and the other sites were checked before
and after both rounds: identical status codes, `nginx -T` md5 unchanged.

Files in this folder: `compose.prod.yml` (project `jqcprod`, from the staging compose with smaller
memory caps; the server copy is identical) and `env.example` (names only).

| Step | Result |
|---|---|
| Discovery | 14 CPUs, 26 GB RAM (about 10 GB available), **swap 10 of 12 GB used**, 94 GB free disk. 127.0.0.1:18002 and :19002 were free. Staging (`jqc`, 7 containers) healthy. |
| Folder | `/srv/jqc-prod/` with `compose/ env/ (700) env/keys-backup/ (700) src/ static/ cache/ acme/ logs/ backups/` |
| Secrets | Freshly generated on the server (not copied from staging, never printed): `env/backend.env`, `env/postgres.env`, `env/minio.env` (600). `FIELD_ENCRYPTION_KEYS` backup: `env/keys-backup/FIELD_ENCRYPTION_KEYS.20261126-113522` (600). **Copy it offline.** No `SEED_DEMO_ALLOWED`, `OTP_TEST_NUMBERS`, `LOADTEST_DATA_ALLOWED`, `JQC_SKIP_STARTUP_CHECK`, no Razorpay keys. |
| Cash only | `ONLINE_PAYMENTS_ENABLED=false` appended to `env/backend.env` (copy before the change: `env/backend.env.bak-20261126-cod`, 600). Checked in the web container: `online_payments_enabled()` is `False`, settings `config.settings.production`. |
| Domain | **Placeholder** `prod-domain-pending.jivo.in` in `DJANGO_ALLOWED_HOSTS`, CSRF origin, S3 media/presign URLs, `DEFAULT_FROM_EMAIL` (backend.env) and `JQCPROD_HOST` (`compose/.env`). Replace all of them when P1 is known, then restart web, worker, worker-slow, beat. |
| SMS / FCM / Maps / Sentry / email | Not set. SMS falls back to `UnconfiguredSmsBackend` (passes checks, sends fail loudly). Push disabled (`notifications.W001`, warning only). Email: dummy backend. |
| Image | `jqcprod-backend:56b778d` built from `main` `56b778d` (`git -c core.autocrlf=false archive`), source in `src/56b778d/`, build log `logs/build-56b778d.log`. Old image `jqcprod-backend:3bdb522` kept (never ran the app). `compose/DEPLOYED_SHA` = `56b778d`. |
| Infra | `jqcprod-postgres-1`, `jqcprod-redis-1`, `jqcprod-minio-1` running and healthy (network `jqcprod_net`, volumes `jqcprod_*`, MinIO on 127.0.0.1:19002). Buckets `jivo-media` (private) and `jivo-public` (anonymous GetObject only). |
| Release | First try on `3bdb522` stopped on `payments.E003` (no live keys), as intended. On `56b778d` with the switch off: `check --deploy` passed (only `notifications.W001`), `migrate` applied 132 migrations on the fresh DB. Log: `logs/release-56b778d.log`. **No `seed_demo`**: 0 users, 0 products. |
| Static | Copied from the image to `/srv/jqc-prod/static/` (13 MB, manifest present). |
| App | `jqcprod-web-1` (healthy), `jqcprod-worker-1`, `jqcprod-worker-slow-1`, `jqcprod-beat-1` up. `curl -H 'Host: prod-domain-pending.jivo.in' http://127.0.0.1:18002/health/ready` = 200 `{"database":"ok","redis":"ok"}`. Celery ping: `celery@` and `slow@` both OK. Beat: DatabaseScheduler started and sends due tasks. |
| Memory after start | Host: 9.5 GB available, swap 9.6 of 12 GB. jqcprod total about 1.3 GB (web 392 MB, worker 406 MB, worker-slow 236 MB, beat 139 MB, postgres 45 MB, minio 64 MB, redis 3 MB). |

### 2026-11-27 update (owner approved)

Staging and the other sites were checked before and after: identical status codes, `nginx -T`
md5 unchanged, live nginx never reloaded. (`jivo-erp_frontend_1` was already restart-looping
before we started; not ours, not touched.)

| Step | Result |
|---|---|
| Code | `jqcprod-backend:f1cb51e` built from pushed `main` `f1cb51e` (`git -c core.autocrlf=false archive`; source `src/f1cb51e/`, log `logs/build-f1cb51e.log`). Pre-deploy dump `backups/pre-f1cb51e.dump` (600). `release`: `check --deploy` no issues, no new migrations (`logs/release-f1cb51e.log`). Static copied additively (root-owned folder, copy with `sudo cp -a`). web, worker, worker-slow, beat restarted (beat stopped first). `compose/DEPLOYED_SHA` = `f1cb51e`. Old images `56b778d` and `3bdb522` kept. |
| Domain | `prod-domain-pending.jivo.in` replaced by `quick.jivo.in` in `env/backend.env` (allowed hosts, CSRF origin, S3 public media domain, presign URL, `DEFAULT_FROM_EMAIL`) and `compose/.env` (`JQCPROD_HOST`). Backups: `env/backend.env.bak-20261127-domain`, `compose/.env.bak-20261127-domain` (600). The old host now gets 400. |
| Push / Maps (same as test) | `GOOGLE_MAPS_SERVER_KEY` copied from staging's env; `FCM_CREDENTIALS_FILE=/run/secrets/fcm-service-account.json`; staging's FCM key file copied to `env/fcm-service-account.json` (0440, root, same group as staging's copy so the container user can read it) and mounted via `JQCPROD_FCM_KEY_FILE` in `compose/.env`. `notifications.W001` is gone. **Note:** this is the test Firebase project; replace it with the production one (P5) before launch. |
| SMS | **Not configured, also not on staging**: staging's env has no SMS settings (it runs `UnconfiguredSmsBackend` and uses OTP test numbers). So nothing was copied; production still has `UnconfiguredSmsBackend` and **real OTP SMS will not send** until the SMS provider settings exist (P4, H-06/H-24). |
| Cash only | `ONLINE_PAYMENTS_ENABLED=false`; `online_payments_enabled()` is `False` after the restart. No Razorpay keys. |
| Catalog | Files in `/srv/jqc-prod/import/` (catalog CSVs and manifests from `f1cb51e`, `shop_jivo_in` photos from the PM's PC, drive photos copied read-only from staging's `/srv/jqc/data/drive-import/images`). Dump before: `backups/pre-catalog-20261127.dump` (600). `import_catalog --commit`: 15 categories, 49 products, 111 variants (99 active). `import_catalog_images --commit`: 228 + 207 = 435 images (3 duplicate rows ignored). Prices: all 83 SKUs that also exist on staging have the same MRP and selling price. GST 5% placeholder, HSN/FSSAI blank, as in the files. Not done: banners, category images, collections (later, in Admin), stock (none), no `seed_demo`, 0 users, 0 stores. Note: staging has deactivated some of these SKUs by hand (74 active there); production has every variant the files mark active. |
| nginx + TLS | Done the same day once DNS pointed here (owner approved): §7 run as written. See "§7 result" below. |
| Verify | `curl -H 'Host: quick.jivo.in' http://127.0.0.1:18002/health/ready` = 200 `{"database":"ok","redis":"ok"}`; Celery ping `celery@` and `slow@` OK. |

**Rollback of this update:**
```bash
cd /srv/jqc-prod/compose
cp -p ../env/backend.env.bak-20261127-domain ../env/backend.env; cp -p .env.bak-20261127-domain .env
docker compose -p jqcprod -f compose.prod.yml stop beat
JQCPROD_IMAGE=jqcprod-backend:56b778d docker compose -p jqcprod -f compose.prod.yml up -d web worker worker-slow beat
echo 56b778d > DEPLOYED_SHA
# catalog only (empties the catalog again): restore backups/pre-catalog-20261127.dump with pg_restore --clean
```

### 2026-11-27 update 2: code `ff30e9c` (owner approved)

| Step | Result |
|---|---|
| Code | `jqcprod-backend:ff30e9c` built from pushed `main` `ff30e9c` (store management, prices, offers, delivery pincodes; source `src/ff30e9c/`, log `logs/build-ff30e9c.log`). Pre-deploy dump `backups/pre-ff30e9c.dump` (600). `release`: `check --deploy` no issues; migrated `catalog.0007_productvariant_manage_prices`, `promotions.0006_coupon_manage_offers`, `stores.0008_delivery_pincodes` (`logs/release-ff30e9c.log`). Static copied additively. beat stopped, then web, worker, worker-slow, beat up on the new image. `compose/DEPLOYED_SHA` = `ff30e9c`. Old images `f1cb51e` and `56b778d` kept (`3bdb522` was no longer present on the host). |
| Verify | `https://quick.jivo.in/health/ready` 200; `/admin/` → login page; Celery ping `celery@` and `slow@` OK; `online_payments_enabled()` False. Staging and other sites identical before/after; `nginx -T` md5 unchanged (nginx not touched). |

**Rollback:** `cd /srv/jqc-prod/compose && docker compose -p jqcprod -f compose.prod.yml stop beat && JQCPROD_IMAGE=jqcprod-backend:f1cb51e docker compose -p jqcprod -f compose.prod.yml up -d web worker worker-slow beat && echo f1cb51e > DEPLOYED_SHA` (migrations are additive; the old code runs on the new schema).

### 2026-11-27 update 3: code `a231672` (owner approved)

Store map editor CSS only (`static/ops/css/map-edit.css`, one line in `ops_console/maps.py`), no migrations. Pre-deploy dump `backups/pre-a231672.dump` (600); `jqcprod-backend:a231672` built from pushed `main`; `release`: no issues, no migrations; static copied additively (`ops/css/map-edit.018eb56dabdd.css` in the manifest); beat stopped, web/worker/worker-slow/beat restarted; `compose/DEPLOYED_SHA` = `a231672`. Verified: `https://quick.jivo.in/health/ready` 200, `/static/ops/css/map-edit.css` and the hashed name 200 (`text/css`, hashed one immutable), Celery `celery@`/`slow@` OK. Staging and other sites identical before/after, nginx untouched. Old images `ff30e9c`, `f1cb51e`, `56b778d` kept. **Rollback:** as update 2, with `jqcprod-backend:ff30e9c` and `echo ff30e9c > DEPLOYED_SHA`.

### 2026-11-27 update 4: code `1178306` (owner approved)

`SECURE_REFERRER_POLICY = "strict-origin-when-cross-origin"` (OpenStreetMap tiles no longer 403), no migrations. Pre-deploy dump `backups/pre-1178306.dump` (600); `jqcprod-backend:1178306` built from pushed `main`; `release`: no issues, no migrations; static copied; beat stopped, web/worker/worker-slow/beat restarted; `compose/DEPLOYED_SHA` = `1178306`. Verified: `/health/ready` 200; `/admin/login/` sends `referrer-policy: strict-origin-when-cross-origin` (was `same-origin`); the nginx file sets `Referrer-Policy` only in the private `/jivo-media/` location, nothing for `/admin/`; Celery OK. Staging and other sites identical before/after, nginx untouched. Old images `a231672`, `ff30e9c`, `f1cb51e`, `56b778d` kept. **Rollback:** as update 2, with `jqcprod-backend:a231672` and `echo a231672 > DEPLOYED_SHA`.

**Note:** before update 5, production was already running `jqcprod-backend:2ff583f` (store map "Use my current location" button; `backups/pre-2ff583f.dump`, `logs/build-2ff583f.log`, `logs/release-2ff583f.log`, `DEPLOYED_SHA` = `2ff583f` on 2026-11-27 17:27). That update was not written up here.

### 2026-11-28 update 5: code `1c7724d` (owner approved: launch work)

Public policy pages at `/legal/` and the `load_legal_pages` command, no migrations. Staging and other sites checked before/after (`logs/sites-before-1c7724d.txt`, `logs/sites-after-1c7724d.txt`): identical status codes, `nginx -T` md5 unchanged, nginx untouched. Pre-deploy dump `backups/pre-1c7724d.dump` (600); `jqcprod-backend:1c7724d` built from pushed `main` (`git -c core.autocrlf=false archive`; source `src/1c7724d/`, log `logs/build-1c7724d.log`); `release`: `check --deploy` no issues, no migrations (`logs/release-1c7724d.log`); static copied additively; web/worker/worker-slow/beat restarted (one beat only); `compose/DEPLOYED_SHA` = `1c7724d`. Then `load_legal_pages --base-url https://quick.jivo.in` (dry run first; log `logs/load-legal-pages-20261128.log`): 6 pages created (terms, privacy, refund-policy, delivery-policy, contact, delete-account); config support phone `+918595349565`, support email `info@jivo.in`, terms/privacy/refund URLs on `https://quick.jivo.in/legal/...`, `terms_version` `2026-11-28`. Verified: `/health/ready` 200; `/legal/` lists the 6 pages, each page 200; `/api/v1/config/app/` returns the new support and policy URLs; `online_payments_enabled()` False; Celery `celery@`/`slow@` OK. Old images `2ff583f`, `1178306`, `a231672`, `ff30e9c`, `f1cb51e`, `56b778d` kept.

**Rollback:** `cd /srv/jqc-prod/compose && export JQCPROD_IMAGE=jqcprod-backend:2ff583f && docker compose -p jqcprod -f compose.prod.yml stop beat && docker compose -p jqcprod -f compose.prod.yml up -d web worker worker-slow beat && echo 2ff583f > DEPLOYED_SHA` (`2ff583f` was running before; use `1178306` the same way to go one further back). The policy pages and config values stay in the DB (harmless for the old code); to undo them too, restore `backups/pre-1c7724d.dump` with `pg_restore --clean`. Every compose command needs `JQCPROD_IMAGE` set, even `stop` (without it compose refuses to run).

### 2026-11-28 catalog text (owner approved: launch work)

Product text without health claims, from pushed `main` `eb7e93c` `data/catalog/text_only/products.csv` (columns slug, short_description, description, highlights; 33 rows; fetched from GitHub raw at that commit, sha256 matches git). Dump before: `backups/pre-catalog-text-20261128.dump` (600). File in `/srv/jqc-prod/import/catalog_text/`, copied into the web container with `docker cp` (`/tmp/catalog_text`, gone when the container is recreated). Dry run (`logs/import-catalog-text-dryrun-20261128.log`): products.csv 0 created, 33 updated, categories/variants not found. Field-level preview inside a rolled-back transaction (`logs/import-catalog-text-preview-20261128.log`): only `short_description`, `description`, `highlights` (+ `updated_at`) changed on 33 products; nothing else in categories, products, variants, price tiers, images, collections, banners or stock. Then `import_catalog --commit --yes` (`logs/import-catalog-text-commit-20261128.log`): 33 updated. A hash of every other catalog/stock field is identical before and after (`import/snapshot-before.txt`, `import/snapshot-after.txt`). Checked `sano-sunflower-oil` in the DB: new text, variant `SNO-SUN-5L` MRP/price 1475.00 unchanged, 5 images. (The public API could not show it: production has no stores yet, so every catalog call needs a store and returns `STORE_NOT_FOUND`.) **Undo:** restore `backups/pre-catalog-text-20261128.dump` with `pg_restore --clean` (also undoes anything saved after it).

### 2026-11-28 all products hidden (owner instruction)

Nothing deleted. Dump before: `backups/pre-hide-products-20261128.dump` (600). List of what was active before: `backups/active-products-20261128.txt` (600; 48 `product <id> <slug>` lines, 99 `variant <id> <sku>` lines). In one transaction `Product.objects.filter(is_active=True).update(is_active=False)` (48 rows; 1 product was already inactive), then the catalog cache version bumped (`apps.catalog.cache.bump_global_version`, as the app's signals do). Variants were **not** changed: the catalog API (`_visible_products()`) and the cart both check `Product.is_active`, so hiding products is enough. Result: 0 of 49 products active, `_visible_products()` 0, 99 active variants untouched (`logs/hide-products-20261128.log`). `/health/ready` 200.

**Restore exactly (shows the same 48 products again):**
```bash
cd /srv/jqc-prod
docker cp backups/active-products-20261128.txt jqcprod-web-1:/tmp/active-products.txt
docker exec jqcprod-web-1 python manage.py shell -c "
from django.db import transaction
from apps.catalog.models import Product
from apps.catalog.cache import bump_global_version
ids = [int(l.split()[1]) for l in open('/tmp/active-products.txt') if l.startswith('product ')]
with transaction.atomic():
    n = Product.objects.filter(id__in=ids).update(is_active=True)
    transaction.on_commit(bump_global_version)
print('restored', n, 'of', len(ids))"
docker exec jqcprod-web-1 rm /tmp/active-products.txt
```
(Variants were never changed, so nothing to restore for them.)

### 2026-11-28 update 6: code `01e0016` (owner approved: launch work)

Email OTP login (backend, admin login switch, store-reviewer email logins, rider `contact_phone`). **Migrations (all additive):** `accounts.0010_email_otp_login`, `cms.0006_login_methods`, `delivery.0004_rider_contact_phone`. Staging and other sites checked before/after (`logs/sites-before-01e0016.txt`, `logs/sites-after-01e0016.txt`): identical status codes, `nginx -T` md5 unchanged, nginx untouched.

| Step | Result |
|---|---|
| Env | Backup `env/backend.env.bak-20261128-email` (600). In `env/backend.env` (600): `EMAIL_BACKEND` changed from the dummy backend to `django.core.mail.backends.smtp.EmailBackend`; added `EMAIL_HOST`, `EMAIL_PORT`, `EMAIL_HOST_USER`, `EMAIL_HOST_PASSWORD`, `EMAIL_USE_TLS=true` (Gmail SMTP, values from the PM's `~/.config/jivo-quick-commerce/email/credentials.txt`, streamed over SSH, never printed); `DEFAULT_FROM_EMAIL=Jivo Quick <sender address>` (replaces `Jivo Quick Commerce <noreply@quick.jivo.in>`); `STORE_REVIEW_LOGINS` = customer reviewer email, rider reviewer email and review phone, each with its code (from `~/.config/jivo-quick-commerce/store-review/logins.txt`). |
| Code | Pre-deploy dump `backups/pre-01e0016.dump` (600). `jqcprod-backend:01e0016` built from pushed `main` (`git -c core.autocrlf=false archive`; source `src/01e0016/`, log `logs/build-01e0016.log`). `release` (`logs/release-01e0016.log`): `check --deploy` no issues (so `accounts.E008`-`E011` pass), then the 3 migrations OK. Static copied additively. beat stopped, then web/worker/worker-slow/beat up on the new image (one beat). `compose/DEPLOYED_SHA` = `01e0016`. |
| Login switch | `apps.cms.services.set_login_methods("customer"/"rider", "email", actor=None)` (audited as `config.login_methods`; log `logs/login-methods-20261128.log`): phone/phone → email/email. `GET /api/v1/auth/methods/?app=customer` and `?app=rider` → `{"methods":["email"]}`. |
| Smoke | Customer reviewer: email-otp request 200, verify with its code 200 + tokens (user id 2 created, no email sent). Sender's own Gmail address: request 200, worker `accounts.send_otp_email` succeeded (`'sent'`). No other real email sent. Rider reviewer: verify with `app=rider` 200 (user id 3 created, `has_phone: false`, `rider_status: NONE`); **not registered yet**: `GET /rider/stores/` is empty (production has no stores), and `preferred_store_id` is required. Register it (contact_phone `+919999900002`) once a store exists. |
| Verify | `/health/ready` 200; `/admin/login/` 200; Celery `celery@`/`slow@` OK; `online_payments_enabled()` False. Old images `1c7724d`, `2ff583f`, `1178306`, `a231672`, `ff30e9c`, `f1cb51e`, `56b778d` kept. |

**Rollback:** `cd /srv/jqc-prod/compose && export JQCPROD_IMAGE=jqcprod-backend:1c7724d && docker compose -p jqcprod -f compose.prod.yml stop beat && docker compose -p jqcprod -f compose.prod.yml up -d web worker worker-slow beat && echo 1c7724d > DEPLOYED_SHA`. The migrations are additive, so the old code runs on the new schema; no DB restore needed (to undo the schema and the two reviewer users too, restore `backups/pre-01e0016.dump` with `pg_restore --clean`, which also drops anything saved after it). The new env lines are harmless for the old code; to undo them: `cp -p /srv/jqc-prod/env/backend.env.bak-20261128-email /srv/jqc-prod/env/backend.env`, then the `up -d` above. To switch logins back to phone without a rollback: Django admin login switch, or `set_login_methods(app, "phone")` in the web shell.

**Next (2026-11-27):** stores/staff (step 6), backups and monitoring (step 7), SMS (P4), production Firebase (P5).

**Earlier next steps (2026-11-26):** P1 domain + DNS, then the one nginx file and TLS (step 5), real data (step 6), backups
and monitoring (step 7). Online payment: put the Razorpay **live** keys and webhook secret in
`backend.env`, set `ONLINE_PAYMENTS_ENABLED=true`, run `release`, restart web and workers.

**Stop the app only (keeps DB and infra):**
```bash
cd /srv/jqc-prod/compose && JQCPROD_IMAGE=jqcprod-backend:01e0016 docker compose -p jqcprod -f compose.prod.yml stop web worker worker-slow beat
```

**Undo (touches only production):**
```bash
cd /srv/jqc-prod/compose && JQCPROD_IMAGE=x docker compose -p jqcprod -f compose.prod.yml down   # keeps volumes
# full removal, only if nothing is needed:
docker volume rm jqcprod_pgdata jqcprod_redisdata jqcprod_miniodata; docker image rm jqcprod-backend:3bdb522 jqcprod-backend:56b778d jqcprod-backend:f1cb51e jqcprod-backend:ff30e9c jqcprod-backend:a231672 jqcprod-backend:1178306 jqcprod-backend:2ff583f jqcprod-backend:1c7724d jqcprod-backend:01e0016
sudo rm -rf /srv/jqc-prod
```

## 7. nginx + TLS for `quick.jivo.in` (DONE 2026-11-27, kept as the runbook)

The site file is `nginx/quick.jivo.in.conf` in this folder (generated from the staging file: every
name `jqcprod_`, upstream `127.0.0.1:18002`, MinIO `127.0.0.1:19002`, files under `/srv/jqc-prod/`).
A staged copy waits on the server at `/srv/jqc-prod/compose/nginx/quick.jivo.in.conf`; it is **not**
in `/etc/nginx` and nginx has not been reloaded for it.

Before and after: record the HTTP status of staging (`https://jqc.jivo.in/health/ready`) and of every
other `server_name` in `sudo nginx -T`, and the md5 of `sudo nginx -T`. Any change in another site:
remove our symlink, `nginx -t`, reload, stop.

```bash
# 0. DNS must answer with the server's IP, or certbot fails (and nothing else may be changed)
dig +short quick.jivo.in            # must print 138.252.101.117
cd /srv/jqc-prod/compose/nginx
# 1. media cache directory (owner = the `user` in the host's nginx.conf)
NGINX_USER=$(sudo nginx -T 2>/dev/null | awk '$1=="user"{gsub(";","",$2); print $2; exit}')
sudo install -d -m 755 /srv/jqc-prod/cache
sudo install -d -m 700 -o "${NGINX_USER:-www-data}" -g "${NGINX_USER:-www-data}" /srv/jqc-prod/cache/nginx-media
sudo install -d -m 755 /srv/jqc-prod/acme
# 2. HTTP-only bootstrap: our file without the HTTPS server block
sed '/^# BEGIN JQCPROD HTTPS/,/^# END JQCPROD HTTPS/d' quick.jivo.in.conf | sudo tee /etc/nginx/sites-available/quick.jivo.in.conf >/dev/null
sudo ln -s /etc/nginx/sites-available/quick.jivo.in.conf /etc/nginx/sites-enabled/quick.jivo.in.conf
sudo nginx -t && sudo systemctl reload nginx      # on failure: sudo rm the symlink, stop
# 3. certificate for quick.jivo.in ONLY (webroot; other sites' certificates untouched)
sudo certbot certonly --webroot -w /srv/jqc-prod/acme -d quick.jivo.in --non-interactive --agree-tos \
  --deploy-hook 'systemctl reload nginx'
# 4. full file (HTTPS + HSTS)
sudo install -m 644 quick.jivo.in.conf /etc/nginx/sites-available/quick.jivo.in.conf
sudo nginx -t && sudo systemctl reload nginx
# 5. check
curl -sS -o /dev/null -w '%{http_code}\n' https://quick.jivo.in/health/ready    # 200
sudo certbot renew --dry-run --cert-name quick.jivo.in
```

**Undo (only production's file):**
```bash
sudo rm /etc/nginx/sites-enabled/quick.jivo.in.conf && sudo nginx -t && sudo systemctl reload nginx
# later, if not needed: sudo certbot delete --cert-name quick.jivo.in; sudo rm /etc/nginx/sites-available/quick.jivo.in.conf
```

### §7 result (2026-11-27, owner approved)

- DNS: `quick.jivo.in` → `138.252.101.117` (checked against 8.8.8.8 and the server's resolver).
- Steps 1-4 run as written. `nginx -t` passed both times (only the host's existing warnings from
  other sites' files); `systemctl reload nginx` only, never restart. The HTTP-only copy is kept at
  `/srv/jqc-prod/compose/nginx/quick.jivo.in.http-only.conf`.
- Installed: `/etc/nginx/sites-available/quick.jivo.in.conf` + `sites-enabled` symlink;
  `/srv/jqc-prod/cache/nginx-media` (www-data, 700); certificate `/etc/letsencrypt/live/quick.jivo.in/`
  (expires 2027-02-25, renewal file `renewal/quick.jivo.in.conf`, deploy hook = reload,
  `certbot renew --dry-run --cert-name quick.jivo.in` succeeded). No other certificate touched.
- Before/after: all other `server_name`s gave identical status codes after the HTTP reload and after the
  HTTPS reload; staging `https://jqc.jivo.in/health/ready` 200 throughout.
- Checks from outside: `https://quick.jivo.in/health/ready` 200 `{"database":"ok","redis":"ok"}`;
  `/admin/` → 302 to the login page (form loads); HSTS header present; `http://` → 301 to `https://`;
  `/static/` 200; a product image under `/media/` 200 (`image/webp`).

