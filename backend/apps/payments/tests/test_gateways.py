"""Phase 3 R1: the payment gateway interface (DL-21), the published dev-only fake scheme, and the
guards that keep the fake gateway out of deployed environments (payments.E001)."""

import hashlib
import hmac
import importlib
import re
import sys

import pytest
from django.core.checks import run_checks
from django.core.exceptions import ImproperlyConfigured

from apps.payments import examples as ex
from apps.payments import gateways
from apps.payments.gateways import (
    FAKE_KEY_ID,
    FAKE_KEY_SECRET,
    FAKE_WEBHOOK_SECRET,
    FakeRazorpayGateway,
    RazorpayGateway,
    get_gateway,
    razorpay_payment_signature,
    razorpay_webhook_signature,
)
from apps.payments.serializers import (
    RAZORPAY_ORDER_ID_PATTERN,
    RAZORPAY_PAYMENT_ID_PATTERN,
    SIGNATURE_PATTERN,
)

FAKE = "apps.payments.gateways.FakeRazorpayGateway"
RAZORPAY = "apps.payments.gateways.RazorpayGateway"


class TestPublishedFakeScheme:
    """06 §2.6: how a dev build of the customer app pays without real keys. If one of these
    fails, the published scheme changed: update 06 and tell the customer app."""

    def test_published_constants(self):
        assert FAKE_KEY_ID == "rzp_fake_jivo_local"
        assert FAKE_KEY_SECRET == "jivo-fake-razorpay-key-secret-local-only"
        assert FAKE_WEBHOOK_SECRET == "jivo-fake-razorpay-webhook-secret-local-only"

    def test_signature_is_razorpays_algorithm(self):
        """hex(HMAC-SHA256(key_secret, "<order_id>|<payment_id>")), as Razorpay documents."""
        message = b"order_Nq3uVxY7kL9pQe|pay_Nq3vA1bC2dE3fG"
        expected = hmac.new(FAKE_KEY_SECRET.encode(), message, hashlib.sha256).hexdigest()
        assert (
            razorpay_payment_signature(
                FAKE_KEY_SECRET, "order_Nq3uVxY7kL9pQe", "pay_Nq3vA1bC2dE3fG"
            )
            == expected
        )

    def test_the_verify_example_is_a_worked_example(self):
        request = ex.VERIFY_REQUEST
        assert FakeRazorpayGateway().verify_payment_signature(
            order_id=request["razorpay_order_id"],
            payment_id=request["razorpay_payment_id"],
            signature=request["razorpay_signature"],
        )

    def test_the_example_matches_the_request_patterns(self):
        request = ex.VERIFY_REQUEST
        assert re.match(RAZORPAY_ORDER_ID_PATTERN, request["razorpay_order_id"])
        assert re.match(RAZORPAY_PAYMENT_ID_PATTERN, request["razorpay_payment_id"])
        assert re.match(SIGNATURE_PATTERN, request["razorpay_signature"])

    def test_a_client_made_payment_id_verifies(self):
        """The dev app makes up `pay_` + 14 letters/digits and signs it itself."""
        gateway = FakeRazorpayGateway()
        order = gateway.create_order(amount_paise=75300, receipt="JV-261103-000123", notes={})
        payment_id = "pay_DevClient00001"
        signature = razorpay_payment_signature(FAKE_KEY_SECRET, order.id, payment_id)
        assert gateway.verify_payment_signature(
            order_id=order.id, payment_id=payment_id, signature=signature
        )

    @pytest.mark.parametrize(
        ("order_id", "payment_id", "signature"),
        [
            ("order_Nq3uVxY7kL9pQe", "pay_Nq3vA1bC2dE3fG", "0" * 64),
            ("order_SomeOtherOrder", "pay_Nq3vA1bC2dE3fG", ex.VERIFY_REQUEST["razorpay_signature"]),
            (
                "order_Nq3uVxY7kL9pQe",
                "pay_SomeOtherPaymnt",
                ex.VERIFY_REQUEST["razorpay_signature"],
            ),
            ("order_Nq3uVxY7kL9pQe", "pay_Nq3vA1bC2dE3fG", ""),
        ],
    )
    def test_anything_else_is_refused(self, order_id, payment_id, signature):
        assert not FakeRazorpayGateway().verify_payment_signature(
            order_id=order_id, payment_id=payment_id, signature=signature
        )

    def test_signature_case_and_whitespace(self):
        signature = ex.VERIFY_REQUEST["razorpay_signature"]
        assert FakeRazorpayGateway().verify_payment_signature(
            order_id=ex.VERIFY_REQUEST["razorpay_order_id"],
            payment_id=ex.VERIFY_REQUEST["razorpay_payment_id"],
            signature=f" {signature.upper()} ",
        )

    def test_webhook_signature_covers_the_raw_body(self):
        gateway = FakeRazorpayGateway()
        body = b'{"event":"payment.captured","payload":{}}'
        signature = hmac.new(FAKE_WEBHOOK_SECRET.encode(), body, hashlib.sha256).hexdigest()
        assert razorpay_webhook_signature(FAKE_WEBHOOK_SECRET, body) == signature
        assert gateway.verify_webhook_signature(body, signature)
        assert not gateway.verify_webhook_signature(body + b" ", signature)
        assert not gateway.verify_webhook_signature(body, None)
        assert not gateway.verify_webhook_signature(body, "")


class TestFakeGateway:
    def test_create_order(self):
        order = FakeRazorpayGateway().create_order(
            amount_paise=75300, receipt="JV-261103-000123", notes={"order_id": 5012}
        )
        assert re.fullmatch(r"order_[A-Za-z0-9]{14}", order.id)
        assert re.match(RAZORPAY_ORDER_ID_PATTERN, order.id)
        assert (order.amount_paise, order.currency, order.receipt) == (
            75300,
            "INR",
            "JV-261103-000123",
        )

    def test_order_ids_are_unique(self):
        gateway = FakeRazorpayGateway()
        ids = {gateway.create_order(amount_paise=100, receipt="r", notes={}).id for _ in range(50)}
        assert len(ids) == 50

    def test_refund(self):
        refund = FakeRazorpayGateway().refund(
            payment_id="pay_Nq3vA1bC2dE3fG", amount_paise=75300, notes={}, receipt="k1"
        )
        assert refund.id.startswith("rfnd_")
        again = FakeRazorpayGateway().refund(
            payment_id="pay_Nq3vA1bC2dE3fG", amount_paise=75300, notes={}, receipt="k1"
        )
        assert again.id == refund.id  # idempotent on the receipt, like Razorpay
        assert (refund.payment_id, refund.amount_paise, refund.status) == (
            "pay_Nq3vA1bC2dE3fG",
            75300,
            "processed",
        )

    def test_key_id(self):
        assert FakeRazorpayGateway().key_id == FAKE_KEY_ID

    def test_tests_use_the_fake(self):
        assert isinstance(get_gateway(), FakeRazorpayGateway)

    @pytest.mark.parametrize("environment", ["staging", "production"])
    def test_refuses_to_run_when_deployed(self, settings, environment):
        """Gunicorn/uvicorn never run system checks: the constructor refuses too."""
        settings.APP_ENVIRONMENT = environment
        with pytest.raises(ImproperlyConfigured, match=r"payments\.E001"):
            FakeRazorpayGateway()
        settings.PAYMENT_GATEWAY = FAKE
        with pytest.raises(ImproperlyConfigured):
            get_gateway()


class TestRazorpayGateway:
    def test_missing_keys_fail_loudly(self, settings):
        settings.RAZORPAY_KEY_ID = ""
        settings.RAZORPAY_KEY_SECRET = ""
        settings.RAZORPAY_WEBHOOK_SECRET = ""
        gateway = RazorpayGateway()
        with pytest.raises(ImproperlyConfigured, match="RAZORPAY_KEY_ID"):
            _ = gateway.key_id
        with pytest.raises(ImproperlyConfigured, match="RAZORPAY_KEY_SECRET"):
            gateway.verify_payment_signature(order_id="order_x", payment_id="pay_x", signature="0")
        with pytest.raises(ImproperlyConfigured, match="RAZORPAY_WEBHOOK_SECRET"):
            gateway.verify_webhook_signature(b"{}", "0")

    def test_signatures_use_the_configured_secrets(self, settings):
        settings.RAZORPAY_KEY_ID = "rzp_test_Example0000001"
        settings.RAZORPAY_KEY_SECRET = "test-key-secret"
        settings.RAZORPAY_WEBHOOK_SECRET = "test-webhook-secret"
        gateway = RazorpayGateway()
        assert gateway.key_id == "rzp_test_Example0000001"
        signature = razorpay_payment_signature("test-key-secret", "order_A", "pay_B")
        assert gateway.verify_payment_signature(
            order_id="order_A", payment_id="pay_B", signature=signature
        )
        # The fake's published secret is never accepted by the real gateway.
        fake_signature = razorpay_payment_signature(FAKE_KEY_SECRET, "order_A", "pay_B")
        assert not gateway.verify_payment_signature(
            order_id="order_A", payment_id="pay_B", signature=fake_signature
        )
        body = b'{"event":"payment.captured"}'
        assert gateway.verify_webhook_signature(
            body, razorpay_webhook_signature("test-webhook-secret", body)
        )
        assert not gateway.verify_webhook_signature(
            body, razorpay_webhook_signature(FAKE_WEBHOOK_SECRET, body)
        )

    def test_works_in_deployed_environments(self, settings):
        settings.APP_ENVIRONMENT = "production"
        settings.PAYMENT_GATEWAY = RAZORPAY
        assert isinstance(get_gateway(), RazorpayGateway)


# --------------------------------------------------------------------------- system check


def _payment_errors() -> set[str]:
    return {e.id for e in run_checks() if e.id.startswith("payments.")}


@pytest.mark.django_db
class TestPaymentGatewayCheck:
    @pytest.mark.parametrize("environment", ["staging", "production"])
    def test_deployed_environments_refuse_the_fake(self, settings, environment):
        settings.APP_ENVIRONMENT = environment
        settings.OTP_TEST_NUMBERS = {}
        settings.PAYMENT_GATEWAY = FAKE
        assert _payment_errors() == {"payments.E001"}

    @pytest.mark.parametrize("environment", ["staging", "production"])
    def test_deployed_environments_accept_razorpay(self, settings, environment):
        settings.APP_ENVIRONMENT = environment
        settings.OTP_TEST_NUMBERS = {}
        settings.PAYMENT_GATEWAY = RAZORPAY
        settings.RAZORPAY_KEY_ID = ""  # missing keys are not a check error (CI has none)
        assert _payment_errors() == set()

    @pytest.mark.parametrize("environment", ["local", "test"])
    def test_local_and_test_use_the_fake(self, settings, environment):
        settings.APP_ENVIRONMENT = environment
        settings.PAYMENT_GATEWAY = FAKE
        assert _payment_errors() == set()

    def test_unimportable_gateway(self, settings):
        settings.PAYMENT_GATEWAY = "apps.payments.gateways.NoSuchGateway"
        assert _payment_errors() == {"payments.E002"}

    def test_deployed_settings_default_to_razorpay(self, monkeypatch):
        """No PAYMENT_GATEWAY in the environment means the real gateway, never the fake."""
        monkeypatch.setenv("DJANGO_SECRET_KEY", "x" * 64)
        monkeypatch.setenv("DJANGO_ALLOWED_HOSTS", "api.example.test")
        monkeypatch.setenv("NUM_PROXIES", "1")
        for name in ("PAYMENT_GATEWAY", "OTP_TEST_NUMBERS", "SENTRY_DSN"):
            monkeypatch.delenv(name, raising=False)
        modules = (
            "config.settings.production",
            "config.settings.staging",
            "config.settings.deployed",
        )
        loaded = {}
        try:
            for name in ("config.settings.production", "config.settings.staging"):
                for module in modules:
                    sys.modules.pop(module, None)
                loaded[name] = importlib.import_module(name)
        finally:
            for module in modules:
                sys.modules.pop(module, None)
        for settings_module in loaded.values():
            assert settings_module.PAYMENT_GATEWAY == RAZORPAY
            assert settings_module.PAYMENT_GATEWAY not in gateways.FAKE_GATEWAYS


class TestNonAsciiSignatures:
    """Code review of R1: a non-ASCII signature must be a refusal, never a TypeError (500)."""

    @pytest.mark.parametrize("signature", ["é" * 64, "bc4bcc84é", "٣" * 64, " é "])
    def test_payment_signature(self, signature):
        assert not FakeRazorpayGateway().verify_payment_signature(
            order_id=ex.VERIFY_REQUEST["razorpay_order_id"],
            payment_id=ex.VERIFY_REQUEST["razorpay_payment_id"],
            signature=signature,
        )

    @pytest.mark.parametrize("signature", ["é" * 64, "٣" * 64])
    def test_webhook_signature(self, signature):
        assert not FakeRazorpayGateway().verify_webhook_signature(b"{}", signature)


@pytest.mark.django_db
class TestRazorpayKeysCheck:
    """payments.E003 (code review of R1): `check --deploy` flags a real deployment of the
    Razorpay gateway without keys; CI's dry run (example.com hosts, no keys) stays green."""

    def errors(self, settings, *, environment="production", hosts=("api.jivo.in",), **keys):
        settings.APP_ENVIRONMENT = environment
        settings.OTP_TEST_NUMBERS = {}
        settings.PAYMENT_GATEWAY = RAZORPAY
        settings.ALLOWED_HOSTS = list(hosts)
        for name in ("RAZORPAY_KEY_ID", "RAZORPAY_KEY_SECRET", "RAZORPAY_WEBHOOK_SECRET"):
            setattr(settings, name, keys.get(name, ""))
        return [e for e in run_checks(include_deployment_checks=True) if e.id == "payments.E003"]

    @pytest.mark.parametrize("environment", ["staging", "production"])
    def test_missing_keys_on_a_real_deployment(self, settings, environment):
        errors = self.errors(settings, environment=environment, RAZORPAY_KEY_ID="rzp_live_x")
        assert len(errors) == 1
        assert "RAZORPAY_KEY_SECRET, RAZORPAY_WEBHOOK_SECRET" in errors[0].msg

    def test_all_keys_set(self, settings):
        keys = {"RAZORPAY_KEY_ID": "a", "RAZORPAY_KEY_SECRET": "b", "RAZORPAY_WEBHOOK_SECRET": "c"}
        assert self.errors(settings, **keys) == []

    @pytest.mark.parametrize(
        "hosts",
        [
            ("api.example.com",),
            ("example.org", "x.example.net"),
            ("api.jivo.test",),
            ("a.invalid",),
        ],
    )
    def test_dry_run_hosts_are_skipped(self, settings, hosts):
        assert self.errors(settings, hosts=hosts) == []

    @pytest.mark.parametrize(
        "hosts", [("api.example.com", "api.jivo.in"), ("*",), ("myexample.com",)]
    )
    def test_a_real_host_is_never_a_dry_run(self, settings, hosts):
        assert len(self.errors(settings, hosts=hosts)) == 1

    @pytest.mark.parametrize("environment", ["local", "test"])
    def test_not_outside_deployed_environments(self, settings, environment):
        assert self.errors(settings, environment=environment) == []

    def test_not_for_the_fake_gateway(self, settings):
        self.errors(settings)
        settings.PAYMENT_GATEWAY = FAKE  # refused by payments.E001 instead
        ids = {e.id for e in run_checks(include_deployment_checks=True)}
        assert "payments.E003" not in ids
        assert "payments.E001" in ids

    def test_only_with_deploy_checks(self, settings):
        self.errors(settings)
        assert not [e for e in run_checks() if e.id == "payments.E003"]
