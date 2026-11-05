"""The backend's fake payment gateway (docs/06 §2.6), local and test servers only. Deployed
environments refuse that gateway (system check payments.E001), so on staging an ONLINE order
gets a real Razorpay test-mode checkout, which a script cannot pay: the flow then abandons it
(cancel, T5) instead."""

import hashlib
import hmac
import secrets
import string

FAKE_KEY_ID = "rzp_fake_jivo_local"
# Published, dev-only value: it only works with FakeRazorpayGateway (06 §2.6), never a secret.
FAKE_KEY_SECRET = "jivo-fake-razorpay-key-secret-local-only"  # noqa: S105
_ALPHABET = string.ascii_letters + string.digits


def is_fake_checkout(razorpay: dict | None) -> bool:
    return bool(razorpay) and razorpay.get("key_id") == FAKE_KEY_ID


def new_payment_id() -> str:
    return "pay_" + "".join(secrets.choice(_ALPHABET) for _ in range(14))


def signature(order_id: str, payment_id: str, secret: str = FAKE_KEY_SECRET) -> str:
    """Razorpay's own algorithm: hex HMAC-SHA256 of "<order_id>|<payment_id>"."""
    message = f"{order_id}|{payment_id}".encode()
    return hmac.new(secret.encode(), message, hashlib.sha256).hexdigest()
