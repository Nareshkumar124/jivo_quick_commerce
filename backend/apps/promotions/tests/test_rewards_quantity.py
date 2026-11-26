"""ADR-0003 on rewards: a FREE_UNIT coupon's `value` is its number of free cartons (a whole number
1 to 10, database and `clean()`); new rewards take it from `ReferralSettings` when they are
created (welcome: `welcome_reward_quantity`; referral: `reward_quantity`), older rewards keep
theirs; `GET /account/rewards/` shows `quantity` and the store's fixed free size
(`free_variant`: the optional `X-Store-Id`, else the caller's cart store)."""

from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, transaction

from apps.accounts.models import User
from apps.cart.models import Cart
from apps.cart.tests import conftest as cart_fixtures
from apps.promotions import rewards
from apps.promotions.choices import CouponSource, DiscountType
from apps.promotions.models import Coupon
from apps.promotions.tests import test_rewards as reward_tests
from apps.promotions.tests.test_rewards import NEW_PHONE, get_rewards, login
from apps.referrals.models import ReferralSettings

pytestmark = pytest.mark.django_db

REWARDS = "/api/v1/account/rewards/"
# Shared fixtures: the cart tests' shop and water, the rewards tests' schema components.
shop = cart_fixtures.shop
water = cart_fixtures.water
components = reward_tests.components


def settings_with(**values) -> ReferralSettings:
    config, _ = ReferralSettings.objects.update_or_create(pk=1, defaults=values)
    return config


class TestQuantityFromSettings:
    def test_welcome_reward_has_the_setting_value(self, api_client):
        """ADR-0003 §3: welcome_reward_quantity 2 -> the new account's reward is 2 cartons."""
        settings_with(welcome_reward_quantity=2, reward_quantity=5)
        login(api_client)
        reward = Coupon.objects.get(owner=User.objects.get(phone=NEW_PHONE))
        assert (reward.source, reward.value, reward.free_units) == (
            CouponSource.WELCOME,
            Decimal("2.00"),
            2,
        )
        assert reward.title == "2 free cartons: welcome reward"
        assert reward.description == "Welcome to Jivo: 2 free cartons with an order, only for you."

    @pytest.mark.parametrize(
        ("source", "title"),
        [
            (CouponSource.REFERRAL_REFERRER, "3 free cartons: you invited a friend"),
            (CouponSource.REFERRAL_REFERRED, "3 free cartons: you joined with a friend's code"),
        ],
    )
    def test_referral_rewards_use_reward_quantity(self, user, source, title):
        settings_with(welcome_reward_quantity=1, reward_quantity=3)
        reward = rewards.create_reward(user, source=source)
        assert (reward.free_units, reward.title) == (3, title)

    def test_one_carton_keeps_the_singular(self, user):
        reward = rewards.create_reward(user, source=CouponSource.WELCOME)  # default 1
        assert (reward.free_units, reward.title) == (1, "1 free carton: welcome reward")

    def test_rewards_given_earlier_keep_their_number(self, user):
        """ADR-0003 §3: the setting is read when a reward is created, never afterwards."""
        old = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER)
        settings_with(reward_quantity=2)
        new = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER)
        old.refresh_from_db()
        assert (old.free_units, new.free_units) == (1, 2)

    @pytest.mark.parametrize(
        ("quantity", "label"),
        [(1, "1 free carton"), (2, "2 free cartons"), (10, "10 free cartons")],
    )
    def test_carton_label(self, quantity, label):
        assert rewards.carton_label(quantity) == label


class TestFreeUnitValueRule:
    def make(self, user, value) -> Coupon:
        return Coupon(
            code="WELTEST1",
            title="Free",
            discount_type=DiscountType.FREE_UNIT,
            value=value,
            owner=user,
            source=CouponSource.WELCOME,
        )

    @pytest.mark.parametrize("value", ["1", "2", "10"])
    def test_whole_numbers_one_to_ten(self, user, value):
        coupon = self.make(user, Decimal(value))
        coupon.clean()
        coupon.save()
        assert coupon.free_units == int(value)

    @pytest.mark.parametrize("value", ["11", "1.50", "0.50"])
    def test_other_values_are_refused(self, user, value):
        """ADR-0003 §2: `coupon_free_unit_quantity_1_to_10` replaced `coupon_free_unit_is_one`."""
        coupon = self.make(user, Decimal(value))
        with pytest.raises(ValidationError) as error:
            coupon.clean()
        assert error.value.message_dict["value"] == [
            "A free-carton coupon gives a whole number of cartons, 1 to 10."
        ]
        with pytest.raises(IntegrityError), transaction.atomic():
            coupon.save()

    def test_flat_coupons_are_not_limited(self):
        coupon = Coupon(code="BIG500", title="₹500 off", discount_type="FLAT", value=500)
        coupon.clean()
        coupon.save()
        assert coupon.free_units == 0

    @pytest.mark.parametrize("field", ["welcome_reward_quantity", "reward_quantity"])
    @pytest.mark.parametrize("value", [0, 11])
    def test_settings_quantities_are_one_to_ten(self, field, value):
        config = ReferralSettings.load()
        setattr(config, field, value)
        with pytest.raises(ValidationError):
            config.full_clean()
        with pytest.raises(IntegrityError), transaction.atomic():
            config.save()


def fix_one_litre(water):
    water.pricing.free_unit_variant = water.one_litre
    water.pricing.save()


class TestRewardsScreen:
    """`GET /account/rewards/`: `quantity` and `free_variant` (ADR-0003 API)."""

    def expected(self, water):
        return {"id": water.one_litre.pk, "name": "1 L x 12", "product_name": "Jivo Water"}

    def test_quantity_and_free_size_from_the_header_store(
        self,
        auth_client,
        user,
        water,
        shop,
        components,
    ):
        settings_with(welcome_reward_quantity=2)
        fix_one_litre(water)
        rewards.create_reward(user, source=CouponSource.WELCOME)
        response = auth_client.get(REWARDS, headers=shop.headers())
        assert response.status_code == 200
        reward = response.json()["available"][0]
        assert (reward["quantity"], reward["free_variant"]) == (2, self.expected(water))
        assert reward["title"] == "2 free cartons: welcome reward"
        earned = response.json()["history"][0]
        assert (earned["kind"], earned["quantity"]) == ("EARNED", 2)

    def test_without_a_header_the_cart_store_is_used(
        self,
        auth_client,
        user,
        water,
        shop,
        components,
    ):
        fix_one_litre(water)
        rewards.create_reward(user, source=CouponSource.WELCOME)
        Cart.objects.create(user=user, store=shop.store_model)
        body = get_rewards(auth_client, components)
        assert body["available"][0]["free_variant"] == self.expected(water)

    @pytest.mark.parametrize("header", ["abc", "999999", "0"])
    def test_a_bad_header_is_never_an_error(
        self,
        auth_client,
        user,
        water,
        shop,
        header,
    ):
        """Malformed or unknown `X-Store-Id`: the cart's store is used instead."""
        fix_one_litre(water)
        rewards.create_reward(user, source=CouponSource.WELCOME)
        Cart.objects.create(user=user, store=shop.store_model)
        response = auth_client.get(REWARDS, headers={"X-Store-Id": header})
        assert response.status_code == 200
        assert response.json()["available"][0]["free_variant"] == self.expected(water)

    def test_no_store_known_no_free_size(self, auth_client, user, components):
        rewards.create_reward(user, source=CouponSource.WELCOME)
        assert get_rewards(auth_client, components)["available"][0]["free_variant"] is None

    def test_store_without_a_fixed_size(
        self,
        auth_client,
        user,
        water,
        shop,
    ):
        """ADR-0002 store: null, the app keeps its size sheet."""
        rewards.create_reward(user, source=CouponSource.WELCOME)
        response = auth_client.get(REWARDS, headers=shop.headers())
        assert response.json()["available"][0]["free_variant"] is None
