"""Local development only: pay the open COD UPI QR of an order, as if the customer had scanned it.

    uv run python manage.py fake_cod_qr_payment JV-261110-001203 [--amount 1.00]

Builds the `qr_code.credited` event the gateway would send and processes it through the webhook
service (idempotent on the event id). Refused unless the fake payment gateway is configured, so
it can never touch a real gateway. `--amount` sends a different amount (to try the refund path).
"""

import secrets
from decimal import Decimal

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError

from apps.delivery.choices import CodQrStatus
from apps.delivery.models import CodQr
from apps.payments.gateways import FAKE_GATEWAYS, to_paise


class Command(BaseCommand):
    help = "Pay an order's open COD UPI QR through the fake gateway (local development only)."

    def add_arguments(self, parser):
        parser.add_argument("order_number")
        parser.add_argument("--amount", default=None, help="Rupees; default: the QR amount.")

    def handle(self, *args, order_number: str, amount: str | None = None, **options):
        from apps.payments.services import handle_webhook

        if settings.PAYMENT_GATEWAY not in FAKE_GATEWAYS:
            raise CommandError("Only with the fake payment gateway (local development).")
        qr = (
            CodQr.objects.filter(order__order_number=order_number, status=CodQrStatus.PENDING)
            .order_by("-created_at")
            .first()
        )
        if qr is None:
            raise CommandError(f"No open UPI QR for order {order_number}.")
        paise = to_paise(Decimal(amount) if amount else qr.amount)
        payment_id = "pay_" + secrets.token_hex(7)
        event = {
            "entity": "event",
            "event": "qr_code.credited",
            "payload": {
                "qr_code": {"entity": {"id": qr.gateway_qr_id, "status": "closed"}},
                "payment": {
                    "entity": {
                        "id": payment_id,
                        "amount": paise,
                        "status": "captured",
                        "method": "upi",
                        "order_id": None,
                    }
                },
            },
        }
        result = handle_webhook(f"evt_fake_{secrets.token_hex(8)}", event)
        qr.refresh_from_db()
        self.stdout.write(f"{result}: QR {qr.gateway_qr_id} is {qr.status} ({payment_id}).")
