"""Coupon edits from the panel (T-406c, backend half of the T-304 review Minors 3-4):
`promotions.services.save_coupon()` and `coupon_edit_errors()`.

- the code cannot change once the coupon is used (a redemption or an order refers to it);
- the total limit cannot go below the uses already counted (HELD + APPLIED), checked on the
  locked coupon row, so a use in flight is never missed;
- a code taken by a concurrent save is a `ValidationError` on `code`, never an IntegrityError.
"""

import threading
import time
from decimal import Decimal

import pytest
from django.core.exceptions import ValidationError
from django.db import IntegrityError, connection, transaction

from apps.accounts.tests.factories import UserFactory
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.promotions import services
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus

pytestmark = pytest.mark.django_db


def make(code="JIVO50", **kwargs) -> Coupon:
    defaults = {
        "title": "Flat ₹50 off",
        "discount_type": "FLAT",
        "value": Decimal("50.00"),
        "usage_limit_per_user": None,
    }
    return Coupon.objects.create(code=code, **{**defaults, **kwargs})


def use(coupon, status=RedemptionStatus.APPLIED) -> CouponRedemption:
    user = UserFactory()
    return CouponRedemption.objects.create(
        coupon=coupon,
        user=user,
        order=OrderFactory(user=user),
        discount_amount=Decimal("50.00"),
        status=status,
    )


def edited(coupon, **changes) -> Coupon:
    """A fresh copy of the stored coupon with `changes`, as a panel form would build it."""
    copy = Coupon.objects.get(pk=coupon.pk)
    for field, value in changes.items():
        setattr(copy, field, value)
    return copy


def refusal(coupon) -> dict:
    with pytest.raises(ValidationError) as caught:
        services.save_coupon(coupon)
    return caught.value.message_dict


class TestSave:
    def test_creates_with_the_code_in_capitals(self):
        coupon = services.save_coupon(
            Coupon(code=" new10 ", title="New", discount_type="FLAT", value=Decimal("10.00"))
        )
        assert Coupon.objects.get(pk=coupon.pk).code == "NEW10"
        assert coupon.history.count() == 1

    def test_unused_coupon_can_be_renamed_and_limited(self):
        coupon = make()
        services.save_coupon(edited(coupon, code="JIVO60", usage_limit_total=0))
        coupon.refresh_from_db()
        assert (coupon.code, coupon.usage_limit_total) == ("JIVO60", 0)

    def test_used_coupon_keeps_its_code(self):
        coupon = make()
        use(coupon)
        assert refusal(edited(coupon, code="OTHER")) == {"code": [services.MSG_CODE_LOCKED]}
        coupon.refresh_from_db()
        assert coupon.code == "JIVO50"

    def test_an_order_alone_also_fixes_the_code(self):
        coupon = make()
        OrderFactory(coupon=coupon)
        assert "code" in refusal(edited(coupon, code="OTHER"))

    def test_same_code_in_another_case_is_not_a_rename(self):
        coupon = make()
        use(coupon)
        services.save_coupon(edited(coupon, code="jivo50", title="Renamed title"))
        coupon.refresh_from_db()
        assert (coupon.code, coupon.title) == ("JIVO50", "Renamed title")

    def test_limit_never_below_counted_uses(self):
        coupon = make()
        use(coupon)
        use(coupon, RedemptionStatus.HELD)
        message = services.MSG_LIMIT_BELOW_USES.format(uses=2)
        assert refusal(edited(coupon, usage_limit_total=1)) == {"usage_limit_total": [message]}
        services.save_coupon(edited(coupon, usage_limit_total=2))  # equal is fine
        coupon.refresh_from_db()
        assert coupon.usage_limit_total == 2

    def test_released_and_reversed_uses_do_not_count(self):
        coupon = make()
        use(coupon, RedemptionStatus.RELEASED)
        use(coupon, RedemptionStatus.REVERSED)
        services.save_coupon(edited(coupon, usage_limit_total=0))
        assert services.counted_uses(coupon) == 0
        assert services.is_used(coupon) is True  # but the code is fixed

    def test_both_errors_at_once_and_nothing_saved(self):
        coupon = make(title="Before")
        use(coupon)
        errors = refusal(edited(coupon, code="OTHER", usage_limit_total=0, title="After"))
        assert set(errors) == {"code", "usage_limit_total"}
        assert Coupon.objects.get(pk=coupon.pk).title == "Before"

    def test_code_taken_is_a_validation_error_and_the_transaction_stays_usable(self):
        make("TAKEN10")
        with transaction.atomic():
            errors = refusal(
                Coupon(code="taken10", title="Dup", discount_type="FLAT", value=Decimal("5.00"))
            )
            assert errors == {"code": [services.MSG_CODE_TAKEN]}
            assert Coupon.objects.count() == 1  # still usable after the refusal

    def test_rename_onto_a_taken_code(self):
        make("TAKEN10")
        coupon = make("FREE10")
        assert refusal(edited(coupon, code="Taken10")) == {"code": [services.MSG_CODE_TAKEN]}

    def test_deleted_coupon_is_never_inserted_again(self):
        """Code review: an edit of a coupon deleted meanwhile is refused (form-level error),
        never saved as a new row with the old id."""
        coupon = make()
        copy = edited(coupon, title="Edited")
        Coupon.objects.filter(pk=coupon.pk).delete()
        assert refusal(copy) == {"__all__": [services.MSG_COUPON_GONE]}
        assert not Coupon.objects.exists()

    def test_other_database_refusals_are_not_hidden(self):
        with pytest.raises(IntegrityError):
            services.save_coupon(
                Coupon(code="ZERO", title="Zero", discount_type="FLAT", value=Decimal("0"))
            )


class TestHelpers:
    def test_edit_errors(self):
        coupon = make()
        assert services.coupon_edit_errors(Coupon(code="X", title="New")) == {}  # not saved yet
        assert services.coupon_edit_errors(edited(coupon, code="OTHER")) == {}  # unused
        use(coupon)
        assert set(services.coupon_edit_errors(edited(coupon, code="OTHER"))) == {"code"}
        gone = edited(coupon, code="OTHER")
        gone.pk = 987654321  # no stored row: nothing to guard
        assert services.coupon_edit_errors(gone) == {}

    def test_code_conflict(self):
        assert services.is_code_conflict(IntegrityError("coupon_code_unique_ci")) is True
        assert services.is_code_conflict(IntegrityError("coupon_value_positive")) is False
        assert services.is_used(None) is False
        assert services.counted_uses(Coupon()) == 0


@pytest.mark.django_db(transaction=True)
class TestRaces:
    def test_two_saves_of_one_code(self):
        """Two staff create the same code at once: one wins, the other gets a validation error
        on `code` (the database's `coupon_code_unique_ci`), never a 500."""
        from apps.orders.tests.test_concurrency import race

        def create():
            return services.save_coupon(
                Coupon(code="race10", title="Race", discount_type="FLAT", value=Decimal("10.00"))
            )

        results = race(create, create)
        wins = [r for r in results if isinstance(r, Coupon)]
        losses = [r for r in results if isinstance(r, Exception)]
        assert (len(wins), len(losses)) == (1, 1), results
        assert isinstance(losses[0], ValidationError)
        assert losses[0].message_dict == {"code": [services.MSG_CODE_TAKEN]}
        assert Coupon.objects.filter(code="RACE10").count() == 1

    def test_limit_check_waits_for_a_use_in_flight(self):
        """An order holding the coupon's last use (placement transaction, coupon row locked) is
        counted: the limit edit waits for it and is refused, never slipped in between."""
        coupon = make()
        customer = UserFactory()
        order = OrderFactory(user=customer, status=OrderStatus.PAYMENT_PENDING, placed_at=None)
        held, release = threading.Event(), threading.Event()
        outcome = {}

        def placement():
            try:
                with transaction.atomic():
                    services.hold_coupon(order, coupon, Decimal("50.00"))
                    held.set()
                    release.wait(10)
            finally:
                connection.close()

        def edit():
            try:
                services.save_coupon(edited(coupon, usage_limit_total=0))
                outcome["saved"] = True
            except ValidationError as exc:
                outcome["errors"] = exc.message_dict
            finally:
                connection.close()

        first = threading.Thread(target=placement)
        first.start()
        try:
            assert held.wait(10)
            second = threading.Thread(target=edit)
            second.start()
            time.sleep(0.5)
            assert second.is_alive()  # waiting on the coupon row lock
        finally:
            release.set()
            first.join(10)
        second.join(10)
        assert outcome == {
            "errors": {"usage_limit_total": [services.MSG_LIMIT_BELOW_USES.format(uses=1)]}
        }
        coupon.refresh_from_db()
        assert coupon.usage_limit_total is None
