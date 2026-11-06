"""Unit tests: PII masking, status badges, navigation registry, sidebar per role."""

import pytest
from django.contrib.auth.models import AnonymousUser, Permission
from django.template import Context, Template
from django.urls import reverse

from apps.accounts import roles
from apps.accounts.models import User
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.ops_console import navigation, pii, status
from apps.ops_console.tests.helpers import (
    ADMIN_SETTINGS_ROLES,
    CUSTOMER_ROLES,
    ROLES,
    SUPERUSER,
    make_principal,
    staff_in_role,
)


class TestMaskPhone:
    @pytest.mark.parametrize(
        ("phone", "masked"),
        [
            ("+919811122233", "+91 XXXXXX2233"),
            ("+14155550123", "XXXXXXXX0123"),
            ("1234", "XXXX"),
            ("", ""),
            (None, ""),
        ],
    )
    def test_mask(self, phone, masked):
        assert pii.mask_phone(phone) == masked

    def test_never_leaks_more_than_four_digits(self):
        masked = pii.mask_phone("+919811122233")
        assert "98111" not in masked
        assert masked.endswith("2233")


@pytest.mark.django_db
class TestPiiPolicy:
    """05 §3 "Customers (PII)": full for Super Admin, Ops, Support; limited (masked) otherwise."""

    @pytest.fixture(autouse=True)
    def _roles(self):
        roles.sync_roles()

    @pytest.mark.parametrize("principal", [*ROLES, SUPERUSER])
    def test_full_phone_only_for_customer_roles(self, principal):
        user = make_principal(principal)
        expected = principal in CUSTOMER_ROLES
        assert pii.can_view_full_phone(user) is expected
        shown = pii.display_phone(user, "+919811122233")
        assert shown == ("+919811122233" if expected else "+91 XXXXXX2233")

    def test_non_staff_and_anonymous_are_masked(self):
        assert pii.display_phone(UserFactory(), "+919811122233") == "+91 XXXXXX2233"
        assert pii.display_phone(AnonymousUser(), "+919811122233") == "+91 XXXXXX2233"

    def test_template_filter(self):
        limited = staff_in_role(roles.STORE_MANAGER)
        full = staff_in_role(roles.SUPPORT)
        template = Template("{% load ops %}{{ phone|phone_for:user }}")
        assert template.render(Context({"phone": "+919811122233", "user": limited})) == (
            "+91 XXXXXX2233"
        )
        assert template.render(Context({"phone": "+919811122233", "user": full})) == (
            "+919811122233"
        )


class TestStatusBadges:
    def test_order_task_payment_states_from_doc_08(self):
        assert set(status.BADGES[status.ORDER]) == {
            "PAYMENT_PENDING",
            "PLACED",
            "ACCEPTED",
            "PACKING",
            "PACKED",
            "OUT_FOR_DELIVERY",
            "DELIVERED",
            "CANCELLED",
            "PAYMENT_FAILED",
            "DELIVERY_FAILED",
            "RETURNED",
        }
        assert set(status.BADGES[status.PAYMENT]) == {"CREATED", "AUTHORIZED", "CAPTURED", "FAILED"}
        assert "UNASSIGNED" in status.BADGES[status.TASK]

    def test_unknown_codes_are_neutral(self):
        assert status.badge_for(status.ORDER, "SOMETHING_NEW") == status.Badge(
            "SOMETHING_NEW", status.NEUTRAL
        )
        assert status.badge_for(status.ORDER, None).label == "-"

    def test_tag_renders_unfold_label(self):
        html = Template('{% load ops %}{% status_badge "order" "DELIVERED" %}').render(Context())
        assert "Delivered" in html
        assert "bg-green-100" in html

    def test_customer_status_precedence(self):
        from django.utils import timezone

        user = User(is_active=False, deleted_at=timezone.now(), anonymised_at=timezone.now())
        assert status.customer_status(user) == "anonymised"
        user.anonymised_at = None
        assert status.customer_status(user) == "deletion_requested"
        user.deleted_at = None
        assert status.customer_status(user) == "blocked"
        user.is_active = True
        assert status.customer_status(user) == "active"


@pytest.mark.django_db
class TestNavigation:
    @pytest.fixture(autouse=True)
    def _roles(self):
        roles.sync_roles()

    def titles(self, user):
        return {
            item["title"]
            for section in navigation.visible_sections(user)
            for item in section["items"]
        }

    def test_every_link_resolves(self):
        """Every link resolves; only the audit log waits for its backend model (core.AuditLog,
        Phase 4 merge), and until then it is hidden, never a broken link."""
        from django.apps import apps

        pending = set()
        try:
            apps.get_model("core", "AuditLog")
        except LookupError:
            pending.add("admin:core_auditlog_changelist")
        # SLICE 5.4: these admin lists register with the Payout model (delivery/admin_54.py).
        try:
            apps.get_model("delivery", "Payout")
        except LookupError:
            for model in ("ridercashledger", "riderearning", "earningrule"):
                pending.add(f"admin:delivery_{model}_changelist")
        for section in navigation.MODULES:
            for item in section.items:
                if item.url_name in pending:
                    assert not item.exists()
                    assert str(item.lazy_url()) == "#"
                    continue
                assert item.url().startswith(("/admin/", "/ops/"))

    @pytest.mark.parametrize("principal", [*ROLES, SUPERUSER])
    def test_ops_sidebar_per_role(self, principal):
        titles = self.titles(make_principal(principal))
        assert "Dashboard" in titles
        assert ("Customers" in titles) is (principal in CUSTOMER_ROLES)
        settings_links = {"Staff users", "Roles & permissions", "App configuration"}
        assert (settings_links <= titles) is (principal in ADMIN_SETTINGS_ROLES)
        assert not (settings_links & titles) or principal in ADMIN_SETTINGS_ROLES

    def test_non_staff_sees_nothing(self):
        assert navigation.visible_sections(UserFactory()) == []

    def test_individual_permission_shows_a_link(self):
        user = StaffUserFactory()
        user.user_permissions.add(Permission.objects.get(codename="view_customer"))
        user = User.objects.get(pk=user.pk)  # fresh permission cache
        assert "Customers" in self.titles(user)

    @pytest.mark.parametrize(
        ("principal", "visible", "hidden"),
        [
            (roles.SUPER_ADMIN, ["Customers", "Staff users", "App configuration"], []),
            (roles.SUPPORT, ["Customers"], ["Staff users", "App configuration"]),
            (roles.FINANCE, [], ["Customers", "Staff users", "App configuration"]),
        ],
    )
    def test_unfold_admin_sidebar_per_role(self, client, principal, visible, hidden):
        client.force_login(make_principal(principal))
        response = client.get(reverse("admin:index"))
        assert response.status_code == 200
        links = {
            item["title"]
            for group in response.context["sidebar_navigation"]
            for item in group["items"]
            if item["has_permission"]
        }
        assert set(visible) <= links
        assert not (set(hidden) & links)

    def test_sidebar_marks_current_page(self, client):
        client.force_login(staff_in_role(roles.OPS))
        html = client.get("/ops/").content.decode()
        assert 'aria-current="page"' in html
