"""Payment gateway behind one small interface (DL-21, D-01): Razorpay by default, Cashfree as the
named alternative. `PAYMENT_GATEWAY` (a dotted path) picks the implementation.

- `RazorpayGateway`: the real gateway (Razorpay REST API v1, HTTPS + basic auth, standard
  library only). Keys come only from the environment (`RAZORPAY_KEY_ID`, `RAZORPAY_KEY_SECRET`,
  `RAZORPAY_WEBHOOK_SECRET`). Missing keys fail loudly when it is used, never silently. Network
  and HTTP errors raise `PaymentGatewayError` (no key or secret in the message).
- `FakeRazorpayGateway`: local development and tests only. No network, no keys. It uses
  Razorpay's own signature algorithms with **published, dev-only** constants, so a dev build of
  the customer app can produce a payment that `POST /payments/razorpay/verify/` accepts without
  real keys (scheme in `docs/06-backend-modules-and-api.md` §2.6). Deployed environments refuse
  it twice: the system check `payments.E001` and this class's constructor.

The server decides payment success (08 §4): a valid signature on verify, or a signed webhook.
The amount always comes from the server-side order, never from the client.
"""

import base64
import hashlib
import hmac
import json
import secrets
import string
import urllib.error
import urllib.parse
import urllib.request
from abc import ABC, abstractmethod
from dataclasses import dataclass, field
from decimal import Decimal

from django.conf import settings
from django.core.exceptions import ImproperlyConfigured
from django.utils.module_loading import import_string

DEPLOYED_ENVIRONMENTS = frozenset({"staging", "production"})
RAZORPAY_API_BASE = "https://api.razorpay.com/v1"
# Orders API per-order capture settings (they override the Dashboard's): capture automatically;
# an authorised payment not captured within 12 minutes (the documented minimum, inside our
# 15-minute payment window) is not captured later and Razorpay refunds it.
AUTO_CAPTURE = {
    "capture": "automatic",
    "capture_options": {
        "automatic_expiry_period": 12,
        "manual_expiry_period": 12,
        "refund_speed": "normal",
    },
}
_ID_ALPHABET = string.ascii_letters + string.digits


def to_paise(amount) -> int:
    """₹753.00 -> 75300. Amounts are already rounded to the paisa (08 §6.2)."""
    return int((Decimal(amount) * 100).to_integral_value())


class PaymentGatewayError(Exception):
    """The gateway call did not succeed. API callers answer 503 `SERVICE_UNAVAILABLE`."""


class GatewayUnavailable(PaymentGatewayError):
    """Network error, timeout or a 5xx: transient, safe to retry (Celery tasks retry these)."""


class PaymentGatewayRejected(PaymentGatewayError):
    """A 4xx: the gateway refused the request. Retrying the same request cannot help."""

    def __init__(self, message: str, *, status: int = 400, description: str = "") -> None:
        super().__init__(message)
        self.status = status
        self.description = description

    @property
    def already_done(self) -> bool:
        """The refund was made before (a repeated receipt) or the payment is fully refunded:
        look the refund up instead of failing. A fallback only: the task's lookup before the POST
        is the guard, and Razorpay refusing a repeated refund receipt is assumed from its docs
        (confirm in Razorpay test mode)."""
        text = self.description.lower()
        return "duplicate receipt" in text or "refunded already" in text


@dataclass(frozen=True)
class GatewayOrder:
    """An order created at the gateway; the app's checkout pays it."""

    id: str  # e.g. "order_Nq3uVxY7kL9pQe"
    amount_paise: int
    currency: str
    receipt: str  # our order number


@dataclass(frozen=True)
class GatewayPayment:
    """A payment attempt on a gateway order, as the gateway reports it."""

    id: str  # e.g. "pay_Nq3vA1bC2dE3fG"
    order_id: str
    amount_paise: int
    status: str  # Razorpay: created / authorized / captured / failed / refunded
    method: str = ""  # upi / card / netbanking / wallet
    raw: dict = field(default_factory=dict)


@dataclass(frozen=True)
class GatewayRefund:
    id: str  # e.g. "rfnd_..."
    payment_id: str
    amount_paise: int
    status: str  # pending / processed / failed
    receipt: str = ""


def refund_receipt(key: str) -> str:
    """The refund `receipt` (at most 40 characters): how `process_refund` recognises its own
    refund among the payment's refunds at the gateway. Razorpay's docs also say a repeated
    refund receipt is refused ("Duplicate receipt"); assumed, confirm in Razorpay test mode."""
    return key if len(key) <= 40 else "rk_" + hashlib.sha256(key.encode()).hexdigest()[:37]


def razorpay_payment_signature(secret: str, order_id: str, payment_id: str) -> str:
    """Razorpay's checkout signature: hex HMAC-SHA256 of `"<order_id>|<payment_id>"`, keyed
    with the key secret."""
    message = f"{order_id}|{payment_id}".encode()
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()


def razorpay_webhook_signature(secret: str, body: bytes) -> str:
    """Razorpay's webhook signature (`X-Razorpay-Signature`): hex HMAC-SHA256 of the raw request
    body bytes, keyed with the webhook secret."""
    return hmac.new(secret.encode(), body, hashlib.sha256).hexdigest()


def _matches(expected: str, given: str | None) -> bool:
    """Constant-time comparison of hex signatures. Anything that is not ASCII is refused first:
    `hmac.compare_digest` raises `TypeError` on non-ASCII `str`, which would turn a forged
    header into a 500 instead of a 400 (code review of R1)."""
    if not given or not given.isascii():
        return False
    return hmac.compare_digest(expected.encode("ascii"), given.strip().lower().encode("ascii"))


class PaymentGateway(ABC):
    """What the order and payment services need from a gateway."""

    #: `Payment.gateway` value (07 §2.7).
    code = "RAZORPAY"

    @property
    @abstractmethod
    def key_id(self) -> str:
        """The public key the app's checkout is opened with."""

    @abstractmethod
    def create_order(self, *, amount_paise: int, receipt: str, notes: dict) -> GatewayOrder:
        """Create a gateway order for exactly `amount_paise` (from the server-side order)."""

    @abstractmethod
    def fetch_order_payments(self, gateway_order_id: str) -> list[GatewayPayment]:
        """Every payment attempt on a gateway order. `expire_unpaid_orders` calls it before
        failing an order, in case a capture webhook was missed (08 §4 rule 3)."""

    @abstractmethod
    def refund(
        self, *, payment_id: str, amount_paise: int, notes: dict, receipt: str
    ) -> GatewayRefund:
        """Refund to the original payment (08 §4 rule 4; T3a late captures). `receipt` identifies
        the refund at the gateway (`refund_receipt()`)."""

    @abstractmethod
    def fetch_payment_refunds(self, payment_id: str) -> list[GatewayRefund]:
        """Every refund of a payment, to find one made before (a repeated receipt)."""

    @abstractmethod
    def _key_secret(self) -> str: ...

    @abstractmethod
    def _webhook_secret(self) -> str: ...

    def verify_payment_signature(self, *, order_id: str, payment_id: str, signature: str) -> bool:
        """True when the checkout's `razorpay_signature` matches this order and payment."""
        expected = razorpay_payment_signature(self._key_secret(), order_id, payment_id)
        return _matches(expected, signature)

    def verify_webhook_signature(self, body: bytes, signature: str | None) -> bool:
        """True when `X-Razorpay-Signature` matches the raw body."""
        expected = razorpay_webhook_signature(self._webhook_secret(), body)
        return _matches(expected, signature)


class RazorpayGateway(PaymentGateway):
    """The real Razorpay gateway (test keys on staging, live keys in production)."""

    def _setting(self, name: str) -> str:
        value = getattr(settings, name, "")
        if not value:
            # Fails loudly (a 500 and Sentry), never a silent success: no checkout works
            # without keys (D-01). Deployed environments set them per environment.
            raise ImproperlyConfigured(f"{name} is not set: Razorpay payments cannot work.")
        return value

    @property
    def key_id(self) -> str:
        return self._setting("RAZORPAY_KEY_ID")

    def _key_secret(self) -> str:
        return self._setting("RAZORPAY_KEY_SECRET")

    def _webhook_secret(self) -> str:
        return self._setting("RAZORPAY_WEBHOOK_SECRET")

    def _call(self, method: str, path: str, body: dict | None = None) -> dict:
        token = base64.b64encode(f"{self.key_id}:{self._key_secret()}".encode()).decode()
        request = urllib.request.Request(  # noqa: S310 - fixed https base URL
            f"{RAZORPAY_API_BASE}{path}",
            data=json.dumps(body).encode() if body is not None else None,
            method=method,
            headers={"Authorization": f"Basic {token}", "Content-Type": "application/json"},
        )
        try:
            with urllib.request.urlopen(  # noqa: S310 - fixed https base URL
                request, timeout=settings.RAZORPAY_TIMEOUT_SECONDS
            ) as response:
                return json.loads(response.read() or b"{}")
        except urllib.error.HTTPError as exc:
            message = f"Razorpay {method} {path}: HTTP {exc.code}"
            if 400 <= exc.code < 500:
                raise PaymentGatewayRejected(
                    message, status=exc.code, description=_error_description(exc)
                ) from exc
            raise GatewayUnavailable(message) from exc
        except (urllib.error.URLError, TimeoutError, OSError, ValueError) as exc:
            raise GatewayUnavailable(f"Razorpay {method} {path}: {type(exc).__name__}") from exc

    def create_order(self, *, amount_paise: int, receipt: str, notes: dict) -> GatewayOrder:
        data = self._call(
            "POST",
            "/orders",
            {
                "amount": amount_paise,
                "currency": "INR",
                "receipt": receipt,
                "notes": notes,
                # PM decision (code review Minor 5): every order auto-captures, so a payment the
                # checkout reports as successful is captured, not just authorised.
                "payment": AUTO_CAPTURE,
            },
        )
        return GatewayOrder(
            id=data["id"],
            amount_paise=data["amount"],
            currency=data.get("currency", "INR"),
            receipt=data.get("receipt", receipt),
        )

    def fetch_order_payments(self, gateway_order_id: str) -> list[GatewayPayment]:
        data = self._call("GET", f"/orders/{urllib.parse.quote(gateway_order_id)}/payments")
        return [
            GatewayPayment(
                id=item["id"],
                order_id=item.get("order_id", gateway_order_id),
                amount_paise=item["amount"],
                status=item["status"],
                method=item.get("method") or "",
                raw=item,
            )
            for item in data.get("items", [])
        ]

    def refund(
        self, *, payment_id: str, amount_paise: int, notes: dict, receipt: str
    ) -> GatewayRefund:
        data = self._call(
            "POST",
            f"/payments/{urllib.parse.quote(payment_id)}/refund",
            {"amount": amount_paise, "notes": notes, "speed": "normal", "receipt": receipt},
        )
        return _gateway_refund(data, payment_id)

    def fetch_payment_refunds(self, payment_id: str) -> list[GatewayRefund]:
        # Razorpay pages 10 by default; 100 is its maximum per request.
        data = self._call("GET", f"/payments/{urllib.parse.quote(payment_id)}/refunds?count=100")
        return [_gateway_refund(item, payment_id) for item in data.get("items", [])]


def _gateway_refund(data: dict, payment_id: str) -> GatewayRefund:
    return GatewayRefund(
        id=data["id"],
        payment_id=data.get("payment_id", payment_id),
        amount_paise=data["amount"],
        status=data.get("status", "pending"),
        receipt=data.get("receipt") or "",
    )


def _error_description(exc: urllib.error.HTTPError) -> str:
    """Razorpay's `{"error": {"description": ...}}`, if the body has one."""
    try:
        return str(json.loads(exc.read() or b"{}").get("error", {}).get("description", ""))
    except (ValueError, OSError, AttributeError):
        return ""


# --------------------------------------------------------------------------- fake (local/test)
# Published on purpose (06 §2.6, "Fake payment gateway"): these are not secrets. They only work
# with FakeRazorpayGateway, which deployed environments refuse (payments.E001 + constructor).
FAKE_KEY_ID = "rzp_fake_jivo_local"
FAKE_KEY_SECRET = "jivo-fake-razorpay-key-secret-local-only"  # noqa: S105 - published fake
FAKE_WEBHOOK_SECRET = "jivo-fake-razorpay-webhook-secret-local-only"  # noqa: S105 - published


def _fake_id(prefix: str) -> str:
    return prefix + "".join(secrets.choice(_ID_ALPHABET) for _ in range(14))


class FakeRazorpayGateway(PaymentGateway):
    """Razorpay without the network, for local development and tests. Never deployed."""

    def __init__(self) -> None:
        if settings.APP_ENVIRONMENT in DEPLOYED_ENVIRONMENTS:
            raise ImproperlyConfigured(
                f"FakeRazorpayGateway is not allowed in {settings.APP_ENVIRONMENT} "
                "(payments.E001). Set PAYMENT_GATEWAY to the Razorpay gateway."
            )

    @property
    def key_id(self) -> str:
        return FAKE_KEY_ID

    def _key_secret(self) -> str:
        return FAKE_KEY_SECRET

    def _webhook_secret(self) -> str:
        return FAKE_WEBHOOK_SECRET

    @staticmethod
    def _check_up() -> None:
        """`FAKE_GATEWAY_DOWN` (local development only, P3-TC-63): every gateway call fails as
        if Razorpay could not be reached, so the "payment unavailable" paths can be tried."""
        if getattr(settings, "FAKE_GATEWAY_DOWN", False):
            raise GatewayUnavailable("Fake gateway is down (FAKE_GATEWAY_DOWN).")

    def verify_payment_signature(self, *, order_id: str, payment_id: str, signature: str) -> bool:
        self._check_up()
        return super().verify_payment_signature(
            order_id=order_id, payment_id=payment_id, signature=signature
        )

    def create_order(self, *, amount_paise: int, receipt: str, notes: dict) -> GatewayOrder:
        self._check_up()
        return GatewayOrder(
            id=_fake_id("order_"), amount_paise=amount_paise, currency="INR", receipt=receipt
        )

    def fetch_order_payments(self, gateway_order_id: str) -> list[GatewayPayment]:
        """The fake has no payment service: it reports the captures the server itself learnt
        (through verify or a signed webhook). A dev payment never verified is never captured."""
        from apps.payments.models import Payment, PaymentAttemptStatus

        self._check_up()

        return [
            GatewayPayment(
                id=payment.gateway_payment_id,
                order_id=gateway_order_id,
                amount_paise=to_paise(payment.amount),
                status="captured",
                method=payment.method,
            )
            for payment in Payment.objects.filter(
                gateway_order_id=gateway_order_id, status=PaymentAttemptStatus.CAPTURED
            ).exclude(gateway_payment_id=None)
        ]

    def refund(
        self, *, payment_id: str, amount_paise: int, notes: dict, receipt: str
    ) -> GatewayRefund:
        """Processed at once. Idempotent on `receipt` like Razorpay: the same receipt always
        gives the same refund id."""
        self._check_up()
        digest = hashlib.sha256(f"{payment_id}|{receipt}".encode()).hexdigest()[:14]
        return GatewayRefund(
            id=f"rfnd_{digest}",
            payment_id=payment_id,
            amount_paise=amount_paise,
            status="processed",
            receipt=receipt,
        )

    def fetch_payment_refunds(self, payment_id: str) -> list[GatewayRefund]:
        """The refunds the server recorded for this payment (the fake keeps no state)."""
        from apps.payments.models import Refund

        self._check_up()

        return [
            GatewayRefund(
                id=refund.gateway_refund_id,
                payment_id=payment_id,
                amount_paise=to_paise(refund.amount),
                status="processed",
                receipt=refund_receipt(refund.idempotency_key),
            )
            for refund in Refund.objects.filter(payment__gateway_payment_id=payment_id).exclude(
                gateway_refund_id=""
            )
        ]


# Gateways that move no money. Refused in deployed environments (payments.E001).
FAKE_GATEWAYS = frozenset({"apps.payments.gateways.FakeRazorpayGateway"})


def get_gateway() -> PaymentGateway:
    return import_string(settings.PAYMENT_GATEWAY)()
