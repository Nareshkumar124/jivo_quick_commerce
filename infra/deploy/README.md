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
  static/                 collectstatic output copied out of the image (nginx /static/; hashed
                          names + staticfiles.json since T-817; copied additively, never emptied)
  cache/                  755 superadmin
    nginx-media/          700 <nginx worker user>  nginx proxy_cache for /media/ (T-819, max 1 GB)
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

**Other sites on the host.** The repo keeps no fixed list: `check_sites.sh` must build its list of
`server_name`s from the current `nginx -T` on every run, because sites change without notice.
Sites seen so far (for reviewing its output, not as the source):

| Seen | `server_name` | Note |
|---|---|---|
| 2026-11-10 | `einvoice.jivo.in` | New since the first deploy; found by the 2026-11-10 update |

Add each newly seen name here. A name that appears or disappears between the before and after
runs of the same check is still a failure of step 4.

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
(D3, staging only), `S3_ENDPOINT_URL=http://minio:9000`, `S3_PRESIGN_ENDPOINT_URL=https://jqc.jivo.in`,
`S3_PUBLIC_MEDIA_DOMAIN=jqc.jivo.in/media`,
`EMAIL_BACKEND=django.core.mail.backends.dummy.EmailBackend` (no SMTP yet), `COD_UPI_QR_ENABLED=false`.
`STAFF_MFA_ENFORCED` is left at its default (on).

### FCM push key (D-19, docs/deployment.md §11.1)

The Firebase service-account JSON is **not** generated on the server; it comes from the Firebase
console (project `jivo-quick` for staging) and is copied with `scp` straight to the server, never
printed, never in an env file, compose file or the repo:

```
/etc/jqc/secrets/                         root:root 0755 (or 0711)
  fcm-service-account.json                root:999 0440  (999 = the image's `jivo` group)
/srv/jqc/compose/.env                     JQC_FCM_KEY_FILE=/etc/jqc/secrets/fcm-service-account.json
/srv/jqc/env/backend.env                  FCM_CREDENTIALS_FILE=/run/secrets/fcm-service-account.json
                                          (PUSH_BACKEND left unset: the key file selects FCM)
```

`compose.prod.yml` mounts `$JQC_FCM_KEY_FILE` read-only at `/run/secrets/fcm-service-account.json`
in `release`, `web`, `worker` and `beat` (unset: `/dev/null`, push disabled). Verify only with
`ls -l` and `sha256sum` (compare the hash with the local copy). If a new image ever changes the
`jivo` gid (`docker run --rm --entrypoint id jqc-backend:<sha>`), the key becomes unreadable and
the release check fails with `notifications.E002` before anything restarts: `chgrp` the file to
the new gid. Rotation: docs/deployment.md §11.2 (replace the file in place, roll worker, beat, web).

To read the staff password on the server without printing other values:
`sudo grep '^SEED_DEMO_STAFF_PASSWORD=' /srv/jqc/env/backend.env` (run it yourself; never paste it).

## Shipping the source from Windows (line endings)

`git archive` applies the local `core.autocrlf` to its output. On a Windows machine
(`core.autocrlf=true`, the Git for Windows default) a commit **older than the `.gitattributes`
LF rules** ships CRLF files: the Dockerfile's heredoc scripts then get a `#!/bin/sh\r` shebang and
every container fails with `exec /usr/local/bin/jqc-entrypoint: no such file or directory`
(staging, 2026-11-10). Commits that contain the rules (`Dockerfile`, `.dockerignore`, `*.py`,
`*.sh`, `infra/deploy/**`, ... are `eol=lf`) are safe either way, but always archive with
autocrlf off so that any commit, including a rollback target, ships exactly what is in git:

```bash
git -c core.autocrlf=false archive "$SHA" backend | ssh <server> "mkdir -p /srv/jqc/src/$SHA && tar -x -C /srv/jqc/src/$SHA"
# check on the server before building (prints nothing when clean):
ssh <server> "grep -lr \$'\r' /srv/jqc/src/$SHA/backend/Dockerfile /srv/jqc/src/$SHA/backend/.dockerignore"
```

From PowerShell, run the same line in Git Bash, or pipe through a file
(`git -c core.autocrlf=false archive --format=tar -o jqc-$SHA.tar $SHA backend`, then `scp` and
`tar -x` on the server): PowerShell 5.1 pipes re-encode binary output and corrupt the tar.
Copying files with `scp` from a Windows **working tree** (instead of `git archive`) has the same
CRLF problem for older commits; don't.

## First deploy (plan.md §6)

```bash
SHA=<pushed develop commit>
# 1. source of that commit only (from a machine with the repo; Windows: see above):
git -c core.autocrlf=false archive "$SHA" backend | ssh <server> "mkdir -p /srv/jqc/src/$SHA && tar -x -C /srv/jqc/src/$SHA"
# 2. image
cd /srv/jqc/src/$SHA/backend && docker build -t jqc-backend:$SHA .
# 3. infra services
cd /srv/jqc/compose && export JQC_IMAGE=jqc-backend:$SHA
docker compose -p jqc -f compose.prod.yml up -d postgres redis minio
# 4. buckets: jivo-media (private), jivo-public (anonymous s3:GetObject only), via boto3 in the image
# 5. release (check --deploy, migrate), then seed (staging)
docker compose -p jqc -f compose.prod.yml run --rm release
docker compose -p jqc -f compose.prod.yml run --rm --entrypoint python web manage.py seed_demo
# 6. static files for nginx: additive (no rm), so pages from the previous release keep their
#    content-hashed files during a roll (docs/deployment.md §9.7). The image must hold a manifest.
docker run --rm --user 0 --entrypoint sh -v /srv/jqc/static:/out jqc-backend:$SHA \
  -c 'test -s /app/staticfiles/staticfiles.json && cp -a /app/staticfiles/. /out/ && chmod -R a+rX /out'
# 7. app: two Celery workers, one per queue (`worker` -Q celery, `worker-slow` -Q slow)
docker compose -p jqc -f compose.prod.yml up -d web worker worker-slow beat
curl -fsS -H 'Host: jqc.jivo.in' http://127.0.0.1:18001/health/ready
```

nginx and TLS (coexistence checklist around each reload):

```bash
# media cache directory (T-819), once, before the first `nginx -t` with the full file. Owner = the
# `user` in the host's nginx.conf (www-data on Debian/Ubuntu, nginx on RHEL).
NGINX_USER=$(sudo nginx -T 2>/dev/null | awk '$1=="user"{gsub(";","",$2); print $2; exit}')
sudo install -d -m 755 /srv/jqc/cache
sudo install -d -m 700 -o "${NGINX_USER:-www-data}" -g "${NGINX_USER:-www-data}" /srv/jqc/cache/nginx-media
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

1. `git -c core.autocrlf=false archive` the new pushed commit (see "Shipping the source from
   Windows"), build `jqc-backend:<new>`.
2. Pre-deploy dump: `docker compose -p jqc -f compose.prod.yml exec -T postgres pg_dump -Fc -U jqc jivo_quick_commerce > /srv/jqc/backups/pre-<new>.dump`.
3. `JQC_IMAGE=jqc-backend:<new> docker compose ... run --rm release`.
   (First T-817/T-819 rollout: do the RAM and nginx connection-budget preconditions in
   docs/deployment.md §8.5 first; the nginx reload waits on the budget check.)
4. Copy static files (step 6 above, additive) **before** web rolls: the new pages name the new hashed files.
5. `docker compose ... stop beat`, then `JQC_IMAGE=jqc-backend:<new> docker compose ... up -d web worker worker-slow beat`.
6. Write the sha to `/srv/jqc/compose/DEPLOYED_SHA`.

**App rollback:** `JQC_IMAGE=jqc-backend:<previous> docker compose -p jqc -f compose.prod.yml up -d web worker worker-slow beat`
(stop beat first). Migrations are expand-only, so the old code runs on the new schema. Rolling back
to a commit before T-817 (no `slow` queue): `worker-slow` then just idles (the old code routes
nothing to `slow`); stop it with `docker compose ... stop worker-slow` if you also restore that
commit's compose file, which has no such service. The first T-817/T-819 rollout and its rollback: docs/deployment.md §8.5.

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

- **Private media links** (KYC files, invoices, support photos, exports) are presigned for
  `https://jqc.jivo.in/jivo-media/<key>?X-Amz-...` (`S3_PRESIGN_ENDPOINT_URL=https://jqc.jivo.in`).
  The site file's `location /jivo-media/` passes them unchanged to MinIO (127.0.0.1:19000) with
  `Host: jqc.jivo.in`, so MinIO checks the signature itself; GET/HEAD only, never cached, bucket
  root returns 404. Uploads and reads by the backend still go to `http://minio:9000`. No MinIO
  setting is needed (do not set `MINIO_DOMAIN`). Until a CDN or S3 exists, private files are
  served by the shared host's nginx.
- **No SMS gateway** (D-02): only the fixed OTP test numbers can log in.
- **No Razorpay keys** (D4, COD only): online payment fails; COD works.
- **No email** (dummy backend), **no Sentry**, **no backups or monitoring yet** (D7/D8, plan.md §8).
