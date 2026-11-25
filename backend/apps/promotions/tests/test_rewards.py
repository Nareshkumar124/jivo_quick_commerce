"""ADR-0002: free-carton rewards on the personal coupon system. The welcome reward (one per
customer account created from now on, given by the OTP login that creates it), the database
rules, the derived statuses and `GET /api/v1/account/rewards/` (the caller's own rewards only,
IDOR, schema, query count)."""

from datetime import timedelta
from decimal import Decimal

import jsonschema
import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, connection, transaction
from django.test.utils import CaptureQueriesContext
from django.utils import timezone
from drf_spectacular.generators import SchemaGenerator

from apps.accounts.models import User
from apps.accounts.tests.factories import UserFactory
from apps.accounts.tests.test_otp_api import request_otp, verify
from apps.catalog.tests.factories import VariantFactory
from apps.orders.choices import FreeSource, OrderStatus
from apps.orders.models import OrderItem
from apps.orders.tests.factories import OrderFactory
from apps.promotions import rewards
from apps.promotions import services as promotions
from apps.promotions.choices import CouponSource, DiscountType, RewardStatus
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus
from apps.referrals.models import ReferralSettings
from tests.test_schema_examples import to_json_schema

pytestmark = pytest.mark.django_db

REWARDS = "/api/v1/account/rewards/"
NEW_PHONE = "+919000000001"  # a fixed-OTP test number (settings.OTP_TEST_NUMBERS), no SMS
TEST_OTP = "123456"


def welcome_rewards(user=None):
    rows = Coupon.objects.filter(source=CouponSource.WELCOME)
    return rows.filter(owner=user) if user is not None else rows


def login(client, phone=NEW_PHONE, app="customer"):
    request_otp(client, phone=phone, app=app)
    response = verify(client, TEST_OTP, phone=phone, app=app)
    assert response.status_code == 200, response.content
    return response.json()


class TestWelcomeReward:
    def test_a_new_customer_account_gets_one(self, api_client):
        """ADR-0002 §7: the OTP login that creates the account gives one free-carton reward,
        valid `reward_validity_days`."""
        ReferralSettings.objects.update_or_create(pk=1, defaults={"reward_validity_days": 45})
        before = timezone.now()
        assert login(api_client)["is_new_user"] is True
        user = User.objects.get(phone=NEW_PHONE)
        reward = welcome_rewards(user).get()
        assert (reward.discount_type, reward.value, reward.source) == (
            DiscountType.FREE_UNIT,
            Decimal("1.00"),
            CouponSource.WELCOME,
        )
        assert (reward.usage_limit_total, reward.usage_limit_per_user) == (1, 1)
        assert reward.owner == user
        assert reward.code.startswith("WEL")
        assert reward.title == "1 free carton: welcome reward"
        assert before + timedelta(days=45) <= reward.ends_at <= timezone.now() + timedelta(days=45)

    def test_only_once(self, api_client):
        login(api_client)
        assert login(api_client)["is_new_user"] is False
        assert welcome_rewards().count() == 1

    def test_existing_accounts_get_none(self, api_client):
        """Accounts created before (here: already in the table) never get one."""
        user = UserFactory(phone=NEW_PHONE)
        assert login(api_client)["is_new_user"] is False
        assert not welcome_rewards(user).exists()

    def test_an_account_created_by_the_rider_app_gets_none(self, api_client):
        login(api_client, app="rider")
        assert not welcome_rewards().exists()
        login(api_client, app="customer")  # later customer login: an existing account
        assert not welcome_rewards().exists()

    def test_grant_is_idempotent(self, user):
        assert rewards.grant_welcome_reward(user) is not None
        assert rewards.grant_welcome_reward(user) is None
        assert welcome_rewards(user).count() == 1

    def test_database_keeps_one_welcome_reward_per_customer(self, user):
        rewards.create_reward(user, source=CouponSource.WELCOME)
        with pytest.raises(IntegrityError), transaction.atomic():
            rewards.create_reward(user, source=CouponSource.WELCOME)

    def test_a_lost_race_is_not_an_error(self, user, monkeypatch):
        """A concurrent grant created it between the check and the insert: None, no 500."""
        rewards.create_reward(user, source=CouponSource.WELCOME)
        monkeypatch.setattr(
            rewards.Coupon.objects, "filter", lambda **kw: Coupon.objects.none(), raising=False
        )
        assert rewards.grant_welcome_reward(user) is None


class TestModel:
    def test_a_free_unit_coupon_is_one_carton(self, user):
        coupon = Coupon(
            code="FREE2", title="Two", discount_type=DiscountType.FREE_UNIT, value=Decimal(2)
        )
        with pytest.raises(ValidationError):
            coupon.clean()
        with pytest.raises(IntegrityError), transaction.atomic():
            coupon.save()

    @pytest.mark.parametrize("kind", ["public", "staff_source"])
    def test_a_free_unit_coupon_is_always_a_personal_reward(self, user, kind):
        """Code review: staff can never make a public (or source NONE) free-carton coupon;
        `clean()` says so and the database refuses it."""
        owner = None if kind == "public" else user
        coupon = Coupon(
            code="FREE1",
            title="Free",
            discount_type=DiscountType.FREE_UNIT,
            value=Decimal(1),
            owner=owner,
            source=CouponSource.NONE if kind == "staff_source" else CouponSource.WELCOME,
        )
        with pytest.raises(ValidationError) as error:
            coupon.clean()
        assert "discount_type" in error.value.message_dict
        with pytest.raises(IntegrityError), transaction.atomic():
            coupon.save()

    def test_a_reward_passes_clean(self, user):
        rewards.create_reward(user, source=CouponSource.WELCOME).clean()

    def test_free_unit_gives_no_money_off(self, user):
        reward = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER)
        assert promotions.coupon_discount(reward, []) == Decimal("0.00")


def redeem(reward, status=OrderStatus.PLACED, redemption=RedemptionStatus.APPLIED, **order):
    order = OrderFactory(user=reward.owner, status=status, **order)
    CouponRedemption.objects.create(
        coupon=reward, user=reward.owner, order=order, discount_amount=0, status=redemption
    )
    return order


@pytest.fixture(scope="module")
def components():
    return SchemaGenerator().get_schema(request=None, public=True)["components"]["schemas"]


def get_rewards(client, components, status=200):
    response = client.get(REWARDS)
    assert response.status_code == status, response.content
    body = response.json()
    if status == 200:
        jsonschema.validate(
            body, to_json_schema({"$ref": "#/components/schemas/Rewards"}, components)
        )
    return body


class TestRewardsEndpoint:
    def test_empty(self, auth_client, components):
        assert get_rewards(auth_client, components) == {"available": [], "history": []}

    def test_statuses_and_history(self, auth_client, user, components):
        """AVAILABLE (soonest expiry first), then CLAIMED; USED and EXPIRED only in history;
        the volume-offer free cartons of delivered orders in history."""
        now = timezone.now()
        later = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER)
        sooner = rewards.create_reward(user, source=CouponSource.WELCOME)
        Coupon.objects.filter(pk=sooner.pk).update(ends_at=now + timedelta(days=2))
        claimed = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRED)
        claim_order = redeem(claimed)
        used = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER)
        used_order = redeem(used, status=OrderStatus.DELIVERED, delivered_at=now)
        expired = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER)
        Coupon.objects.filter(pk=expired.pk).update(ends_at=now - timedelta(days=1))
        returned = rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER)
        redeem(returned, status=OrderStatus.CANCELLED, redemption=RedemptionStatus.REVERSED)
        volume_order = OrderFactory(user=user, status=OrderStatus.DELIVERED, delivered_at=now)
        free_variant = VariantFactory()
        OrderItem.objects.create(
            order=volume_order,
            variant=free_variant,
            product=free_variant.product,
            product_name="Jivo Water",
            variant_name="1 L",
            sku=free_variant.sku,
            mrp=Decimal("110.00"),
            selling_price=Decimal("0.00"),
            quantity=3,
            quantity_unavailable=1,
            line_total=Decimal("0.00"),
            is_free=True,
            free_source=FreeSource.VOLUME_OFFER,
        )
        Coupon.objects.create(  # an old ₹ personal coupon is not a reward here
            code="REFOLD90",
            title="₹90 off",
            discount_type=DiscountType.FLAT,
            value=Decimal(90),
            owner=user,
        )

        body = get_rewards(auth_client, components)
        assert [(r["code"], r["status"], r["order_number"]) for r in body["available"]] == [
            (sooner.code, "AVAILABLE", None),
            (later.code, "AVAILABLE", None),
            (returned.code, "AVAILABLE", None),
            (claimed.code, "CLAIMED", claim_order.order_number),
        ]
        kinds = sorted((e["kind"], e["order_number"] or "", e["quantity"]) for e in body["history"])
        assert kinds == sorted(
            [
                *[("EARNED", "", 1)] * 6,
                ("CLAIMED", claim_order.order_number, 1),
                ("CLAIMED", used_order.order_number, 1),
                ("CLAIMED", returned.redemptions.get().order.order_number, 1),
                ("USED", used_order.order_number, 1),
                ("EXPIRED", "", 1),
                ("VOLUME_FREE", volume_order.order_number, 2),
            ]
        )
        assert body["history"] == sorted(
            body["history"], key=lambda e: (e["at"], e["kind"]), reverse=True
        )
        volume = next(e for e in body["history"] if e["kind"] == "VOLUME_FREE")
        assert volume["title"] == "2 free cartons with your order"
        assert rewards.reward_state(rewards.rewards_of(user).get(pk=expired.pk)).status == (
            RewardStatus.EXPIRED
        )

    def test_switched_off_reward_is_expired(self, user):
        reward = rewards.create_reward(user, source=CouponSource.WELCOME)
        Coupon.objects.filter(pk=reward.pk).update(is_active=False)
        assert rewards.reward_state(rewards.rewards_of(user).get()).status == RewardStatus.EXPIRED

    def test_idor_only_the_callers_rewards(self, auth_client, user, make_auth_client, components):
        """Another customer never sees the caller's rewards (and the other way round)."""
        mine = rewards.create_reward(user, source=CouponSource.WELCOME)
        other = UserFactory()
        theirs = rewards.create_reward(other, source=CouponSource.WELCOME)
        redeem(theirs)
        assert [r["code"] for r in get_rewards(auth_client, components)["available"]] == [mine.code]
        body = get_rewards(make_auth_client(other), components)
        assert [r["code"] for r in body["available"]] == [theirs.code]
        assert sorted(e["kind"] for e in body["history"]) == ["CLAIMED", "EARNED"]

    def test_unauthenticated(self, api_client):
        response = api_client.get(REWARDS)
        assert response.status_code == 401

    def test_rider_app_token_is_refused(self, user, make_auth_client):
        response = make_auth_client(user, app="rider").get(REWARDS)
        assert response.status_code == 403

    def test_query_count_does_not_grow(self, auth_client, user, components):
        rewards.create_reward(user, source=CouponSource.WELCOME)
        get_rewards(auth_client, components)  # warm-up (first request of the client)
        with CaptureQueriesContext(connection) as one:
            get_rewards(auth_client, components)
        for _ in range(3):
            redeem(rewards.create_reward(user, source=CouponSource.REFERRAL_REFERRER))
        with CaptureQueriesContext(connection) as four:
            get_rewards(auth_client, components)
        assert len(four) == len(one)
