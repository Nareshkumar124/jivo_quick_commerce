"""Coupons admin: free-carton rewards (ADR 0002; `DiscountType.FREE_UNIT` with a `source`).

- The list says "N free cartons" from the coupon's `value` (ADR 0003; no ₹ amount), shows the
  source, and filters by type and source. A reward's redemptions say "N free cartons" too.
- A reward's page has no type, value, cap or minimum fields (a "Reward" section with "1 free
  carton" and the reward's status instead), and its usage limits are read-only: a crafted POST
  cannot turn it into money off or give it more uses. Its end date and on/off switch stay
  editable by the coupon managers.
- Rewards are made by the system only: FREE_UNIT is not offered on the add form.
- The role matrix is the coupons' one (05 §3 "Coupons"), unchanged for rewards.
"""

from decimal import Decimal

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.ops_console.tests.helpers import (
    COUPON_EDIT_ROLES,
    COUPON_VIEW_ROLES,
    PRINCIPALS,
    admin_form_data,
    expected_status,
    login_as,
    offer_editor,
    staff_in_role,
)
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.promotions import rewards
from apps.promotions.admin import STORE_MINIMUM
from apps.promotions.choices import CouponSource, DiscountType
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus

pytestmark = pytest.mark.django_db

ADD = "admin:promotions_coupon_add"
LIST = "admin:promotions_coupon_changelist"
REDEMPTIONS = "admin:promotions_couponredemption_changelist"
MONEY_FIELDS = ("discount_type", "value", "max_discount", "min_order_value")


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


@pytest.fixture
def owner():
    return UserFactory(name="Asha Verma", phone="+919811122233")


@pytest.fixture
def reward(owner) -> Coupon:
    """A welcome reward made by the backend (`rewards.create_reward`)."""
    return rewards.create_reward(owner, source=CouponSource.WELCOME)


@pytest.fixture
def two_cartons(reward) -> Coupon:
    """ADR 0003: a reward of 2 free cartons (`value` = its number of cartons)."""
    Coupon.objects.filter(pk=reward.pk).update(value=Decimal("2"))
    reward.refresh_from_db()
    return reward


@pytest.fixture
def flat() -> Coupon:
    return Coupon.objects.create(
        code="JIVO50", title="Flat ₹50 off", discount_type="FLAT", value=Decimal("50.00")
    )


def change_url(coupon) -> str:
    return reverse("admin:promotions_coupon_change", args=[coupon.pk])


def claim(reward, status=OrderStatus.PLACED) -> CouponRedemption:
    """The reward on an order (as the backend records it: a ₹0 redemption)."""
    order = OrderFactory(user=reward.owner, status=status, coupon=reward, coupon_code=reward.code)
    return CouponRedemption.objects.create(
        coupon=reward,
        user=reward.owner,
        order=order,
        discount_amount=Decimal("0.00"),
        status=RedemptionStatus.APPLIED,
    )


# --------------------------------------------------------------------------- role matrix


@pytest.mark.parametrize("page", ["change", "history"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_reward_pages_keep_the_coupon_matrix(client, reward, principal, page):
    login_as(client, principal)
    response = client.get(reverse(f"admin:promotions_coupon_{page}", args=[reward.pk]))
    assert response.status_code == expected_status(principal, COUPON_VIEW_ROLES), principal


@pytest.mark.parametrize("principal", sorted(COUPON_VIEW_ROLES))
def test_only_coupon_managers_can_save_a_reward(client, reward, principal):
    login_as(client, principal)
    html = client.get(change_url(reward)).content.decode()
    assert ('name="_save"' in html) is (principal in COUPON_EDIT_ROLES)


# --------------------------------------------------------------------------- list


class TestList:
    def test_reward_shows_one_free_carton_and_its_source(self, client, reward, flat):
        client.force_login(staff_in_role(roles.FINANCE))
        response = client.get(reverse(LIST))
        html = response.content.decode()
        assert response.status_code == 200
        assert "1 free carton" in html
        assert "Welcome reward (new account)" in html
        assert "Made by staff" in html  # the staff coupon's source
        assert STORE_MINIMUM in html  # a reward's minimum is the store's cartons, not ₹0
        model_admin = response.context["cl"].model_admin
        assert model_admin.discount(reward) == "1 free carton"
        assert model_admin.discount(flat) == "₹50.00 off"

    @pytest.mark.parametrize(
        ("params", "expected"),
        [
            ({"discount_type__exact": DiscountType.FREE_UNIT}, {"reward"}),
            ({"discount_type__exact": DiscountType.FLAT}, {"flat"}),
            ({"source__exact": CouponSource.WELCOME}, {"reward"}),
            ({"source__exact": CouponSource.NONE}, {"flat"}),
            ({"source__exact": CouponSource.REFERRAL_REFERRER}, set()),
        ],
    )
    def test_filters_by_type_and_source(self, client, reward, flat, params, expected):
        client.force_login(staff_in_role(roles.SUPPORT))
        response = client.get(reverse(LIST), params)
        assert response.status_code == 200
        found = {c.pk for c in response.context["cl"].result_list}
        assert found == {{"reward": reward.pk, "flat": flat.pk}[name] for name in expected}

    def test_reward_redemption_says_one_free_carton(self, client, reward):
        claim(reward)
        client.force_login(staff_in_role(roles.FINANCE))
        html = client.get(reverse(REDEMPTIONS)).content.decode()
        assert reward.code in html
        assert "1 free carton" in html

    def test_two_carton_reward_in_the_list_and_its_redemption(self, client, two_cartons, flat):
        """ADR 0003: the quantity comes from the reward itself (plural from 2)."""
        claim(two_cartons)
        client.force_login(staff_in_role(roles.FINANCE))
        response = client.get(reverse(LIST))
        assert response.status_code == 200
        assert "2 free cartons" in response.content.decode()
        assert response.context["cl"].model_admin.discount(two_cartons) == "2 free cartons"
        response = client.get(reverse(REDEMPTIONS))
        assert response.status_code == 200
        (row,) = response.context["cl"].result_list
        assert response.context["cl"].model_admin.discount(row) == "2 free cartons"
        assert "2 free cartons" in response.content.decode()


# --------------------------------------------------------------------------- reward page


class TestRewardPage:
    @pytest.fixture
    def manager(self, client):
        user = offer_editor()  # ADR 0004: editing needs promotions.manage_offers
        client.force_login(user)
        return user

    def test_no_money_fields_and_fixed_limits(self, client, manager, reward):
        response = client.get(change_url(reward))
        assert response.status_code == 200
        form = response.context["adminform"].form
        for name in MONEY_FIELDS:
            assert name not in form.fields, name
        for name in ("usage_limit_total", "usage_limit_per_user", "first_order_only"):
            assert name not in form.fields, name  # shown read-only
        assert {"ends_at", "is_active", "title"} <= set(form.fields)
        html = response.content.decode()
        assert "1 free carton (₹0, the store&#x27;s free carton size)" in html
        assert "Can be used" in html  # reward status: AVAILABLE
        assert "Welcome reward (new account)" in html

    def test_two_carton_reward_page(self, client, manager, two_cartons):
        response = client.get(change_url(two_cartons))
        assert response.status_code == 200
        assert "value" not in response.context["adminform"].form.fields  # fixed (ADR 0003)
        assert "2 free cartons (₹0, the store&#x27;s free carton size)" in (
            response.content.decode()
        )

    def test_crafted_post_cannot_change_the_number_of_cartons(self, client, manager, two_cartons):
        data = admin_form_data(client.get(change_url(two_cartons)))
        data["value"] = "10"
        response = client.post(change_url(two_cartons), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        two_cartons.refresh_from_db()
        assert two_cartons.value == Decimal("2.00")

    def test_crafted_post_cannot_change_the_reward_terms(self, client, manager, reward):
        data = admin_form_data(client.get(change_url(reward)))
        data.update(
            {
                "title": "Welcome gift",
                "discount_type": "FLAT",
                "value": "500.00",
                "max_discount": "500.00",
                "min_order_value": "1.00",
                "usage_limit_total": "50",
                "usage_limit_per_user": "50",
                "source": CouponSource.NONE,
            }
        )
        response = client.post(change_url(reward), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        reward.refresh_from_db()
        assert reward.title == "Welcome gift"  # an allowed edit
        assert reward.discount_type == DiscountType.FREE_UNIT
        assert reward.value == Decimal("1.00")
        assert reward.max_discount is None
        assert reward.min_order_value == Decimal("0.00")
        assert (reward.usage_limit_total, reward.usage_limit_per_user) == (1, 1)
        assert reward.source == CouponSource.WELCOME

    def test_manager_can_switch_a_reward_off(self, client, manager, reward):
        data = admin_form_data(client.get(change_url(reward)))
        data.pop("is_active", None)
        response = client.post(change_url(reward), data)
        assert response.status_code == 302, response.context["adminform"].form.errors
        reward.refresh_from_db()
        assert reward.is_active is False
        assert "Expired without being used" in client.get(change_url(reward)).content.decode()

    def test_claimed_reward_names_its_order(self, client, manager, reward):
        redemption = claim(reward)
        html = client.get(change_url(reward)).content.decode()
        assert f"order {redemption.order.order_number}" in html
        assert "On an order that is not delivered yet" in html

    def test_used_reward(self, client, manager, reward):
        claim(reward, status=OrderStatus.DELIVERED)
        html = client.get(change_url(reward)).content.decode()
        assert "Used on a delivered order" in html

    def test_history_page_of_a_reward_renders(self, client, manager, reward):
        reward.title = "Changed"
        reward.save()
        version = reward.history.order_by("history_id").first()
        url = reverse("admin:promotions_coupon_simple_history", args=[reward.pk, version.pk])
        response = client.get(url)
        assert response.status_code == 200
        assert "+919811122233" not in response.content.decode()

    def test_staff_coupon_page_is_unchanged(self, client, manager, flat):
        form = client.get(change_url(flat)).context["adminform"].form
        for name in MONEY_FIELDS:
            assert name in form.fields, name
        assert "usage_limit_total" in form.fields


# --------------------------------------------------------------------------- add


class TestAdd:
    def test_free_unit_is_not_offered(self, client):
        client.force_login(offer_editor())
        form = client.get(reverse(ADD)).context["adminform"].form
        offered = {value for value, _label in form.fields["discount_type"].choices}
        assert DiscountType.FREE_UNIT not in offered
        assert {DiscountType.FLAT, DiscountType.PERCENT} <= offered

    def test_posting_free_unit_is_refused(self, client):
        client.force_login(offer_editor())
        data = admin_form_data(client.get(reverse(ADD)))
        data.update(
            {
                "code": "FREEBIE",
                "title": "Free carton",
                "discount_type": DiscountType.FREE_UNIT,
                "value": "1",
                "usage_limit_per_user": "1",
            }
        )
        response = client.post(reverse(ADD), data)
        assert response.status_code == 200
        assert "discount_type" in response.context["adminform"].form.errors
        assert not Coupon.objects.filter(code="FREEBIE").exists()
