"""Referrals admin (07 §2.5a; added 2026-11-13).

- Role matrix: referral settings belong to the coupon roles (05 §3 "Coupons": Super Admin and
  Catalog Manager edit; Support and Finance view); referrals and codes are view-only for the
  same viewers. Until `apps.accounts.roles` grants any `referrals.*` permission, only the
  superuser flag opens these screens (the matrix switches by itself once the grants land, like
  the slice 5.4 screens in `ops_console.tests.helpers`). The permission tests below check the
  admin itself with explicit permissions, whatever the roles grant.
- Settings: a single row (no add, no delete), history kept, audited, validated.
- Referrals and codes: read-only for everyone; customers masked per the PII policy; phone
  search only for roles that see customers in full.
"""

from decimal import Decimal

import pytest
from django.contrib.auth.models import Permission
from django.db import connection
from django.test.utils import CaptureQueriesContext
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory, UserFactory
from apps.core.models import AuditLog
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    COUPON_EDIT_ROLES,
    COUPON_VIEW_ROLES,
    NON_STAFF,
    PRINCIPALS,
    SUPERUSER,
    expected_status,
    login_as,
)
from apps.orders.choices import OrderStatus
from apps.orders.tests.factories import OrderFactory
from apps.referrals import services
from apps.referrals.admin import AUDIT_SETTINGS_CHANGE
from apps.referrals.choices import ReferralStatus
from apps.referrals.models import SINGLETON_ID, Referral, ReferralCode, ReferralSettings

pytestmark = pytest.mark.django_db

SETTINGS_LIST = "admin:referrals_referralsettings_changelist"
SETTINGS_CHANGE = "admin:referrals_referralsettings_change"
REFERRALS = "admin:referrals_referral_changelist"
CODES = "admin:referrals_referralcode_changelist"

REFERRER_PHONE = "+919811122233"
REFERRER_MASKED = "+91 XXXXXX2233"
FRIEND_PHONE = "+919822233344"
FRIEND_MASKED = "+91 XXXXXX3344"


def _roles_grant_referrals() -> bool:
    if "referrals" in roles.SUPER_ADMIN_APPS:
        return True
    return any(
        perm.startswith("referrals.") for perms in roles.ROLE_PERMISSIONS.values() for perm in perms
    )


GRANTED = _roles_grant_referrals()
VIEW_ROLES = COUPON_VIEW_ROLES if GRANTED else frozenset({SUPERUSER})
EDIT_ROLES = COUPON_EDIT_ROLES if GRANTED else frozenset({SUPERUSER})

VIEW_SETTINGS = "referrals.view_referralsettings"
CHANGE_SETTINGS = "referrals.change_referralsettings"
VIEW_REFERRAL = "referrals.view_referral"
VIEW_CODE = "referrals.view_referralcode"
FULL_PII = "accounts.view_customer"


@pytest.fixture(autouse=True)
def _roles_synced():
    roles.sync_roles()


def staff_with(*perms):
    """A staff member holding exactly `perms` (no role): checks the admin, not roles.py."""
    user = StaffUserFactory()
    for dotted in perms:
        app_label, codename = dotted.split(".", 1)
        user.user_permissions.add(
            Permission.objects.get(content_type__app_label=app_label, codename=codename)
        )
    return user


@pytest.fixture
def config():
    return ReferralSettings.load()


@pytest.fixture
def referrer():
    return UserFactory(name="Asha Verma", phone=REFERRER_PHONE)


@pytest.fixture
def friend():
    return UserFactory(name="Ravi Kumar", phone=FRIEND_PHONE)


@pytest.fixture
def pending(referrer, friend) -> Referral:
    return services.apply_code(friend, services.code_for(referrer).code)


def rewarded_referral(referrer=None) -> Referral:
    """A REWARDED referral made by the real services (code entered, first order delivered)."""
    referrer = referrer or UserFactory()
    friend = UserFactory()
    services.apply_code(friend, services.code_for(referrer).code)
    order = OrderFactory(user=friend, status=OrderStatus.DELIVERED, delivered_at=timezone.now())
    assert services.reward_for_order(order.pk) == "rewarded"
    return Referral.objects.get(referred=friend)


def settings_post(**overrides) -> dict:
    data = {
        "is_enabled": "on",
        "reward_amount": "90.00",
        "reward_validity_days": "30",
        "reward_min_order_value": "0.00",
        "_save": "Save",
    }
    data.update(overrides)
    return {key: value for key, value in data.items() if value is not None}


def change_url() -> str:
    return reverse(SETTINGS_CHANGE, args=[SINGLETON_ID])


# --------------------------------------------------------------------------- role matrix


@pytest.mark.parametrize("principal", PRINCIPALS)
def test_settings_list_opens_the_single_row(client, config, principal):
    login_as(client, principal)
    response = client.get(reverse(SETTINGS_LIST))
    if principal in VIEW_ROLES:
        assert response.status_code == 302
        assert response["Location"] == change_url()
    elif principal in (NON_STAFF, ANONYMOUS):
        assert response.status_code == 302
        assert reverse("admin:login") in response["Location"]
    else:
        assert response.status_code == 403


@pytest.mark.parametrize("page", ["change", "history"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_settings_page_matrix(client, config, principal, page):
    login_as(client, principal)
    response = client.get(reverse(f"admin:referrals_referralsettings_{page}", args=[config.pk]))
    assert response.status_code == expected_status(principal, VIEW_ROLES), (principal, page)


@pytest.mark.parametrize("principal", sorted(VIEW_ROLES))
def test_settings_edit_only_for_coupon_managers(client, config, principal):
    login_as(client, principal)
    html = client.get(change_url()).content.decode()
    can_edit = principal in EDIT_ROLES
    assert ('name="_save"' in html) is can_edit
    response = client.post(change_url(), settings_post(reward_amount="120.00"))
    config.refresh_from_db()
    if can_edit:
        assert response.status_code == 302, response.content
        assert config.reward_amount == Decimal("120.00")
    else:
        assert response.status_code == 403
        assert config.reward_amount == Decimal("90.00")


@pytest.mark.parametrize("model", ["referral", "referralcode"])
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_list_and_detail_matrix(client, pending, principal, model):
    login_as(client, principal)
    obj = pending if model == "referral" else ReferralCode.objects.get()
    for page, args in (("changelist", []), ("change", [obj.pk])):
        response = client.get(reverse(f"admin:referrals_{model}_{page}", args=args))
        assert response.status_code == expected_status(principal, VIEW_ROLES), (principal, page)


def test_roles_grant_status_is_known():
    """Documents the state the matrix above runs in (see the module docstring)."""
    if not GRANTED:
        pytest.skip("apps.accounts.roles grants no referrals.* permission yet (backend gap)")
    for role in (roles.SUPER_ADMIN, roles.CATALOG_MANAGER, roles.SUPPORT, roles.FINANCE):
        assert role in VIEW_ROLES


# --------------------------------------------------------------------------- settings by permission


class TestSettingsPermissions:
    def test_view_only_sees_rupees_and_cannot_save(self, client, config):
        client.force_login(staff_with(VIEW_SETTINGS))
        response = client.get(change_url())
        html = response.content.decode()
        assert response.status_code == 200
        assert 'name="_save"' not in html
        assert "₹90.00" in html
        assert "No minimum" in html
        response = client.post(change_url(), settings_post(reward_amount="150.00"))
        assert response.status_code == 403
        config.refresh_from_db()
        assert config.reward_amount == Decimal("90.00")

    def test_change_saves_audits_and_keeps_history(self, client, config):
        editor = staff_with(VIEW_SETTINGS, CHANGE_SETTINGS)
        client.force_login(editor)
        response = client.post(
            change_url(),
            settings_post(
                is_enabled=None,
                reward_amount="75.50",
                reward_validity_days="45",
                reward_min_order_value="199.00",
            ),
        )
        assert response.status_code == 302, response.context["adminform"].form.errors
        config.refresh_from_db()
        assert config.is_enabled is False
        assert config.reward_amount == Decimal("75.50")
        assert config.reward_validity_days == 45
        assert config.reward_min_order_value == Decimal("199.00")
        assert ReferralSettings.objects.count() == 1

        entry = AuditLog.objects.get(action=AUDIT_SETTINGS_CHANGE)
        assert entry.actor == editor
        assert entry.object_id == str(SINGLETON_ID)
        assert entry.changes == {
            "fields": [
                "is_enabled",
                "reward_amount",
                "reward_min_order_value",
                "reward_validity_days",
            ],
            "is_enabled": False,
            "reward_amount": "75.50",
            "reward_validity_days": 45,
            "reward_min_order_value": "199.00",
        }
        latest = config.history.first()
        assert latest.history_user == editor
        assert latest.reward_amount == Decimal("75.50")

    def test_change_form_has_short_help_texts(self, client, config):
        client.force_login(staff_with(VIEW_SETTINGS, CHANGE_SETTINGS))
        html = client.get(change_url()).content.decode()
        assert "Not used for new rewards: the referral reward is now 1 free carton each." in html
        assert "Reward amount (old ₹ rewards only)" in html
        assert "Minimum item total (old ₹ rewards only)" in html
        assert "1 free carton" in html  # the reward now (ADR 0002)

    @pytest.mark.parametrize(
        ("field", "value"),
        [
            ("reward_amount", "0"),
            ("reward_amount", "1000.01"),
            ("reward_validity_days", "0"),
            ("reward_validity_days", "366"),
            ("reward_min_order_value", "-1"),
        ],
    )
    def test_out_of_range_values_are_refused(self, client, config, field, value):
        client.force_login(staff_with(VIEW_SETTINGS, CHANGE_SETTINGS))
        response = client.post(change_url(), settings_post(**{field: value}))
        assert response.status_code == 200
        assert field in response.context["adminform"].form.errors
        config.refresh_from_db()
        assert (config.reward_amount, config.reward_validity_days) == (Decimal("90.00"), 30)
        assert not AuditLog.objects.filter(action=AUDIT_SETTINGS_CHANGE).exists()


# --------------------------------------------------------------------------- singleton


class TestSingleton:
    def test_list_creates_the_row_once_and_opens_it(self, client):
        client.force_login(SuperUserFactory())
        assert not ReferralSettings.objects.exists()
        for _ in range(2):
            response = client.get(reverse(SETTINGS_LIST))
            assert response.status_code == 302
            assert response["Location"] == change_url()
        config = ReferralSettings.objects.get()
        assert config.pk == SINGLETON_ID
        assert config.reward_amount == Decimal("90.00")

    def test_no_add_and_no_delete_even_for_a_superuser(self, client, config):
        client.force_login(SuperUserFactory())
        assert client.get(reverse("admin:referrals_referralsettings_add")).status_code == 403
        delete = reverse("admin:referrals_referralsettings_delete", args=[config.pk])
        assert client.get(delete).status_code == 403
        assert client.post(delete, {"post": "yes"}).status_code == 403
        html = client.get(change_url()).content.decode()
        assert "_addanother" not in html
        assert ReferralSettings.objects.count() == 1

    def test_history_is_view_only(self, client, config):
        client.force_login(SuperUserFactory())
        client.post(change_url(), settings_post(reward_amount="100.00"))
        version = config.history.order_by("history_id").first()
        url = reverse(
            "admin:referrals_referralsettings_simple_history",
            args=[config.pk, version.history_id],
        )
        assert client.get(url).status_code == 200
        assert client.post(url, settings_post(reward_amount="5.00")).status_code == 403
        config.refresh_from_db()
        assert config.reward_amount == Decimal("100.00")


# --------------------------------------------------------------------------- referrals


class TestReferralList:
    def test_list_shows_status_codes_coupons_and_masked_people(self, client, pending, referrer):
        done = rewarded_referral(referrer)
        client.force_login(staff_with(VIEW_REFERRAL))
        response = client.get(reverse(REFERRALS))
        html = response.content.decode()
        assert response.status_code == 200
        assert set(response.context["cl"].result_list) == {pending, done}
        assert "Waiting for first delivery" in html
        assert "Rewarded" in html
        assert done.referrer_coupon.code in html
        assert done.referred_coupon.code in html
        assert done.reward_order.order_number in html
        assert "1 free carton" in html  # ADR 0002: free-carton rewards have no ₹ amount
        assert pending.code in html
        assert REFERRER_MASKED in html
        assert FRIEND_MASKED in html
        assert REFERRER_PHONE not in html
        assert FRIEND_PHONE not in html

    def test_full_pii_viewer_sees_phones(self, client, pending):
        client.force_login(staff_with(VIEW_REFERRAL, FULL_PII))
        html = client.get(reverse(REFERRALS)).content.decode()
        assert REFERRER_PHONE in html
        assert FRIEND_PHONE in html

    def test_detail_is_masked_for_limited_viewers(self, client, pending):
        client.force_login(staff_with(VIEW_REFERRAL))
        url = reverse("admin:referrals_referral_change", args=[pending.pk])
        html = client.get(url).content.decode()
        assert REFERRER_MASKED in html
        assert FRIEND_MASKED in html
        assert REFERRER_PHONE not in html
        assert FRIEND_PHONE not in html

    def test_filter_by_status(self, client, pending):
        done = rewarded_referral()
        client.force_login(SuperUserFactory())
        for status, expected in (
            (ReferralStatus.PENDING, [pending]),
            (ReferralStatus.REWARDED, [done]),
            (ReferralStatus.VOID, []),
        ):
            response = client.get(reverse(REFERRALS), {"status__exact": status})
            assert list(response.context["cl"].result_list) == expected, status

    def test_search_by_code_any_case(self, client, pending):
        rewarded_referral()
        client.force_login(staff_with(VIEW_REFERRAL))
        response = client.get(reverse(REFERRALS), {"q": pending.code.lower()})
        assert list(response.context["cl"].result_list) == [pending]

    @pytest.mark.parametrize(("perms", "found"), [((VIEW_REFERRAL, FULL_PII), True), ((), False)])
    def test_phone_search_only_with_full_pii(self, client, pending, perms, found):
        rewarded_referral()
        client.force_login(staff_with(VIEW_REFERRAL, *perms))
        for query in (FRIEND_PHONE, REFERRER_PHONE, "98222"):
            response = client.get(reverse(REFERRALS), {"q": query})
            expected = [pending] if found else []
            assert list(response.context["cl"].result_list) == expected, query

    def test_read_only_even_for_a_superuser(self, client, pending):
        client.force_login(SuperUserFactory())
        assert client.get(reverse("admin:referrals_referral_add")).status_code == 403
        change = reverse("admin:referrals_referral_change", args=[pending.pk])
        response = client.get(change)
        assert response.status_code == 200
        assert 'name="_save"' not in response.content.decode()
        before = (pending.status, pending.code, pending.note)
        response = client.post(change, {"status": ReferralStatus.REWARDED, "note": "x"})
        assert response.status_code == 403
        pending.refresh_from_db()
        assert (pending.status, pending.code, pending.note) == before
        delete = reverse("admin:referrals_referral_delete", args=[pending.pk])
        assert client.post(delete, {"post": "yes"}).status_code == 403
        assert Referral.objects.filter(pk=pending.pk).exists()
        listing = client.get(reverse(REFERRALS)).content.decode()
        assert 'name="action"' not in listing

    def test_list_queries_do_not_grow_with_rows(self, client):
        client.force_login(staff_with(VIEW_REFERRAL))
        rewarded_referral()
        client.get(reverse(REFERRALS))  # warm-up (first-request caches)
        with CaptureQueriesContext(connection) as few:
            assert client.get(reverse(REFERRALS)).status_code == 200
        for _ in range(4):
            rewarded_referral()
        with CaptureQueriesContext(connection) as many:
            assert client.get(reverse(REFERRALS)).status_code == 200
        assert len(many) == len(few)


# --------------------------------------------------------------------------- referral codes


class TestReferralCodeList:
    def test_masked_customer_and_search_by_code(self, client, referrer):
        code = services.code_for(referrer)
        other = services.code_for(UserFactory())
        client.force_login(staff_with(VIEW_CODE))
        response = client.get(reverse(CODES))
        html = response.content.decode()
        assert set(response.context["cl"].result_list) == {code, other}
        assert REFERRER_MASKED in html
        assert REFERRER_PHONE not in html
        response = client.get(reverse(CODES), {"q": code.code.lower()})
        assert list(response.context["cl"].result_list) == [code]
        # Phone search is not offered on codes.
        response = client.get(reverse(CODES), {"q": REFERRER_PHONE})
        assert list(response.context["cl"].result_list) == []

    def test_full_pii_viewer_sees_the_phone(self, client, referrer):
        services.code_for(referrer)
        client.force_login(staff_with(VIEW_CODE, FULL_PII))
        assert REFERRER_PHONE in client.get(reverse(CODES)).content.decode()

    def test_read_only_even_for_a_superuser(self, client, referrer):
        code = services.code_for(referrer)
        client.force_login(SuperUserFactory())
        assert client.get(reverse("admin:referrals_referralcode_add")).status_code == 403
        change = reverse("admin:referrals_referralcode_change", args=[code.pk])
        assert 'name="_save"' not in client.get(change).content.decode()
        assert client.post(change, {"code": "HACKED"}).status_code == 403
        delete = reverse("admin:referrals_referralcode_delete", args=[code.pk])
        assert client.post(delete, {"post": "yes"}).status_code == 403
        code.refresh_from_db()
        assert code.code != "HACKED"
        assert 'name="action"' not in client.get(reverse(CODES)).content.decode()

    def test_list_queries_do_not_grow_with_rows(self, client):
        client.force_login(staff_with(VIEW_CODE))
        services.code_for(UserFactory())
        client.get(reverse(CODES))  # warm-up (first-request caches)
        with CaptureQueriesContext(connection) as few:
            assert client.get(reverse(CODES)).status_code == 200
        for _ in range(4):
            services.code_for(UserFactory())
        with CaptureQueriesContext(connection) as many:
            assert client.get(reverse(CODES)).status_code == 200
        assert len(many) == len(few)


# --------------------------------------------------------------------------- ADR 0002


class TestFreeCartonRewards:
    """ADR 0002: the reward is 1 free carton each; the ₹ settings are for old rewards only."""

    def test_new_reward_says_one_free_carton(self, client):
        from apps.promotions.choices import DiscountType

        done = rewarded_referral()
        assert done.reward_amount is None
        assert done.referrer_coupon.discount_type == DiscountType.FREE_UNIT
        client.force_login(staff_with(VIEW_REFERRAL))
        response = client.get(reverse("admin:referrals_referral_change", args=[done.pk]))
        html = response.content.decode()
        assert response.status_code == 200
        assert "1 free carton" in html
        assert "Older referrals got a ₹ off coupon." in html

    def test_old_rupee_reward_keeps_its_amount(self, client, pending):
        from apps.promotions import services as promotions

        coupons = [
            promotions.create_personal_coupon(
                user,
                amount=Decimal("90.00"),
                valid_days=30,
                min_order_value=Decimal("0.00"),
                title="₹90 off: referral reward",
                now=timezone.now(),
            )
            for user in (pending.referrer, pending.referred)
        ]
        order = OrderFactory(
            user=pending.referred, status=OrderStatus.DELIVERED, delivered_at=timezone.now()
        )
        Referral.objects.filter(pk=pending.pk).update(
            status=ReferralStatus.REWARDED,
            reward_order=order,
            reward_amount=Decimal("90.00"),
            referrer_coupon=coupons[0],
            referred_coupon=coupons[1],
            rewarded_at=timezone.now(),
        )
        client.force_login(staff_with(VIEW_REFERRAL))
        response = client.get(reverse(REFERRALS))
        assert response.status_code == 200
        model_admin = response.context["cl"].model_admin
        (row,) = response.context["cl"].result_list
        assert model_admin.reward(row) == "₹90.00"

    def test_view_only_settings_label_the_old_rupee_values(self, client, config):
        client.force_login(staff_with(VIEW_SETTINGS))
        html = client.get(change_url()).content.decode()
        assert "Reward amount (old ₹ rewards only)" in html
        assert "Minimum item total (old ₹ rewards only)" in html
        assert "Old ₹ rewards" in html
        assert "1 free carton" in html
        assert "₹90.00" in html
