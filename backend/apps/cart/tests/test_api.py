"""The cart and coupon endpoints (06 §2.5) against real data: bill, stock rules, coupons, COD,
checkout blockers, the store following X-Store-Id, IDOR and query counts. Every response is
also validated against the published `Cart` / `CouponList` schemas."""

from datetime import timedelta
from decimal import Decimal

import jsonschema
import pytest
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from drf_spectacular.generators import SchemaGenerator

from apps.accounts.tests.factories import UserFactory
from apps.cart.models import Cart, CartItem
from apps.cart.tests.conftest import OUTSIDE, make_address
from apps.inventory.models import StoreInventory, stock_write
from apps.orders.tests.factories import OrderFactory
from apps.promotions.models import Coupon
from apps.stores.models import PricingConfig
from tests.test_schema_examples import to_json_schema

pytestmark = pytest.mark.django_db

CART = "/api/v1/cart/"
ITEMS = "/api/v1/cart/items/"
COUPON = "/api/v1/cart/coupon/"
COUPONS = "/api/v1/cart/coupons/"


@pytest.fixture(scope="module")
def components():
    return SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]


@pytest.fixture
def api(auth_client, shop, components):
    """Calls the cart API as the signed-in customer at the shop's store and checks every 200
    against the published schema."""

    class Api:
        client = auth_client

        def call(self, method, path, data=None, *, store=None, status=200, schema="Cart"):
            response = getattr(auth_client, method)(path, data, headers=shop.headers(store))
            assert response.status_code == status, response.content
            body = response.json()
            if status == 200:
                jsonschema.validate(
                    body, to_json_schema({"$ref": f"#/components/schemas/{schema}"}, components)
                )
            return body

        def add(self, variant, quantity, **kwargs):
            return self.call(
                "post", ITEMS, {"variant_id": variant.pk, "quantity": quantity}, **kwargs
            )

    return Api()


def coupon(code="JIVO50", **kwargs) -> Coupon:
    defaults = {
        "title": "Flat ₹50 off",
        "discount_type": "FLAT",
        "value": Decimal("50.00"),
        "min_order_value": Decimal("299.00"),
    }
    return Coupon.objects.create(code=code, **{**defaults, **kwargs})


def set_stock(store, variant, on_hand: int, reserved: int = 0):
    inventory = StoreInventory.objects.get(store=store, variant=variant)
    inventory.on_hand, inventory.reserved = on_hand, reserved
    with stock_write():
        inventory.save(update_fields=["on_hand", "reserved"])


def blocker_codes(body) -> list[str]:
    return [blocker["code"] for blocker in body["checkout"]["blockers"]]


class TestReadingTheCart:
    def test_new_customer_gets_an_empty_cart(self, api, shop):
        body = api.call("get", CART)
        assert body["items"] == []
        assert body["item_count"] == 0
        assert set(body["bill"].values()) == {"0.00"}
        assert body["store"]["id"] == shop.store_model.pk
        assert body["store"]["is_open"] is True
        assert blocker_codes(body) == ["CART_EMPTY"]
        assert body["thresholds"] == {
            "min_order_value": "99.00",
            "amount_to_min_order": "99.00",
            "free_delivery_threshold": "299.00",
            "amount_to_free_delivery": "299.00",
        }
        assert body["address"] is None
        assert body["coupon"] is None
        assert body["instructions"] == {"chips": [], "note": ""}

    def test_reads_never_write(self, api, shop, user):
        """Code review F5: GET /cart/ and the coupon sheet create or change nothing."""
        from apps.cms.models import AppConfig

        AppConfig.load()  # the app-guard middleware's singleton (Phase 1), created on first use
        with CaptureQueriesContext(connection) as queries:
            api.call("get", CART)
            api.call("get", COUPONS, schema="CouponList")
        assert not Cart.objects.filter(user=user).exists()
        writes = [
            q["sql"]
            for q in queries
            if q["sql"].lstrip().upper().startswith(("INSERT", "UPDATE", "DELETE"))
        ]
        assert writes == []

    def test_ready_cart(self, api, shop, address):
        api.call("patch", CART, {"address_id": address.pk, "tip": "20.00"})
        api.add(shop.canola_1l, 2)
        body = api.add(shop.chia, 1)
        assert [line["quantity"] for line in body["items"]] == [2, 1]
        assert body["items"][0]["variant"]["id"] == shop.canola_1l.pk
        assert body["items"][0]["line_total"] == "558.00"
        assert body["bill"] == {
            "mrp_total": "848.00",
            "item_total": "677.00",
            "product_discount": "171.00",
            "coupon_discount": "0.00",
            "delivery_fee": "0.00",
            "small_cart_fee": "0.00",
            "handling_fee": "0.00",
            "tip": "20.00",
            "grand_total": "697.00",
            "total_savings": "171.00",
        }
        assert body["checkout"] == {"can_place_order": True, "blockers": []}
        assert body["address"]["id"] == address.pk
        assert body["address"]["is_serviceable"] is True
        assert body["item_count"] == 3

    def test_small_cart_and_minimum_order(self, api, shop, address):
        api.call("patch", CART, {"address_id": address.pk})
        body = api.add(shop.flax, 1)  # ₹79
        assert (body["bill"]["delivery_fee"], body["bill"]["small_cart_fee"]) == ("25.00", "15.00")
        assert body["bill"]["grand_total"] == "119.00"
        assert body["thresholds"]["amount_to_min_order"] == "20.00"
        assert body["thresholds"]["amount_to_free_delivery"] == "220.00"
        assert body["checkout"]["blockers"] == [
            {
                "code": "MIN_ORDER_NOT_MET",
                "message": "Add items worth ₹20 more to place your order (minimum ₹99).",
            }
        ]

    def test_address_override_is_not_saved(self, api, shop, user, address):
        api.add(shop.chia, 1)
        far = make_address(user, OUTSIDE)
        body = api.call("get", f"{CART}?address_id={far.pk}")
        assert body["address"]["id"] == far.pk
        assert "NOT_SERVICEABLE" in blocker_codes(body)
        assert Cart.objects.get(user=user).address_id is None
        assert "ADDRESS_REQUIRED" in blocker_codes(api.call("get", CART))

    def test_address_override_idor(self, api, shop):
        """Another user's address id answers like an unknown one."""
        theirs = make_address(UserFactory())
        body = api.call("get", f"{CART}?address_id={theirs.pk}", status=400)
        assert body["error"]["details"] == {"address_id": ["Address not found."]}

    def test_deleted_address_is_ignored(self, api, shop, address):
        api.add(shop.chia, 1)
        api.call("patch", CART, {"address_id": address.pk})
        address.is_deleted = True
        address.save(update_fields=["is_deleted"])
        body = api.call("get", CART)
        assert body["address"] is None
        assert "ADDRESS_REQUIRED" in blocker_codes(body)

    def test_closed_store_blocks_checkout(self, api, shop, address):
        api.call("patch", CART, {"address_id": address.pk})
        api.add(shop.chia, 2)
        shop.store_model.is_accepting_orders = False
        shop.store_model.save()
        body = api.call("get", CART)
        assert body["store"]["is_open"] is False
        assert body["checkout"]["blockers"] == [
            {
                "code": "STORE_CLOSED",
                "message": "The store is not taking orders right now. Please check back soon.",
            }
        ]

    @pytest.mark.parametrize("with_coupon", [False, True])
    def test_query_count_does_not_grow_with_lines(self, api, shop, address, with_coupon):
        api.call("patch", CART, {"address_id": address.pk})
        api.add(shop.chia, 1)
        if with_coupon:
            coupon(min_order_value=Decimal(0), first_order_only=True).categories.add(shop.seeds)
            api.call("post", COUPON, {"code": "JIVO50"})
        with CaptureQueriesContext(connection) as one:
            api.call("get", CART)
        for variant in (shop.canola_1l, shop.canola_5l, shop.flax):
            api.add(variant, 1)
        with CaptureQueriesContext(connection) as four:
            api.call("get", CART)
        assert len(four) == len(one)
        assert len(one) <= (16 if with_coupon else 12)


class TestSettingQuantities:
    def test_post_sets_the_quantity_so_retries_never_double(self, api, shop):
        api.add(shop.canola_1l, 2)
        body = api.add(shop.canola_1l, 2)
        assert [line["quantity"] for line in body["items"]] == [2]

    def test_zero_removes_and_is_idempotent(self, api, shop):
        api.add(shop.canola_1l, 2)
        assert api.add(shop.canola_1l, 0)["items"] == []
        assert api.add(shop.canola_1l, 0)["items"] == []

    def test_above_the_per_order_limit(self, api, shop):
        body = api.add(shop.canola_5l, 4, status=422)
        assert body["error"] == {
            "code": "MAX_QTY_EXCEEDED",
            "message": "You can order at most 3 of this item.",
            "details": {"variant_id": shop.canola_5l.pk, "max_qty_per_order": 3},
        }

    def test_above_the_stock(self, api, shop):
        body = api.add(shop.canola_5l, 3, status=409)  # 2 in stock
        assert body["error"] == {
            "code": "STOCK_UNAVAILABLE",
            "message": "Only 2 left.",
            "details": {
                "items": [
                    {
                        "variant_id": shop.canola_5l.pk,
                        "requested_quantity": 3,
                        "orderable_quantity": 2,
                    }
                ]
            },
        }

    def test_reserved_stock_is_not_orderable(self, api, shop):
        set_stock(shop.store_model, shop.canola_1l, on_hand=10, reserved=9)
        body = api.add(shop.canola_1l, 2, status=409)
        assert body["error"]["details"]["items"][0]["orderable_quantity"] == 1

    @pytest.mark.parametrize("which", ["unsold", "inactive", "unknown"])
    def test_not_sold_here(self, api, shop, which):
        if which == "inactive":
            shop.chia.is_active = False
            shop.chia.save()
            variant_id = shop.chia.pk
        else:
            variant_id = shop.unsold.pk if which == "unsold" else 999999
        body = api.call("post", ITEMS, {"variant_id": variant_id, "quantity": 1}, status=409)
        assert body["error"]["message"] == "This item is out of stock."
        assert body["error"]["details"]["items"][0]["orderable_quantity"] == 0

    def test_a_decrease_is_always_accepted(self, api, shop):
        api.add(shop.canola_1l, 5)
        set_stock(shop.store_model, shop.canola_1l, on_hand=1)
        body = api.add(shop.canola_1l, 4)
        assert body["items"][0]["quantity"] == 4
        assert body["items"][0]["issue"] == {
            "code": "QUANTITY_UNAVAILABLE",
            "message": "Only 1 left. Reduce the quantity to 1.",
        }
        api.add(shop.canola_1l, 5, status=409)  # an increase is checked

    def test_patch_and_delete_a_line(self, api, shop):
        line_id = api.add(shop.canola_1l, 1)["items"][0]["id"]
        body = api.call("patch", f"{ITEMS}{line_id}/", {"quantity": 3})
        assert body["items"][0]["quantity"] == 3
        api.call("patch", f"{ITEMS}{line_id}/", {"quantity": 6}, status=422)
        assert api.call("delete", f"{ITEMS}{line_id}/")["items"] == []
        api.call("delete", f"{ITEMS}{line_id}/", status=404)

    def test_another_users_line_is_404(self, api, shop, make_auth_client):
        """IDOR: line ids of another customer's cart are never reachable."""
        other = make_auth_client(UserFactory())
        other.post(ITEMS, {"variant_id": shop.chia.pk, "quantity": 1}, headers=shop.headers())
        theirs = CartItem.objects.get(variant=shop.chia).pk
        for method, data in (("patch", {"quantity": 2}), ("delete", None)):
            body = api.call(method, f"{ITEMS}{theirs}/", data, status=404)
            assert body["error"] == {
                "code": "NOT_FOUND",
                "message": "Cart item not found.",
                "details": {},
            }
        assert CartItem.objects.get(pk=theirs).quantity == 1

    def test_clear_keeps_address_and_instructions(self, api, shop, address):
        coupon()
        api.call(
            "patch",
            CART,
            {
                "address_id": address.pk,
                "tip": "30.00",
                "instructions": {"chips": ["LEAVE_AT_DOOR"], "note": "Gate 2"},
            },
        )
        api.add(shop.canola_1l, 2)
        api.call("post", COUPON, {"code": "jivo50"})
        body = api.call("delete", CART)
        assert body["items"] == []
        assert body["coupon"] is None
        assert body["tip"] == "0.00"
        assert body["address"]["id"] == address.pk
        assert body["instructions"] == {"chips": ["LEAVE_AT_DOOR"], "note": "Gate 2"}


class TestCartSettings:
    def test_tip_and_instructions(self, api, shop):
        api.add(shop.canola_1l, 2)
        body = api.call(
            "patch",
            CART,
            {"tip": "20", "instructions": {"chips": ["DONT_RING_BELL"], "note": " Ring once "}},
        )
        assert body["tip"] == "20.00"
        assert body["bill"]["tip"] == "20.00"
        assert body["instructions"] == {"chips": ["DONT_RING_BELL"], "note": "Ring once"}

    def test_tip_is_kept_but_not_billed_while_empty(self, api, shop):
        body = api.call("patch", CART, {"tip": "10.00"})
        assert (body["tip"], body["bill"]["tip"]) == ("10.00", "0.00")

    def test_address_outside_the_store_is_refused(self, api, shop, user):
        far = make_address(user, OUTSIDE)
        body = api.call("patch", CART, {"address_id": far.pk}, status=422)
        assert body["error"]["code"] == "NOT_SERVICEABLE"
        assert body["error"]["details"] == {"address_id": far.pk}
        assert Cart.objects.get(user=user).address_id is None

    def test_another_users_address_is_400(self, api, shop):
        theirs = make_address(UserFactory())
        body = api.call("patch", CART, {"address_id": theirs.pk}, status=400)
        assert body["error"]["details"] == {"address_id": ["Address not found."]}


class TestStoreFollowing:
    def test_lines_take_the_new_stores_price_and_stock(self, api, shop, user):
        api.add(shop.canola_5l, 2)  # 2 in stock at the first store
        inventory = StoreInventory.objects.get(store=shop.other_store_model, variant=shop.canola_5l)
        inventory.price_override = Decimal("1199.00")
        inventory.save(update_fields=["price_override"])
        body = api.call("get", CART, store=shop.other_store_model)
        assert body["store"]["id"] == shop.other_store_model.pk
        assert body["items"][0]["variant"]["selling_price"] == "1199.00"
        assert body["bill"]["item_total"] == "2398.00"
        # A read never writes (code review F5); the next change saves the binding.
        assert Cart.objects.get(user=user).store_id == shop.store_model.pk
        assert api.add(shop.canola_5l, 3, store=shop.other_store_model)["items"][0]["quantity"] == 3
        assert Cart.objects.get(user=user).store_id == shop.other_store_model.pk
        # Back at the first store, 3 is more than it has: flagged, not changed.
        body = api.call("get", CART)
        assert body["items"][0]["quantity"] == 3
        assert body["items"][0]["issue"]["code"] == "QUANTITY_UNAVAILABLE"
        assert "STOCK_UNAVAILABLE" in blocker_codes(body)

    def test_out_of_stock_line(self, api, shop):
        api.add(shop.chia, 1)
        set_stock(shop.store_model, shop.chia, on_hand=0)
        body = api.call("get", CART)
        assert body["items"][0]["issue"] == {
            "code": "OUT_OF_STOCK",
            "message": "Out of stock. Remove it to continue.",
        }
        assert body["items"][0]["variant"]["orderable_quantity"] == 0
        assert body["bill"]["item_total"] == "119.00"  # shown as it is (PM decision)

    def test_lowered_per_order_limit(self, api, shop):
        api.add(shop.canola_1l, 5)
        shop.canola_1l.max_qty_per_order = 3
        shop.canola_1l.save()
        body = api.call("get", CART)
        assert body["items"][0]["issue"] == {
            "code": "QUANTITY_UNAVAILABLE",
            "message": "At most 3 per order. Reduce the quantity to 3.",
        }


class TestPaymentMethods:
    def cod(self, body):
        return body["payment_methods"][1]

    def test_cod_within_the_limit(self, api, shop):
        body = api.add(shop.canola_1l, 2)
        assert self.cod(body) == {
            "method": "COD",
            "is_available": True,
            "unavailable_reason": None,
            "message": None,
        }
        assert body["payment_methods"][0]["method"] == "ONLINE"

    def test_cod_above_the_limit(self, api, shop):
        set_stock(shop.store_model, shop.canola_5l, on_hand=5)
        body = api.add(shop.canola_5l, 2)  # ₹2,598
        assert self.cod(body)["unavailable_reason"] == "ABOVE_LIMIT"
        assert self.cod(body)["message"] == "Cash on delivery is available on orders up to ₹2,000."

    def test_cod_disabled_by_the_store(self, api, shop):
        PricingConfig.objects.create(store=shop.store_model, cod_enabled=False)
        assert self.cod(api.add(shop.chia, 1))["unavailable_reason"] == "COD_DISABLED"

    def test_cod_blocked_customer(self, api, shop, user):
        user.cod_blocked = True
        user.save(update_fields=["cod_blocked"])
        assert self.cod(api.add(shop.chia, 1))["unavailable_reason"] == "NOT_ALLOWED"

    def test_store_pricing_config_is_used(self, api, shop):
        PricingConfig.objects.create(
            store=shop.store_model, delivery_fee=Decimal(0), min_order_value=Decimal(50)
        )
        body = api.add(shop.flax, 1)
        assert body["bill"]["delivery_fee"] == "0.00"
        assert body["thresholds"]["free_delivery_threshold"] is None
        assert body["thresholds"]["amount_to_free_delivery"] is None
        assert "MIN_ORDER_NOT_MET" not in blocker_codes(body)


class TestCoupons:
    def test_apply_and_remove(self, api, shop):
        coupon()
        api.add(shop.canola_1l, 2)  # ₹558
        body = api.call("post", COUPON, {"code": " jivo50 "})
        assert body["coupon"] == {
            "code": "JIVO50",
            "title": "Flat ₹50 off",
            "discount": "50.00",
            "is_applicable": True,
            "message": None,
            "amount_to_unlock": None,
        }
        assert body["bill"]["coupon_discount"] == "50.00"
        assert body["bill"]["grand_total"] == "508.00"
        body = api.call("delete", COUPON)
        assert body["coupon"] is None
        assert body["bill"]["coupon_discount"] == "0.00"
        assert api.call("delete", COUPON)["coupon"] is None  # idempotent

    @pytest.mark.parametrize(
        ("setup", "code", "error", "details"),
        [
            ({}, "NOPE", "COUPON_INVALID", {"code": "NOPE"}),
            ({"is_active": False}, "JIVO50", "COUPON_INVALID", {"code": "JIVO50"}),
            ({"ends_at": "past"}, "JIVO50", "COUPON_EXPIRED", {"code": "JIVO50"}),
            (
                {"min_order_value": Decimal("1499.00")},
                "JIVO50",
                "COUPON_NOT_ELIGIBLE",
                {
                    "code": "JIVO50",
                    "reason": "MIN_ORDER_VALUE",
                    "min_order_value": "1499.00",
                    "amount_to_unlock": "941.00",
                },
            ),
        ],
    )
    def test_refused(self, api, shop, setup, code, error, details):
        if setup.get("ends_at") == "past":
            setup = {"ends_at": timezone.now() - timedelta(minutes=1)}
        coupon(**setup)
        api.add(shop.canola_1l, 2)
        body = api.call("post", COUPON, {"code": code}, status=422)
        assert (body["error"]["code"], body["error"]["details"]) == (error, details)
        assert api.call("get", CART)["coupon"] is None

    def test_per_customer_limit_one_below_and_at_the_limit(self, api, shop, user):
        """Review of R2a: a coupon used once with a limit of 2 still applies; at 2 it does not."""
        from apps.promotions.models import CouponRedemption

        limited = coupon(usage_limit_per_user=2, min_order_value=Decimal(0))
        api.add(shop.canola_1l, 2)

        def use_once():
            CouponRedemption.objects.create(
                coupon=limited, user=user, order=OrderFactory(user=user),
                discount_amount=Decimal(50), status="APPLIED",
            )  # fmt: skip

        use_once()
        assert api.call("post", COUPON, {"code": "JIVO50"})["coupon"]["is_applicable"] is True
        use_once()
        body = api.call("post", COUPON, {"code": "JIVO50"}, status=422)
        assert body["error"]["details"] == {"code": "JIVO50", "scope": "per_user"}
        cart = api.call("get", CART)
        assert cart["coupon"]["is_applicable"] is False
        assert cart["coupon"]["amount_to_unlock"] is None

    def test_first_order_and_usage(self, api, shop, user):
        coupon("WELCOME100", first_order_only=True, min_order_value=Decimal(0))
        OrderFactory(user=user)
        api.add(shop.canola_1l, 2)
        body = api.call("post", COUPON, {"code": "WELCOME100"}, status=422)
        assert body["error"]["details"] == {"code": "WELCOME100", "reason": "FIRST_ORDER_ONLY"}

    def test_coupon_that_stops_applying_blocks_checkout(self, api, shop, address):
        coupon()
        api.call("patch", CART, {"address_id": address.pk})
        api.add(shop.canola_1l, 2)
        api.call("post", COUPON, {"code": "JIVO50"})
        body = api.add(shop.canola_1l, 1)  # ₹279
        assert body["coupon"] == {
            "code": "JIVO50",
            "title": "Flat ₹50 off",
            "discount": "0.00",
            "is_applicable": False,
            "message": "Add items worth ₹20 more to use this coupon.",
            "amount_to_unlock": "20.00",
        }
        assert body["bill"]["coupon_discount"] == "0.00"
        assert body["checkout"]["blockers"] == [
            {
                "code": "COUPON_NOT_ELIGIBLE",
                "message": "Add items worth ₹20 more to use JIVO50, or remove the coupon.",
            }
        ]

    def test_expired_coupon_on_the_cart(self, api, shop, address):
        applied = coupon()
        api.call("patch", CART, {"address_id": address.pk})
        api.add(shop.canola_1l, 2)
        api.call("post", COUPON, {"code": "JIVO50"})
        Coupon.objects.filter(pk=applied.pk).update(ends_at=timezone.now())
        body = api.call("get", CART)
        assert body["checkout"]["blockers"] == [
            {
                "code": "COUPON_EXPIRED",
                "message": "This coupon has expired. Remove it to continue.",
            }
        ]

    def test_coupon_sheet(self, api, shop):
        coupon()
        coupon("OILS15", discount_type="PERCENT", value=Decimal(15), max_discount=Decimal(150),
               min_order_value=Decimal(0)).categories.add(shop.oils)  # fmt: skip
        api.add(shop.canola_1l, 2)
        api.add(shop.chia, 1)
        api.call("post", COUPON, {"code": "JIVO50"})
        body = api.call("get", COUPONS, schema="CouponList")
        assert [(o["code"], o["savings"], o["is_applied"]) for o in body["results"]] == [
            ("OILS15", "83.70", False),  # 15% of ₹558 of oils
            ("JIVO50", "50.00", True),
        ]

    def test_coupon_sheet_for_an_empty_cart(self, api, shop):
        coupon()
        body = api.call("get", COUPONS, schema="CouponList")
        assert body["results"][0]["ineligible_reason"] == "MIN_ORDER_VALUE"
