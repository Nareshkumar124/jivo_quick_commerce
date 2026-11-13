"""Set variants' volume (slab) prices from a small JSON file (ADR 0001), for
`manage.py set_price_tiers`. Each entry may also set the variant's `mrp` and `selling_price`.

File shape::

    {"variants": [
        {"sku": "JVW-WTR-1L-12", "mrp": "90.00", "selling_price": "90.00",
         "tiers": [{"min_order_units": 5, "price": "90.00"}, {"min_order_units": 25, ...}]}
    ]}

A listed variant ends with exactly the listed tiers (others are removed). Unchanged rows are not
saved, so a second run changes nothing. The whole file is applied in one transaction, and any
error leaves the database as it was; without `commit` the run is rolled back after validating.
"""

import json
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation
from pathlib import Path

from django.core.exceptions import ValidationError
from django.db import transaction

from apps.catalog.models import ProductVariant, VariantPriceTier

CENT = Decimal("0.01")


@dataclass
class TierRow:
    min_order_units: int
    price: Decimal


@dataclass
class VariantPlan:
    sku: str
    mrp: Decimal | None
    selling_price: Decimal | None
    tiers: list[TierRow]


@dataclass
class TierResult:
    lines: list[str] = field(default_factory=list)
    errors: list[str] = field(default_factory=list)
    committed: bool = False


def _money(value, where: str, errors: list[str]) -> Decimal | None:
    try:
        amount = Decimal(str(value))
    except (InvalidOperation, ValueError):
        errors.append(f"{where}: {value!r} is not an amount.")
        return None
    if not amount.is_finite() or amount <= 0 or amount != amount.quantize(CENT):
        errors.append(f"{where}: {value!r} must be above 0 with at most 2 decimals.")
        return None
    return amount


def read_plan(path: Path) -> tuple[list[VariantPlan], list[str]]:
    """Parse and check the file's shape and numbers (the database is checked when applying)."""
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
        mrp = _money(entry["mrp"], f"{where} mrp", errors) if "mrp" in entry else None
        selling = (
            _money(entry["selling_price"], f"{where} selling_price", errors)
            if "selling_price" in entry
            else None
        )
        tiers, units_seen = [], set()
        raw_tiers = entry.get("tiers")
        if not isinstance(raw_tiers, list):
            errors.append(f'{where}: "tiers" must be a list ([] removes every tier).')
            continue
        for tier in raw_tiers:
            units = tier.get("min_order_units") if isinstance(tier, dict) else None
            if isinstance(units, bool) or not isinstance(units, int) or not 1 <= units <= 32767:
                errors.append(f"{where}: min_order_units {units!r} must be a whole number >= 1.")
                continue
            if units in units_seen:
                errors.append(f"{where}: min_order_units {units} is listed twice.")
                continue
            units_seen.add(units)
            price = _money(tier.get("price"), f"{where} tier {units}", errors)
            if price is not None:
                tiers.append(TierRow(units, price))
        plans.append(VariantPlan(sku, mrp, selling, sorted(tiers, key=lambda t: t.min_order_units)))
    return plans, errors


def _describe(tiers) -> str:
    return ", ".join(f"{t.min_order_units}+: {t.price}" for t in tiers) or "none"


def _apply_one(plan: VariantPlan, result: TierResult) -> None:
    variant = ProductVariant.objects.select_for_update().filter(sku=plan.sku).first()
    if variant is None:
        result.errors.append(f"{plan.sku}: no variant with this SKU.")
        return
    new_mrp = plan.mrp if plan.mrp is not None else variant.mrp
    new_selling = plan.selling_price if plan.selling_price is not None else variant.selling_price
    above = [
        f"{plan.sku}: tier {tier.min_order_units} price {tier.price} is above the MRP {new_mrp}."
        for tier in plan.tiers
        if tier.price > new_mrp
    ]
    if new_selling > new_mrp:
        above.append(f"{plan.sku}: selling_price {new_selling} is above the MRP {new_mrp}.")
    if above:
        result.errors.extend(above)
        return
    # Tiers first, so the variant's MRP check sees the new tiers.
    current = {t.min_order_units: t for t in variant.price_tiers.all()}
    wanted = {t.min_order_units: t for t in plan.tiers}
    removed = [current[u] for u in current.keys() - wanted.keys()]
    for tier in removed:
        tier.delete()
    created = updated = 0
    for units, row in wanted.items():
        tier = current.get(units)
        if tier is None:
            VariantPriceTier.objects.create(variant=variant, min_order_units=units, price=row.price)
            created += 1
        elif tier.price != row.price:
            tier.price = row.price
            tier.save(update_fields=["price", "updated_at"])
            updated += 1
    price_note = "prices unchanged"
    if (new_mrp, new_selling) != (variant.mrp, variant.selling_price):
        price_note = (
            f"mrp {variant.mrp} -> {new_mrp}, selling_price {variant.selling_price} -> "
            f"{new_selling}"
        )
        variant.mrp, variant.selling_price = new_mrp, new_selling
        try:
            variant.full_clean()
        except ValidationError as error:
            result.errors.extend(
                f"{plan.sku}: {key}: {message}"
                for key, messages in error.message_dict.items()
                for message in messages
            )
            return
        variant.save(update_fields=["mrp", "selling_price", "updated_at"])
    result.lines.append(
        f"{plan.sku}: {price_note}; tiers {_describe(plan.tiers)} (created {created}, updated "
        f"{updated}, removed {len(removed)}, unchanged "
        f"{len(wanted) - created - updated})"
    )


def set_price_tiers(plans: list[VariantPlan], *, commit: bool) -> TierResult:
    """Apply `plans` in one transaction; roll back on any error, or when not `commit`."""
    result = TierResult()
    with transaction.atomic():
        for plan in plans:
            _apply_one(plan, result)
        if result.errors or not commit:
            transaction.set_rollback(True)
        else:
            result.committed = True
    return result
