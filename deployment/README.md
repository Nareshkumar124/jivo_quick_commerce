# JQC staging deployment: what was done (2026-11-06)

This records the first deployment of the Jivo Quick Commerce backend to the shared server, following `plan.md`.
**No secret values appear here.** The repository is public. All secrets exist only on the server, in `/srv/jqc/env/` (mode 600).

## Status at a glance

| Item | State |
|---|---|
| Backend stack running on the server (commit `72669d2`) | Done |
| Database migrated (103 migrations) and demo data seeded | Done |
| Works locally on the server (health, OTP login, home, cart, admin) | Done |
| nginx site for `jqc.jivo.in` (HTTP and HTTPS) | Done |
| HTTPS certificate for `jqc.jivo.in` | Done (2026-11-06, after the user opened port 80): see section 5 |
| Live site tested from outside (health, admin, ops, API, OTP login, WebSocket, media, TLS) | Done |
| Other websites on the server | Unchanged (checked before and after every change) |
| Backups and monitoring | Deferred (D7/D8) |

## Decisions used

| # | Decision |
|---|---|
| D1 | Staging (`config.settings.staging`) |
| D2 | Fresh database plus `seed_demo` |
| D3 | Fixed OTP test numbers allowed (staging only) |
| D4 | COD only, no Razorpay keys |
| D5 | Deployed as the existing `superadmin` account with an SSH key. No passwords, users or SSH settings were changed. |
| D7/D8 | Backups and monitoring deferred |

## 1. Discovery (read only, before any change)

- **Server:**
  - Ubuntu 24.04.4, kernel 6.14, 14 CPUs, 28 GB RAM (about 13.8 GB available).
  - 105 GB free disk. Swap was already 6.8 of 12 GB used.
- **DNS:** `jqc.jivo.in` resolves to `138.252.101.117`. The server itself sits behind NAT, on internal address 10.10.101.117.
- **Docker:** 29.2.1 and Compose v5.0.2 were already installed and were reused. Other projects run 21 containers (zammad, jivo-erp, jivo_auth, traefik, node_ci_cd_v2).
- **nginx:**
  - nginx 1.24.0 uses the `sites-available` / `sites-enabled` layout.
  - Names already used by other sites (`$connection_upgrade`, the zones `general` and `api`) were noted. All JQC names start with `jqc_` to avoid collisions.
- **Ports:** 18001 and 19000 were free, and JQC uses only those, on `127.0.0.1`.
- **certbot:** certbot 2.9.0 with the renewal timer active, and 21 existing certificates.
- **Firewall:** ufw is not installed. An upstream firewall exists (see below).
- **Other sites:** 23 hostnames were recorded with their HTTP and HTTPS status codes as a baseline.

## 2. Files added to the repository

- `infra/deploy/compose.prod.yml`: the Docker stack.
  - Project `jqc`, network `jqc_net`, volumes `jqc_*`.
  - Memory caps and log caps on every container.
  - Only web (`127.0.0.1:18001`) and MinIO (`127.0.0.1:19000`) are reachable from the host.
- `infra/deploy/nginx/jqc.jivo.in.conf`: the single nginx site file for `jqc.jivo.in`.
  - Rate limits, WebSocket support and body-size caps.
  - A JSON access log without query strings.
  - `/media/` for public product images, and HSTS for this host only.
- `infra/deploy/README.md`: install, update, rollback and the checklist for keeping other sites safe.

## 3. What was done on the server

1. **Folder.** Created `/srv/jqc/` with `compose/`, `env/` (private), `src/`, `static/`, `acme/`, `logs/` and `backups/`.
2. **Code.** Copied the backend source of the pushed commit `72669d2` with `git archive`, then built the Docker image `jqc-backend:72669d2`.
   - The first build failed: Windows line endings broke the startup scripts. It was rebuilt with `git -c core.autocrlf=false archive`, and nothing had run on the bad image.
3. **Secrets.** Generated fresh on the server, never printed or copied off it:
   - Django secret key, JWT key and OTP hash key, all different.
   - The field encryption key.
   - Database and MinIO passwords.
   - The demo staff password.

   The field encryption key is also backed up in `/srv/jqc/env/keys-backup/`. **Copy that file somewhere safe offline:** without it, rider KYC and bank data cannot be read.
4. **Infrastructure.** Started PostgreSQL 16 + PostGIS 3.4.3, Redis 7.4 and MinIO. Then created two buckets:
   - `jivo-media`: private.
   - `jivo-public`: anyone can read files, but nobody can list them.
5. **Release.** `check --deploy` passed with no issues, then all 103 migrations were applied to the fresh database.
6. **Seed.** `seed_demo` created:
   - roles and 7 staff users (`superadmin@jivo.test`, `ops@`, `store.manager@`, `store.staff@`, `catalog@`, `support@`, `finance@`);
   - the demo store GGN-01 (Gurugram), 20 products, coupons and a demo order;
   - a test rider and the test customer.
7. **App.** Copied the static files out of the image for nginx, then started `web`, `worker` and `beat`.
8. **nginx.** Installed the HTTP part of the site file, tested it with `nginx -t` and reloaded (no restart).
   - The other 23 sites returned exactly the same status codes before and after.
   - The `nginx -T` comparison shows only the new JQC file was added.
9. **HTTPS.** Tried to issue the certificate with `certbot --webroot` for `jqc.jivo.in` only. It failed; see the next section.

## 4. Verification results

- `/health/ready` returns `{"status":"ok","checks":{"database":"ok","redis":"ok"}}`.
- App config and serviceability return 200 (store GGN-01 serviceable, 14-minute ETA).
- OTP login with `+919000000001` and OTP `123456` works.
- Profile, home and cart return 200.
- The admin login page returns 200, and the Ops Console redirects to the login page.
- The Celery worker and beat are running scheduled jobs (the dispatch sweep runs every 15 seconds).
- The other websites are unchanged, and the other 21 containers were not touched.

## 5. HTTPS (done 2026-11-06)

**First attempt: blocked.** Let's Encrypt could not connect to port 80 ("Timeout during connect") because of the firewall in front of the server. Until then, `https://jqc.jivo.in` showed another site (eximbe.jivo.in). That is why `/ops/` gave a 404 and `/admin/` showed a foreign login page.

**After the user opened port 80:**
1. **Certificate.**
   - A certbot dry run passed first.
   - Then `certbot certonly --webroot -w /srv/jqc/acme -d jqc.jivo.in` issued the certificate, for `jqc.jivo.in` only, using the server's existing Let's Encrypt account.
   - The only new renewal file is `/etc/letsencrypt/renewal/jqc.jivo.in.conf` (webroot `/srv/jqc/acme`, renew hook `systemctl reload nginx`). No other certificate was touched.
2. **The certificate itself.**
   - Subject `CN=jqc.jivo.in` (SAN `jqc.jivo.in`), issued by Let's Encrypt YE1, which chains to ISRG Root X1.
   - Valid from 2026-11-06 to **2027-02-04**. The chain verifies OK.
   - It renews automatically through the existing certbot timer. `certbot renew --cert-name jqc.jivo.in --dry-run` reported "all simulated renewals succeeded". Non-interactive renew waits a random 0-8 minutes before contacting the CA; that delay is normal.
3. **nginx.**
   - Installed the full `jqc.jivo.in.conf` with the HTTPS block, ran `nginx -t`, then reloaded.
   - The `nginx -T` diff shows only added lines (the JQC HTTPS block), nothing removed.
   - All 23 other hostnames returned the same status before and after.

**Live tests from outside (2026-11-06), all passed:**

| Test | Result |
|---|---|
| `https://jqc.jivo.in/health/ready` | 200 `{"status":"ok","checks":{"database":"ok","redis":"ok"}}` |
| `http://` → `https://` | 301 |
| `/admin/login/` | 200 (login page) |
| `/admin/` and `/ops/` | 302 to `/admin/login/?next=...` (login required, as expected) |
| `/static/admin/css/base.css` | 200 |
| `/api/v1/config/app/` | 200 |
| Serviceability (Gurugram, Sector 14) | 200, serviceable, store GGN-01, 14-minute ETA |
| OTP request + verify, `+919000000001` / `123456` | 200 / 200, token issued |
| `/api/v1/me/`, `/api/v1/cart/`, `/api/v1/orders/` | 200 |
| `/api/v1/home/` (store 1) | 200, with 45 image URLs under `https://jqc.jivo.in/media/...` |
| A `/media/` image | 200 `image/webp` |
| WebSocket `wss://jqc.jivo.in/ws/v1/orders/1/` | Handshake OK. The `auth` first message got `auth.ok`, then `order.status`, then `ping` got `pong` |
| HSTS header | `max-age=31536000; includeSubDomains` |

The site is live at:
- **Admin:** https://jqc.jivo.in/admin/ (staff login, then authenticator-app setup on first login)
- **Ops Console:** https://jqc.jivo.in/ops/
- **API for the apps:** `https://jqc.jivo.in` (build the staging flavors with `--dart-define=API_BASE_URL=https://jqc.jivo.in`)

**Warning about the other sites (not changed by JQC):** these certificates expire soon. They failed to renew while port 80 was blocked, so check that they renew now that it is open:
- datasync: Nov 7
- factory: Nov 9
- hana2sheets: Nov 10
- hr and sampooran: Nov 11
- offer.jivomart.in: Nov 15

## 6. Things to know about this staging setup

- **Online payments do not work (D4).** The deploy check refuses to start without Razorpay keys, so clearly labelled fake keys are set. COD works. Replace the fake keys with real Razorpay test keys when they arrive.
- **No SMS.** Only the test numbers `+919000000001`, `…002` and `…003` (OTP `123456`) can log in.
- **No email.** Mail is discarded, including staff password-reset mail.
- **Private files (KYC, invoices) cannot be opened from outside yet.** Public product images work.
- **Staff MFA is on.** The first admin login asks you to set up an authenticator app. The staff password is stored only on the server. Read it there yourself, and never paste it anywhere: `sudo grep '^SEED_DEMO_STAFF_PASSWORD=' /srv/jqc/env/backend.env`.
- **Future deploys from Windows** must use `git -c core.autocrlf=false archive`.

## 7. How to undo it (touches only JQC)

```bash
# remove the website from nginx
sudo rm /etc/nginx/sites-enabled/jqc.jivo.in.conf && sudo nginx -t && sudo systemctl reload nginx
sudo rm /etc/nginx/sites-available/jqc.jivo.in.conf
# stop the app (keeps the data)
cd /srv/jqc/compose && JQC_IMAGE=jqc-backend:72669d2 docker compose -p jqc -f compose.prod.yml down
# delete everything, only after a final backup
docker volume rm jqc_pgdata jqc_redisdata jqc_miniodata
docker image rm jqc-backend:72669d2
sudo rm -rf /srv/jqc
```

## 8. Where things are on the server

| What | Path |
|---|---|
| Docker compose file | `/srv/jqc/compose/compose.prod.yml` |
| nginx site file | `/etc/nginx/sites-available/jqc.jivo.in.conf` (+ `sites-enabled` link) |
| Secrets (private) | `/srv/jqc/env/` |
| Encryption key backup | `/srv/jqc/env/keys-backup/` |
| Logs: build, release, seed, nginx and site checks | `/srv/jqc/logs/` |
| Static files | `/srv/jqc/static/` |
