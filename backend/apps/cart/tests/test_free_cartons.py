"""ADR-0002 on the cart: the volume offer (1 free carton for every `free_unit_every` paid ones,
the cheapest size, the tie-break, the stock fallback and the notice) and free-carton rewards
applied as the cart's coupon (`free_variant_id`, 5 paid cartons, a size sold at the store).
Free cartons cost ₹0: never in `item_total`, the fees, the minimums or the COD limit; their MRP
value is `bill.free_items_value`, part of `total_savings`. Every 200 is checked against the
published `Cart` schema."""

from decimal import Decimal

import pytest

from apps.accounts.tests.factories import UserFactory
from apps.cart.models import Cart
from apps.cart.tests import test_api as cart_api
from apps.cart.tests.test_api import CART, COUPON, COUPONS, blocker_codes, set_stock
from apps.promotions import rewards
from apps.promotions.choices import CouponSource

pytestmark = pytest.mark.django_db

api = cart_api.api  # the cart API tests' fixture (every 200 checked against the schema)
components = cart_api.components


def money(value) -> str:
    return str(Decimal(value).quantize(Decimal("0.01")))


def free(body) -> list[tuple]:
    return [
        (line["variant"]["id"], line["quantity"], line["source"]) for line in body["free_lines"]
    ]


def reward(user, source=CouponSource.WELCOME):
    return rewards.create_reward(user, source=source)


def apply(api, code, variant=None, *, status=200):
    data = {"code": code}
    if variant is not None:
        data["free_variant_id"] = variant if isinstance(variant, int) else variant.pk
    return api.call("post", COUPON, data, status=status)


class TestVolumeOffer:
    @pytest.mark.parametrize(
        ("paid", "free_units"),
        [(5, 0), (9, 0), (10, 1), (19, 1), (20, 2), (30, 3), (40, 4)],
    )
    def test_one_free_carton_for_every_ten_paid(self, api, water, paid, free_units):
        """ADR-0002 §3: free = paid // 10, of the (only) size in the cart, at ₹0."""
        body = api.add(water.one_litre, paid)
        offer = body["free_offer"]
        assert (offer["every"], offer["paid_units"], offer["free_units"]) == (10, paid, free_units)
        assert offer["units_to_next_free"] == 10 - paid % 10
        assert offer["notice"] is None
        expected = [(water.one_litre.pk, free_units, "VOLUME_OFFER")] if free_units else []
        assert free(body) == expected
        bill = body["bill"]
        assert bill["item_total"] == money(110 * paid)
        assert bill["mrp_total"] == money(110 * paid)
        assert bill["free_items_value"] == money(110 * free_units)
        assert bill["total_savings"] == money(110 * free_units)
        assert bill["grand_total"] == bill["item_total"]  # free delivery above ₹299
        assert body["item_count"] == paid  # the badge counts paid units

    def test_free_line_body(self, api, water):
        """ADR-0002 API: {product, variant, quantity, mrp, value, source}."""
        line = api.add(water.one_litre, 20)["free_lines"][0]
        assert line["product"]["name"] == "Jivo Water"
        assert line["variant"]["id"] == water.one_litre.pk
        assert (line["quantity"], line["mrp"], line["value"]) == (2, "110.00", "220.00")

    @pytest.mark.parametrize(
        ("paid", "message"),
        [
            (3, "Add 7 more cartons to get 1 free"),
            (12, "Add 8 more cartons to get 1 more free"),
            (20, "Add 10 more cartons to get 1 more free"),
        ],
    )
    def test_nudge_message(self, api, water, paid, message):
        assert api.add(water.one_litre, paid)["free_offer"]["message"] == message

    def test_no_offer_when_the_store_has_none(self, api, water):
        """`free_unit_every` 0 (the default) = no offer: `free_offer` null, no free lines."""
        water.pricing.free_unit_every = 0
        water.pricing.save()
        body = api.add(water.one_litre, 20)
        assert body["free_offer"] is None
        assert body["free_lines"] == []
        assert body["bill"]["free_items_value"] == "0.00"

    def test_empty_cart(self, api, water):
        body = api.call("get", CART)
        assert body["free_lines"] == []
        assert body["free_offer"]["paid_units"] == 0
        assert body["bill"]["free_items_value"] == "0.00"

    def test_cheapest_size_wins_even_with_fewer_units(self, api, water):
        """ADR-0002 §3: the lowest unit price among the paid lines (1 L ₹110 < 500 ml ₹140)."""
        api.add(water.half, 8)
        body = api.add(water.one_litre, 2)
        assert free(body) == [(water.one_litre.pk, 1, "VOLUME_OFFER")]
        assert body["bill"]["free_items_value"] == "110.00"

    def test_tie_goes_to_the_size_with_more_paid_units(self, api, water):
        """1 L and 250 ml are both ₹110: the size with more paid units."""
        api.add(water.one_litre, 3)
        body = api.add(water.quarter, 7)
        assert free(body) == [(water.quarter.pk, 1, "VOLUME_OFFER")]

    def test_full_tie_goes_to_the_lowest_variant_id(self, api, water):
        api.add(water.quarter, 5)
        body = api.add(water.one_litre, 5)
        assert water.one_litre.pk < water.quarter.pk
        assert free(body) == [(water.one_litre.pk, 1, "VOLUME_OFFER")]

    def test_stock_fallback_to_the_next_cheapest_size(self, api, water, shop):
        """The cheapest size must supply paid + free; else the next-cheapest that can."""
        api.add(water.half, 10)
        api.add(water.one_litre, 10)
        set_stock(shop.store_model, water.one_litre, 11)  # 10 paid + 2 free > 11
        body = api.call("get", CART)
        assert free(body) == [(water.half.pk, 2, "VOLUME_OFFER")]
        assert body["free_offer"]["notice"] is None
        assert body["bill"]["free_items_value"] == "280.00"

    def test_reserved_units_are_not_free_stock(self, api, water, shop):
        api.add(water.one_litre, 10)
        set_stock(shop.store_model, water.one_litre, 20, reserved=10)  # 10 free to sell
        body = api.call("get", CART)
        assert free(body) == []
        assert body["free_offer"]["notice"] == rewards_notice()

    def test_notice_when_no_size_can_supply_it(self, api, water, shop, address):
        """No free carton and a notice; it never blocks checkout."""
        api.call("patch", CART, {"address_id": address.pk})
        api.add(water.one_litre, 10)
        set_stock(shop.store_model, water.one_litre, 10)
        body = api.call("get", CART)
        assert free(body) == []
        offer = body["free_offer"]
        assert (offer["free_units"], offer["notice"]) == (1, rewards_notice())
        assert body["bill"]["free_items_value"] == "0.00"
        assert body["checkout"] == {"can_place_order": True, "blockers": []}


def rewards_notice() -> str:
    from apps.cart.services import MSG_FREE_NO_STOCK

    return MSG_FREE_NO_STOCK


class TestFreeCartonsAreNotPaid:
    def test_never_count_for_the_minimum_units(self, api, water, address):
        """ADR-0002 §2: 4 paid + 2 free is still 1 short of the 5-carton minimum."""
        water.pricing.free_unit_every = 2
        water.pricing.save()
        api.call("patch", CART, {"address_id": address.pk})
        body = api.add(water.one_litre, 4)
        assert free(body) == [(water.one_litre.pk, 2, "VOLUME_OFFER")]
        assert body["thresholds"]["units_to_min_order"] == 1
        assert "MIN_UNITS_NOT_MET" in blocker_codes(body)

    def test_out_of_item_total_fees_minimum_value_and_cod_limit(self, api, water, address):
        """ADR-0002 §4: thresholds compare the paid item total only."""
        pricing = water.pricing
        pricing.free_unit_every = 2
        pricing.free_delivery_threshold = Decimal("1000.00")
        pricing.min_order_value = Decimal("500.00")
        pricing.cod_max_order_value = Decimal("450.00")
        pricing.save()
        api.call("patch", CART, {"address_id": address.pk})
        body = api.add(water.one_litre, 4)  # ₹440 paid + 2 free (₹220)
        bill = body["bill"]
        assert bill["item_total"] == "440.00"
        assert bill["delivery_fee"] == "25.00"  # still below ₹1,000
        assert bill["small_cart_fee"] == "0.00"
        assert bill["grand_total"] == "465.00"
        assert bill["free_items_value"] == "220.00"
        assert bill["total_savings"] == "220.00"
        assert body["thresholds"]["amount_to_min_order"] == "60.00"
        assert "MIN_ORDER_NOT_MET" in blocker_codes(body)
        cod = next(m for m in body["payment_methods"] if m["method"] == "COD")
        assert cod["unavailable_reason"] == "ABOVE_LIMIT"


class TestRewardOnTheCart:
    def test_reward_adds_a_free_line_of_the_chosen_size(self, api, water, user):
        """ADR-0002 §9: the reward's carton (500 ml picked) is a REWARD free line; it stacks
        with the volume offer and gives no money off."""
        code = reward(user).code
        api.add(water.one_litre, 12)
        body = apply(api, code, water.half)
        assert free(body) == [
            (water.one_litre.pk, 1, "VOLUME_OFFER"),
            (water.half.pk, 1, "REWARD"),
        ]
        assert body["coupon"] == {
            "code": code,
            "title": "1 free carton: welcome reward",
            "discount_type": "FREE_UNIT",
            "source": "WELCOME",
            "free_variant_id": water.half.pk,
            "free_quantity": 1,  # ADR-0003: the reward's cartons
            "discount": "0.00",
            "is_applicable": True,
            "message": None,
            "amount_to_unlock": None,
        }
        bill = body["bill"]
        assert (bill["item_total"], bill["coupon_discount"]) == ("1320.00", "0.00")
        assert (bill["free_items_value"], bill["total_savings"]) == ("250.00", "250.00")
        assert bill["grand_total"] == "1320.00"
        assert Cart.objects.get(user=user).free_variant_id == water.half.pk

    def test_apply_needs_free_variant_id(self, api, water, user):
        code = reward(user).code
        api.add(water.one_litre, 5)
        body = apply(api, code, status=400)
        assert body["error"]["details"] == {
            "free_variant_id": ["Choose a size for your free carton."]
        }
        assert Cart.objects.get(user=user).coupon_id is None

    def test_apply_needs_five_paid_cartons(self, api, water, user):
        """ADR-0002 §9: the order still needs the store's minimum paid cartons."""
        code = reward(user).code
        api.add(water.one_litre, 4)
        body = apply(api, code, water.half, status=422)
        assert body["error"]["code"] == "COUPON_NOT_ELIGIBLE"
        assert body["error"]["details"] == {
            "code": code,
            "reason": "MIN_ORDER_UNITS",
            "min_order_units": 5,
            "paid_units": 4,
            "units_to_unlock": 1,
        }
        assert body["error"]["message"] == (
            "Add 1 more cartons to use this reward (minimum 5 paid cartons)."
        )

    def test_at_least_one_paid_carton_without_a_store_minimum(self, api, water, user):
        water.pricing.min_order_units = 0
        water.pricing.save()
        body = apply(api, reward(user).code, water.half, status=422)
        assert body["error"]["details"]["reason"] == "MIN_ORDER_UNITS"

    @pytest.mark.parametrize(
        "which", ["unsold", "unknown", "out_of_stock", "switched_off", "other_category"]
    )
    def test_refuses_a_size_the_store_cannot_give(self, api, water, shop, user, which):
        """The size must be sold at the cart's store, be of the category of a paid line (PM,
        2026-11-25: chia seeds are sold and stocked here, but the cart is water) and have stock
        for paid + the free carton."""
        code = reward(user).code
        api.add(water.one_litre, 5)
        variant = {
            "unsold": shop.unsold.pk,
            "unknown": 999_999,
            "other_category": shop.chia.pk,
        }.get(which, water.half.pk)
        if which == "out_of_stock":
            set_stock(shop.store_model, water.half, 0)
        if which == "switched_off":
            water.half.is_active = False
            water.half.save()
        body = apply(api, code, variant, status=422)
        assert body["error"]["code"] == "COUPON_NOT_ELIGIBLE"
        assert body["error"]["details"] == {
            "code": code,
            "reason": "FREE_VARIANT_UNAVAILABLE",
            "free_variant_id": variant,
        }
        assert Cart.objects.get(user=user).coupon_id is None

    def test_same_size_needs_stock_for_paid_reward_and_volume(self, api, water, shop, user):
        """1 L x10 paid with the reward on 1 L and 11 in stock: the reward fits (10 + 1), the
        volume carton (10 + 1 + 1) does not and there is no other size: a notice."""
        code = reward(user).code
        api.add(water.one_litre, 10)
        set_stock(shop.store_model, water.one_litre, 11)
        body = apply(api, code, water.one_litre)
        assert free(body) == [(water.one_litre.pk, 1, "REWARD")]
        assert body["free_offer"]["notice"] == rewards_notice()

    def test_size_that_runs_out_later_blocks_checkout(self, api, water, shop, user, address):
        code = reward(user).code
        api.call("patch", CART, {"address_id": address.pk})
        api.add(water.one_litre, 5)
        apply(api, code, water.half)
        set_stock(shop.store_model, water.half, 0)
        body = api.call("get", CART)
        assert body["coupon"]["is_applicable"] is False
        assert free(body) == []
        assert body["checkout"]["blockers"] == [
            {
                "code": "COUPON_NOT_ELIGIBLE",
                "message": (
                    "This size is not available for your free carton here. Choose another "
                    "size. Or remove the reward to continue."
                ),
            }
        ]

    def test_below_the_minimum_only_the_units_blocker(self, api, water, user, address):
        """A reward that drops below 5 paid cartons stays on the cart without its own blocker
        (MIN_UNITS_NOT_MET says what to do) and comes back at 5."""
        code = reward(user).code
        api.call("patch", CART, {"address_id": address.pk})
        api.add(water.one_litre, 5)
        apply(api, code, water.half)
        body = api.add(water.one_litre, 4)
        assert body["coupon"]["is_applicable"] is False
        assert free(body) == []
        assert blocker_codes(body) == ["MIN_UNITS_NOT_MET"]
        body = api.add(water.one_litre, 5)
        assert free(body) == [(water.half.pk, 1, "REWARD")]
        assert body["checkout"]["can_place_order"] is True

    def test_another_customers_reward_is_an_unknown_code(self, api, water):
        """IDOR: a reward is personal; another customer's code looks like an unknown one."""
        code = reward(UserFactory()).code
        api.add(water.one_litre, 5)
        body = apply(api, code, water.half, status=422)
        assert body["error"]["code"] == "COUPON_INVALID"

    def test_reward_takes_the_single_coupon_slot(self, api, water, user):
        """One reward or one coupon per order: applying a coupon replaces the reward (and its
        size), and the other way round."""
        from apps.cart.tests.test_api import coupon

        coupon(min_order_value=Decimal(0))
        code = reward(user).code
        api.add(water.one_litre, 5)
        apply(api, code, water.half)
        body = apply(api, "JIVO50")
        assert body["coupon"]["code"] == "JIVO50"
        assert body["coupon"]["free_variant_id"] is None
        assert free(body) == []
        assert Cart.objects.get(user=user).free_variant_id is None
        body = apply(api, code, water.half)
        assert body["bill"]["coupon_discount"] == "0.00"

    def test_remove_clears_the_size(self, api, water, user):
        api.add(water.one_litre, 5)
        apply(api, reward(user).code, water.half)
        body = api.call("delete", COUPON)
        assert body["coupon"] is None
        assert free(body) == []
        assert Cart.objects.get(user=user).free_variant_id is None

    def test_coupon_sheet_lists_the_reward(self, api, water, user):
        code = reward(user).code
        api.add(water.one_litre, 5)
        offers = {o["code"]: o for o in api.call("get", COUPONS, schema="CouponList")["results"]}
        offer = offers[code]
        assert (offer["discount_type"], offer["source"], offer["savings"]) == (
            "FREE_UNIT",
            "WELCOME",
            "0.00",
        )
        assert (offer["is_eligible"], offer["is_personal"], offer["free_variant_id"]) == (
            True,
            True,
            None,
        )
        apply(api, code, water.half)
        offers = {o["code"]: o for o in api.call("get", COUPONS, schema="CouponList")["results"]}
        assert (offers[code]["is_applied"], offers[code]["free_variant_id"]) == (
            True,
            water.half.pk,
        )

    def test_coupon_sheet_below_the_minimum(self, api, water, user):
        code = reward(user).code
        api.add(water.one_litre, 2)
        offers = {o["code"]: o for o in api.call("get", COUPONS, schema="CouponList")["results"]}
        assert offers[code]["is_eligible"] is False
        assert offers[code]["ineligible_reason"] == "MIN_ORDER_UNITS"


def test_reward_size_follows_the_paid_lines_category(api, water, shop, user):
    """PM, 2026-11-25: a water reward needs a water line among the paid lines. With only oil
    paid, a water size is refused; once water is in the cart, it applies; if the water lines
    leave the cart, the reward stops applying (a blocker), never a free carton on an oil order."""
    water.pricing.min_order_units = 1
    water.pricing.save()
    code = reward(user).code
    api.add(shop.canola_1l, 2)
    body = apply(api, code, water.half, status=422)
    assert body["error"]["details"]["reason"] == "FREE_VARIANT_UNAVAILABLE"
    api.add(water.one_litre, 1)
    assert free(apply(api, code, water.half)) == [(water.half.pk, 1, "REWARD")]
    body = api.add(water.one_litre, 0)
    assert free(body) == []
    assert body["coupon"]["is_applicable"] is False
    assert "COUPON_NOT_ELIGIBLE" in blocker_codes(body)
