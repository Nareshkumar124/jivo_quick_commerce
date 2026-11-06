"""T-814: backend fixes from the Phase 8 OWASP review (H2, H3, M2, M4, L1-L4, L10).

The Support refund caps (M3) are in apps/payments/tests/test_refund_caps.py and the placement
gateway call (M6) in apps/orders/tests (test_placement.py, test_concurrency.py).
"""

import http.server
import importlib
import logging
import sys
import threading
import urllib.error
import urllib.request
from datetime import timedelta
from types import SimpleNamespace
from unittest import mock

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured
from django.test import Client
from django.urls import reverse
from django.utils import timezone
from rest_framework.test import APIClient
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.services import auth, otp
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.core import http as core_http
from apps.core import throttling
from apps.core.models import AuditLog

pytestmark = pytest.mark.django_db

REFRESH = "/api/v1/auth/token/refresh/"
ADDRESSES = "/api/v1/addresses/"
APP_CONFIG = "/api/v1/config/app/"
ME = "/api/v1/me/"
SERVICEABILITY = "/api/v1/serviceability/"
OTP_REQUEST = "/api/v1/auth/otp/request/"
ADDRESS = {
    "label": "home",
    "house": "12",
    "building_street": "MG Road",
    "area": "Sector 14",
    "city": "Gurugram",
    "state": "Haryana",
    "pincode": "122001",
    "lat": 28.4646,
    "lng": 77.0864,
}


def throttles_of(view_class, method: str = "GET") -> list[type]:
    view = view_class()
    view.request = SimpleNamespace(method=method)
    return [type(throttle) for throttle in view.get_throttles()]


BASELINE = [throttling.BaselineAnonThrottle, throttling.BaselineUserThrottle]


# --------------------------------------------------------------------------- H3: throttling


class TestBaselineThrottles:
    def test_anonymous_callers_are_throttled_per_ip(self, api_client, monkeypatch):
        monkeypatch.setattr(throttling.BaselineAnonThrottle, "THROTTLE_RATES", {"anon": "2/min"})
        for _ in range(2):
            assert api_client.get(APP_CONFIG).status_code == 200
        response = api_client.get(APP_CONFIG)
        assert response.status_code == 429
        assert response.json()["error"]["code"] == "RATE_LIMITED"
        assert response.json()["error"]["details"]["retry_after_seconds"] > 0
        other_ip = api_client.get(APP_CONFIG, REMOTE_ADDR="198.51.100.20")
        assert other_ip.status_code == 200

    def test_signed_in_callers_are_throttled_per_user(self, user, make_auth_client, monkeypatch):
        monkeypatch.setattr(throttling.BaselineUserThrottle, "THROTTLE_RATES", {"user": "2/min"})
        client = make_auth_client(user)
        for _ in range(2):
            assert client.get(ME).status_code == 200
        assert client.get(ME).status_code == 429
        assert make_auth_client(UserFactory()).get(ME).status_code == 200  # per user

    def test_user_baseline_ignores_anonymous_callers(self, api_client, monkeypatch):
        monkeypatch.setattr(throttling.BaselineUserThrottle, "THROTTLE_RATES", {"user": "1/min"})
        for _ in range(3):
            assert api_client.get(APP_CONFIG).status_code == 200

    def test_fails_open_without_redis(self, api_client, monkeypatch):
        def broken(self, request, view):
            raise ConnectionError("redis down")

        monkeypatch.setattr(throttling.AnonRateThrottle, "allow_request", broken)
        assert api_client.get(APP_CONFIG).status_code == 200

    def test_exempt_views(self):
        from apps.core.views import HealthLiveView
        from apps.payments.views import RazorpayWebhookView

        assert throttles_of(RazorpayWebhookView, "POST") == []
        assert throttles_of(HealthLiveView) == []


class TestScopedThrottles:
    def test_scoped_views_replace_the_baseline(self):
        """Stricter scopes replace the defaults (never both), including the existing ones."""
        from apps.accounts.views import AddressDetailView, AddressListCreateView
        from apps.cart.views import CartCouponView
        from apps.catalog.views import SearchSuggestView, SearchView
        from apps.orders.views import OrderInvoiceView, OrderListCreateView, OrderRetryPaymentView
        from apps.payments.views import RazorpayVerifyView
        from apps.stores.views import NotifyMeThrottle, NotifyMeView, ServiceabilityView
        from apps.support.throttling import TicketCreateThrottle, TicketMessageThrottle
        from apps.support.views import TicketListCreateView

        assert throttles_of(SearchView) == [throttling.SearchThrottle]
        assert throttles_of(SearchSuggestView) == [throttling.SearchThrottle]
        assert throttles_of(ServiceabilityView) == [throttling.ServiceabilityThrottle]
        assert throttles_of(CartCouponView, "POST") == [throttling.CouponApplyThrottle]
        assert throttles_of(CartCouponView, "DELETE") == BASELINE
        for method in ("POST", "PATCH", "DELETE"):
            assert throttles_of(AddressDetailView, method) == [throttling.AddressWriteThrottle]
        assert throttles_of(AddressListCreateView, "POST") == [throttling.AddressWriteThrottle]
        assert throttles_of(AddressListCreateView, "GET") == BASELINE
        assert throttles_of(OrderInvoiceView) == [throttling.InvoiceThrottle]
        # The per-endpoint throttles that existed before T-814 still apply.
        assert throttles_of(OrderListCreateView, "POST") == [throttling.OrderPlacementThrottle]
        assert throttles_of(OrderListCreateView, "GET") == BASELINE
        assert throttles_of(OrderRetryPaymentView, "POST") == [throttling.PaymentThrottle]
        assert throttles_of(RazorpayVerifyView, "POST") == [throttling.PaymentThrottle]
        assert throttles_of(NotifyMeView, "POST") == [NotifyMeThrottle]
        assert throttles_of(TicketListCreateView, "POST") == [TicketCreateThrottle]
        assert throttles_of(TicketListCreateView, "GET") == BASELINE
        from apps.support.views import TicketMessageCreateView

        assert throttles_of(TicketMessageCreateView, "POST") == [TicketMessageThrottle]

    def test_rider_endpoints_are_not_throttled_twice(self):
        """The rider scopes (P5) replace the baseline; other rider views get the baseline once."""
        from apps.delivery import throttling as rider
        from apps.delivery import views

        assert throttles_of(views.LocationsView, "POST") == [rider.RiderLocationsThrottle]
        assert throttles_of(views.HeartbeatView, "POST") == [rider.RiderHeartbeatThrottle]
        assert throttles_of(views.RiderDocumentsView, "POST") == [rider.RiderDocumentsThrottle]
        assert throttles_of(views.RiderRegisterView, "POST") == [rider.RiderProfileWriteThrottle]
        assert throttles_of(views.CurrentTaskView) == BASELINE

    def test_address_writes(self, user, make_auth_client, monkeypatch):
        monkeypatch.setattr(
            throttling.AddressWriteThrottle, "THROTTLE_RATES", {"address_write": "1/hour"}
        )
        client = make_auth_client(user)
        assert client.post(ADDRESSES, ADDRESS, format="json").status_code == 201
        response = client.post(ADDRESSES, ADDRESS, format="json")
        assert response.status_code == 429
        assert response.json()["error"]["code"] == "RATE_LIMITED"
        assert client.get(ADDRESSES).status_code == 200  # reads are not address writes

    def test_serviceability_per_ip(self, api_client, monkeypatch):
        monkeypatch.setattr(
            throttling.ServiceabilityThrottle, "THROTTLE_RATES", {"serviceability": "1/min"}
        )
        query = {"lat": "28.4646", "lng": "77.0864"}
        assert api_client.get(SERVICEABILITY, query).status_code == 200
        assert api_client.get(SERVICEABILITY, query).status_code == 429
        assert api_client.get(SERVICEABILITY, query, REMOTE_ADDR="198.51.100.7").status_code == 200

    def test_rates_are_settings(self, settings):
        rates = settings.REST_FRAMEWORK["DEFAULT_THROTTLE_RATES"]
        for scope in (
            "anon",
            "user",
            "search",
            "serviceability",
            "coupon_apply",
            "address_write",
            "invoice",
        ):
            assert rates[scope]
        assert rates["coupon_apply"] == "20/hour"
        assert rates["address_write"] == "30/hour"


# --------------------------------------------------------------------------- H2: lockout


class TestStaffLockoutPerUsername:
    def test_rotating_ips_cannot_brute_force_one_account(self):
        StaffUserFactory(email="finance@jivo.test", password="a-strong-pass-1")
        client, url = Client(), reverse("admin:login")
        for i in range(5):
            client.post(
                url,
                {"username": "finance@jivo.test", "password": "wrong"},
                REMOTE_ADDR=f"203.0.113.{i + 1}",
            )
        locked = client.post(
            url,
            {"username": "finance@jivo.test", "password": "a-strong-pass-1"},
            REMOTE_ADDR="203.0.113.99",
        )
        assert locked.status_code == 429

    def test_other_accounts_are_not_locked(self):
        StaffUserFactory(email="ops@jivo.test", password="a-strong-pass-1")
        client, url = Client(), reverse("admin:login")
        for _ in range(5):
            client.post(url, {"username": "someone@jivo.test", "password": "wrong"})
        ok = client.post(
            url,
            {"username": "ops@jivo.test", "password": "a-strong-pass-1"},
            REMOTE_ADDR="203.0.113.50",
        )
        assert ok.status_code == 302


# --------------------------------------------------------------------------- M2: token reuse


class TestRefreshTokenReuse:
    def test_reuse_revokes_every_session_and_logs_without_the_token(self, caplog):
        user = UserFactory()
        _, phone_refresh = auth.issue_tokens(user, "customer")
        _, tablet_refresh = auth.issue_tokens(user, "customer")
        client = APIClient()
        rotated = client.post(REFRESH, {"refresh": phone_refresh}, format="json").json()
        with caplog.at_level(logging.WARNING, logger="jqc.security"):
            reused = client.post(REFRESH, {"refresh": phone_refresh}, format="json")
        assert reused.status_code == 401
        assert reused.json()["error"]["message"] == "Token is blacklisted"
        # Every refresh token of the user is revoked: the rotated one and the other device's.
        for raw in (rotated["refresh"], tablet_refresh):
            response = client.post(REFRESH, {"refresh": raw}, format="json")
            assert response.status_code == 401
        assert not OutstandingToken.objects.filter(
            user=user, blacklistedtoken__isnull=True
        ).exists()
        # One event per presentation of a revoked token: the first ended both sessions, the
        # two later ones (the devices trying their now-revoked tokens) found nothing left.
        events = list(
            AuditLog.objects.filter(action="auth.refresh_token_reuse").order_by("created_at", "pk")
        )
        assert [e.changes["revoked_tokens"] for e in events] == [2, 0, 0]
        entry = events[0]
        assert entry.object_id == str(user.pk)
        assert "Refresh token reuse" in caplog.text
        jti = RefreshToken(rotated["refresh"], verify=False)["jti"]
        for secret in (phone_refresh, rotated["refresh"], jti):
            assert secret not in caplog.text
            assert secret not in str(entry.changes)

    def test_reuse_during_the_atomic_redemption(self):
        """The race path (simplejwt's fast check skipped): the loser is reuse too."""
        user = UserFactory()
        _, refresh = auth.issue_tokens(user, "rider")
        _, other = auth.issue_tokens(user, "rider")
        with mock.patch.object(RefreshToken, "check_blacklist", return_value=None):
            auth.rotate_refresh_token(refresh)
            with pytest.raises(auth.TokenError):
                auth.rotate_refresh_token(refresh)
        other_jti = RefreshToken(other, verify=False)["jti"]
        assert BlacklistedToken.objects.filter(token__jti=other_jti).exists()
        assert AuditLog.objects.filter(action="auth.refresh_token_reuse").count() == 1

    @pytest.mark.parametrize("raw", ["garbage", "expired"])
    def test_invalid_or_expired_tokens_are_not_reuse(self, raw):
        user = UserFactory()
        _, keep = auth.issue_tokens(user, "customer")
        if raw == "expired":
            token = RefreshToken.for_user(user)
            token.set_exp(lifetime=-timedelta(seconds=1))
            raw = str(token)
        with pytest.raises(auth.TokenError):
            auth.rotate_refresh_token(raw)
        keep_jti = RefreshToken(keep, verify=False)["jti"]
        assert not BlacklistedToken.objects.filter(token__jti=keep_jti).exists()
        assert not AuditLog.objects.filter(action="auth.refresh_token_reuse").exists()

    def test_access_token_is_not_reuse(self):
        user = UserFactory()
        access, _ = auth.issue_tokens(user, "customer")
        assert auth._detect_reuse(access, ip=None) is False

    def test_cleanup_tasks_are_scheduled_and_run(self, settings):
        from apps.accounts import tasks

        schedule = {entry["task"] for entry in settings.CELERY_BEAT_SCHEDULE.values()}
        assert {"accounts.flush_expired_tokens", "accounts.clear_expired_sessions"} <= schedule
        user = UserFactory()
        token = RefreshToken.for_user(user)
        OutstandingToken.objects.filter(jti=token["jti"]).update(
            expires_at=timezone.now() - timedelta(days=1)
        )
        assert tasks.flush_expired_tokens() == "done"
        assert not OutstandingToken.objects.filter(jti=token["jti"]).exists()
        assert tasks.clear_expired_sessions() == "done"


# --------------------------------------------------------------------------- M4: personal data


class TestPaymentPayloadScrub:
    RAW = {
        "id": "pay_Scrub00000001",
        "amount": 55800,
        "status": "captured",
        "method": "upi",
        "contact": "+919876543210",
        "email": "a@b.test",
        "vpa": "someone@okbank",
        "upi": {"vpa": "someone@okbank", "payer_account_type": "bank_account"},
        "card": {"last4": "1111", "name": "A Person"},
        "notes": {"order_number": "JV-1"},
    }

    def test_old_payloads_lose_personal_fields(self, settings):
        from apps.orders.tests.factories import OrderFactory
        from apps.payments import retention
        from apps.payments.models import Payment, PaymentWebhookEvent

        order = OrderFactory()
        old = Payment.objects.create(
            order=order, gateway="razorpay", amount=558, status="CAPTURED", raw=self.RAW
        )
        new = Payment.objects.create(
            order=order, gateway="razorpay", amount=558, status="CAPTURED", raw=self.RAW
        )
        event = PaymentWebhookEvent.objects.create(
            event_id="evt_scrub_1",
            event_type="payment.captured",
            payload={"payload": {"payment": {"entity": self.RAW}}},
        )
        long_ago = timezone.now() - timedelta(days=settings.PAYMENT_PAYLOAD_RETENTION_DAYS + 1)
        Payment.objects.filter(pk=old.pk).update(created_at=long_ago)
        PaymentWebhookEvent.objects.filter(pk=event.pk).update(created_at=long_ago)

        assert retention.scrub_payment_payloads() == {"payment": 1, "paymentwebhookevent": 1}
        old.refresh_from_db()
        event.refresh_from_db()
        new.refresh_from_db()
        assert old.raw == {
            "id": "pay_Scrub00000001",
            "amount": 55800,
            "status": "captured",
            "method": "upi",
            "notes": {"order_number": "JV-1"},
        }
        assert old.pii_scrubbed_at is not None
        assert event.payload["payload"]["payment"]["entity"] == old.raw
        assert new.raw == self.RAW
        assert new.pii_scrubbed_at is None
        # Idempotent: nothing left to do.
        assert retention.scrub_payment_payloads() == {"payment": 0, "paymentwebhookevent": 0}

    def test_task_runs_batches_and_is_scheduled(self, settings):
        from apps.orders.tests.factories import OrderFactory
        from apps.payments import retention
        from apps.payments.models import Payment

        settings.PAYMENT_PAYLOAD_SCRUB_BATCH = 1
        order = OrderFactory()
        for _ in range(3):
            Payment.objects.create(
                order=order, gateway="razorpay", amount=558, status="FAILED", raw=self.RAW
            )
        Payment.objects.update(created_at=timezone.now() - timedelta(days=365))
        assert retention.scrub_payment_payloads_task()["payment"] == 3
        assert not Payment.objects.filter(pii_scrubbed_at__isnull=True).exists()
        schedule = {entry["task"] for entry in settings.CELERY_BEAT_SCHEDULE.values()}
        assert "payments.scrub_payment_payloads" in schedule


class TestAnonymisationFreeText:
    def test_instructions_and_message_bodies_are_erased(self):
        from apps.orders.tests.factories import OrderFactory
        from apps.support import services as support
        from apps.support.models import TicketMessage

        user = UserFactory()
        other = UserFactory()
        order = OrderFactory(
            user=user,
            instructions={"note": "Gate code 4321, ring twice"},
            address_snapshot={"house": "12", "city": "Gurugram"},
        )
        kept = OrderFactory(user=other, instructions={"note": "keep"})
        ticket = support.create_ticket(user, category="OTHER", message="My flat is 12B, call me")
        agent = StaffUserFactory()
        TicketMessage.objects.create(ticket=ticket, sender=agent, is_staff=True, body="On it")
        user.deleted_at = timezone.now() - timedelta(days=60)
        user.save(update_fields=["deleted_at"])

        assert auth.anonymise_user(user.pk)
        order.refresh_from_db()
        kept.refresh_from_db()
        assert order.instructions == {}
        assert order.address_snapshot == {"house": "12", "city": "Gurugram"}  # tax retention
        assert kept.instructions == {"note": "keep"}
        bodies = dict(TicketMessage.objects.filter(ticket=ticket).values_list("is_staff", "body"))
        assert bodies == {False: auth.ERASED_TEXT, True: "On it"}


# --------------------------------------------------------------------------- L1, L3: settings


@pytest.fixture
def deploy_env(monkeypatch):
    monkeypatch.setenv("DJANGO_SECRET_KEY", "s" * 64)
    monkeypatch.setenv("JWT_SIGNING_KEY", "j" * 64)
    monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.test")
    monkeypatch.setenv("NUM_PROXIES", "1")
    monkeypatch.delenv("OTP_TEST_NUMBERS", raising=False)
    monkeypatch.delenv("SENTRY_DSN", raising=False)
    yield monkeypatch
    for name in ("config.settings.production", "config.settings.deployed"):
        sys.modules.pop(name, None)


def load_production():
    for name in ("config.settings.production", "config.settings.deployed"):
        sys.modules.pop(name, None)
    return importlib.import_module("config.settings.production")


class TestDeployedSettings:
    @pytest.mark.parametrize("value", ["0", "-1"])
    def test_num_proxies_must_be_at_least_one(self, deploy_env, value):
        deploy_env.setenv("NUM_PROXIES", value)
        with pytest.raises(ImproperlyConfigured, match="NUM_PROXIES"):
            load_production()

    def test_loads_with_one_proxy_and_its_own_jwt_key(self, deploy_env):
        production = load_production()
        assert production.NUM_PROXIES == 1
        assert production.SIMPLE_JWT["SIGNING_KEY"] == "j" * 64


class TestSigningKeyChecks:
    def ids(self):
        return {e.id for e in run_checks() if e.id in ("accounts.E005", "accounts.E006")}

    def test_local_and_test_need_nothing(self, settings):
        settings.SIMPLE_JWT = {**settings.SIMPLE_JWT, "SIGNING_KEY": settings.SECRET_KEY}
        assert self.ids() == set()

    @pytest.mark.parametrize("environment", ["staging", "production"])
    def test_jwt_key_must_differ_from_secret_key(self, settings, environment):
        settings.APP_ENVIRONMENT = environment
        settings.SIMPLE_JWT = {**settings.SIMPLE_JWT, "SIGNING_KEY": settings.SECRET_KEY}
        assert self.ids() == {"accounts.E005"}
        settings.SIMPLE_JWT = {**settings.SIMPLE_JWT, "SIGNING_KEY": "short"}
        assert self.ids() == {"accounts.E005"}
        settings.SIMPLE_JWT = {**settings.SIMPLE_JWT, "SIGNING_KEY": "j" * 64}
        assert self.ids() == set()

    def test_explicit_otp_key_must_be_its_own(self, settings):
        settings.APP_ENVIRONMENT = "production"
        settings.SIMPLE_JWT = {**settings.SIMPLE_JWT, "SIGNING_KEY": "j" * 64}
        settings.OTP_HASH_KEY = settings.SECRET_KEY
        assert self.ids() == {"accounts.E006"}
        settings.OTP_HASH_KEY = "o" * 40
        assert self.ids() == set()

    def test_otp_hash_key_is_never_the_raw_secret_key(self, settings):
        settings.OTP_HASH_KEY = ""
        derived = otp.otp_hash_key()
        assert derived != settings.SECRET_KEY.encode()
        settings.OTP_HASH_KEY = "o" * 40
        assert otp.otp_hash_key() == b"o" * 40
        assert otp.hash_code("+919876543210", "customer", "login", "123456") != otp.hash_code(
            "+919876543210", "customer", "login", "654321"
        )


# --------------------------------------------------------------------------- L4: unknown IPs


class TestOtpUnknownIp:
    def test_unparseable_ips_share_one_bucket(self, api_client, settings):
        settings.OTP_SEND_LIMIT_PER_IP_PER_HOUR = 2
        for i in range(2):
            response = api_client.post(
                OTP_REQUEST,
                {"phone": f"+91987650001{i}", "app": "customer"},
                format="json",
                REMOTE_ADDR="not-an-ip",
            )
            assert response.status_code == 200
        response = api_client.post(
            OTP_REQUEST,
            {"phone": "+919876500019", "app": "customer"},
            format="json",
            REMOTE_ADDR="also-not-an-ip",
        )
        assert response.status_code == 429
        assert response.json()["error"]["code"] == "OTP_RATE_LIMITED"

    def test_verify_counts_unknown_ips(self, settings):
        from apps.core.exceptions import OtpRateLimited

        settings.OTP_VERIFY_LIMIT_PER_IP_PER_HOUR = 1
        otp.request_otp(phone="+919876500021", app="customer", purpose="login", ip=None)
        with pytest.raises(auth.ApiError):
            otp.verify_otp(phone="+919876500021", purpose="login", code="000000", ip=None)
        with pytest.raises(OtpRateLimited):
            otp.verify_otp(phone="+919876500021", purpose="login", code="000000", ip=None)


# --------------------------------------------------------------------------- L2: redirects


def test_razorpay_opener_never_follows_a_redirect(monkeypatch, settings):
    """The real opener against a local server answering 307: the credentials never reach the
    Location, and the gateway reports the call as unavailable."""
    from apps.payments import gateways

    hits = []

    class Handler(http.server.BaseHTTPRequestHandler):
        def do_POST(self):
            hits.append((self.path, self.headers.get("Authorization")))
            self.rfile.read(int(self.headers["Content-Length"]))
            self.send_response(307)
            self.send_header("Location", "/elsewhere")
            self.send_header("Content-Length", "0")
            self.end_headers()

        def log_message(self, *args):
            pass

    server = http.server.ThreadingHTTPServer(("127.0.0.1", 0), Handler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    try:
        request = urllib.request.Request(
            f"http://127.0.0.1:{server.server_port}/v1/orders",
            data=b"{}",
            method="POST",
            headers={"Authorization": "Basic secret"},
        )
        with pytest.raises(urllib.error.HTTPError) as caught:
            core_http.open_no_redirect(request, 5)
        assert caught.value.code == 307
        base = f"http://127.0.0.1:{server.server_port}/v1"
        monkeypatch.setattr(gateways, "RAZORPAY_API_BASE", base)
        settings.RAZORPAY_KEY_ID = "rzp_test_EXAMPLEEXAMPLE"
        settings.RAZORPAY_KEY_SECRET = "example-secret"
        settings.RAZORPAY_WEBHOOK_SECRET = "example-webhook-secret"
        with pytest.raises(gateways.GatewayUnavailable):
            gateways.RazorpayGateway().create_order(amount_paise=100, receipt="JV-1", notes={})
    finally:
        server.shutdown()
        server.server_close()
    assert [path for path, _ in hits] == ["/v1/orders", "/v1/orders"]  # never "/elsewhere"


# --------------------------------------------------------------------------- L10: addresses


class TestAddressCap:
    def test_cap_per_user(self, user, make_auth_client, settings):
        from apps.cart.tests.conftest import make_address

        settings.MAX_ADDRESSES_PER_USER = 2
        make_address(user)
        deleted = make_address(user)
        deleted.is_deleted = True
        deleted.save(update_fields=["is_deleted"])
        client = make_auth_client(user)
        assert client.post(ADDRESSES, ADDRESS, format="json").status_code == 201
        response = client.post(ADDRESSES, ADDRESS, format="json")
        assert response.status_code == 400
        error = response.json()["error"]
        assert error["code"] == "VALIDATION_ERROR"
        assert "up to 2 addresses" in error["details"]["non_field_errors"][0]
        assert (
            make_auth_client(UserFactory()).post(ADDRESSES, ADDRESS, format="json").status_code
            == 201
        )

    def test_default_is_twenty(self, settings):
        assert settings.MAX_ADDRESSES_PER_USER == 20
