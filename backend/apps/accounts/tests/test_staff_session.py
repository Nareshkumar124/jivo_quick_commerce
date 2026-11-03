"""Staff session policy (05 §5, BUG-0006) and the staff time zone (IST on /admin and /ops)."""

from datetime import UTC, datetime, timedelta

import pytest
from django.contrib.auth import SESSION_KEY
from django.contrib.auth.models import Group
from django.http import HttpResponse
from django.test import RequestFactory
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts import roles
from apps.accounts.middleware import LAST_SEEN_KEY, LOGIN_AT_KEY
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory
from apps.core.middleware import staff_timezone_middleware

pytestmark = pytest.mark.django_db

ADMIN = "/admin/"
START = "2026-11-03 04:00:00"  # 09:30 IST


def _role(user, *names):
    roles.sync_roles()
    user.groups.add(*Group.objects.filter(name__in=names))
    return user


def _signed_in(client) -> bool:
    return SESSION_KEY in client.session


@pytest.fixture
def store_manager(db):
    return _role(StaffUserFactory(), roles.STORE_MANAGER)


@pytest.fixture
def ops_user(db):
    return _role(StaffUserFactory(), roles.OPS)


def _login(client, user):
    """A real login (the `user_logged_in` signal stamps the session)."""
    client.force_login(user)
    assert client.session[LOGIN_AT_KEY]


class TestSessionLimits:
    def test_default_absolute_age_is_8_hours_and_idle_is_2(self, settings):
        """BUG-0006: was a fixed 12 hours."""
        from config.settings import base

        assert base.SESSION_COOKIE_AGE == 8 * 3600
        assert base.STAFF_SESSION_MAX_AGE_SECONDS == 8 * 3600
        assert base.STAFF_SESSION_IDLE_SECONDS == 2 * 3600

    def test_an_old_12_hour_cookie_age_does_not_extend_staff_sessions(
        self, client, store_manager, settings
    ):
        """BUG-0006: an env file still carrying DJANGO_SESSION_COOKIE_AGE=43200 keeps 8 h."""
        settings.SESSION_COOKIE_AGE = 12 * 3600
        with freeze_time(START) as frozen:
            _login(client, store_manager)
            frozen.tick(timedelta(hours=8, minutes=1))
            client.get(ADMIN)
            assert not _signed_in(client)

    def test_admin_role_session_ends_after_2_hours_idle(self, client, ops_user):
        """BUG-0006: admin roles: 2 hours without a request ends the session."""
        with freeze_time(START) as frozen:
            _login(client, ops_user)
            frozen.tick(timedelta(hours=1, minutes=59))
            assert client.get(ADMIN).status_code == 200
            assert _signed_in(client)
            frozen.tick(timedelta(hours=2, minutes=1))
            response = client.get(ADMIN)
            assert response.status_code == 302
            assert "/login/" in response["Location"]
            assert not _signed_in(client)

    def test_activity_keeps_an_admin_role_session_until_8_hours(self, client, ops_user):
        with freeze_time(START) as frozen:
            _login(client, ops_user)
            for _ in range(7):
                frozen.tick(timedelta(hours=1))
                assert client.get(ADMIN).status_code == 200
            frozen.tick(timedelta(hours=1))  # 8 h after login, active all along
            assert client.get(ADMIN).status_code == 302
            assert not _signed_in(client)

    def test_store_staff_have_no_idle_timeout_but_end_at_8_hours(self, client, store_manager):
        """BUG-0006: store staff: one 8-hour session, however idle."""
        with freeze_time(START) as frozen:
            _login(client, store_manager)
            frozen.tick(timedelta(hours=7, minutes=59))
            assert client.get(ADMIN).status_code == 200
            assert _signed_in(client)
            frozen.tick(timedelta(minutes=2))
            assert client.get(ADMIN).status_code == 302
            assert not _signed_in(client)

    @pytest.mark.parametrize(
        "make",
        [
            SuperUserFactory,
            StaffUserFactory,  # no role
            lambda: _role(StaffUserFactory(), roles.STORE_MANAGER, roles.OPS),  # mixed
        ],
    )
    def test_superusers_mixed_and_roleless_staff_get_the_idle_timeout(self, client, make):
        with freeze_time(START) as frozen:
            _login(client, make())
            frozen.tick(timedelta(hours=2, minutes=1))
            client.get(ADMIN)
            assert not _signed_in(client)

    def test_cookie_expiry_is_absolute(self, client, store_manager):
        """Saving the session later never pushes its expiry past login + 8 h."""
        with freeze_time(START) as frozen:
            _login(client, store_manager)
            frozen.tick(timedelta(hours=3))
            client.get(ADMIN)
            expiry = client.session.get_expiry_date()
        assert expiry == datetime(2026, 11, 3, 12, 0, tzinfo=UTC)  # 04:00 UTC + 8 h

    def test_activity_is_written_at_most_once_a_minute(self, client, ops_user):
        with freeze_time(START) as frozen:
            _login(client, ops_user)
            first = client.session[LAST_SEEN_KEY]
            frozen.tick(timedelta(seconds=30))
            client.get(ADMIN)
            assert client.session[LAST_SEEN_KEY] == first
            frozen.tick(timedelta(seconds=31))
            client.get(ADMIN)
            assert client.session[LAST_SEEN_KEY] > first

    def test_session_from_before_the_policy_starts_its_clocks_now(self, client, ops_user):
        with freeze_time(START):
            _login(client, ops_user)
            session = client.session
            del session[LOGIN_AT_KEY]
            session.save()
            assert client.get(ADMIN).status_code == 200
            assert client.session[LOGIN_AT_KEY]

    def test_api_requests_are_not_affected(self, client, ops_user):
        """JWT clients have no session: the middleware does nothing."""
        assert client.get("/api/v1/config/app/").status_code == 200


class TestStaffTimeZone:
    def _seen_tz(self, path, user):
        seen = {}

        def view(request):
            seen["tz"] = timezone.get_current_timezone_name()
            return HttpResponse()

        request = RequestFactory().get(path)
        request.user = user
        staff_timezone_middleware(view)(request)
        return seen["tz"]

    @pytest.mark.parametrize("path", ["/admin/", "/ops/orders/"])
    def test_staff_panel_runs_in_ist(self, path):
        assert self._seen_tz(path, StaffUserFactory()) == "Asia/Kolkata"
        assert timezone.get_current_timezone_name() == "UTC"  # nothing leaks

    def test_other_paths_and_non_staff_stay_utc(self, user):
        assert self._seen_tz("/api/v1/me/", StaffUserFactory()) == "UTC"
        assert self._seen_tz("/admin/", user) == "UTC"
