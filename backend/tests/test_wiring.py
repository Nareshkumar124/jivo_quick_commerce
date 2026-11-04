"""Infrastructure wiring: settings, Celery, Channels (Redis on 6380), ASGI, simplejwt."""

from datetime import timedelta
from urllib.parse import urlparse

import pytest
from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer
from channels.routing import ProtocolTypeRouter
from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from rest_framework_simplejwt.settings import api_settings as jwt_settings

from config.env import env_test_database_name, env_test_redis_db
from config.testing import NamespacedRedisCache, worker_redis_namespace, xdist_worker

PROJECT_REDIS_PORT = 6380


class TestSettings:
    def test_postgis_engine_since_phase_2(self):
        assert settings.DATABASES["default"]["ENGINE"] == "django.contrib.gis.db.backends.postgis"
        assert "django.contrib.gis" in settings.INSTALLED_APPS

    @pytest.mark.django_db
    def test_postgis_is_available(self):
        from django.contrib.gis.geos import Point, Polygon
        from django.db import connection

        with connection.cursor() as cursor:
            cursor.execute("SELECT PostGIS_Lib_Version()")
            assert cursor.fetchone()[0].startswith("3.")
        square = Polygon(((77.0, 28.4), (77.1, 28.4), (77.1, 28.5), (77.0, 28.5), (77.0, 28.4)))
        assert square.contains(Point(77.05, 28.45))

    def test_only_this_test_database_is_ever_created(self):
        """Serial: exactly POSTGRES_TEST_DB. Under pytest-xdist, pytest-django appends the worker
        id (`_gw0`, ...) and nothing else (T-408c)."""
        name = settings.DATABASES["default"]["TEST"]["NAME"]
        worker = xdist_worker()
        expected = (
            f"{settings.TEST_DATABASE_NAME}_{worker}" if worker else settings.TEST_DATABASE_NAME
        )
        assert name == expected
        assert name.startswith("test_jivo_quick_commerce")

    @pytest.mark.parametrize("name", ["jivo_quick_commerce", "test_other_project", " "])
    def test_test_database_name_is_guarded(self, monkeypatch, name):
        monkeypatch.setenv("POSTGRES_TEST_DB", name)
        with pytest.raises(ImproperlyConfigured, match="POSTGRES_TEST_DB"):
            env_test_database_name()

    def test_test_database_name_override(self, monkeypatch):
        monkeypatch.setenv("POSTGRES_TEST_DB", "test_jivo_quick_commerce_admin")
        assert env_test_database_name() == "test_jivo_quick_commerce_admin"
        monkeypatch.delenv("POSTGRES_TEST_DB")
        assert env_test_database_name() == "test_jivo_quick_commerce"

    @pytest.mark.parametrize("value", ["0", "2", "16"])
    def test_test_redis_db_is_guarded(self, monkeypatch, value):
        monkeypatch.setenv("TEST_REDIS_DB", value)
        with pytest.raises(ImproperlyConfigured, match="TEST_REDIS_DB"):
            env_test_redis_db()

    def test_tests_use_their_own_redis_db(self):
        assert 3 <= settings.TEST_REDIS_DB <= 15
        assert urlparse(settings.CACHES["default"]["LOCATION"]).path == f"/{settings.TEST_REDIS_DB}"

    def test_redis_keys_are_namespaced_per_xdist_worker(self):
        worker = xdist_worker()
        namespace = "jqc-test" + (f"-{worker}" if worker else "")
        assert settings.TEST_REDIS_NAMESPACE == namespace
        assert settings.CACHES["default"]["KEY_PREFIX"] == namespace
        assert settings.CACHES["default"]["BACKEND"] == "config.testing.NamespacedRedisCache"
        assert settings.CHANNEL_LAYERS["default"]["CONFIG"]["prefix"] == f"{namespace}:asgi"

    @pytest.mark.parametrize(
        ("worker", "namespace"),
        [("", "jqc-test"), ("gw0", "jqc-test-gw0"), ("gw12", "jqc-test-gw12")],
    )
    def test_worker_namespace(self, monkeypatch, worker, namespace):
        monkeypatch.setenv("PYTEST_XDIST_WORKER", worker)
        assert worker_redis_namespace() == namespace

    @pytest.mark.parametrize("worker", ["gw", "gw0:x", "*", "master"])
    def test_unexpected_worker_ids_are_refused(self, monkeypatch, worker):
        monkeypatch.setenv("PYTEST_XDIST_WORKER", worker)
        with pytest.raises(ValueError, match="PYTEST_XDIST_WORKER"):
            worker_redis_namespace()

    def test_cache_clear_leaves_other_workers_keys_alone(self):
        """T-408c: Django's RedisCache.clear() is FLUSHDB, which wiped every parallel worker's
        cache, rate-limit counters and channel groups mid-test."""
        from django.core.cache import cache, caches

        assert isinstance(caches["default"], NamespacedRedisCache)
        client = cache._cache.get_client(None, write=True)
        neighbour = "jqc-test-neighbour-t408c:1:kept"
        ours = [f"{settings.TEST_REDIS_NAMESPACE}:rl:t408c:{i}" for i in range(1203)]
        try:
            client.set(neighbour, 1, ex=60)
            client.mset(dict.fromkeys(ours, 1))
            cache.set("t408c", 1)
            assert cache.clear() is True
            assert cache.get("t408c") is None
            assert client.exists(*ours) == 0
            assert client.exists(neighbour) == 1
        finally:
            client.delete(neighbour)

    def test_rate_limit_counters_live_in_the_worker_namespace(self):
        from django.core.cache import cache

        from apps.core import ratelimit

        limit = ratelimit.Limit("t408c", limit=1, window_seconds=60)
        key = ratelimit._key(limit, "+919000000009")
        assert key.startswith(f"{settings.TEST_REDIS_NAMESPACE}:jqc:rl:t408c:")
        assert ratelimit.hit(limit, "+919000000009") == 0
        assert ratelimit.hit(limit, "+919000000009") > 0
        cache.clear()
        assert ratelimit.hit(limit, "+919000000009") == 0

    @pytest.mark.parametrize("prefix", ["", "a:b", "a*", "a[b]"])
    def test_namespaced_cache_needs_a_plain_prefix(self, prefix):
        cache = NamespacedRedisCache(settings.REDIS_URL, {"KEY_PREFIX": prefix})
        with pytest.raises(ValueError, match="KEY_PREFIX"):
            cache.clear()

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
