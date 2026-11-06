"""Example payloads for the Phase 3 payment contract.

`VERIFY_REQUEST` is also the worked example of the dev-only fake gateway scheme (06 §2.6): its
signature is hex HMAC-SHA256 of "order_Nq3uVxY7kL9pQe|pay_Nq3vA1bC2dE3fG" keyed with the
published fake key secret, so `FakeRazorpayGateway` accepts it (checked by
apps/payments/tests/test_gateways.py).
"""

from apps.orders.examples import GATEWAY_ORDER_ID

PAYMENT_ID = "pay_Nq3vA1bC2dE3fG"
VERIFY_REQUEST = {
    "order_id": 5012,
    "razorpay_order_id": GATEWAY_ORDER_ID,
    "razorpay_payment_id": PAYMENT_ID,
    "razorpay_signature": "bc4bcc84a495aaddc2f52819146edd4d26728c1221e5621f23995c106721c977",
}

WEBHOOK_PAYMENT_CAPTURED = {
    "entity": "event",
    "account_id": "acc_EXAMPLEEXAMPLE",
    "event": "payment.captured",
    "contains": ["payment"],
    "payload": {
        "payment": {
            "entity": {
                "id": PAYMENT_ID,
                "entity": "payment",
                "amount": 75300,
                "currency": "INR",
                "status": "captured",
                "order_id": GATEWAY_ORDER_ID,
                "method": "upi",
                "captured": True,
                "notes": {"order_number": "JV-261103-000123"},
            }
        }
    },
    "created_at": 1793687525,
}
WEBHOOK_PAYMENT_FAILED = {
    **WEBHOOK_PAYMENT_CAPTURED,
    "event": "payment.failed",
    "payload": {
        "payment": {
            "entity": {
                "id": "pay_Nq3wQ9rS8tU7vW",
                "entity": "payment",
                "amount": 75300,
                "currency": "INR",
                "status": "failed",
                "order_id": GATEWAY_ORDER_ID,
                "method": "card",
                "captured": False,
                "error_code": "BAD_REQUEST_ERROR",
                "error_description": "Payment failed due to insufficient balance.",
            }
        }
    },
}

ACK_PROCESSED = {"status": "processed"}
ACK_DUPLICATE = {"status": "duplicate"}
ACK_IGNORED = {"status": "ignored"}
