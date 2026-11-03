"""Settings shared by every environment.

Environment modules (local, test, staging, production) import everything from here and override
what differs. Every value that changes between environments is read from an environment variable;
see ``infra/env/backend.env.example`` for the full list.
"""

from datetime import timedelta
from decimal import Decimal
from pathlib import Path

from celery.schedules import crontab

from config.env import (
    env_bool,
    env_dict,
    env_float,
    env_int,
    env_list,
    env_str,
    env_test_database_name,
    load_env_file,
)

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
    # `unfold` (and its contrib apps) must come before django.contrib.admin.
    "unfold",
    "unfold.contrib.import_export",  # unfold-styled import/export screens (admin)
    "unfold.contrib.simple_history",  # unfold-styled history screens (admin)
    "django.contrib.admin",
    "django.contrib.auth",
    "django.contrib.contenttypes",
    "django.contrib.sessions",
    "django.contrib.messages",
    "django.contrib.staticfiles",
    # GeoDjango (Phase 2): PostGIS on the server, GDAL/GEOS on the host and in the Docker image.
    "django.contrib.gis",
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
    "apps.stores",
    "apps.catalog",
    "apps.inventory",
    "apps.promotions",
    "apps.cart",
    "apps.orders",
    "apps.payments",
    "apps.ops_console",
]

MIDDLEWARE = [
    "django.middleware.security.SecurityMiddleware",
    "django.contrib.sessions.middleware.SessionMiddleware",
    "django.middleware.common.CommonMiddleware",
    "django.middleware.csrf.CsrfViewMiddleware",
    "django.contrib.auth.middleware.AuthenticationMiddleware",
    "apps.accounts.middleware.staff_session_policy_middleware",  # 05 §5 staff session limits
    "apps.core.middleware.staff_timezone_middleware",  # staff panel in IST, storage UTC
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
# The only database tests may create or drop (the server is shared): POSTGRES_TEST_DB, default
# `test_jivo_quick_commerce`. Any name not starting with that is refused at settings load.
TEST_DATABASE_NAME = env_test_database_name()

# Built from separate variables (never a DATABASE_URL: passwords may contain URL-reserved chars).
# PostGIS since Phase 2 (serviceability, distances). Migrating a test database runs
# `CREATE EXTENSION IF NOT EXISTS postgis` (the DB user is allowed to); never run it by hand.
DATABASES = {
    "default": {
        "ENGINE": "django.contrib.gis.db.backends.postgis",
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
            # The DB is remote: detect a dropped connection (network blip, NAT timeout) within
            # about a minute instead of waiting forever for a reply that will never come.
            "keepalives": 1,
            "keepalives_idle": env_int("POSTGRES_KEEPALIVES_IDLE", default=30),
            "keepalives_interval": 10,
            "keepalives_count": 3,
            "tcp_user_timeout": env_int("POSTGRES_TCP_USER_TIMEOUT_MS", default=60_000),
        },
        # pytest may only ever create/drop a `test_jivo_quick_commerce*` database on the shared
        # server. POSTGRES_TEST_DB lets parallel agents/CI jobs use separate test databases.
        "TEST": {"NAME": TEST_DATABASE_NAME},
    }
}

# T-218: connection reuse. Opening a connection to the remote DB costs about 99 ms and
# occasionally times out (> 5 s), so per-request connections are slow and fragile.
# - Web (ASGI): persistent connections (CONN_MAX_AGE) are unsafe under ASGI (Django docs), so the
#   web process uses psycopg's pool: POSTGRES_POOL=true. Connections are opened in the background
#   and health-checked on checkout (CONN_HEALTH_CHECKS); a broken one is replaced, not served.
# - Celery worker / beat (sync, long-lived threads): POSTGRES_CONN_MAX_AGE=60 instead.
# Never both: Django refuses a pool with CONN_MAX_AGE > 0. Size it for the shared server:
# web processes x POSTGRES_POOL_MAX_SIZE + Celery concurrency must stay under its connection
# limit. Off by default; deployed environments turn it on per process (devops, T-218).
POSTGRES_POOL = env_bool("POSTGRES_POOL", default=False)
if POSTGRES_POOL:
    DATABASES["default"]["CONN_MAX_AGE"] = 0
    DATABASES["default"]["OPTIONS"]["pool"] = {
        "min_size": env_int("POSTGRES_POOL_MIN_SIZE", default=2),
        "max_size": env_int("POSTGRES_POOL_MAX_SIZE", default=8),
        # Seconds a request waits for a free connection before failing (then a 500/503).
        "timeout": env_float("POSTGRES_POOL_TIMEOUT", default=10.0),
        "max_idle": env_float("POSTGRES_POOL_MAX_IDLE", default=300.0),
        "max_lifetime": env_float("POSTGRES_POOL_MAX_LIFETIME", default=1800.0),
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
# 05 §5 (BUG-0006): a staff session ends 8 h after login (absolute, enforced from a login stamp
# by apps.accounts.middleware, whatever SESSION_COOKIE_AGE says), and admin roles also after 2 h
# without a request.
SESSION_COOKIE_AGE = env_int("DJANGO_SESSION_COOKIE_AGE", default=8 * 60 * 60)
STAFF_SESSION_MAX_AGE_SECONDS = env_int("DJANGO_STAFF_SESSION_MAX_AGE_SECONDS", default=8 * 3600)
STAFF_SESSION_IDLE_SECONDS = env_int("DJANGO_STAFF_SESSION_IDLE_SECONDS", default=2 * 60 * 60)
# The panel (admin, Ops Console) shows and takes times in IST for signed-in staff.
STAFF_TIME_ZONE = "Asia/Kolkata"
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
    # Public catalog media (product, category, banner images): plain, non-expiring URLs (cached
    # API payloads hold them), long browser/CDN caching (keys are random and never reused).
    # S3_PUBLIC_MEDIA_DOMAIN is the CDN host (or "10.0.2.2:9000/jivo-public" for a phone/emulator
    # against local MinIO, with S3_PUBLIC_MEDIA_PROTOCOL=http:).
    "public": {
        "BACKEND": "storages.backends.s3.S3Storage",
        "OPTIONS": {
            "bucket_name": env_str("S3_PUBLIC_MEDIA_BUCKET", default="jivo-public"),
            "endpoint_url": S3_ENDPOINT_URL,
            "access_key": env_str("S3_ACCESS_KEY_ID", default="") or None,
            "secret_key": env_str("S3_SECRET_ACCESS_KEY", default="") or None,
            "region_name": env_str("S3_REGION", default="ap-south-1"),
            "addressing_style": "path" if S3_ENDPOINT_URL else "auto",
            "default_acl": None,
            "file_overwrite": False,
            "querystring_auth": False,
            "custom_domain": env_str("S3_PUBLIC_MEDIA_DOMAIN", default="") or None,
            "url_protocol": env_str("S3_PUBLIC_MEDIA_PROTOCOL", default="https:"),
            "object_parameters": {"CacheControl": "public, max-age=31536000, immutable"},
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
# Local default: the console backend (logs the OTP). Deployed environments default to
# UnconfiguredSmsBackend and refuse console/locmem (deployed.py, accounts.E003; BUG-0005).
SMS_BACKEND = env_str("SMS_BACKEND", default="apps.notifications.sms.ConsoleSmsBackend")
SMS_CONSOLE_BACKEND_ALLOWED = False  # staging only, see deployed.py
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
        '`{"error": {"code", "message", "details"}}` (see the `ErrorEnvelope` schema). '
        "Any request whose body is larger than 2.5 MB gets 413 `PAYLOAD_TOO_LARGE`."
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
    # A nullable choice field is published as a nullable `$ref` to its enum, not as
    # `oneOf: [XEnum, NullEnum]`, which the Dart (dart-dio) generator cannot compile (Phase 3).
    "ENUM_ADD_EXPLICIT_BLANK_NULL_CHOICE": False,
    "ENUM_NAME_OVERRIDES": {
        "ErrorCodeEnum": "apps.core.errors.ErrorCode",
        "HealthStatusEnum": "apps.core.serializers.HealthStatus",
        "HealthCheckStatusEnum": "apps.core.serializers.HealthCheckStatus",
        "AppEnum": "apps.accounts.choices.AppName",
        "PlatformEnum": "apps.accounts.choices.Platform",
        "OtpPurposeEnum": "apps.accounts.choices.OtpPurpose",
        "RiderStatusEnum": "apps.accounts.choices.RiderStatus",
        "AddressLabelEnum": "apps.accounts.choices.AddressLabel",
        "ProductSortEnum": "apps.catalog.choices.ProductSort",
        "StockStatusEnum": "apps.catalog.choices.StockStatus",
        "BannerLinkTypeEnum": "apps.catalog.choices.BannerLinkType",
        "SearchSuggestionTypeEnum": "apps.catalog.choices.SuggestionType",
        # Phase 3: cart, coupons, orders, payments
        "DeliveryInstructionChipEnum": "apps.cart.choices.DeliveryInstructionChip",
        "CartLineIssueCodeEnum": "apps.cart.choices.CartLineIssueCode",
        "CheckoutBlockerCodeEnum": "apps.cart.choices.CheckoutBlockerCode",
        "PaymentUnavailableReasonEnum": "apps.cart.choices.PaymentUnavailableReason",
        "CouponDiscountTypeEnum": "apps.promotions.choices.DiscountType",
        "CouponIneligibleReasonEnum": "apps.promotions.choices.CouponIneligibleReason",
        "OrderStatusEnum": "apps.orders.choices.OrderStatus",
        "PaymentMethodEnum": "apps.orders.choices.PaymentMethod",
        "PaymentStatusEnum": "apps.orders.choices.PaymentStatus",
        "OrderListStatusEnum": "apps.orders.choices.OrderListStatus",
        "CancelReasonEnum": "apps.orders.choices.CancelReason",
        "WebhookResultEnum": "apps.payments.choices.WebhookResult",
    },
    "TAGS": [
        {"name": "health", "description": "Liveness and readiness probes. No authentication."},
        {"name": "auth", "description": "Phone OTP sign-in, token refresh, logout (06 §2.1)."},
        {"name": "account", "description": "Profile, push devices, account deletion (06 §2.1)."},
        {"name": "addresses", "description": "Saved delivery addresses (06 §2.2)."},
        {"name": "config", "description": "App configuration: versions, maintenance, contacts."},
        {
            "name": "serviceability",
            "description": "Which store serves a location, and notify-me (06 §2.3).",
        },
        {
            "name": "catalog",
            "description": (
                "Home, categories, products, search and collections for one store: every "
                "operation takes the `X-Store-Id` header (06 §2.4)."
            ),
        },
        {
            "name": "cart",
            "description": (
                "The server cart, its bill and coupons, priced at the store in `X-Store-Id` "
                "(06 §2.5). The app renders the bill; it never computes money."
            ),
        },
        {
            "name": "orders",
            "description": "Place orders, list them, retry a payment, cancel (06 §2.6, 08).",
        },
        {
            "name": "payments",
            "description": "Online payment confirmation and the gateway webhook (06 §2.6, 08 §4).",
        },
    ],
    "SWAGGER_UI_SETTINGS": {"persistAuthorization": True, "displayOperationId": True},
}

# --------------------------------------------------------------------------- stores & catalog (P2)
# Store opening hours (StoreTiming) are wall-clock times in this zone; the API sends UTC.
STORE_TIME_ZONE = "Asia/Kolkata"
# "Only N left" (LOW_STOCK) when 1 <= available <= this (DL-26, PM default 3).
CATALOG_LOW_STOCK_UNITS = env_int("CATALOG_LOW_STOCK_UNITS", default=3)
CATALOG_IMAGE_MAX_BYTES = 5 * 1024 * 1024  # 09 §3.6
# Per-store Redis cache of home/catalog responses; also bounds banner start/end lag.
CATALOG_CACHE_SECONDS = env_int("CATALOG_CACHE_SECONDS", default=300)
# ETA (08 §8): prep + rider wait + distance x road factor / speed + buffer.
ETA_AVG_SPEED_KMPH = env_float("ETA_AVG_SPEED_KMPH", default=20.0)
ETA_ROAD_FACTOR = env_float("ETA_ROAD_FACTOR", default=1.3)
ETA_BUFFER_MINUTES = env_int("ETA_BUFFER_MINUTES", default=2)
# Typical wait for a rider at the store, used by the serviceability ETA (PM default 3 min).
ETA_RIDER_WAIT_MINUTES = env_int("ETA_RIDER_WAIT_MINUTES", default=3)
# Notify-me leads per user (or IP when anonymous). Fails open when Redis is down.
REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"] = {
    "notify_me": env_str("NOTIFY_ME_RATE", default="10/hour"),
}

# --------------------------------------------------------------------------- cart & payments (P3)
# Largest rider tip the cart accepts (PM default, pending confirmation; 03 §2.8 offers 10/20/30
# or a custom amount).
CART_MAX_TIP = Decimal(env_str("CART_MAX_TIP", default="500.00"))
# Payment gateway (D-01, DL-21): Razorpay by default, behind apps.payments.gateways. local.py and
# test.py default to FakeRazorpayGateway; staging and production refuse it (payments.E001).
PAYMENT_GATEWAY = env_str("PAYMENT_GATEWAY", default="apps.payments.gateways.RazorpayGateway")
# Razorpay keys (test keys on staging, live keys in production). Environment only, never
# committed. Empty here: the Razorpay gateway fails loudly when used without them.
RAZORPAY_KEY_ID = env_str("RAZORPAY_KEY_ID", default="")
RAZORPAY_KEY_SECRET = env_str("RAZORPAY_KEY_SECRET", default="")
RAZORPAY_WEBHOOK_SECRET = env_str("RAZORPAY_WEBHOOK_SECRET", default="")

# --------------------------------------------------------------------------- import / export
# The admin's import is two requests (preview, then confirm), possibly served by different web
# processes or containers: keep the uploaded file in Redis, not in a process-local temp folder.
# Entries expire after a day (CacheStorage.CACHE_LIFETIME).
IMPORT_EXPORT_TMP_STORAGE_CLASS = "import_export.tmp_storages.CacheStorage"
# CSV and Excel only (05 §2), with formula-injection escaping on export: cells starting with
# = + - @ are written as text, never as formulas (apps.core.export_formats).
# (import-export instantiates these classes directly, so they are imported here.)
from apps.core.export_formats import FORMATS as IMPORT_EXPORT_FORMATS  # noqa: E402, F401

IMPORT_EXPORT_ESCAPE_FORMULAE_ON_EXPORT = True

# --------------------------------------------------------------------------- admin (unfold)
from config.admin_ui import UNFOLD  # noqa: E402, F401  (owned by the admin panel track)

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
