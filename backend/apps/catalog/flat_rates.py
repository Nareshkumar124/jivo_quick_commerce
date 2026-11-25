"""Flat rates per variant (ADR 0002), for `manage.py set_flat_rates`: each listed variant gets
MRP = selling price = its rate (no false "% off") and loses every volume price tier
(`VariantPriceTier`, ADR 0001). The tier code stays; it just has no rows for these variants.

File shape::

    {"variants": [{"sku": "JVW-WTR-1L-12", "rate": "110.00"}, ...]}

Built on `apps.catalog.price_tiers` (a plan with no tiers removes them all): the whole file is
applied in one transaction, any error saves nothing, a dry run is rolled back after validating,
and a second run changes nothing. Store price overrides are left as they are and reported, as a
lower override would still win at that store.
"""

import json
from pathlib import Path

from apps.catalog.price_tiers import TierResult, VariantPlan, _money, set_price_tiers


def read_rates(path: Path) -> tuple[list[VariantPlan], list[str]]:
    """Parse and check the file (the database is checked when applying)."""
    errors: list[str] = []
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        return [], [f"Cannot read {path}: {error}"]
    entries = data.get("variants") if isinstance(data, dict) else None
    if not isinstance(entries, list) or not entries:
        return [], ['The file needs a non-empty "variants" list.']
    plans, seen = [], set()
    for index, entry in enumerate(entries, start=1):
        where = f"variants[{index}]"
        sku = entry.get("sku") if isinstance(entry, dict) else None
        if not isinstance(sku, str) or not sku.strip():
            errors.append(f"{where}: sku is required.")
            continue
        sku = sku.strip()
        where = f"{where} ({sku})"
        if sku in seen:
            errors.append(f"{where}: listed twice.")
            continue
        seen.add(sku)
        if "rate" not in entry:
            errors.append(f"{where}: rate is required.")
            continue
        rate = _money(entry["rate"], f"{where} rate", errors)
        if rate is not None:
            plans.append(VariantPlan(sku, mrp=rate, selling_price=rate, tiers=[]))
    return plans, errors


def override_notes(plans: list[VariantPlan]) -> list[str]:
    """Store price overrides still set on the listed variants (they win over the flat rate at
    that store when lower; the panel's inventory screen clears them)."""
    from apps.inventory.models import StoreInventory

    rows = (
        StoreInventory.objects.filter(
            variant__sku__in=[plan.sku for plan in plans], price_override__isnull=False
        )
        .select_related("store", "variant")
        .order_by("variant__sku", "store__code")
    )
    return [
        f"Note: {row.variant.sku} has a price override of {row.price_override} at store "
        f"{row.store.code}; it is not changed here."
        for row in rows
    ]


def set_flat_rates(plans: list[VariantPlan], *, commit: bool) -> TierResult:
    """Apply `plans` (MRP = selling price = rate, no tiers) in one transaction; roll back on any
    error, or when not `commit`."""
    result = set_price_tiers(plans, commit=commit)
    result.lines.extend(override_notes(plans))
    return result
