"""Shared set-up for the Phase 4 order screens: orders with lines, and stand-ins for the
backend's Phase 4 order services (not on this branch yet; `order_actions` calls them by name).
"""

import importlib
import sys
import types
from dataclasses import dataclass, field
from datetime import timedelta

import pytest
from django.db import models
from django.utils import timezone

from apps.catalog.tests.factories import VariantFactory
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
from apps.orders.choices import OrderStatus
from apps.orders.models import OrderItem
from apps.orders.tests.factories import OrderFactory

SERVICE_NAMES = (
    "accept_order",
    "start_packing",
    "mark_item_unavailable",
    "mark_packed",
    "cancel_by_staff",
)


def make_order(store, status=OrderStatus.PLACED, *, lines=1, age_minutes=1, **kwargs):
    """An order at `store` placed `age_minutes` ago with `lines` lines of 2 units each."""
    now = timezone.now()
    placed = now - timedelta(minutes=age_minutes)
    kwargs.setdefault("placed_at", placed)
    kwargs.setdefault("eta_at", placed + timedelta(minutes=30))
    kwargs.setdefault("pickup_code", "")
    order = OrderFactory(store=store, status=status, **kwargs)
    for _ in range(lines):
        variant = VariantFactory()
        OrderItem.objects.create(
            order=order,
            variant=variant,
            product=variant.product,
            product_name=variant.product.name,
            variant_name=variant.name,
            sku=variant.sku,
            mrp=variant.mrp,
            selling_price=variant.selling_price,
            quantity=2,
            line_total=variant.selling_price * 2,
        )
    return order


class StaffCancelReason(models.TextChoices):
    """Stand-in for `orders.choices.StaffCancelReason` (T12) until the backend's is on this
    branch; same codes, so the tests do not change after the merge."""

    ITEMS_UNAVAILABLE = "ITEMS_UNAVAILABLE", "Items are not available at the store"
    STORE_CLOSING = "STORE_CLOSING", "The store had to close"
    OTHER_STAFF = "OTHER_STAFF", "Cancelled by the store"


@dataclass
class FakeServices:
    """Records calls with the real `orders.store_ops` signatures:
    `name(order_id, *args, **kwargs)`, e.g. ("mark_item_unavailable", 7, (12,), {...})."""

    calls: list = field(default_factory=list)
    refuse_with: Exception | None = None

    def make(self, name):
        def service(order_id, *args, **kwargs):
            self.calls.append((name, order_id, args, kwargs))
            if self.refuse_with is not None:
                raise self.refuse_with
            return None

        return service


@pytest.fixture
def fake_services(monkeypatch):
    """Replace the `orders.store_ops` services with recording fakes (creating the module while
    the backend's is not on this branch) and make sure staff cancel reasons exist."""
    from apps.orders import choices

    try:
        store_ops = importlib.import_module("apps.orders.store_ops")
    except ModuleNotFoundError:
        store_ops = types.ModuleType("apps.orders.store_ops")
        monkeypatch.setitem(sys.modules, "apps.orders.store_ops", store_ops)
    fakes = FakeServices()
    for name in SERVICE_NAMES:
        monkeypatch.setattr(store_ops, name, fakes.make(name), raising=False)
    if not hasattr(choices, "StaffCancelReason"):
        monkeypatch.setattr(choices, "StaffCancelReason", StaffCancelReason, raising=False)
    return fakes


def invalid_transition() -> ApiError:
    return ApiError(ErrorCode.INVALID_STATE_TRANSITION, "This order is already packed.", details={})
