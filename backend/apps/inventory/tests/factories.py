from apps.inventory.models import MovementType, StoreInventory
from apps.inventory.services import adjust_stock, ensure_inventory


def stock(store, variant, quantity: int, *, reserved: int = 0) -> StoreInventory:
    """Put `variant` on sale at `store` with `quantity` on hand (through the ledger) and
    optionally `reserved` units held (orders arrive in Phase 3, so tests set it directly)."""
    ensure_inventory(store, variant)
    if quantity:
        adjust_stock(
            store=store,
            variant=variant,
            delta=quantity,
            movement_type=MovementType.INWARD,
            reason="test stock",
        )
    inventory = StoreInventory.objects.get(store=store, variant=variant)
    if reserved:
        inventory.reserved = reserved
        inventory.save(update_fields=["reserved"])
    return inventory
