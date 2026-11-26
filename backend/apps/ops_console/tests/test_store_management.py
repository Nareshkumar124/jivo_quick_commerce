# ruff: noqa: RUF001 - the size label with a multiplication sign is the user's own example
"""Store management pages (ADR 0004 §4): bottle prices, offers, delivery locations.

- Super Admin and superusers only: every other role gets 403 on every page and button (GET and
  POST), non-staff and signed-out visitors go to the login; nothing changes for them.
- Each button calls its backend service (the real ones; they write the audit log) behind a
  confirm dialog, and shows the service's message, refusals in plain words.
- The sidebar group "Store management" shows only for Super Admin (both sidebars).

The offers page also saves the ADR 0003 fields: the store's free carton size
(`PricingConfig.free_unit_variant`) and the reward quantities.
"""

import html
import json
from datetime import UTC, datetime, timedelta
from decimal import Decimal
from types import SimpleNamespace
from urllib.parse import unquote

import pytest
from django.contrib.auth.models import Permission
from django.contrib.gis.geos import MultiPolygon, Polygon
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.catalog.models import ProductVariant, VariantPriceTier
from apps.catalog.tests.factories import VariantFactory
from apps.core.models import AuditLog
from apps.inventory.models import StoreInventory
from apps.inventory.tests.factories import stock
from apps.ops_console import navigation
from apps.ops_console import store_management as sm
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    NON_STAFF,
    PRINCIPALS,
    ROLES,
    SUPERUSER,
    expected_status,
    login_as,
    make_principal,
)
from apps.promotions.choices import DiscountType
from apps.promotions.models import Coupon
from apps.referrals.models import ReferralSettings
from apps.stores.models import DeliveryPincode, PincodeBoundary, PricingConfig
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}
MANAGERS = frozenset({roles.SUPER_ADMIN, SUPERUSER})
THIS = "apps.ops_console.tests.test_store_management"

CALLS: list[tuple] = []


def stand_in(*args, **kwargs):
    """A stand-in service: records the call, reports a change."""
    CALLS.append((args, kwargs))
    return True


def page_text(response) -> str:
    return html.unescape(response.content.decode())


def toast(response) -> dict:
    return json.loads(response["HX-Trigger"])["ops:toast"]


def refusal_message(response) -> str:
    return unquote(response["X-Ops-Message"])


def outline(pincode: str) -> PincodeBoundary:
    shape = MultiPolygon(Polygon.from_bbox((77.10, 28.63, 77.13, 28.66)), srid=4326)
    return PincodeBoundary.objects.create(pincode=pincode, geom=shape, source="test")


@pytest.fixture
def world():
    store = DarkStoreFactory(code="GGN-01", name="Gurugram One")
    other = DarkStoreFactory(code="DEL-02", name="Delhi Two")
    water = VariantFactory(
        product__name="Jivo Water",
        name="1 L × 12",
        net_quantity="12 x 1 L",
        mrp=Decimal("110.00"),
        selling_price=Decimal("110.00"),
    )
    oil = VariantFactory(
        product__name="Jivo Oil",
        name="1 L",
        mrp=Decimal("299.00"),
        selling_price=Decimal("299.00"),
    )
    stock(store, water, 20)
    stock(store, oil, 5)
    stock(other, water, 5)
    StoreInventory.objects.filter(store=other, variant=water).update(
        price_override=Decimal("105.00")
    )
    coupon = Coupon.objects.create(
        code="JIVO50",
        title="Flat ₹50 off",
        discount_type=DiscountType.FLAT,
        value=Decimal("50.00"),
        min_order_value=Decimal("299.00"),
    )
    pin = DeliveryPincode.objects.create(store=store, pincode="110027", area_name="Rajouri Garden")
    return SimpleNamespace(store=store, other=other, water=water, oil=oil, coupon=coupon, pin=pin)


def pages(world) -> list[str]:
    return [
        reverse("ops:prices"),
        reverse("ops:offers"),
        reverse("ops:delivery"),
        reverse("ops:coupon-add"),
        reverse("ops:coupon-edit", args=[world.coupon.pk]),
        reverse("ops:pincode-add"),
        reverse("ops:pincode-edit", args=[world.pin.pk]),
    ]


def actions(world) -> list[tuple[str, dict]]:
    return [
        (reverse("ops:price-set", args=[world.water.pk]), {"price": "115"}),
        (
            reverse("ops:offer-volume", args=[world.store.pk]),
            {"enabled": "on", "every": "10", "free_variant": str(world.water.pk)},
        ),
        (reverse("ops:offer-rewards"), {"welcome": "2", "referral": "2"}),
        (
            reverse("ops:coupon-add"),
            {"code": "NEW10", "title": "New", "discount_type": "FLAT", "value": "10"},
        ),
        (
            reverse("ops:coupon-edit", args=[world.coupon.pk]),
            {"code": "JIVO50", "title": "Changed", "discount_type": "FLAT", "value": "50"},
        ),
        (reverse("ops:coupon-active", args=[world.coupon.pk]), {"active": "0"}),
        (
            reverse("ops:pincode-add"),
            {"store": str(world.store.pk), "pincode": "110018", "is_active": "on"},
        ),
        (
            reverse("ops:pincode-edit", args=[world.pin.pk]),
            {"pincode": "110027", "area_name": "Changed"},
        ),
        (reverse("ops:pincode-active", args=[world.pin.pk]), {"active": "0"}),
    ]


# --------------------------------------------------------------------------- role matrix


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_pages_open_only_for_super_admin(client, world, principal):
    login_as(client, principal)
    for url in pages(world):
        response = client.get(url)
        assert response.status_code == expected_status(principal, MANAGERS), (principal, url)


@pytest.mark.parametrize("principal", [p for p in PRINCIPALS if p not in MANAGERS])
@pytest.mark.parametrize("htmx", [False, True], ids=["plain", "htmx"])
def test_every_change_is_refused_for_other_roles(client, world, principal, htmx):
    """403 (or the login) on every button, and nothing changes: no service runs."""
    login_as(client, principal)
    for url, data in actions(world):
        response = client.post(url, data, **(HX if htmx else {}))
        if principal in (NON_STAFF, ANONYMOUS):
            assert response.status_code == (401 if htmx else 302), url
        else:
            assert response.status_code == 403, (principal, url)
            assert response["X-Ops-Refused"] == "1"
    world.water.refresh_from_db()
    world.coupon.refresh_from_db()
    world.pin.refresh_from_db()
    assert world.water.selling_price == Decimal("110.00")
    assert world.coupon.is_active
    assert world.coupon.title == "Flat ₹50 off"
    assert world.pin.is_active
    assert world.pin.area_name == "Rajouri Garden"
    assert not Coupon.objects.filter(code="NEW10").exists()
    assert not DeliveryPincode.objects.filter(pincode="110018").exists()
    assert not AuditLog.objects.exists()


def test_permission_alone_does_not_reach_other_stores(client, world):
    """A staff member given only the pincode permission (no role, so no stores) sees no store,
    and another store's pincode is a 404: the lookup is scoped, no service runs."""
    user = StaffUserFactory()
    user.user_permissions.add(Permission.objects.get(codename="manage_delivery_pincodes"))
    client.force_login(user)
    page = page_text(client.get(reverse("ops:delivery")))
    assert "110027" not in page
    assert client.get(reverse("ops:pincode-edit", args=[world.pin.pk])).status_code == 404
    response = client.post(reverse("ops:pincode-active", args=[world.pin.pk]), {"active": "0"})
    assert response.status_code == 404
    world.pin.refresh_from_db()
    assert world.pin.is_active


@pytest.mark.parametrize(
    "url_name", ["ops:price-set", "ops:coupon-active", "ops:pincode-active", "ops:offer-volume"]
)
def test_unknown_or_huge_ids_are_404(client, world, url_name):
    login_as(client, roles.SUPER_ADMIN)
    for object_id in (999999, int("9" * 19)):
        response = client.post(reverse(url_name, args=[object_id]), {"active": "1"}, **HX)
        assert response.status_code == 404, object_id


# --------------------------------------------------------------------------- sidebar


@pytest.mark.parametrize("principal", [*ROLES, SUPERUSER])
def test_ops_sidebar_group_only_for_super_admin(principal):
    sections = {
        section["title"]: [item["title"] for item in section["items"]]
        for section in navigation.visible_sections(make_principal(principal))
    }
    if principal in MANAGERS:
        assert sections["Store management"] == ["Bottle prices", "Offers", "Delivery locations"]
    else:
        assert "Store management" not in sections


@pytest.mark.parametrize("principal", [roles.SUPER_ADMIN, roles.OPS, roles.CATALOG_MANAGER])
def test_admin_sidebar_group_only_for_super_admin(client, principal):
    client.force_login(make_principal(principal))
    response = client.get(reverse("admin:index"))
    assert response.status_code == 200
    allowed = [
        item["title"]
        for group in response.context["sidebar_navigation"]
        if group["title"] == "Store management"
        for item in group["items"]
        if item["has_permission"]
    ]
    expected = ["Bottle prices", "Offers", "Delivery locations"]
    assert allowed == (expected if principal == roles.SUPER_ADMIN else [])


# --------------------------------------------------------------------------- bottle prices


def test_prices_page_shows_sizes_overrides_and_confirm_dialog(client, world):
    login_as(client, roles.SUPER_ADMIN)
    response = client.get(reverse("ops:prices"))
    assert response.status_code == 200
    page = page_text(response)
    assert "Orders already placed keep their price." in page
    row = page.split(f'data-testid="price-row-{world.water.pk}"')[1].split("</tr>")[0]
    assert "Jivo Water" in row
    assert "1 L × 12" in row
    assert "₹110.00" in row
    assert "DEL-02 ₹105.00" in row  # the store override is shown
    # The confirm dialog: old -> typed price, with the user's wording.
    assert (
        'data-confirm-template="₹110 → ₹{price} for Jivo Water 1 L × 12. Customers will see '
        'this at once. Orders already placed keep their price."'
    ) in row
    assert "hx-confirm=" in row
    assert 'data-confirm-title="Change the price?"' in row
    assert 'name="csrfmiddlewaretoken"' in row
    assert f'hx-post="{reverse("ops:price-set", args=[world.water.pk])}"' in row
    # The page has the one confirm dialog (Alpine store "confirm").
    assert 'id="ops-confirm-title"' in page
    # The sidebar marks the page.
    assert f'href="{reverse("ops:prices")}"' in page
    assert 'aria-current="page"' in page


def test_prices_search(client, world):
    login_as(client, roles.SUPER_ADMIN)
    page = page_text(client.get(reverse("ops:prices"), {"q": "oil"}))
    assert f"price-row-{world.oil.pk}" in page
    assert f"price-row-{world.water.pk}" not in page
    page = page_text(client.get(reverse("ops:prices"), {"q": "nothing like this"}))
    assert "No sizes match your search" in page


def test_save_price_calls_the_service(client, world):
    user = login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:price-set", args=[world.water.pk])
    response = client.post(url, {"price": "115"}, **HX)
    assert response.status_code == 204
    assert toast(response) == {
        "message": (
            "Jivo Water 1 L × 12 now costs ₹115 (was ₹110). Customers see the new price at once."
        ),
        "tone": "success",
    }
    assert json.loads(response["HX-Trigger"])["ops:refresh"] is True
    world.water.refresh_from_db()
    assert world.water.mrp == world.water.selling_price == Decimal("115.00")
    entry = AuditLog.objects.get(action="variant.price")
    assert entry.actor == user
    assert entry.object_id == str(world.water.pk)

    again = client.post(url, {"price": "115.00"}, **HX)
    assert again.status_code == 204
    assert toast(again)["tone"] == "info"
    assert "already costs ₹115" in toast(again)["message"]


@pytest.mark.parametrize("price", ["0", "-5", "12.345", "abc", "10001"])
def test_price_errors_are_plain_words(client, world, price):
    login_as(client, roles.SUPER_ADMIN)
    response = client.post(reverse("ops:price-set", args=[world.water.pk]), {"price": price}, **HX)
    assert response.status_code == 400
    assert refusal_message(response) == (
        "Enter a price above ₹0 and at most ₹10,000, with at most 2 decimals."
    )
    world.water.refresh_from_db()
    assert world.water.selling_price == Decimal("110.00")


def test_price_error_without_javascript_comes_back_as_a_message(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:price-set", args=[world.water.pk])
    response = client.post(url, {"price": ""}, follow=True)
    assert response.redirect_chain[-1][0] == reverse("ops:prices")
    assert 'data-tone="error">Enter the new price.</template>' in page_text(response)
    response = client.post(url, {"price": "120"}, follow=True)
    assert 'data-tone="success">Jivo Water 1 L × 12 now costs ₹120' in page_text(response)


def test_price_with_tiers_is_refused_and_explained(client, world):
    VariantPriceTier.objects.create(
        variant=world.water, min_order_units=10, price=Decimal("100.00")
    )
    login_as(client, roles.SUPER_ADMIN)
    page = page_text(client.get(reverse("ops:prices")))
    assert f'data-testid="tiers-{world.water.pk}"' in page
    assert f'data-testid="price-form-{world.water.pk}"' not in page
    response = client.post(reverse("ops:price-set", args=[world.water.pk]), {"price": "120"}, **HX)
    assert response.status_code == 400
    assert "Remove them first" in refusal_message(response)


def test_inactive_size_is_not_listed_or_priced(client, world):
    ProductVariant.objects.filter(pk=world.oil.pk).update(is_active=False)
    login_as(client, roles.SUPER_ADMIN)
    assert f"price-row-{world.oil.pk}" not in page_text(client.get(reverse("ops:prices")))
    response = client.post(reverse("ops:price-set", args=[world.oil.pk]), {"price": "1"}, **HX)
    assert response.status_code == 404


def test_missing_service_is_501_and_the_button_is_disabled(client, world, monkeypatch):
    monkeypatch.setitem(sm.SERVICES, sm.SET_PRICE, (THIS, "no_such_service"))
    login_as(client, roles.SUPER_ADMIN)
    response = client.post(reverse("ops:price-set", args=[world.water.pk]), {"price": "120"}, **HX)
    assert response.status_code == 501
    assert refusal_message(response) == "This action is not available yet."
    page = page_text(client.get(reverse("ops:prices")))
    form = page.split(f'data-testid="price-form-{world.water.pk}"')[1].split("</form>")[0]
    assert 'disabled title="Not available yet"' in form
    world.water.refresh_from_db()
    assert world.water.selling_price == Decimal("110.00")


def test_prices_page_query_count_does_not_grow(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:prices")
    client.get(url)  # warm the permission and session caches
    with CaptureQueriesContext(connection) as few:
        assert client.get(url).status_code == 200
    for index in range(12):
        variant = VariantFactory(
            product__name=f"Jivo Extra {index}",
            mrp=Decimal("200.00"),
            selling_price=Decimal("200.00"),
        )
        stock(world.other, variant, 1)
        StoreInventory.objects.filter(variant=variant).update(price_override=Decimal("150.00"))
        VariantPriceTier.objects.create(variant=variant, min_order_units=5, price=Decimal("180.00"))
    with CaptureQueriesContext(connection) as many:
        assert client.get(url).status_code == 200
    assert len(many) == len(few)


# --------------------------------------------------------------------------- offers


def test_offers_page_has_three_cards_and_confirm_dialogs(client, world):
    login_as(client, roles.SUPER_ADMIN)
    response = client.get(reverse("ops:offers"))
    assert response.status_code == 200
    page = page_text(response)
    for card in ("card-volume", "card-rewards", "card-coupons"):
        assert f'data-testid="{card}"' in page
    row = page.split(f'data-testid="coupon-{world.coupon.pk}"')[1].split("</tr>")[0]
    assert "JIVO50" in row
    assert "Flat ₹50 off" in row
    assert "₹50 off" in row
    assert "₹299.00" in row
    assert "Active" in row
    assert 'hx-confirm="Turn off JIVO50? Customers can no longer see or use it.' in row
    assert 'data-confirm-label="Disable"' in row
    assert 'data-testid="add-coupon"' in page
    assert 'data-testid="rewards-form"' in page
    assert "hx-confirm=" in page
    volume = page.split(f'data-testid="volume-{world.store.pk}"')[0].rsplit("<form", 1)[1]
    assert "data-confirm-on=" in volume
    assert "data-confirm-off=" in volume
    assert f'id="vol{world.store.pk}_free_variant"' in page  # the free size, per store
    assert 'id="id_welcome"' in page
    assert 'id="id_referral"' in page


def test_coupon_states(client, world):
    now = timezone.now()
    off = Coupon.objects.create(
        code="OFF10", title="Off", discount_type="FLAT", value=10, is_active=False
    )
    old = Coupon.objects.create(
        code="OLD10",
        title="Old",
        discount_type="PERCENT",
        value=10,
        max_discount=100,
        ends_at=now - timedelta(days=1),
        starts_at=now - timedelta(days=9),
    )
    later = Coupon.objects.create(
        code="LATER",
        title="Later",
        discount_type="FLAT",
        value=10,
        starts_at=now + timedelta(days=2),
    )
    personal = Coupon.objects.create(
        code="MINE", title="Mine", discount_type="FLAT", value=10, owner=UserFactory()
    )
    login_as(client, roles.SUPER_ADMIN)
    page = page_text(client.get(reverse("ops:offers")))

    def row(coupon):
        return page.split(f'data-testid="coupon-{coupon.pk}"')[1].split("</tr>")[0]

    assert "Disabled" in row(off)
    assert 'data-confirm-label="Enable"' in row(off)
    assert "Expired" in row(old)
    assert "10% off, up to ₹100" in row(old)
    assert "Starts later" in row(later)
    assert f'data-testid="coupon-{personal.pk}"' not in page  # personal rewards are not here


def test_coupon_enable_disable_calls_the_service(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:coupon-active", args=[world.coupon.pk])
    response = client.post(url, {"active": "0"}, **HX)
    assert response.status_code == 204
    assert toast(response)["message"] == (
        "Coupon JIVO50 is off. Customers can no longer see or use it."
    )
    world.coupon.refresh_from_db()
    assert not world.coupon.is_active
    assert AuditLog.objects.filter(action="coupon.disable").count() == 1

    response = client.post(url, {"active": "1"}, **HX)
    assert response.status_code == 204
    world.coupon.refresh_from_db()
    assert world.coupon.is_active
    assert client.post(url, {"active": "maybe"}, **HX).status_code == 400


def test_personal_coupon_is_not_managed_here(client, world):
    personal = Coupon.objects.create(
        code="MINE", title="Mine", discount_type="FLAT", value=10, owner=UserFactory()
    )
    login_as(client, roles.SUPER_ADMIN)
    assert client.get(reverse("ops:coupon-edit", args=[personal.pk])).status_code == 404
    response = client.post(reverse("ops:coupon-active", args=[personal.pk]), {"active": "0"})
    assert response.status_code == 404
    personal.refresh_from_db()
    assert personal.is_active


def coupon_post(**changes) -> dict:
    data = {
        "code": "SAVE10",
        "title": "10% off",
        "description": "",
        "discount_type": "PERCENT",
        "value": "10",
        "min_order_value": "199",
        "max_discount": "100",
        "starts_at": "",
        "ends_at": "2099-12-31T23:00",
        "usage_limit_total": "500",
        "usage_limit_per_user": "1",
    }
    data.update(changes)
    return data


def test_add_coupon_calls_the_service(client, world):
    user = login_as(client, roles.SUPER_ADMIN)
    page = page_text(client.get(reverse("ops:coupon-add")))
    assert 'data-ops-confirm="Add this coupon?' in page
    assert 'name="csrfmiddlewaretoken"' in page
    response = client.post(reverse("ops:coupon-add"), coupon_post(code="save10"), follow=True)
    assert response.redirect_chain[-1][0] == reverse("ops:offers")
    coupon = Coupon.objects.get(code="SAVE10")
    assert coupon.owner is None
    assert coupon.discount_type == DiscountType.PERCENT
    assert coupon.value == Decimal("10.00")
    assert coupon.max_discount == Decimal("100.00")
    assert coupon.min_order_value == Decimal("199.00")
    assert coupon.usage_limit_total == 500
    # Typed in IST (23:00), stored in UTC (17:30).
    assert coupon.ends_at == datetime(2099, 12, 31, 17, 30, tzinfo=UTC)
    assert AuditLog.objects.get(action="coupon.create").actor == user
    assert "Coupon SAVE10 added." in page_text(response)


@pytest.mark.parametrize(
    ("changes", "field", "message"),
    [
        ({"max_discount": ""}, "max_discount", "A percent coupon needs a maximum discount"),
        ({"code": "jivo50"}, "code", "A coupon with this code already exists"),
        ({"code": "SAVE 10"}, "code", "Use letters and numbers without spaces"),
        ({"value": "150"}, "value", "A percent coupon is at most 100."),
        ({"discount_type": "FLAT"}, "max_discount", "A flat coupon has no cap"),
        (
            {"starts_at": "2099-12-31T23:00", "ends_at": "2099-12-01T10:00"},
            "ends_at",
            "Must be after the start.",
        ),
        ({"value": "abc"}, "value", "Enter a number, e.g. 50 or 49.50."),
        ({"discount_type": "FREE_UNIT"}, "discount_type", "Choose ₹ off or % off."),
    ],
)
def test_add_coupon_shows_errors_next_to_the_fields(client, world, changes, field, message):
    login_as(client, roles.SUPER_ADMIN)
    response = client.post(reverse("ops:coupon-add"), coupon_post(**changes))
    assert response.status_code == 400
    errors = " ".join(response.context["form"].errors.get(field, []))
    assert message in errors, response.context["form"].errors
    assert message in page_text(response)
    assert 'data-testid="form-errors"' in page_text(response)
    assert not Coupon.objects.filter(code__in=["SAVE10", "SAVE 10"]).exists()


def test_edit_coupon_calls_the_service(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:coupon-edit", args=[world.coupon.pk])
    page = page_text(client.get(url))
    assert 'value="JIVO50"' in page
    assert 'value="50.00"' in page
    assert 'data-ops-confirm="Save the changes to JIVO50?' in page
    data = coupon_post(
        code="JIVO50", title="Now ₹60 off", discount_type="FLAT", value="60", max_discount=""
    )
    response = client.post(url, data, follow=True)
    assert response.redirect_chain[-1][0] == reverse("ops:offers")
    world.coupon.refresh_from_db()
    assert world.coupon.title == "Now ₹60 off"
    assert world.coupon.value == Decimal("60.00")
    assert AuditLog.objects.filter(action="coupon.update").count() == 1
    assert "Coupon JIVO50 saved." in page_text(response)

    response = client.post(url, data, follow=True)
    assert "Nothing changed in coupon JIVO50." in page_text(response)


def test_rewards_referral_switch_calls_the_service(client, world):
    ReferralSettings.load()
    login_as(client, roles.SUPER_ADMIN)
    data = {"welcome": "1", "referral": "1"}  # referral_enabled unticked = off
    response = client.post(reverse("ops:offer-rewards"), data, **HX)
    assert response.status_code == 204, response.content
    assert toast(response)["message"].startswith("Rewards saved.")
    assert not ReferralSettings.load().is_enabled
    assert AuditLog.objects.filter(action="offer.rewards").exists()


def test_rewards_quantities_are_saved(client, world):
    login_as(client, roles.SUPER_ADMIN)
    data = {"referral_enabled": "on", "welcome": "2", "referral": "3"}
    response = client.post(reverse("ops:offer-rewards"), data, **HX)
    assert response.status_code == 204
    config = ReferralSettings.load()
    assert (config.welcome_reward_quantity, config.reward_quantity) == (2, 3)
    assert config.is_enabled
    # The limits are the model's (1 to 10), in plain words; nothing is saved.
    for wrong in ("99", "0"):
        response = client.post(reverse("ops:offer-rewards"), {**data, "welcome": wrong}, **HX)
        assert response.status_code == 400
        assert refusal_message(response) == "Enter 1 to 10."
    response = client.post(reverse("ops:offer-rewards"), {**data, "referral": ""}, **HX)
    assert refusal_message(response) == "Enter the number of free cartons."
    assert ReferralSettings.load().welcome_reward_quantity == 2


def test_volume_offer_form_passes_the_values(client, world, monkeypatch):
    """The form's values reach the service as typed (a stand-in records the call)."""
    CALLS.clear()
    monkeypatch.setitem(sm.SERVICES, sm.SET_VOLUME_OFFER, (THIS, "stand_in"))
    user = login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:offer-volume", args=[world.store.pk])
    data = {"enabled": "on", "every": "10", "free_variant": str(world.water.pk)}
    response = client.post(url, data, **HX)
    assert response.status_code == 204
    assert toast(response)["message"] == "Buy 10 get 1 free is on at GGN-01. Carts show it at once."
    args, kwargs = CALLS[-1]
    assert (args[0].pk, args[1], args[2], kwargs["actor"]) == (
        world.store.pk,
        10,
        world.water.pk,
        user,
    )
    response = client.post(url, {"every": "10"}, **HX)  # switched off
    assert toast(response)["message"] == "Buy-N-get-1 is off at GGN-01."
    assert CALLS[-1][0][1] == 0
    # A size the store does not sell is not offered; "on" needs a number.
    other_size = VariantFactory()
    response = client.post(url, {**data, "free_variant": str(other_size.pk)}, **HX)
    assert response.status_code == 400
    response = client.post(url, {"enabled": "on", "every": ""}, **HX)
    assert response.status_code == 400
    assert refusal_message(response) == "Enter how many paid cartons give 1 free carton."
    assert len(CALLS) == 2


def test_volume_offer_is_saved(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:offer-volume", args=[world.store.pk])
    data = {"enabled": "on", "every": "10", "free_variant": str(world.water.pk)}
    response = client.post(url, data, **HX)
    assert response.status_code == 204
    assert toast(response)["message"] == "Buy 10 get 1 free is on at GGN-01. Carts show it at once."
    config = PricingConfig.objects.get(store=world.store)
    assert (config.free_unit_every, config.free_unit_variant_id) == (10, world.water.pk)
    assert AuditLog.objects.filter(action="offer.volume").count() == 1
    # The page shows it: on, N and the chosen size.
    page = page_text(client.get(reverse("ops:offers")))
    form = page.split(f'data-testid="volume-{world.store.pk}"')[1].split("</form>")[0]
    assert 'value="10"' in form
    assert f'<option value="{world.water.pk}" selected>' in form

    response = client.post(url, data, **HX)
    assert toast(response) == {"message": "Nothing changed at GGN-01.", "tone": "info"}
    response = client.post(url, {"every": "", "free_variant": str(world.water.pk)}, **HX)
    assert toast(response)["message"] == "Buy-N-get-1 is off at GGN-01."
    config.refresh_from_db()
    assert (config.free_unit_every, config.free_unit_variant_id) == (0, world.water.pk)


# --------------------------------------------------------------------------- delivery locations


def test_delivery_page_lists_pincodes_and_warns_about_outlines(client, world):
    login_as(client, roles.SUPER_ADMIN)
    response = client.get(reverse("ops:delivery"))
    assert response.status_code == 200
    page = page_text(response)
    assert "Customers can order only from active pincodes." in page
    row = page.split(f'data-testid="pincode-{world.pin.pk}"')[1].split("</tr>")[0]
    assert "110027" in row
    assert "Rajouri Garden" in row
    assert "Active" in row
    assert f'data-testid="outline-{world.pin.pk}"' in row
    assert "warning" in row.split(f'data-testid="outline-{world.pin.pk}"')[1].split("</td>")[0]
    assert f'data-testid="outline-warning-{world.store.pk}"' in page
    assert sm.MSG_NO_OUTLINE in page
    assert "can't find the store from their location until an outline is imported" in page
    # The confirm dialog says what customers will experience; it is the store's last pincode.
    assert (
        "Turn off delivery to 110027 (Rajouri Garden)? Customers there will see \"We don't "
        "deliver here yet\" and can't place new orders."
    ) in row
    assert "This is the last active pincode of GGN-01" in row
    assert 'data-confirm-tone="danger"' in row
    assert 'name="csrfmiddlewaretoken"' in row
    # A store with no pincodes keeps its map area.
    assert f'data-testid="map-area-{world.other.pk}"' in page

    outline("110027")
    page = page_text(client.get(reverse("ops:delivery")))
    assert f'data-testid="outline-warning-{world.store.pk}"' not in page
    cell = page.split(f'data-testid="outline-{world.pin.pk}"')[1].split("</td>")[0]
    assert "Yes" in cell


def test_delivery_page_query_count_does_not_grow(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:delivery")
    client.get(url)
    with CaptureQueriesContext(connection) as few:
        client.get(url)
    for index in range(10):
        DeliveryPincode.objects.create(store=world.other, pincode=f"1100{index + 30}")
    outline("110030")
    with CaptureQueriesContext(connection) as many:
        client.get(url)
    assert len(many) == len(few)


def test_add_pincode_calls_the_service(client, world):
    user = login_as(client, roles.SUPER_ADMIN)
    page = page_text(client.get(reverse("ops:pincode-add"), {"store": world.store.pk}))
    assert f'<option value="{world.store.pk}" selected>' in page
    assert 'data-ops-confirm="Add this pincode?' in page
    data = {
        "store": str(world.store.pk),
        "pincode": " 110018 ",
        "area_name": "Hari Nagar",
        "is_active": "on",
    }
    response = client.post(reverse("ops:pincode-add"), data, follow=True)
    assert response.redirect_chain[-1][0] == reverse("ops:delivery")
    row = DeliveryPincode.objects.get(store=world.store, pincode="110018")
    assert row.is_active
    assert row.area_name == "Hari Nagar"
    assert AuditLog.objects.get(action="delivery_pincode.add").actor == user
    page = page_text(response)
    assert "Pincode 110018 (Hari Nagar) added to GGN-01. Customers there can order now." in page
    assert f"{sm.MSG_NO_OUTLINE} Pincode: 110018." in page  # the warning message


@pytest.mark.parametrize(
    ("changes", "field", "message"),
    [
        ({"pincode": "11002"}, "pincode", "Enter a 6-digit pincode, e.g. 110027."),
        ({"pincode": "110027"}, "pincode", "This store already delivers to this pincode."),
        ({"pincode": ""}, "pincode", "Enter the pincode."),
        ({"store": "999999"}, "store", "Choose a store from the list."),
        ({"area_name": "x" * 81}, "area_name", "Use at most 80 characters."),
    ],
)
def test_add_pincode_shows_errors_next_to_the_fields(client, world, changes, field, message):
    login_as(client, roles.SUPER_ADMIN)
    data = {"store": str(world.store.pk), "pincode": "110018", "is_active": "on", **changes}
    response = client.post(reverse("ops:pincode-add"), data)
    assert response.status_code == 400
    assert message in " ".join(response.context["form"].errors.get(field, []))
    assert message in page_text(response)
    assert DeliveryPincode.objects.count() == 1


def test_edit_pincode_calls_the_service(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:pincode-edit", args=[world.pin.pk])
    page = page_text(client.get(url))
    assert 'value="110027"' in page
    assert 'value="Rajouri Garden"' in page
    response = client.post(url, {"pincode": "110027", "area_name": "Tagore Garden"}, follow=True)
    assert response.redirect_chain[-1][0] == reverse("ops:delivery")
    world.pin.refresh_from_db()
    assert world.pin.area_name == "Tagore Garden"
    assert AuditLog.objects.filter(action="delivery_pincode.update").count() == 1
    assert "Pincode 110027 (Tagore Garden) of GGN-01 saved." in page_text(response)
    response = client.post(url, {"pincode": "1100", "area_name": ""})
    assert response.status_code == 400
    assert "Enter a 6-digit pincode, e.g. 110027." in page_text(response)


def test_activate_and_deactivate_pincode(client, world):
    login_as(client, roles.SUPER_ADMIN)
    url = reverse("ops:pincode-active", args=[world.pin.pk])
    response = client.post(url, {"active": "0"}, **HX)
    assert response.status_code == 204
    assert toast(response)["message"] == (
        "Delivery to 110027 (Rajouri Garden) (GGN-01) is off. Customers there can't place new "
        "orders."
    )
    world.pin.refresh_from_db()
    assert not world.pin.is_active
    assert AuditLog.objects.filter(action="delivery_pincode.deactivate").count() == 1
    page = page_text(client.get(reverse("ops:delivery")))
    assert f'data-testid="no-active-{world.store.pk}"' in page
    assert "Turn on delivery to 110027 (Rajouri Garden)?" in page

    response = client.post(url, {"active": "1"})  # without JavaScript
    assert response.status_code == 302
    world.pin.refresh_from_db()
    assert world.pin.is_active
