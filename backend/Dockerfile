# syntax=docker/dockerfile:1.7
# Jivo Quick Commerce backend. One image for the web (ASGI), worker (Celery) and beat processes.
#
#   docker build --target dev -t jivoqc-backend:dev backend/        # used by infra/docker-compose.yml
#   docker build -t jivoqc-backend backend/                          # production (default target)

ARG PYTHON_VERSION=3.13
ARG UV_VERSION=0.11.26

FROM ghcr.io/astral-sh/uv:${UV_VERSION} AS uv

# --------------------------------------------------------------------------- base
FROM python:${PYTHON_VERSION}-slim-trixie AS base

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    UV_COMPILE_BYTECODE=1 \
    UV_LINK_MODE=copy \
    UV_PYTHON_DOWNLOADS=never \
    UV_PROJECT_ENVIRONMENT=/opt/venv \
    PATH="/opt/venv/bin:${PATH}"

# - GDAL, GEOS, PROJ: GeoDjango (Phase 2 switches the DB engine to PostGIS). Installed now so the
#   image is ready; the build fails if the shared libraries are missing.
# - Pango / HarfBuzz / fonts: WeasyPrint GST invoices (Phase 4).
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        gdal-bin binutils \
        libpango-1.0-0 libpangoft2-1.0-0 libharfbuzz-subset0 fonts-dejavu-core \
    && rm -rf /var/lib/apt/lists/* \
    && ldconfig -p | grep -q 'libgdal\.so' \
    && ldconfig -p | grep -q 'libgeos_c\.so' \
    && ldconfig -p | grep -q 'libproj\.so'

COPY --from=uv /uv /uvx /bin/
WORKDIR /app

# --------------------------------------------------------------------------- dev
# Local compose target: dev dependencies included; the source is bind-mounted over /app.
FROM base AS dev
COPY pyproject.toml uv.lock .python-version ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-install-project
COPY . .
EXPOSE 8000
CMD ["python", "manage.py", "runserver", "0.0.0.0:8000"]

# --------------------------------------------------------------------------- production
FROM base AS production
COPY pyproject.toml uv.lock .python-version ./
RUN --mount=type=cache,target=/root/.cache/uv uv sync --frozen --no-dev --no-install-project
COPY . .
# collectstatic needs importable settings, not a database: placeholder values, build-time only.
RUN DJANGO_SETTINGS_MODULE=config.settings.local \
    DJANGO_SECRET_KEY=collectstatic-build-only \
    POSTGRES_HOST=unused POSTGRES_DB=unused POSTGRES_USER=unused POSTGRES_PASSWORD=unused \
    python manage.py collectstatic --noinput \
    && python -c "import weasyprint" \
    && useradd --system --uid 10001 --no-create-home jivo

# ASGI worker for gunicorn (P8 OWASP L5, L8). gunicorn's command line cannot reach uvicorn's own
# settings, so this small subclass sets them:
# - ws_max_size: the largest WebSocket message accepted (uvicorn's default is 16 MiB). Our messages
#   are small JSON (auth, location pings); WS_MAX_MESSAGE_BYTES overrides the 64 KiB default.
# - access_log off: uvicorn's access line holds the full request line, query string included
#   (serviceability lat/lng). The edge (nginx or the load balancer) writes the access log without
#   query strings (infra/nginx/default.conf, docs/deployment.md §9).
COPY <<'PYEOF' /opt/jqc/jqc_asgi_worker.py
import os

from uvicorn_worker import UvicornWorker


class JqcUvicornWorker(UvicornWorker):
    CONFIG_KWARGS = {
        "loop": "auto",
        "http": "auto",
        "ws_max_size": int(os.environ.get("WS_MAX_MESSAGE_BYTES", "65536")),
        "access_log": False,
    }
PYEOF

# Startup guard (P8 OWASP M8): every web, worker and beat container runs the deploy checks against
# its REAL environment before it starts, so accounts.E003 (console SMS backend), payments.E001/E004
# (fake gateway), delivery.E001 (field encryption keys), notifications.E001 (dev push backend) and
# the other errors stop a misconfigured release, instead of only passing CI with placeholders.
# ERROR level: deploy warnings are printed but do not block.
# JQC_SKIP_STARTUP_CHECK=1 is for local/dev settings only (with a loud warning). Under the staging,
# production or deployed settings it is REFUSED for every command (gunicorn, uvicorn, celery,
# jqc-release, anything): a skipped check must never reach a deployed service. Break-glass in an
# incident is an explicit `--entrypoint python` override, which leaves an audit trail in the
# orchestrator. Tested by infra/scripts/test_entrypoint.sh (CI: infra.yml).
COPY --chmod=0755 <<'SHEOF' /usr/local/bin/jqc-entrypoint
#!/bin/sh
set -eu
settings="${DJANGO_SETTINGS_MODULE:-}"
case "$settings" in
    config.settings.production|config.settings.staging|config.settings.deployed) deployed=1 ;;
    *) deployed=0 ;;
esac
if [ "${JQC_SKIP_STARTUP_CHECK:-0}" = "1" ]; then
    if [ "$deployed" = "1" ]; then
        echo "jqc-entrypoint: ERROR: JQC_SKIP_STARTUP_CHECK=1 is refused under $settings (command: ${1:-none}). Remove it; deploy checks always run in staging and production." >&2
        exit 64
    fi
    echo "jqc-entrypoint: WARNING: JQC_SKIP_STARTUP_CHECK=1: deploy checks SKIPPED under '${settings:-unset}'. Local/dev only." >&2
else
    python /app/manage.py check --deploy --fail-level ERROR
fi
exec "$@"
SHEOF

# Release step: a one-off task, run once per deploy before the new web/worker/beat start
# (docs/deployment.md §8). The same checks, then migrations (expand-only, backward compatible).
COPY --chmod=0755 <<'SHEOF' /usr/local/bin/jqc-release
#!/bin/sh
set -eu
cd /app
python manage.py check --deploy --fail-level ERROR
python manage.py migrate --noinput
SHEOF

USER jivo
ENV DJANGO_SETTINGS_MODULE=config.settings.production \
    PYTHONPATH=/opt/jqc
EXPOSE 8000
ENTRYPOINT ["/usr/local/bin/jqc-entrypoint"]
# Same image, other commands (docs/deployment.md §4):
#   release: jqc-release                                 (one-off task, once per deploy)
#   worker:  celery -A config worker -l INFO             (POSTGRES_CONN_MAX_AGE=60)
#   beat:    celery -A config beat -l INFO --scheduler django_celery_beat.schedulers:DatabaseScheduler
#            exactly one replica per environment
# Web: set POSTGRES_POOL=true (T-218). No app-server access log (see jqc_asgi_worker above).
# --no-control-socket: gunicorn >= 25.1 opens a control socket for `gunicornc` at
# $XDG_RUNTIME_DIR/gunicorn.ctl, else $HOME/.gunicorn/gunicorn.ctl. The `jivo` user has no home
# directory, so startup logged "Control server error: Permission denied". A container does not
# need it (the orchestrator scales and restarts). Keep the flag on every command override
# (infra/deploy/compose.prod.yml).
CMD ["gunicorn", "config.asgi:application", "--worker-class", "jqc_asgi_worker.JqcUvicornWorker", \
     "--bind", "0.0.0.0:8000", "--workers", "3", "--graceful-timeout", "30", "--no-control-socket"]
