"""Personal coupons (`Coupon.owner`, 07 §2.5; added 2026-11-13 for referral rewards): only the
owner sees and uses them; public coupons are unchanged."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.utils import timezone
from freezegun import freeze_time

from apps.accounts.tests.factories import UserFactory
from apps.core.exceptions import ApiError
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.promotions import services
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus
from apps.promotions.tests.test_services import check, lines, make, store  # noqa: F401

pytestmark = pytest.mark.django_db

NOW = timezone.now().replace(microsecond=0)


def personal(owner, **kwargs) -> Coupon:
    terms = {
        "amount": Decimal("90.00"),
        "valid_days": 30,
        "min_order_value": Decimal("0.00"),
        "title": "₹90 off: referral reward",
        "now": NOW,
        **kwargs,
    }
    return services.create_personal_coupon(owner, **terms)


def offers(user, store, *totals, now=NOW):  # noqa: F811
    cart_lines = lines(*totals)
    return services.coupon_offers(
        user=user,
        store_id=store.pk,
        lines=cart_lines,
        item_total=sum((line.line_total for line in cart_lines), Decimal(0)),
        applied=None,
        now=now,
    )


class TestCreate:
    def test_a_personal_coupon(self, user):
        coupon = personal(user, description="Your reward.")
        assert coupon.owner == user
        assert coupon.code.startswith("REF")
        assert len(coupon.code) == 11
        assert set(coupon.code[3:]) <= set(services.PERSONAL_CODE_ALPHABET)
        assert (coupon.discount_type, coupon.value, coupon.min_order_value) == (
            "FLAT",
            Decimal("90.00"),
            Decimal("0.00"),
        )
        assert (coupon.usage_limit_total, coupon.usage_limit_per_user) == (1, 1)
        assert coupon.ends_at == NOW + timedelta(days=30)
        assert coupon.description == "Your reward."
        assert coupon in user.personal_coupons.all()

    def test_a_clashing_code_is_retried(self, user, monkeypatch):
        make("REFTAKEN1")
        generated = iter(["REFTAKEN1", "reftaken1", "REFFRESH2"])
        monkeypatch.setattr(services, "personal_code", lambda prefix: next(generated))
        assert personal(user).code == "REFFRESH2"

    def test_gives_up_when_every_code_clashes(self, user, monkeypatch):
        make("REFTAKEN1")
        monkeypatch.setattr(services, "personal_code", lambda prefix: "REFTAKEN1")
        with pytest.raises(RuntimeError, match="unique personal coupon code"):
            personal(user)


class TestOnlyTheOwner:
    def test_owner_can_use_it(self, user, store):  # noqa: F811
        result = check(personal(user), user, store, "300")
        assert result.ok
        assert result.discount == Decimal("90.00")

    def test_anyone_else_gets_coupon_invalid(self, user, store):  # noqa: F811
        """Another customer gets exactly the unknown-code answer (IDOR: reveals nothing)."""
        result = check(personal(UserFactory()), user, store, "300")
        assert (result.error, result.message) == ("COUPON_INVALID", services.MSG_INVALID)

    def test_listed_only_for_its_owner(self, user, store):  # noqa: F811
        """The owner's sheet lists it first-class with `is_personal`; nobody else's does."""
        make("JIVO50", min_order_value=Decimal("0"))
        mine = personal(user)
        theirs = personal(UserFactory())
        sheet = offers(user, store, "300")
        assert [offer["code"] for offer in sheet] == [mine.code, "JIVO50"]
        assert sheet[0]["is_personal"] is True
        assert sheet[0]["savings"] == "90.00"
        assert sheet[0]["ends_at"] == mine.ends_at
        assert sheet[1]["is_personal"] is False
        other_sheet = [offer["code"] for offer in offers(UserFactory(), store, "300")]
        assert other_sheet == ["JIVO50"]
        assert theirs.code not in other_sheet

    def test_listing_without_a_customer_has_no_personal_coupons(self, user, store):  # noqa: F811
        personal(user)
        public = make("JIVO50")
        assert list(services.listed_coupons(store.pk, NOW)) == [public]

    def test_using_it_rechecks_the_owner_on_the_locked_row(self, user):
        """An order of another customer can never use it (`_use`, placement transaction)."""
        coupon = personal(UserFactory())
        order = OrderFactory(user=user, status=OrderStatus.PAYMENT_PENDING, placed_at=None)
        with pytest.raises(ApiError) as caught:
            services.hold_coupon(order, coupon, Decimal("90.00"))
        assert caught.value.error_code == "COUPON_INVALID"
        assert not CouponRedemption.objects.exists()

    def test_owner_uses_it_once(self, user, store):  # noqa: F811
        coupon = personal(user)
        services.apply_coupon_now(OrderFactory(user=user), coupon, Decimal("90.00"))
        assert check(coupon, user, store, "300").error == "COUPON_USAGE_EXCEEDED"
        assert [offer["code"] for offer in offers(user, store, "300")] == []  # used up

    def test_cancelled_order_gives_it_back(self, user, store):  # noqa: F811
        coupon = personal(user)
        order = OrderFactory(user=user)
        services.apply_coupon_now(order, coupon, Decimal("90.00"))
        services.reverse_coupon(order)
        assert CouponRedemption.objects.get(order=order).status == RedemptionStatus.REVERSED
        assert check(coupon, user, store, "300").ok


class TestExpiry:
    def test_expired_after_the_validity(self, user, store):  # noqa: F811
        coupon = personal(user)
        later = NOW + timedelta(days=30, seconds=1)
        assert check(coupon, user, store, "300", now=later).error == "COUPON_EXPIRED"
        assert offers(user, store, "300", now=later) == []
        assert check(coupon, user, store, "300", now=later - timedelta(seconds=2)).ok

    def test_expired_when_an_order_tries_to_use_it(self, user):
        coupon = personal(user)
        order = OrderFactory(user=user)
        with freeze_time(NOW + timedelta(days=31)), pytest.raises(ApiError) as caught:
            services.apply_coupon_now(order, coupon, Decimal("90.00"))
        assert caught.value.error_code == "COUPON_EXPIRED"


class TestPublicCouponsUnchanged:
    def test_public_coupon_for_everyone(self, store):  # noqa: F811
        coupon = make("JIVO50", min_order_value=Decimal("0"))
        assert coupon.owner is None
        for customer in (UserFactory(), UserFactory()):
            assert check(coupon, customer, store, "300").ok
            sheet = offers(customer, store, "300")
            assert [(o["code"], o["is_personal"]) for o in sheet] == [("JIVO50", False)]

    def test_hidden_public_code_still_works_and_is_not_listed(self, user, store):  # noqa: F811
        hidden = make("JIVOSTAFF", is_visible=False, min_order_value=Decimal("0"))
        assert check(hidden, user, store, "300").ok
        assert offers(user, store, "300") == []
