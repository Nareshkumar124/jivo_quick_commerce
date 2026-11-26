# Production on the same server: plan

**Status (2026-11-26): steps 1-4 done. The app runs in cash-on-delivery-only mode (DL-85), reachable only on 127.0.0.1:18002 (no domain, no nginx yet). See §6.** Each further step needs the owner's go-ahead.
**No secret values ever go in this folder.** The repository is public.

Production runs on the same shared server as staging (`138.252.101.117`), **next to** the staging
stack (`jqc.jivo.in`), fully separate from it. All rules R1–R10 in `plan.md` §0 still apply: other
websites and the staging stack must not be disturbed.

## 1. What stays separate from staging

| Item | Staging (today) | Production (new) |
|---|---|---|
| Domain | `jqc.jivo.in` | **to decide** (e.g. `quick.jivo.in` or `api.quick.jivo.in`) |
| Settings | `config.settings.staging` | `config.settings.production` |
| Compose project / network | `jqc` / `jqc_net` | `jqcprod` / `jqcprod_net` |
| Volumes | `jqc_*` | `jqcprod_pgdata`, `jqcprod_redisdata`, `jqcprod_miniodata` |
| Folder on server | `/srv/jqc/` | `/srv/jqc-prod/` (same layout: compose, env, src, static, cache, acme, logs, backups) |
| Host ports (127.0.0.1 only) | 18001 web, 19000 MinIO | 18002 web, 19002 MinIO (check free with `ss -tlnp`) |
| nginx file | `jqc.jivo.in.conf` | one new file `<prod-domain>.conf`, zones/maps prefixed `jqcprod_` |
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

**Next:** P1 domain + DNS, then the one nginx file and TLS (step 5), real data (step 6), backups
and monitoring (step 7). Online payment: put the Razorpay **live** keys and webhook secret in
`backend.env`, set `ONLINE_PAYMENTS_ENABLED=true`, run `release`, restart web and workers.

**Stop the app only (keeps DB and infra):**
```bash
cd /srv/jqc-prod/compose && JQCPROD_IMAGE=jqcprod-backend:56b778d docker compose -p jqcprod -f compose.prod.yml stop web worker worker-slow beat
```

**Undo (touches only production):**
```bash
cd /srv/jqc-prod/compose && JQCPROD_IMAGE=x docker compose -p jqcprod -f compose.prod.yml down   # keeps volumes
# full removal, only if nothing is needed:
docker volume rm jqcprod_pgdata jqcprod_redisdata jqcprod_miniodata; docker image rm jqcprod-backend:3bdb522 jqcprod-backend:56b778d
sudo rm -rf /srv/jqc-prod
```
