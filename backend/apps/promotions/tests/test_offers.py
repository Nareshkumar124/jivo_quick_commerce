"""ADR 0004 §3: the "Offers" page services (`apps.promotions.offers`). Public coupons reuse the
coupon rules; a disabled or expired coupon is hidden and refused by the existing checks. The
buy-N-get-1 and rewards services set the ADR 0003 fields (the store's free size, the reward
quantities)."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import NON_FIELD_ERRORS, PermissionDenied, ValidationError
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.cart.tests.conftest import shop  # noqa: F401 - shared fixture
from apps.core.models import AuditLog
from apps.promotions import offers
from apps.promotions.models import Coupon
from apps.promotions.services import MSG_CODE_TAKEN
from apps.stores.models import PricingConfig

pytestmark = pytest.mark.django_db

COUPONS = "/api/v1/cart/coupons/"
COUPON = "/api/v1/cart/coupon/"
ITEMS = "/api/v1/cart/items/"

FLAT_50 = {
    "code": "jivo50",
    "title": "Flat ₹50 off",
    "discount_type": "FLAT",
    "value": Decimal("50.00"),
    "min_order_value": Decimal("299.00"),
}


@pytest.fixture
def admin_user():
    return SuperUserFactory()


def role_user(role):
    roles.sync_roles()
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    return user


def actions() -> list[str]:
    return list(AuditLog.objects.order_by("id").values_list("action", flat=True))


class TestCreate:
    def test_creates_a_public_coupon(self, admin_user, shop):  # noqa: F811
        coupon = offers.create_public_coupon(
            FLAT_50, actor=admin_user, stores=[shop.store_model], categories=[shop.oils]
        )
        coupon.refresh_from_db()
        assert (coupon.code, coupon.owner_id, coupon.source) == ("JIVO50", None, "NONE")
        assert list(coupon.stores.all()) == [shop.store_model]
        entry = AuditLog.objects.get(action="coupon.create")
        assert entry.actor == admin_user
        assert entry.changes["code"] == "JIVO50"
        assert entry.changes["value"] == "50.00"
        assert entry.changes["store_ids"] == [shop.store_model.pk]
        assert entry.changes["category_ids"] == [shop.oils.pk]
        assert "title" not in entry.changes  # free text stays out of the audit log

    @pytest.mark.parametrize(
        ("change", "field"),
        [
            ({"value": Decimal("0")}, "value"),
            ({"discount_type": "PERCENT", "value": Decimal(120), "max_discount": 100}, "value"),
            ({"discount_type": "PERCENT", "value": Decimal(10)}, "max_discount"),
            ({"max_discount": Decimal("20.00")}, "max_discount"),
            ({"discount_type": "FREE_UNIT", "value": Decimal(1)}, "discount_type"),
            ({"code": "JIVO 50"}, "code"),
            ({"title": ""}, "title"),
        ],
    )
    def test_coupon_rules(self, admin_user, change, field):
        with pytest.raises(ValidationError) as error:
            offers.create_public_coupon({**FLAT_50, **change}, actor=admin_user)
        assert field in error.value.message_dict
        assert not Coupon.objects.exists()
        assert not AuditLog.objects.exists()

    def test_end_after_start(self, admin_user):
        now = timezone.now()
        with pytest.raises(ValidationError) as error:
            offers.create_public_coupon(
                {**FLAT_50, "starts_at": now, "ends_at": now - timedelta(days=1)},
                actor=admin_user,
            )
        assert "ends_at" in error.value.message_dict

    def test_unique_code_ignores_case(self, admin_user):
        offers.create_public_coupon(FLAT_50, actor=admin_user)
        with pytest.raises(ValidationError) as error:
            offers.create_public_coupon({**FLAT_50, "code": "Jivo50"}, actor=admin_user)
        assert error.value.message_dict["code"] == [MSG_CODE_TAKEN]

    def test_unknown_field_is_a_programming_error(self, admin_user):
        with pytest.raises(ValueError, match="owner"):
            offers.create_public_coupon({**FLAT_50, "owner": None}, actor=admin_user)


class TestUpdateAndActive:
    def test_update(self, admin_user, shop):  # noqa: F811
        coupon = offers.create_public_coupon(FLAT_50, actor=admin_user)
        ends = timezone.now() + timedelta(days=7)
        assert offers.update_public_coupon(coupon, {"value": Decimal("50")}, actor=admin_user) is (
            False
        )
        assert offers.update_public_coupon(
            coupon,
            {"ends_at": ends, "title": "₹50 off", "value": Decimal("60")},
            actor=admin_user,
            stores=[shop.store_model],
        )
        coupon.refresh_from_db()
        assert (coupon.ends_at, coupon.value, coupon.title) == (ends, Decimal("60.00"), "₹50 off")
        assert AuditLog.objects.get(action="coupon.update").changes == {
            "ends_at": [None, ends.isoformat()],
            "title": "changed",
            "value": ["50.00", "60.00"],
            "store_ids": [[], [shop.store_model.pk]],
        }
        with pytest.raises(ValidationError) as error:
            offers.update_public_coupon(coupon, {"value": Decimal("-1")}, actor=admin_user)
        assert "value" in error.value.message_dict

    def test_personal_rewards_are_refused(self, admin_user):
        personal = Coupon.objects.create(
            code="FRIEND1",
            title="Reward",
            discount_type="FLAT",
            value=Decimal("50.00"),
            owner=UserFactory(),
        )
        with pytest.raises(ValidationError) as error:
            offers.update_public_coupon(personal, {"title": "x"}, actor=admin_user)
        assert error.value.message_dict == {NON_FIELD_ERRORS: [offers.MSG_PERSONAL]}
        with pytest.raises(ValidationError):
            offers.set_public_coupon_active(personal, False, actor=admin_user)
        assert not AuditLog.objects.exists()

    def test_set_active(self, admin_user):
        coupon = offers.create_public_coupon(FLAT_50, actor=admin_user)
        assert offers.set_public_coupon_active(coupon, True, actor=admin_user) is False
        assert offers.set_public_coupon_active(coupon, False, actor=admin_user) is True
        assert coupon.is_active is False
        assert offers.set_public_coupon_active(coupon, True, actor=admin_user) is True
        assert actions() == ["coupon.create", "coupon.disable", "coupon.enable"]

    def test_deleted_coupon(self, admin_user):
        coupon = offers.create_public_coupon(FLAT_50, actor=admin_user)
        Coupon.objects.filter(pk=coupon.pk).delete()
        with pytest.raises(ValidationError):
            offers.update_public_coupon(coupon, {"title": "x"}, actor=admin_user)
        with pytest.raises(ValidationError):
            offers.set_public_coupon_active(coupon, False, actor=admin_user)

    @pytest.mark.parametrize("role", [roles.CATALOG_MANAGER, roles.SUPPORT, roles.FINANCE])
    def test_other_roles_are_refused(self, admin_user, role):
        coupon = offers.create_public_coupon(FLAT_50, actor=admin_user)
        actor = role_user(role)
        with pytest.raises(PermissionDenied):
            offers.create_public_coupon({**FLAT_50, "code": "NEW"}, actor=actor)
        with pytest.raises(PermissionDenied):
            offers.update_public_coupon(coupon, {"title": "x"}, actor=actor)
        with pytest.raises(PermissionDenied):
            offers.set_public_coupon_active(coupon, False, actor=actor)

    def test_super_admin_role_may(self):
        assert offers.create_public_coupon(FLAT_50, actor=role_user(roles.SUPER_ADMIN)).pk


class TestTheAppSeesIt:
    """A disabled or expired coupon is hidden from the coupon sheet and refused at the cart."""

    def codes(self, client, shop):  # noqa: F811
        body = client.get(COUPONS, headers=shop.headers()).json()
        return [offer["code"] for offer in body["results"]]

    def apply(self, client, shop):  # noqa: F811
        return client.post(COUPON, {"code": "JIVO50"}, headers=shop.headers())

    def test_disable_and_expire(self, auth_client, shop, admin_user):  # noqa: F811
        coupon = offers.create_public_coupon(FLAT_50, actor=admin_user)
        auth_client.post(
            ITEMS, {"variant_id": shop.canola_1l.pk, "quantity": 2}, headers=shop.headers()
        )
        assert self.codes(auth_client, shop) == ["JIVO50"]

        offers.set_public_coupon_active(coupon, False, actor=admin_user)
        assert self.codes(auth_client, shop) == []
        response = self.apply(auth_client, shop)
        assert (response.status_code, response.json()["error"]["code"]) == (422, "COUPON_INVALID")

        offers.set_public_coupon_active(coupon, True, actor=admin_user)
        assert self.apply(auth_client, shop).status_code == 200
        auth_client.delete(COUPON, headers=shop.headers())

        past = timezone.now() - timedelta(minutes=1)
        offers.update_public_coupon(coupon, {"ends_at": past}, actor=admin_user)
        assert self.codes(auth_client, shop) == []
        response = self.apply(auth_client, shop)
        assert (response.status_code, response.json()["error"]["code"]) == (422, "COUPON_EXPIRED")


class TestVolumeOffer:
    def test_set_volume_offer(self, admin_user, shop):  # noqa: F811
        store, size = shop.store_model, shop.canola_1l
        assert offers.set_volume_offer(store, 10, size, actor=admin_user) is True
        config = PricingConfig.objects.get(store=store)
        assert (config.free_unit_every, config.free_unit_variant_id) == (10, size.pk)
        assert offers.set_volume_offer(store.pk, "10", size.pk, actor=admin_user) is False
        assert offers.set_volume_offer(store, 0, None, actor=admin_user) is True  # off
        assert AuditLog.objects.filter(action="offer.volume").first().changes == {
            "store_id": store.pk,
            "free_unit_every": [10, 0],
            "free_unit_variant_id": [size.pk, None],
        }

    @pytest.mark.parametrize(
        "every",
        [
            *(-1, "abc", True, None, "2.0", "+2", "1_0", "1 0"),
            *("\u0661\u0660", "\uff11\uff10", "\u0967\u0966"),  # Arabic-Indic, fullwidth, Hindi
        ],
        ids=lambda value: repr(value),
    )
    def test_invalid_every(self, admin_user, shop, every):  # noqa: F811
        with pytest.raises(ValidationError) as error:
            offers.set_volume_offer(shop.store_model, every, actor=admin_user)
        assert "free_unit_every" in error.value.message_dict

    def test_size_must_be_sold_at_the_store(self, admin_user, shop):  # noqa: F811
        with pytest.raises(ValidationError) as error:
            offers.set_volume_offer(shop.store_model, 10, shop.unsold, actor=admin_user)
        assert "free_unit_variant" in error.value.message_dict

    def test_refused_for_other_roles(self, shop):  # noqa: F811
        with pytest.raises(PermissionDenied):
            offers.set_volume_offer(shop.store_model, 10, actor=role_user(roles.CATALOG_MANAGER))


class TestRewardQuantities:
    def test_set_reward_quantities(self, admin_user):
        from apps.referrals.models import ReferralSettings

        assert offers.set_reward_quantities(
            actor=admin_user, welcome_quantity=3, referral_quantity="2", referral_enabled=False
        )
        config = ReferralSettings.load()
        assert (config.welcome_reward_quantity, config.reward_quantity, config.is_enabled) == (
            3,
            2,
            False,
        )
        assert offers.set_reward_quantities(actor=admin_user, welcome_quantity=3) is False
        assert AuditLog.objects.get(action="offer.rewards").changes == {
            "welcome_reward_quantity": [1, 3],
            "reward_quantity": [1, 2],
            "is_enabled": [True, False],
        }

    @pytest.mark.parametrize("quantity", [0, 11, "x", "1_0", "\u0663", "\uff13", " 3 3"])
    def test_one_to_ten(self, admin_user, quantity):
        with pytest.raises(ValidationError):
            offers.set_reward_quantities(actor=admin_user, referral_quantity=quantity)

    def test_refused_for_other_roles(self):
        with pytest.raises(PermissionDenied):
            offers.set_reward_quantities(actor=role_user(roles.SUPPORT), welcome_quantity=2)
