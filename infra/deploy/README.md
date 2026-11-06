# JQC on the shared server (`jqc.jivo.in`, staging)

The runbook is `plan.md` at the repo root; rules R1-R10 (§0) are absolute. This folder holds the
only repo files the deployment uses. **No secrets live here, ever** (the repository is public).

| File | On the server |
|---|---|
| `compose.prod.yml` | `/srv/jqc/compose/compose.prod.yml` |
| `nginx/jqc.jivo.in.conf` | `/etc/nginx/sites-available/jqc.jivo.in.conf` + symlink in `sites-enabled/` |

## Layout on the server (everything JQC owns)

```
/srv/jqc/                 755 superadmin   (nginx must traverse it for static/ and acme/)
  compose/                compose.prod.yml, the deployed commit in DEPLOYED_SHA
  env/                    700  backend.env, postgres.env, minio.env (600, generated on the server)
    keys-backup/          700  FIELD_ENCRYPTION_KEYS copies (600), one file per generation
  src/<sha>/              the backend source of that commit (git archive), the image build context
  static/                 collectstatic output copied out of the image (nginx /static/)
  acme/                   certbot --webroot for jqc.jivo.in only
  logs/                   deploy notes, nginx -T snapshots, other-site status checks
/etc/nginx/sites-available/jqc.jivo.in.conf  (+ sites-enabled symlink)
/etc/letsencrypt/{live,archive,renewal}/jqc.jivo.in*   (certbot, webroot, deploy hook = reload)
Docker: project jqc, network jqc_net, volumes jqc_pgdata / jqc_redisdata / jqc_miniodata,
        image jqc-backend:<sha>. Published: 127.0.0.1:18001 (web), 127.0.0.1:19000 (MinIO API).
```

`superadmin` owns everything (decision D5: no new users yet). Nothing else on the host is changed.

## Coexistence checklist (every nginx change)

1. `sudo nginx -T > /srv/jqc/logs/nginxT-before-<ts>.txt` and record every other `server_name`'s
   HTTP and HTTPS status (`/srv/jqc/logs/check_sites.sh`, which curls each name through the local nginx).
2. Change only `jqc.jivo.in.conf`. Then `sudo nginx -t`; on failure remove our symlink and stop.
3. `sudo systemctl reload nginx` (never `restart`).
4. Re-run `check_sites.sh` and diff against the baseline. **Any difference: remove our symlink,
   `nginx -t`, reload, report.**
5. `nginx -T` diff must show only our file.

## Secrets (generated on the server, never printed)

Generated once by a script run on the server that writes `env/backend.env`, `env/postgres.env`
and `env/minio.env` with `umask 077` (mode 600): `DJANGO_SECRET_KEY`, `JWT_SIGNING_KEY`,
`OTP_HASH_KEY` (all different), `FIELD_ENCRYPTION_KEYS` (a Fernet key), the Postgres password, the
MinIO root keys and `SEED_DEMO_STAFF_PASSWORD`. Values come from Python's `secrets` module and are
never echoed. `FIELD_ENCRYPTION_KEYS` is also copied to `env/keys-backup/` (600): **without it,
rider KYC and bank numbers cannot be read.** Copy that file offsite by hand (D7).

Staging values (non-secret): `DJANGO_SETTINGS_MODULE=config.settings.staging`,
`DJANGO_ALLOWED_HOSTS=jqc.jivo.in`, `DJANGO_CSRF_TRUSTED_ORIGINS=https://jqc.jivo.in`,
`NUM_PROXIES=1`, `OTP_TEST_NUMBERS=+919000000001:123456,+919000000002:123456,+919000000003:123456`
(D3, staging only), `S3_ENDPOINT_URL=http://minio:9000`, `S3_PUBLIC_MEDIA_DOMAIN=jqc.jivo.in/media`,
`EMAIL_BACKEND=django.core.mail.backends.dummy.EmailBackend` (no SMTP yet), `COD_UPI_QR_ENABLED=false`.
`STAFF_MFA_ENFORCED` is left at its default (on).

To read the staff password on the server without printing other values:
`sudo grep '^SEED_DEMO_STAFF_PASSWORD=' /srv/jqc/env/backend.env` (run it yourself; never paste it).

## First deploy (plan.md §6)

```bash
SHA=<pushed develop commit>
# 1. source of that commit only (from a machine with the repo):
git archive "$SHA" backend | ssh <server> "mkdir -p /srv/jqc/src/$SHA && tar -x -C /srv/jqc/src/$SHA"
# 2. image
cd /srv/jqc/src/$SHA/backend && docker build -t jqc-backend:$SHA .
# 3. infra services
cd /srv/jqc/compose && export JQC_IMAGE=jqc-backend:$SHA
docker compose -p jqc -f compose.prod.yml up -d postgres redis minio
# 4. buckets: jivo-media (private), jivo-public (anonymous s3:GetObject only), via boto3 in the image
# 5. release (check --deploy, migrate), then seed (staging)
docker compose -p jqc -f compose.prod.yml run --rm release
docker compose -p jqc -f compose.prod.yml run --rm --entrypoint python web manage.py seed_demo
# 6. static files for nginx
docker run --rm --user 0 --entrypoint sh -v /srv/jqc/static:/out jqc-backend:$SHA \
  -c 'rm -rf /out/* && cp -a /app/staticfiles/. /out/ && chmod -R a+rX /out'
# 7. app
docker compose -p jqc -f compose.prod.yml up -d web worker beat
curl -fsS -H 'Host: jqc.jivo.in' http://127.0.0.1:18001/health/ready
```

nginx and TLS (coexistence checklist around each reload):

```bash
# HTTP-only bootstrap: our file without the HTTPS server block
sed '/^# BEGIN JQC HTTPS/,/^# END JQC HTTPS/d' jqc.jivo.in.conf | sudo tee /etc/nginx/sites-available/jqc.jivo.in.conf >/dev/null
sudo ln -s /etc/nginx/sites-available/jqc.jivo.in.conf /etc/nginx/sites-enabled/jqc.jivo.in.conf
sudo nginx -t && sudo systemctl reload nginx
sudo certbot certonly --webroot -w /srv/jqc/acme -d jqc.jivo.in --non-interactive --agree-tos \
  --deploy-hook 'systemctl reload nginx'
# full file
sudo install -m 644 jqc.jivo.in.conf /etc/nginx/sites-available/jqc.jivo.in.conf
sudo nginx -t && sudo systemctl reload nginx
```

## Update (plan.md §9)

1. `git archive` the new pushed commit, build `jqc-backend:<new>`.
2. Pre-deploy dump: `docker compose -p jqc -f compose.prod.yml exec -T postgres pg_dump -Fc -U jqc jivo_quick_commerce > /srv/jqc/backups/pre-<new>.dump`.
3. `JQC_IMAGE=jqc-backend:<new> docker compose ... run --rm release`.
4. Copy static files (step 6 above).
5. `docker compose ... stop beat`, then `JQC_IMAGE=jqc-backend:<new> docker compose ... up -d web worker beat`.
6. Write the sha to `/srv/jqc/compose/DEPLOYED_SHA`.

**App rollback:** `JQC_IMAGE=jqc-backend:<previous> docker compose -p jqc -f compose.prod.yml up -d web worker beat`
(stop beat first). Migrations are expand-only, so the old code runs on the new schema.

## Remove JQC entirely (R10)

```bash
sudo rm /etc/nginx/sites-enabled/jqc.jivo.in.conf && sudo nginx -t && sudo systemctl reload nginx
cd /srv/jqc/compose && JQC_IMAGE=x docker compose -p jqc -f compose.prod.yml down      # keeps volumes
# only after a final backup:
#   docker volume rm jqc_pgdata jqc_redisdata jqc_miniodata; docker image rm jqc-backend:<sha>
#   sudo certbot delete --cert-name jqc.jivo.in; sudo rm /etc/nginx/sites-available/jqc.jivo.in.conf
#   sudo rm -rf /srv/jqc
```

Never `docker system prune`, never touch other containers, never edit `/etc/docker/daemon.json`.

## Known staging limits

- **Private media links** (KYC files, invoices) are presigned against `http://minio:9000`, which is
  not reachable from outside. Public catalog images work through `/media/`. Fix later with S3 or a
  public MinIO endpoint for presigning.
- **No SMS gateway** (D-02): only the fixed OTP test numbers can log in.
- **No Razorpay keys** (D4, COD only): online payment fails; COD works.
- **No email** (dummy backend), **no Sentry**, **no backups or monitoring yet** (D7/D8, plan.md §8).
