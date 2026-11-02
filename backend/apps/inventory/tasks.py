"""Inventory Celery tasks. All idempotent and safe to retry."""

import logging

from celery import shared_task

from apps.inventory.models import StoreInventory

logger = logging.getLogger(__name__)


@shared_task(name="inventory.low_stock_alert")
def low_stock_alert(store_id: int, variant_id: int) -> str:
    """06 §5 `low_stock_alert`: warn when available falls below the row's threshold.

    Phase 2 logs a warning (ops log / Sentry); Phase 7 notifies the store manager. It re-checks
    the current stock, so a late or repeated run never alerts on stock that has recovered.
    """
    inventory = (
        StoreInventory.objects.select_related("variant", "store")
        .filter(store_id=store_id, variant_id=variant_id)
        .first()
    )
    if inventory is None or inventory.available >= inventory.low_stock_threshold:
        return "skipped"
    logger.warning(
        "Low stock: store=%s sku=%s available=%s threshold=%s",
        inventory.store.code,
        inventory.variant.sku,
        inventory.available,
        inventory.low_stock_threshold,
    )
    return "alerted"
