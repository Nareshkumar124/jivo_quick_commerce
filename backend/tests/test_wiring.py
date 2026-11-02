"""Infrastructure wiring: settings, Celery, Channels (Redis on 6380), ASGI, simplejwt."""

from datetime import timedelta
from urllib.parse import urlparse

import pytest
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from channels.routing import ProtocolTypeRouter
from django.conf import settings
from rest_framework_simplejwt.settings import api_settings as jwt_settings

PROJECT_REDIS_PORT = 6380


class TestSettings:
    def test_plain_postgres_engine_until_phase_2(self):
        assert settings.DATABASES["default"]["ENGINE"] == "django.db.backends.postgresql"
        assert "django.contrib.gis" not in settings.INSTALLED_APPS

    def test_only_this_test_database_is_ever_created(self):
        assert settings.DATABASES["default"]["TEST"]["NAME"] == "test_jivo_quick_commerce"

    def test_custom_user_model(self):
        assert settings.AUTH_USER_MODEL == "accounts.User"

    def test_redis_urls_use_the_project_port(self):
        urls = [
            settings.REDIS_URL,
            settings.CACHES["default"]["LOCATION"],
            *settings.CHANNEL_LAYERS["default"]["CONFIG"]["hosts"],
        ]
        assert all(urlparse(url).port == PROJECT_REDIS_PORT for url in urls), urls

    def test_jwt_lifetimes_per_02_section_5(self):
        assert jwt_settings.ACCESS_TOKEN_LIFETIME == timedelta(minutes=15)
        assert jwt_settings.REFRESH_TOKEN_LIFETIME == timedelta(days=30)
        assert jwt_settings.ROTATE_REFRESH_TOKENS
        assert jwt_settings.BLACKLIST_AFTER_ROTATION
        assert jwt_settings.AUTH_HEADER_TYPES == ("Bearer",)

    def test_api_defaults(self):
        drf = settings.REST_FRAMEWORK
        assert drf["EXCEPTION_HANDLER"] == "apps.core.exceptions.exception_handler"
        assert drf["DEFAULT_PAGINATION_CLASS"] == "apps.core.pagination.StandardPagination"
        assert drf["DEFAULT_PERMISSION_CLASSES"] == ["rest_framework.permissions.IsAuthenticated"]
        assert settings.TIME_ZONE == "UTC"
        assert settings.USE_TZ


class TestCelery:
    def test_app_reads_django_settings(self):
        from config import celery_app

        assert celery_app.conf.task_always_eager is True
        assert celery_app.conf.beat_scheduler == ("django_celery_beat.schedulers:DatabaseScheduler")
        assert celery_app.conf.task_acks_late is True

    def test_tasks_are_autodiscovered_and_run(self):
        from apps.core.tasks import ping
        from config import celery_app

        assert "core.ping" in celery_app.tasks
        assert ping.delay().get(timeout=5) == "pong"


class TestChannels:
    def test_redis_channel_layer_round_trip(self):
        layer = get_channel_layer()
        assert type(layer).__name__ == "RedisChannelLayer"

        async def round_trip():
            channel = await layer.new_channel()
            await layer.send(channel, {"type": "phase0.hello", "value": 42})
            return await layer.receive(channel)

        assert async_to_sync(round_trip)() == {"type": "phase0.hello", "value": 42}

    def test_asgi_application_routes_http_and_websocket(self):
        from config.asgi import application

        assert isinstance(application, ProtocolTypeRouter)
        assert set(application.application_mapping) == {"http", "websocket"}


@pytest.mark.django_db
def test_migrations_are_applied_to_the_test_database():
    from django.db import connection

    tables = connection.introspection.table_names()
    assert "accounts_user" in tables
    assert "django_celery_beat_periodictask" in tables
    assert "token_blacklist_outstandingtoken" in tables
