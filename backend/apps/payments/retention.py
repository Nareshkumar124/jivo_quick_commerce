"""T-814 (M4, DL-60 ⚠ Jivo): personal data in stored gateway payloads.

`Payment.raw` and `PaymentWebhookEvent.payload` keep what the gateway sent, which helps with
disputes for a while. After `PAYMENT_PAYLOAD_RETENTION_DAYS` (default 90) the personal fields
are removed (contact, email, VPA, card and address details, wherever they are nested); ids,
amounts, statuses, methods and error codes stay. Runs as a batched beat job; idempotent (each
row is stamped `pii_scrubbed_at` and never selected again).
"""

import logging
from datetime import timedelta

from celery import shared_task
from django.conf import settings
from django.db import transaction
from django.utils import timezone

logger = logging.getLogger(__name__)

# Keys removed at any depth. Razorpay puts the payer's details on the payment entity
# (`contact`, `email`, `vpa`, `card`, `upi`) and sometimes on `customer_details` / addresses.
PII_KEYS = frozenset(
    {
        "contact",
        "email",
        "vpa",
        "card",
        "upi",
        "customer_details",
        "billing_address",
        "shipping_address",
        "phone",
        "name",
    }
)


def scrub(value):
    """A copy of `value` (JSON) without `PII_KEYS` at any depth."""
    if isinstance(value, dict):
        return {key: scrub(item) for key, item in value.items() if key not in PII_KEYS}
    if isinstance(value, list):
        return [scrub(item) for item in value]
    return value


def scrub_payment_payloads(now=None, batch: int | None = None) -> dict:
    """One batch of each model (oldest first). Returns how many rows were scrubbed."""
    from apps.payments.models import Payment, PaymentWebhookEvent

    now = now or timezone.now()
    batch = batch or settings.PAYMENT_PAYLOAD_SCRUB_BATCH
    cutoff = now - timedelta(days=settings.PAYMENT_PAYLOAD_RETENTION_DAYS)
    counts = {}
    for model, field in ((Payment, "raw"), (PaymentWebhookEvent, "payload")):
        with transaction.atomic():
            rows = list(
                model.objects.select_for_update(skip_locked=True)
                .filter(created_at__lt=cutoff, pii_scrubbed_at__isnull=True)
                .order_by("created_at", "pk")[:batch]
            )
            for row in rows:
                setattr(row, field, scrub(getattr(row, field)))
                row.pii_scrubbed_at = now
            model.objects.bulk_update(rows, [field, "pii_scrubbed_at"])
        counts[model._meta.model_name] = len(rows)
    return counts


@shared_task(name="payments.scrub_payment_payloads")
def scrub_payment_payloads_task() -> dict:
    """Beat, daily: scrubs batches until a batch comes back short (bounded per run)."""
    total: dict[str, int] = {}
    for _ in range(100):
        counts = scrub_payment_payloads()
        for name, count in counts.items():
            total[name] = total.get(name, 0) + count
        if all(count < settings.PAYMENT_PAYLOAD_SCRUB_BATCH for count in counts.values()):
            break
    logger.info("Payment payloads scrubbed: %s", total)
    return total
