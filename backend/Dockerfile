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
USER jivo
ENV DJANGO_SETTINGS_MODULE=config.settings.production
EXPOSE 8000
# Worker: celery -A config worker -l INFO · Beat: celery -A config beat -l INFO
CMD ["gunicorn", "config.asgi:application", "--worker-class", "uvicorn_worker.UvicornWorker", \
     "--bind", "0.0.0.0:8000", "--workers", "3", "--access-logfile", "-"]
