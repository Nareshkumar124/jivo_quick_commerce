"""Settings shared by every environment.

Environment modules (local, test, staging, production) import everything from here and override
what differs. Every value that changes between environments is read from an environment variable;
see ``infra/env/backend.env.example`` for the full list.
"""

from datetime import timedelta
from pathlib import Path

from celery.schedules import crontab

from config.env import env_bool, env_dict, env_int, env_list, env_str, load_env_file

BASE_DIR = Path(__file__).resolve().parent.parent.parent  # backend/

# Local development reads backend/.env (gitignored). Real environment variables take precedence.
load_env_file(BASE_DIR / ".env")

# One of: local, test, staging, production. Each environment module sets it.
APP_ENVIRONMENT = "base"

# --------------------------------------------------------------------------- core
# Empty here on purpose: local/test supply a development key, production requires one.
SECRET_KEY = env_str("DJANGO_SECRET_KEY", default="")
DEBUG = False
ALLOWED_HOSTS: list[str] = env_list("DJANGO_ALLOWED_HOSTS", default=[])
CSRF_TRUSTED_ORIGINS: list[str] = env_list("DJANGO_CSRF_TRUSTED_ORIGINS", default=[])

INSTALLED_APPS = [
    # `daphne` first: it makes `runserver` an ASGI server, so Channels works in local dev.
    "daphne",
    # `unfold` must come before django.contrib.admin.
    "unfold",
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # NOTE: no `django.contrib.gis` yet. The PostgreSQL server has no PostGIS; Phase 2 adds it.
    # Third party
    "rest_framework",
    "rest_framework_simplejwt.token_blacklist",
    "django_filters",
    "drf_spectacular",
    "channels",
    "django_celery_beat",
    "storages",
    "import_export",
    "simple_history",
    "axes",
    # Project apps
    "apps.core",
    "apps.accounts",
    "apps.cms",
    "apps.notifications",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "django.contrib.messages.middleware.MessageMiddleware",
    "django.middleware.clickjacking.XFrameOptionsMiddleware",
    "simple_history.middleware.HistoryRequestMiddleware",
    "apps.core.middleware.client_info_middleware",
    "apps.cms.middleware.app_guard_middleware",  # 426 force update / 503 maintenance
    # Last, per django-axes: locks out repeated failed staff logins.
    "axes.middleware.AxesMiddleware",
]

ROOT_URLCONF = "config.urls"
WSGI_APPLICATION = "config.wsgi.application"
ASGI_APPLICATION = "config.asgi.application"

TEMPLATES = [
    {
        "BACKEND": "django.template.backends.django.DjangoTemplates",
        "DIRS": [BASE_DIR / "templates"],
        "APP_DIRS": True,
        "OPTIONS": {
            "context_processors": [
                "django.template.context_processors.request",
                "django.contrib.auth.context_processors.auth",
                "django.contrib.messages.context_processors.messages",
            ],
        },
    },
]

# --------------------------------------------------------------------------- database
# Built from separate variables (never a DATABASE_URL: passwords may contain URL-reserved chars).
# Phase 0 uses the plain PostgreSQL engine because the server has no PostGIS yet. Phase 2 switches
# ENGINE to "django.contrib.gis.db.backends.postgis" once PostGIS is installed on the server.
DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": env_str("POSTGRES_DB"),
        "USER": env_str("POSTGRES_USER"),
        "PASSWORD": env_str("POSTGRES_PASSWORD"),
        "HOST": env_str("POSTGRES_HOST"),
        "PORT": env_str("POSTGRES_PORT", default="5432"),
        # The web process is ASGI: Django recommends no persistent connections there.
        "CONN_MAX_AGE": env_int("POSTGRES_CONN_MAX_AGE", default=0),
        "CONN_HEALTH_CHECKS": True,
        "OPTIONS": {
            "connect_timeout": env_int("POSTGRES_CONNECT_TIMEOUT", default=5),
            "sslmode": env_str("POSTGRES_SSLMODE", default="prefer"),
        },
        # Hard-set: pytest may only ever create/drop this database on the shared server.
        "TEST": {"NAME": "test_jivo_quick_commerce"},
    }
}
DEFAULT_AUTO_FIELD = "django.db.models.BigAutoField"

# --------------------------------------------------------------------------- auth
AUTH_USER_MODEL = "accounts.User"
AUTH_PASSWORD_VALIDATORS = [
    {"NAME": "django.contrib.auth.password_validation.UserAttributeSimilarityValidator"},
    {
        "NAME": "django.contrib.auth.password_validation.MinimumLengthValidator",
        "OPTIONS": {"min_length": 10},
    },
    {"NAME": "django.contrib.auth.password_validation.CommonPasswordValidator"},
    {"NAME": "django.contrib.auth.password_validation.NumericPasswordValidator"},
]
# Staff use Django session login until Jivo Auth (D-04). User.auth_id is reserved for that.
SESSION_COOKIE_AGE = env_int("DJANGO_SESSION_COOKIE_AGE", default=60 * 60 * 12)
AUTHENTICATION_BACKENDS = [
    "axes.backends.AxesStandaloneBackend",  # must be first
    "django.contrib.auth.backends.ModelBackend",
]

# Staff login throttling (09 §3.1, django-axes): lock a username+IP pair after N failures.
AXES_FAILURE_LIMIT = env_int("AXES_FAILURE_LIMIT", default=5)
AXES_COOLOFF_TIME = timedelta(minutes=env_int("AXES_COOLOFF_MINUTES", default=15))
AXES_LOCKOUT_PARAMETERS = [["username", "ip_address"]]
AXES_RESET_ON_SUCCESS = True
AXES_CLIENT_IP_CALLABLE = "apps.core.net.client_ip"
# The admin form posts `username` (axes would default to USERNAME_FIELD, "email"); normalised so
# every spelling of one email shares a failure counter.
AXES_USERNAME_FORM_FIELD = "username"
AXES_USERNAME_CALLABLE = "apps.accounts.authentication.axes_username"

# Trusted reverse proxies in front of Django (nginx / load balancer): client IPs are then read
# from X-Forwarded-For for OTP limits, DRF throttles and axes. 0 locally.
NUM_PROXIES = env_int("NUM_PROXIES", default=0)

# --------------------------------------------------------------------------- i18n / time
LANGUAGE_CODE = "en-us"
# Stored and sent in UTC (02 §5). The apps convert to IST for display.
TIME_ZONE = "UTC"
USE_I18N = True
USE_TZ = True

# --------------------------------------------------------------------------- static / media
STATIC_URL = "/static/"
STATIC_ROOT = BASE_DIR / "staticfiles"
STATICFILES_DIRS = [BASE_DIR / "static"]

# Object storage: MinIO locally, S3 in the cloud (django-storages). Private/public bucket split
# (KYC documents, invoices, product images) is added in Phases 2, 4 and 5.
S3_ENDPOINT_URL = env_str("S3_ENDPOINT_URL", default="") or None
STORAGES = {
    "default": {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {
            "bucket_name": env_str("S3_MEDIA_BUCKET", default="jivo-media"),
            "endpoint_url": S3_ENDPOINT_URL,
            "access_key": env_str("S3_ACCESS_KEY_ID", default="") or None,
            "secret_key": env_str("S3_SECRET_ACCESS_KEY", default="") or None,
            "region_name": env_str("S3_REGION", default="ap-south-1"),
            "addressing_style": "path" if S3_ENDPOINT_URL else "auto",
            "default_acl": None,
            "file_overwrite": False,
            "querystring_auth": True,
        },
    },
    "staticfiles": {"BACKEND": "django.contrib.staticfiles.storage.StaticFilesStorage"},
}

# --------------------------------------------------------------------------- redis
# Port 6380 is this project's Redis (infra/docker-compose.yml). Separate DB numbers per use.
REDIS_URL = env_str("REDIS_URL", default="redis://localhost:6380/0")
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.redis.RedisCache",
        "LOCATION": REDIS_URL,
        "KEY_PREFIX": "jqc",
        "TIMEOUT": 300,
        "OPTIONS": {"socket_connect_timeout": 2, "socket_timeout": 2},
    }
}

# --------------------------------------------------------------------------- channels
CHANNELS_REDIS_URL = env_str("CHANNELS_REDIS_URL", default="redis://localhost:6380/2")
CHANNEL_LAYERS = {
    "default": {
        "BACKEND": "channels_redis.core.RedisChannelLayer",
        "CONFIG": {"hosts": [CHANNELS_REDIS_URL], "prefix": "jqc-asgi"},
    }
}

# --------------------------------------------------------------------------- celery
CELERY_BROKER_URL = env_str("CELERY_BROKER_URL", default="redis://localhost:6380/1")
CELERY_BROKER_CONNECTION_RETRY_ON_STARTUP = True
CELERY_BROKER_TRANSPORT_OPTIONS = {"visibility_timeout": 60 * 60}
CELERY_TASK_IGNORE_RESULT = True
CELERY_TASK_ACKS_LATE = True  # tasks are idempotent, so redelivery after a crash is safe
CELERY_TASK_REJECT_ON_WORKER_LOST = True
CELERY_WORKER_PREFETCH_MULTIPLIER = 1
CELERY_TASK_TIME_LIMIT = 5 * 60
CELERY_TASK_SOFT_TIME_LIMIT = 4 * 60
CELERY_TIMEZONE = "UTC"
CELERY_BEAT_SCHEDULER = "django_celery_beat.schedulers:DatabaseScheduler"
# Synced into django-celery-beat's tables when beat starts. Times are UTC (21:30 = 03:00 IST).
CELERY_BEAT_SCHEDULE = {
    "anonymise-deleted-accounts": {
        "task": "accounts.anonymise_deleted_accounts",
        "schedule": crontab(hour=21, minute=30),
    },
    "purge-old-otp-requests": {
        "task": "accounts.purge_old_otp_requests",
        "schedule": crontab(hour=21, minute=45),
    },
}

# --------------------------------------------------------------------------- email
EMAIL_BACKEND = env_str("EMAIL_BACKEND", default="django.core.mail.backends.smtp.EmailBackend")
EMAIL_HOST = env_str("EMAIL_HOST", default="localhost")
EMAIL_PORT = env_int("EMAIL_PORT", default=1025)
EMAIL_HOST_USER = env_str("EMAIL_HOST_USER", default="")
EMAIL_HOST_PASSWORD = env_str("EMAIL_HOST_PASSWORD", default="")
EMAIL_USE_TLS = env_bool("EMAIL_USE_TLS", default=False)
DEFAULT_FROM_EMAIL = env_str(
    "DEFAULT_FROM_EMAIL", default="Jivo Quick Commerce <noreply@localhost>"
)

# --------------------------------------------------------------------------- DRF
REST_FRAMEWORK = {
    # The app API is token-only (JWT). Staff use Django session views (admin, Ops Console) and
    # the schema/docs views, which also accept sessions (SERVE_AUTHENTICATION below).
    "DEFAULT_AUTHENTICATION_CLASSES": [
        "apps.accounts.authentication.JWTAuthentication",
    ],
    "NUM_PROXIES": NUM_PROXIES or None,
    # Secure by default: public endpoints opt in with AllowAny.
    "DEFAULT_PERMISSION_CLASSES": ["rest_framework.permissions.IsAuthenticated"],
    "DEFAULT_RENDERER_CLASSES": ["rest_framework.renderers.JSONRenderer"],
    "DEFAULT_PARSER_CLASSES": ["rest_framework.parsers.JSONParser"],
    "DEFAULT_PAGINATION_CLASS": "apps.core.pagination.StandardPagination",
    "PAGE_SIZE": 20,
    "DEFAULT_FILTER_BACKENDS": ["django_filters.rest_framework.DjangoFilterBackend"],
    "DEFAULT_SCHEMA_CLASS": "drf_spectacular.openapi.AutoSchema",
    "EXCEPTION_HANDLER": "apps.core.exceptions.exception_handler",
    "COERCE_DECIMAL_TO_STRING": True,
    "TEST_REQUEST_DEFAULT_FORMAT": "json",
}

# 02 §5: access 15 min, refresh 30 days, rotating; old refresh tokens blacklisted.
# Signs with SECRET_KEY unless JWT_SIGNING_KEY is set (production sets it explicitly).
SIMPLE_JWT = {
    "ACCESS_TOKEN_LIFETIME": timedelta(minutes=15),
    "REFRESH_TOKEN_LIFETIME": timedelta(days=30),
    "ROTATE_REFRESH_TOKENS": True,
    "BLACKLIST_AFTER_ROTATION": True,
    "UPDATE_LAST_LOGIN": False,
    "ALGORITHM": "HS256",
    "AUTH_HEADER_TYPES": ("Bearer",),
    "USER_ID_FIELD": "id",
    "USER_ID_CLAIM": "user_id",
    # Refresh is refused for blocked or deleted accounts.
    "USER_AUTHENTICATION_RULE": "apps.accounts.authentication.user_can_authenticate",
}

# --------------------------------------------------------------------------- OTP (09 §3.1)
OTP_TTL_SECONDS = 5 * 60
OTP_MAX_ATTEMPTS = 5
OTP_RESEND_AFTER_SECONDS = 30
OTP_SEND_LIMIT_PER_10_MIN = env_int("OTP_SEND_LIMIT_PER_10_MIN", default=3)
OTP_SEND_LIMIT_PER_DAY = env_int("OTP_SEND_LIMIT_PER_DAY", default=10)
OTP_SEND_LIMIT_PER_IP_PER_HOUR = env_int("OTP_SEND_LIMIT_PER_IP_PER_HOUR", default=30)
OTP_VERIFY_LIMIT_PER_IP_PER_HOUR = env_int("OTP_VERIFY_LIMIT_PER_IP_PER_HOUR", default=60)
OTP_RETENTION_DAYS = 30  # 07 §4
# D-15: phone -> fixed 6-digit code, no SMS and no send limits. Never in production.
# Env format: "+919000000001:123456,+919000000002:123456". local.py has defaults.
OTP_TEST_NUMBERS: dict[str, str] = env_dict("OTP_TEST_NUMBERS", default={})

# --------------------------------------------------------------------------- SMS (D-02)
SMS_BACKEND = env_str("SMS_BACKEND", default="apps.notifications.sms.ConsoleSmsBackend")
SMS_SENDER_ID = env_str("SMS_SENDER_ID", default="")
SMS_OTP_DLT_TEMPLATE_ID = env_str("SMS_OTP_DLT_TEMPLATE_ID", default="")
# Must match the DLT-registered template text exactly. {app_hash} is the Android SMS Retriever
# hash of the app that asked (blank if unset).
SMS_OTP_TEMPLATE = env_str(
    "SMS_OTP_TEMPLATE",
    default="<#> {otp} is your Jivo verification code. It expires in 5 minutes. "
    "Do not share it with anyone. {app_hash}",
)
SMS_RETRIEVER_APP_HASHES = {
    "customer": env_str("SMS_APP_HASH_CUSTOMER", default=""),
    "rider": env_str("SMS_APP_HASH_RIDER", default=""),
}

# --------------------------------------------------------------------------- account deletion
ACCOUNT_DELETION_GRACE_DAYS = env_int("ACCOUNT_DELETION_GRACE_DAYS", default=30)  # 07 §4

# --------------------------------------------------------------------------- OpenAPI
# /api/schema/ and /api/docs/ are public only where API_DOCS_PUBLIC is true (local); staff-only
# elsewhere (02 §5). The committed contract is backend/openapi/schema.yaml.
API_DOCS_PUBLIC = env_bool("API_DOCS_PUBLIC", default=False)
SPECTACULAR_SETTINGS = {
    "TITLE": "Jivo Quick Commerce API",
    "DESCRIPTION": (
        "REST API for the Jivo customer and rider apps.\n\n"
        "Conventions (docs/02-system-architecture.md §5): JSON with snake_case keys; money as "
        "2-decimal strings; times in UTC ISO 8601; pagination with `page`/`page_size` "
        "(default 20, max 100). Apps send `X-App-Name`, `X-App-Version` and `X-Platform` on "
        "every request. Errors use the envelope "
        '`{"error": {"code", "message", "details"}}` (see the `ErrorEnvelope` schema).'
    ),
    "VERSION": "0.1.0",
    "SERVE_INCLUDE_SCHEMA": False,
    "SERVE_PERMISSIONS": ["apps.core.permissions.ApiDocsPermission"],
    # JWT first so anonymous requests get 401 (with WWW-Authenticate), not 403.
    "SERVE_AUTHENTICATION": [
        "apps.accounts.authentication.JWTAuthentication",
        "rest_framework.authentication.SessionAuthentication",
    ],
    # Separate request/response components: better generated clients (read-only fields etc.).
    "COMPONENT_SPLIT_REQUEST": True,
    "SCHEMA_PATH_PREFIX": r"/api/v[0-9]+",
    "ENUM_NAME_OVERRIDES": {
        "ErrorCodeEnum": "apps.core.errors.ErrorCode",
        "HealthStatusEnum": "apps.core.serializers.HealthStatus",
        "HealthCheckStatusEnum": "apps.core.serializers.HealthCheckStatus",
        "AppEnum": "apps.accounts.choices.AppName",
        "PlatformEnum": "apps.accounts.choices.Platform",
        "OtpPurposeEnum": "apps.accounts.choices.OtpPurpose",
        "RiderStatusEnum": "apps.accounts.choices.RiderStatus",
        "AddressLabelEnum": "apps.accounts.choices.AddressLabel",
    },
    "TAGS": [
        {"name": "health", "description": "Liveness and readiness probes. No authentication."},
        {"name": "auth", "description": "Phone OTP sign-in, token refresh, logout (06 §2.1)."},
        {"name": "account", "description": "Profile, push devices, account deletion (06 §2.1)."},
        {"name": "addresses", "description": "Saved delivery addresses (06 §2.2)."},
        {"name": "config", "description": "App configuration: versions, maintenance, contacts."},
    ],
    "SWAGGER_UI_SETTINGS": {"persistAuthorization": True, "displayOperationId": True},
}

# --------------------------------------------------------------------------- admin (unfold)
UNFOLD = {
    "SITE_TITLE": "Jivo Admin",
    "SITE_HEADER": "Jivo Quick Commerce",
    "SITE_SYMBOL": "local_shipping",
    "ENVIRONMENT": "apps.core.admin.environment_callback",
    "SHOW_HISTORY": True,
}

# --------------------------------------------------------------------------- project flags
# `manage.py seed_demo` is refused where this is False (production).
SEED_DEMO_ALLOWED = env_bool("SEED_DEMO_ALLOWED", default=True)

# --------------------------------------------------------------------------- logging
LOG_LEVEL = env_str("LOG_LEVEL", default="INFO")
LOGGING = {
    "version": 1,
    "disable_existing_loggers": False,
    "formatters": {
        "plain": {"format": "%(asctime)s %(levelname)s %(name)s %(message)s"},
    },
    "handlers": {
        "console": {"class": "logging.StreamHandler", "formatter": "plain"},
    },
    "root": {"handlers": ["console"], "level": LOG_LEVEL},
    "loggers": {
        "django.db.backends": {"level": "WARNING"},
    },
}
