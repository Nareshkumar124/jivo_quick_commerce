"""seed_demo step (idempotent): opening stock at the demo store, through the ledger.

Only rows that have never had a movement get their opening INWARD, so re-runs add nothing.
`JV-MUS-KG-1L` is sold but out of stock, `JV-CAN-CP-5L` and `JV-OLV-POM-5L` are low (2 left),
and `JV-PMP-200` is not sold at the store at all (the product is hidden there).
"""

from apps.catalog.models import ProductVariant
from apps.inventory.models import MovementType, StockMovement
from apps.inventory.services import adjust_stock, ensure_inventory
from apps.stores.models import DarkStore
from apps.stores.seed import DEMO_STORE_CODE

OPENING = {"JV-MUS-KG-1L": 0, "JV-CAN-CP-5L": 2, "JV-OLV-POM-5L": 2}
DEFAULT_OPENING = 40
NOT_SOLD = {"JV-PMP-200"}


def seed_stock(stdout, options) -> None:
    store = DarkStore.objects.get(code=DEMO_STORE_CODE)
    added = 0
    for variant in ProductVariant.objects.filter(sku__startswith="JV-").order_by("pk"):
        if variant.sku in NOT_SOLD:
            continue
        ensure_inventory(store, variant)
        if StockMovement.objects.filter(store=store, variant=variant).exists():
            continue
        quantity = OPENING.get(variant.sku, DEFAULT_OPENING)
        if quantity:
            adjust_stock(
                store=store,
                variant=variant,
                delta=quantity,
                movement_type=MovementType.INWARD,
                reason="seed_demo opening stock",
            )
            added += 1
    stdout.write(f"  stock at {store.code}: {added} opening inward movements")
