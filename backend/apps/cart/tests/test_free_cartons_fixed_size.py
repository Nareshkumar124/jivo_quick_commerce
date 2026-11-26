"""ADR-0003 on the cart: the store's fixed free size (`PricingConfig.free_unit_variant`, the 1 L
carton) is the size of every free carton, the volume offer and rewards, whatever the paid sizes;
no cheapest-size rule and no fallback. A reward gives `value` cartons (2 here), is applied
without a size (`free_variant_id` optional; any other id is 422 FREE_VARIANT_UNAVAILABLE) and
skips the category rule. With the setting empty, ADR-0002 is unchanged (test_free_cartons.py).
Every 200 is checked against the published `Cart` / `CouponList` schemas."""

import pytest

from apps.cart.models import Cart
from apps.cart.tests import test_api as cart_api
from apps.cart.tests.test_api import CART, COUPON, COUPONS, blocker_codes, set_stock
from apps.promotions import rewards
from apps.promotions.choices import CouponSource
from apps.referrals.models import ReferralSettings

pytestmark = pytest.mark.django_db

api = cart_api.api  # the cart API tests' fixture (every 200 checked against the schema)
components = cart_api.components


def free(body) -> list[tuple]:
    return [
        (line["variant"]["id"], line["quantity"], line["source"]) for line in body["free_lines"]
    ]


def notice() -> str:
    from apps.cart.services import MSG_FREE_NO_STOCK

    return MSG_FREE_NO_STOCK


@pytest.fixture
def fixed(water):
    """GGN-01's setting: every free carton is the 1 L carton; rewards give 2 cartons."""
    water.pricing.free_unit_variant = water.one_litre
    water.pricing.save()
    ReferralSettings.objects.update_or_create(
        pk=1, defaults={"welcome_reward_quantity": 2, "reward_quantity": 2}
    )
    return water


def one_litre_body(water) -> dict:
    return {"id": water.one_litre.pk, "name": "1 L x 12", "product_name": "Jivo Water"}


def reward(user, source=CouponSource.WELCOME):
    return rewards.create_reward(user, source=source)


def apply(api, code, variant=None, *, status=200):
    data = {"code": code}
    if variant is not None:
        data["free_variant_id"] = variant if isinstance(variant, int) else variant.pk
    return api.call("post", COUPON, data, status=status)


class TestVolumeOfferFixedSize:
    def test_ten_quarter_litre_cartons_give_one_free_litre_carton(self, api, fixed):
        """ADR-0003 §1: 10 paid 250 ml cartons earn 1 free 1 L carton (₹110 MRP), not 250 ml."""
        body = api.add(fixed.quarter, 10)
        assert free(body) == [(fixed.one_litre.pk, 1, "VOLUME_OFFER")]
        assert body["free_offer"]["free_variant"] == one_litre_body(fixed)
        assert body["free_offer"]["notice"] is None
        assert body["bill"]["item_total"] == "1100.00"
        assert body["bill"]["free_items_value"] == "110.00"
        assert body["bill"]["grand_total"] == "1100.00"

    def test_twenty_half_litre_cartons_give_two_free_litre_cartons(self, api, fixed):
        """ADR-0003 §1: 20 x 500 ml (₹140 each) earn 2 free 1 L cartons, even though 500 ml is
        the only (and the dearer) size in the cart."""
        body = api.add(fixed.half, 20)
        assert free(body) == [(fixed.one_litre.pk, 2, "VOLUME_OFFER")]
        assert body["bill"]["free_items_value"] == "220.00"
        line = body["free_lines"][0]
        assert (line["mrp"], line["value"]) == ("110.00", "220.00")
        assert line["variant"]["id"] == fixed.one_litre.pk

    def test_mixed_sizes_count_together(self, api, fixed):
        api.add(fixed.quarter, 4)
        body = api.add(fixed.half, 6)
        assert free(body) == [(fixed.one_litre.pk, 1, "VOLUME_OFFER")]

    def test_free_size_is_shown_before_a_carton_is_earned(self, api, fixed):
        body = api.add(fixed.half, 3)
        assert free(body) == []
        assert body["free_offer"]["free_variant"] == one_litre_body(fixed)
        assert body["free_offer"]["message"] == "Add 7 more cartons to get 1 free"

    def test_empty_cart_shows_the_free_size(self, api, fixed):
        body = api.call("get", CART)
        assert body["free_offer"]["free_variant"] == one_litre_body(fixed)

    def test_no_stock_of_the_fixed_size_no_free_carton_and_no_fallback(
        self, api, fixed, shop, address
    ):
        """ADR-0003 §1: 1 L out of stock: no free carton (250 ml has stock, but there is no
        fallback), the notice is set, and it never blocks checkout."""
        api.call("patch", CART, {"address_id": address.pk})
        set_stock(shop.store_model, fixed.one_litre, 0)
        body = api.add(fixed.quarter, 10)
        assert free(body) == []
        offer = body["free_offer"]
        assert (offer["free_units"], offer["notice"]) == (1, notice())
        assert offer["free_variant"] == one_litre_body(fixed)
        assert body["bill"]["free_items_value"] == "0.00"
        assert body["checkout"] == {"can_place_order": True, "blockers": []}

    def test_fixed_size_that_is_also_paid_needs_stock_for_both(self, api, fixed, shop):
        """10 paid 1 L + 1 free 1 L need 11; with 10 in stock: no free carton, a notice."""
        set_stock(shop.store_model, fixed.one_litre, 10)
        body = api.add(fixed.one_litre, 10)
        assert free(body) == []
        assert body["free_offer"]["notice"] == notice()

    def test_fixed_size_switched_off_with_stock_gives_nothing(self, api, fixed, shop, user):
        """Code review: the store switched 1 L off (`is_available` false) but it still has 100
        on hand: no volume carton (a notice), and a reward cannot be applied."""
        from apps.inventory.models import StoreInventory

        StoreInventory.objects.filter(store=shop.store_model, variant=fixed.one_litre).update(
            is_available=False
        )
        assert StoreInventory.objects.get(variant=fixed.one_litre).on_hand == 100
        body = api.add(fixed.half, 10)
        assert free(body) == []
        assert body["free_offer"]["notice"] == notice()
        assert body["bill"]["free_items_value"] == "0.00"
        error = apply(api, reward(user).code, status=422)["error"]
        assert error["details"]["reason"] == "FREE_VARIANT_UNAVAILABLE"

    def test_null_setting_keeps_the_cheapest_size_rule(self, api, water):
        """ADR-0003 §1: with no fixed size, ADR-0002 applies (the 500 ml cart gets 500 ml)."""
        body = api.add(water.half, 10)
        assert free(body) == [(water.half.pk, 1, "VOLUME_OFFER")]
        assert body["free_offer"]["free_variant"] is None


class TestRewardFixedSize:
    def test_applied_without_a_size_gives_two_litre_cartons(self, api, fixed, user):
        """ADR-0003 §1-§3: the welcome reward (2 cartons from the setting) applied with no
        `free_variant_id` is a REWARD line of 2 x 1 L; no money off."""
        code = reward(user).code
        body = api.add(fixed.half, 5)
        body = apply(api, code)
        assert free(body) == [(fixed.one_litre.pk, 2, "REWARD")]
        assert body["coupon"] == {
            "code": code,
            "title": "2 free cartons: welcome reward",
            "discount_type": "FREE_UNIT",
            "source": "WELCOME",
            "free_variant_id": fixed.one_litre.pk,
            "free_quantity": 2,
            "discount": "0.00",
            "is_applicable": True,
            "message": None,
            "amount_to_unlock": None,
        }
        bill = body["bill"]
        assert (bill["item_total"], bill["coupon_discount"], bill["grand_total"]) == (
            "700.00",
            "0.00",
            "700.00",
        )
        assert (bill["free_items_value"], bill["total_savings"]) == ("220.00", "220.00")
        assert Cart.objects.get(user=user).free_variant_id == fixed.one_litre.pk

    def test_sending_the_fixed_size_is_accepted(self, api, fixed, user):
        api.add(fixed.half, 5)
        body = apply(api, reward(user).code, fixed.one_litre)
        assert free(body) == [(fixed.one_litre.pk, 2, "REWARD")]

    @pytest.mark.parametrize("which", ["half", "quarter", "unknown"])
    def test_a_different_size_is_422(self, api, fixed, user, which):
        """ADR-0003 §1: the customer does not pick; another id is COUPON_NOT_ELIGIBLE /
        FREE_VARIANT_UNAVAILABLE, and nothing changes."""
        code = reward(user).code
        api.add(fixed.half, 5)
        variant = {"half": fixed.half.pk, "quarter": fixed.quarter.pk}.get(which, 999_999)
        body = apply(api, code, variant, status=422)
        assert body["error"]["code"] == "COUPON_NOT_ELIGIBLE"
        assert body["error"]["details"] == {
            "code": code,
            "reason": "FREE_VARIANT_UNAVAILABLE",
            "free_variant_id": variant,
        }
        assert body["error"]["message"] == (
            "Free cartons here come in one size only. Apply the reward without choosing a size."
        )
        cart = Cart.objects.get(user=user)
        assert (cart.coupon_id, cart.free_variant_id) == (None, None)

    def test_the_category_rule_is_skipped(self, api, fixed, shop, user):
        """ADR-0003 §1: the 0002 'same category as a paid line' check does not apply to the
        fixed size: an oil-only cart gets the 1 L water cartons."""
        fixed.pricing.min_order_units = 1
        fixed.pricing.save()
        api.add(shop.canola_1l, 2)
        body = apply(api, reward(user).code)
        assert free(body) == [(fixed.one_litre.pk, 2, "REWARD")]

    def test_needs_stock_for_all_its_cartons(self, api, fixed, shop, user):
        """2 cartons with 1 in stock: 422 FREE_VARIANT_UNAVAILABLE for the fixed size."""
        code = reward(user).code
        api.add(fixed.half, 5)
        set_stock(shop.store_model, fixed.one_litre, 1)
        body = apply(api, code, status=422)
        assert body["error"]["details"] == {
            "code": code,
            "reason": "FREE_VARIANT_UNAVAILABLE",
            "free_variant_id": fixed.one_litre.pk,
        }
        assert body["error"]["message"] == (
            "The free cartons for this reward are out of stock here right now."
        )

    def test_runs_out_after_applying_blocks_checkout(self, api, fixed, shop, user, address):
        code = reward(user).code
        api.call("patch", CART, {"address_id": address.pk})
        api.add(fixed.half, 5)
        apply(api, code)
        set_stock(shop.store_model, fixed.one_litre, 1)
        body = api.call("get", CART)
        assert body["coupon"]["is_applicable"] is False
        assert body["coupon"]["free_variant_id"] == fixed.one_litre.pk
        assert free(body) == []
        assert body["checkout"]["blockers"] == [
            {
                "code": "COUPON_NOT_ELIGIBLE",
                "message": (
                    "The free cartons for this reward are out of stock here right now. Remove "
                    "the reward to continue."
                ),
            }
        ]

    def test_reward_and_volume_offer_share_the_fixed_size_stock(self, api, fixed, shop, user):
        """10 x 500 ml + the 2-carton reward: 3 free 1 L in all. With 2 in stock the reward
        fits (2), the volume carton (2 + 1) does not: a notice, never a blocker."""
        api.add(fixed.half, 10)
        body = apply(api, reward(user).code)
        assert free(body) == [
            (fixed.one_litre.pk, 1, "VOLUME_OFFER"),
            (fixed.one_litre.pk, 2, "REWARD"),
        ]
        assert body["bill"]["free_items_value"] == "330.00"
        set_stock(shop.store_model, fixed.one_litre, 2)
        body = api.call("get", CART)
        assert free(body) == [(fixed.one_litre.pk, 2, "REWARD")]
        assert body["free_offer"]["notice"] == notice()

    def test_fixed_size_replaces_a_size_picked_before(self, api, water, user):
        """A reward applied under ADR-0002 with 500 ml picked: once the store has a fixed size,
        the cart uses it (ADR-0003 replaces the customer's size choice)."""
        code = reward(user).code  # quantity 1 (settings still at the default)
        api.add(water.one_litre, 5)
        assert free(apply(api, code, water.half)) == [(water.half.pk, 1, "REWARD")]
        water.pricing.free_unit_variant = water.quarter
        water.pricing.save()
        body = api.call("get", CART)
        assert free(body) == [(water.quarter.pk, 1, "REWARD")]
        assert body["coupon"]["free_variant_id"] == water.quarter.pk

    def test_below_the_minimum_only_the_units_blocker(self, api, fixed, user, address):
        code = reward(user).code
        api.call("patch", CART, {"address_id": address.pk})
        api.add(fixed.half, 5)
        apply(api, code)
        body = api.add(fixed.half, 4)
        assert body["coupon"]["is_applicable"] is False
        assert body["coupon"]["free_quantity"] == 2
        assert blocker_codes(body) == ["MIN_UNITS_NOT_MET"]

    def test_coupon_sheet_prefills_the_fixed_size(self, api, fixed, user):
        """ADR-0003 API: every reward offer has `free_quantity` and the store's fixed size in
        `free_variant_id`, applied or not; other coupons have both null."""
        from decimal import Decimal

        from apps.cart.tests.test_api import coupon

        coupon(min_order_value=Decimal(0))
        code = reward(user).code
        api.add(fixed.half, 5)
        offers = {o["code"]: o for o in api.call("get", COUPONS, schema="CouponList")["results"]}
        assert (offers[code]["free_variant_id"], offers[code]["free_quantity"]) == (
            fixed.one_litre.pk,
            2,
        )
        assert offers[code]["value"] == "2.00"
        assert (offers["JIVO50"]["free_variant_id"], offers["JIVO50"]["free_quantity"]) == (
            None,
            None,
        )
        apply(api, code)
        offers = {o["code"]: o for o in api.call("get", COUPONS, schema="CouponList")["results"]}
        assert (offers[code]["is_applied"], offers[code]["free_variant_id"]) == (
            True,
            fixed.one_litre.pk,
        )


class TestRewardWithoutFixedSize:
    """ADR-0003 §2 with ADR-0002 sizes: a 2-carton reward of the size the customer picks."""

    def test_picked_size_line_has_the_reward_quantity(self, api, water, user):
        ReferralSettings.objects.update_or_create(pk=1, defaults={"welcome_reward_quantity": 2})
        code = reward(user).code
        api.add(water.one_litre, 5)
        body = apply(api, code, water.half)
        assert free(body) == [(water.half.pk, 2, "REWARD")]
        assert (body["coupon"]["free_variant_id"], body["coupon"]["free_quantity"]) == (
            water.half.pk,
            2,
        )
        assert body["bill"]["free_items_value"] == "280.00"

    def test_picked_size_needs_stock_for_paid_plus_all_cartons(self, api, water, shop, user):
        ReferralSettings.objects.update_or_create(pk=1, defaults={"welcome_reward_quantity": 2})
        code = reward(user).code
        api.add(water.half, 5)
        set_stock(shop.store_model, water.half, 6)  # 5 paid + 2 free > 6
        body = apply(api, code, water.half, status=422)
        assert body["error"]["details"]["reason"] == "FREE_VARIANT_UNAVAILABLE"

    def test_still_needs_a_size(self, api, water, user):
        api.add(water.one_litre, 5)
        body = apply(api, reward(user).code, status=400)
        assert body["error"]["details"] == {
            "free_variant_id": ["Choose a size for your free carton."]
        }
