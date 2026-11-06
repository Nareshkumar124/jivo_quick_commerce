# Deployment plan: Jivo Quick Commerce backend on `jqc.jivo.in`

**Status: PLAN ONLY.** Nothing has been deployed or changed on the server yet. Each phase below needs the owner's go-ahead.

**Target:** a shared Linux server at `138.252.101.117`, with DNS `jqc.jivo.in` pointing to it. The whole JQC backend stack runs in Docker. The server **already runs nginx with other live websites**.

> **Security**
> - This repository is **public**. No password, key or `.env` content is ever committed, and this file contains **no credentials**.
> - The server password was shared in a chat message. Treat it as exposed. Section 2 explains how to retire it **without affecting other users of the server**.

---

## 0. Ground rule: do not disturb the existing websites

The server already hosts other sites on its nginx. **This deployment must not modify, restart or break any of them.** Every step below follows these rules:

| # | Rule |
|---|---|
| R1 | **No edits to existing nginx files.** Leave `nginx.conf`, `conf.d/*`, other sites' files and existing certificates untouched. JQC adds **exactly one new file**, `/etc/nginx/sites-available/jqc.jivo.in.conf` (plus its `sites-enabled` symlink), or `conf.d/jqc.jivo.in.conf` if the server uses that layout. |
| R2 | **Only `server_name jqc.jivo.in`.** No `default_server`, no catch-all, no wildcard. Other domains' requests are never matched by our block. |
| R3 | **All global names are namespaced.** `limit_req_zone`, `limit_conn_zone`, `map` variables and `upstream` names are prefixed `jqc_` (e.g. `jqc_api`, `$jqc_connection_upgrade`), so they can't collide with directives already defined by other sites. |
| R4 | **Always `nginx -t` before any reload. Only `systemctl reload nginx`, never `restart`.** A reload is graceful: existing connections and other sites keep serving. If `nginx -t` fails, nothing is reloaded and our file is removed. |
| R5 | **TLS without touching other sites.** Issue the certificate with `certbot certonly --webroot` (or `--nginx -d jqc.jivo.in` only), for `jqc.jivo.in` only. Never re-run certbot for other domains. Renewal uses the existing certbot timer, if present, and only adds a renewal file for our domain. |
| R6 | **No host ports used by others.** Before choosing ports, list what's in use (`ss -tlnp`). JQC containers publish **only to `127.0.0.1`** on free ports (proposed: web `127.0.0.1:18001`, MinIO API `127.0.0.1:19000`). Postgres, Redis and MinIO-internal are **not published at all**; they're reachable only on the JQC Docker network. |
| R7 | **Docker is isolated.** If Docker already runs other containers, JQC uses its own compose project name (`jqc`), its own network (`jqc_net`) and volumes prefixed `jqc_`. We never run `docker system prune`, never stop or restart other containers, and never change `/etc/docker/daemon.json` without approval (it affects all containers). If Docker isn't installed, install it. Installing it doesn't affect a host nginx. |
| R8 | **No global system changes without explicit approval.** No changes to SSH configuration, firewall rules, users, OS upgrades, unattended-upgrades or kernel settings that could affect other services. |
| R9 | **Resources.** Check free disk, RAM and CPU first. Set container memory limits, so JQC can't starve the other sites. Docker logs are capped per container (`max-size`, `max-file` set in our compose file, not globally). |
| R10 | **Rollback that only touches JQC.** Remove our symlink, `nginx -t`, reload, then `docker compose -p jqc down`. The server is then back to exactly its previous state for the other sites. |

---

## 1. Backend components that will run

### 1.1 Processes (one Docker image, different commands)
| Component | What it does |
|---|---|
| **web**: gunicorn + uvicorn (ASGI) | REST API `/api/v1/`, WebSockets `/ws/v1/` (customer, rider) and `/ws/ops/live/` (staff), Django Admin `/admin/`, Ops Console `/ops/`, health `/health/live` and `/health/ready` |
| **worker**: Celery | Notifications (push, SMS, inbox), refunds, invoices, dispatch, WebSocket broadcasts |
| **beat**: Celery beat (exactly one) | Scheduled jobs (section 1.4) |
| **release** (one-off job per deploy) | `check --deploy` against the real environment, then `migrate` |

### 1.2 Infrastructure services (JQC-only containers)
| Component | Used for |
|---|---|
| **PostgreSQL 16 + PostGIS 3.4** | All data. PostGIS handles delivery areas and rider distances. |
| **Redis** | Cache, Celery broker, WebSocket channel layer, rate limits, rider live location |
| **MinIO (S3)** | Private bucket for KYC documents and invoices; public bucket for product images |
| **SMTP** | Staff and system email (an external mail service) |
| **The existing host nginx** | Reverse proxy and TLS for `jqc.jivo.in`, via **one new site file** only (section 0) |

### 1.3 Django apps
`accounts` (OTP, JWT, staff roles, MFA, DPDP erasure), `stores`, `catalog`, `inventory`, `cart` (`compute_bill`), `promotions`, `orders`, `payments` (Razorpay, refunds), `delivery` (riders, KYC, shifts, dispatch, tasks, OTP), `realtime` (WebSockets), `notifications`, `support`, `cms`, `ops_console`, `core`, and `loadtest` (staging only).

### 1.4 Scheduled jobs
- **Orders and payments:** expire unpaid orders; sync refund status; scrub old payment data.
- **Store:** auto-accept orders and the acceptance-SLA alert.
- **Delivery:** dispatch sweep; rider heartbeat auto-offline.
- **Retention:** purge offboarded KYC; purge old rider locations; purge old notifications; sweep stuck sends.
- **Housekeeping:** flush expired tokens; clear expired sessions.

### 1.5 External services
- **Razorpay:** keys needed (D-01).
- **SMS gateway with DLT:** a provider needed (D-02).
- **Firebase FCM:** a project needed (D-19).
- **Sentry:** a DSN needed.
- **WeasyPrint:** invoice PDFs; needs Pango libraries in the image.

---

## 2. Decisions needed before starting

| # | Decision | Recommendation |
|---|---|---|
| D1 | Staging or production? | **Staging first** (`config.settings.staging`). Production after pilot and UAT. |
| D2 | Fresh DB or a copy of dev? | **Fresh DB**, plus `seed_demo` (the dev DB holds QA test data). |
| D3 | OTP login | Deployed settings refuse the console SMS backend. For staging, allow the fixed test numbers via `OTP_TEST_NUMBERS`, or use a working SMS gateway (D-02). |
| D4 | Payments | Razorpay **test keys** (D-01). Until then, COD only. |
| D5 | Server account | Retire the shared password safely. Add an **SSH key for a new `deploy` user** (in the `docker` group). Change the `superadmin` password **only if no other person or service relies on it; confirm first**. Global SSH settings stay unchanged unless the server owner approves (R8). |
| D6 | Capacity | Confirm OS, CPU, RAM and free disk. JQC needs about 2 vCPU, 4 GB RAM and 40 GB for staging, **on top of** the existing sites. |
| D7 | Offsite backups | A target for nightly DB and MinIO copies |
| D8 | Alert email | A mailbox for TLS expiry and alerts |

---

## 3. Read-only discovery (first visit, changes nothing)

Before any change, record:
- **nginx:** `nginx -v`, `nginx -T` (to learn the layout and avoid name collisions; no edits), the `sites-enabled` list.
- **Ports in use:** `ss -tlnp`.
- **Docker:** `docker --version`, `docker ps`, existing networks and volumes.
- **certbot:** installed? Which renewal timer?
- **Disk, memory, CPU:** `df -h`, `free -m`, `nproc`.
- **Firewall:** `ufw status` (read only; 80 and 443 are already open, because sites are served).
- **DNS:** confirm `jqc.jivo.in` resolves to this IP.

The findings go into a short report before anything is installed.

## 4. Repository files to add (no secrets)

`infra/deploy/` (owner: DevOps):
- **`compose.prod.yml`:** compose project `jqc`, network `jqc_net`, volumes prefixed `jqc_`, memory limits and log caps per service.
  - Services: `postgres` (postgis 16-3.4), `redis`, `minio`, `release`, `web`, `worker`, `beat`.
  - **No nginx container.**
  - Only `web` (`127.0.0.1:18001`) and MinIO's public read path (`127.0.0.1:19000`) are published, to localhost only.
- **`nginx/jqc.jivo.in.conf`:** the single site file for the host nginx. It follows rules R2 and R3, and adapts the hardening already in `infra/nginx/default.conf`:
  - per-IP rate limits with `jqc_*` zones;
  - JSON access log without query strings, written to its own file `/var/log/nginx/jqc.access.log`;
  - WebSocket upgrade for `/ws/`;
  - body-size caps;
  - `/media/` proxied to MinIO public objects only;
  - HSTS for this host only.
- **`README.md`:** install, deploy, rollback and the coexistence checklist.

## 5. Secrets and configuration (on the server only)

- `/srv/jqc/env/backend.env`, mode `600`, owned by `deploy`. Generate fresh values on the server:
  - `DJANGO_SECRET_KEY`
  - `JWT_SIGNING_KEY` (at least 50 characters, different from the secret key)
  - `OTP_HASH_KEY`
  - `FIELD_ENCRYPTION_KEYS`
  - the Postgres app password
  - the MinIO keys
- Settings:
  - `DJANGO_ALLOWED_HOSTS=jqc.jivo.in`
  - `CSRF_TRUSTED_ORIGINS=https://jqc.jivo.in`
  - `NUM_PROXIES=1` (the host nginx)
  - `STAFF_MFA_ENFORCED` stays on (the default)
- **Back up `FIELD_ENCRYPTION_KEYS` separately.** Without it, KYC and bank data can't be read.

## 6. First deployment (in order, each step reversible)

1. Create `/srv/jqc/` (compose, env, data, backups), owned by `deploy`. Nothing outside `/srv/jqc` and the one nginx file is created.
2. Install Docker if it's missing. If it's present, reuse it as is (R7).
3. Build the image from the tagged `develop` commit.
4. `docker compose -p jqc up -d postgres redis minio`, wait until they're healthy, then create the MinIO buckets.
5. Run the `release` job (`check --deploy` must pass), then `migrate` on the fresh DB, then `seed_demo` (if D2 says so).
6. `docker compose -p jqc up -d web worker beat`. Check `curl http://127.0.0.1:18001/health/ready`.
7. **nginx, carefully:**
   1. Add `jqc.jivo.in.conf` with an HTTP-only block for the ACME challenge.
   2. `nginx -t`, then `reload`.
   3. `certbot certonly --webroot -d jqc.jivo.in`.
   4. Enable the HTTPS block in the same file.
   5. `nginx -t`, then `reload`.
8. **Check the other sites:** before and after, load each existing site's home page and confirm the same HTTP status (a scripted check of every `server_name` found in discovery).

## 7. Verification

- **JQC:**
  - `https://jqc.jivo.in/health/ready` returns `{"status":"ok"}`.
  - The admin, MFA enrolment and the Ops Console work.
  - API smoke: serviceability, catalog, cart and a COD order.
  - `wss://jqc.jivo.in/ws/v1/...` connects.
  - The Celery worker and beat are alive.
  - Build the customer and rider app staging flavors against `https://jqc.jivo.in`, then run the phone tests.
- **Other sites unchanged:**
  - every pre-existing domain returns the same status as before;
  - `nginx -T` diff shows only the added JQC file;
  - the other containers' (if any) uptime is unchanged.

## 8. Backups and monitoring (JQC only)

- **Nightly `pg_dump`** with `infra/backup/backup_db.sh`, plus a MinIO mirror, run by a `deploy` user cron or systemd **user** timer. Keep 14 days locally plus an offsite copy (D7).
- **A restore test** with the guarded restore script into a `test_jivo_quick_commerce_restore*` DB inside the JQC Postgres.
- **Monitoring:**
  - Sentry;
  - an uptime check on `/health/ready`;
  - container memory and disk alerts;
  - the business alerts from `infra/monitoring/`.

## 9. Updates and rollback

- **Deploy:**
  1. Build or pull the new tag.
  2. Take an automatic pre-deploy DB dump.
  3. Run `release` (migrate).
  4. Restart `web` and `worker`. **Beat stays a singleton:** stop the old beat before starting the new one.
- **Rollback the app:** run the previous image tag. Migrations are additive, so the old code works on the new schema.
- **Remove JQC entirely:**
  1. Remove the symlink, `nginx -t`, reload.
  2. `docker compose -p jqc down`.
  3. Remove `/srv/jqc` only after a final backup.

  Other sites are unaffected at every step.

## 10. Risks

- **Shared server.** JQC load (DB, MinIO) shares CPU, RAM and disk with the existing sites. Memory limits and monitoring are mandatory. Production should later get its own server or a managed DB.
- **nginx directive collisions.** These are prevented by the `jqc_` names and `nginx -t` before every reload.
- **certbot renewals** reload nginx for all sites. That's already the case for the existing sites, and a reload is graceful.
- **WeasyPrint system libraries:** verify the image build includes them.
- **No real SMS or payments** until D-01 and D-02.

## 11. Execution order

| Step | Who | Needs approval |
|---|---|---|
| Decisions D1–D8 | Owner / Jivo | Yes |
| Section 3: read-only discovery | DevOps agent over SSH | Yes (first login to the server) |
| Section 4: `infra/deploy/` files | DevOps agent, in the repo | Code review |
| Sections 5–7: secrets, first deploy, single nginx file, TLS | DevOps agent on the server | Yes |
| Section 8: backups and monitoring | DevOps agent | Offsite target (D7) |

**Estimate:**
- About half a day once the decisions are made and discovery is clean.
- Backups and monitoring as a second step.
