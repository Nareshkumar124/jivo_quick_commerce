"""Phase 3 panel units: badges pinned to the model choices, rupee display, address and gateway
data masking, and the new sidebar links per role (T-304)."""

from decimal import Decimal

import pytest

from apps.accounts import roles
from apps.ops_console import navigation, pii, status
from apps.ops_console.money import RupeeInput, inr
from apps.ops_console.tests.helpers import (
    COUPON_VIEW_ROLES,
    ORDER_VIEW_ROLES,
    PAYMENT_VIEW_ROLES,
    PRICING_VIEW_ROLES,
    ROLES,
    SUPERUSER,
    WEBHOOK_ROLES,
    make_principal,
)
from apps.orders.choices import OrderStatus, PaymentStatus
from apps.payments.models import PaymentAttemptStatus, RefundStatus
from apps.promotions.models import RedemptionStatus


class TestBadgesMatchTheModels:
    @pytest.mark.parametrize(
        ("kind", "choices"),
        [
            (status.ORDER, OrderStatus),
            (status.ORDER_PAYMENT, PaymentStatus),
            (status.PAYMENT, PaymentAttemptStatus),
            (status.REFUND, RefundStatus),
            (status.REDEMPTION, RedemptionStatus),
        ],
    )
    def test_every_state_has_a_badge(self, kind, choices):
        assert set(status.BADGES[kind]) == set(choices.values)

    @pytest.mark.parametrize("kind", sorted(status.BADGES))
    def test_labels_are_unique_within_a_kind(self, kind):
        """unfold's `@display(label=...)` maps label -> tone, so labels must not repeat."""
        labels = [badge.label for badge in status.BADGES[kind].values()]
        assert len(labels) == len(set(labels))
        assert status.label_tones(kind) == {
            badge.label: badge.tone for badge in status.BADGES[kind].values()
        }


class TestRupees:
    @pytest.mark.parametrize(
        ("value", "text"),
        [
            (Decimal("0.00"), "₹0.00"),
            (Decimal("99"), "₹99.00"),
            (Decimal("1299.50"), "₹1,299.50"),
            (Decimal("2000.00"), "₹2,000.00"),
            (Decimal("100000.00"), "₹1,00,000.00"),
            (Decimal("12345678.90"), "₹1,23,45,678.90"),
            (Decimal("-50.00"), "-₹50.00"),
            ("349.00", "₹349.00"),
            (None, "-"),
        ],
    )
    def test_inr(self, value, text):
        assert inr(value) == text

    def test_rupee_input_renders_a_prefixed_number_field(self):
        html = RupeeInput().render("delivery_fee", Decimal("2000.00"))
        assert 'value="2000.00"' in html  # not localised to "2,000.00" (a number input)
        assert 'type="number"' in html
        assert "₹" in html
        assert 'step="0.01"' in html


SNAPSHOT = {
    "receiver_name": "Asha Verma",
    "receiver_phone": "+919876543210",
    "house": "Flat 402",
    "building_street": "Sunshine Apartments",
    "landmark": "Near the park",
    "area": "Sector 14",
    "city": "Gurugram",
    "state": "Haryana",
    "pincode": "122001",
    "lat": 28.4501,
    "lng": 77.0502,
}


class TestAddressAndPeople:
    def test_full_address(self):
        assert pii.address_lines(SNAPSHOT, full=True) == [
            "Asha Verma, +919876543210",
            "Flat 402",
            "Sunshine Apartments",
            "Near the park",
            "Sector 14, Gurugram",
            "Haryana 122001",
        ]

    def test_limited_address_is_the_locality_with_a_masked_phone(self):
        lines = pii.address_lines(SNAPSHOT, full=False)
        assert lines == ["Asha Verma, +91 XXXXXX3210", "Sector 14, Gurugram", "Haryana 122001"]
        text = " ".join(lines)
        for hidden in ("Flat 402", "Sunshine", "Near the park", "28.45", "77.05", "9876543210"):
            assert hidden not in text

    def test_empty_snapshot(self):
        assert pii.address_lines({}, full=True) == []
        assert pii.address_lines(None, full=False) == []

    def test_customer_and_person_labels_never_use_str_user(self):
        from apps.accounts.models import User

        customer = User(pk=42, name="", phone="+919811122233")
        assert pii.customer_label(customer, full=False) == "Customer 42, +91 XXXXXX2233"
        assert pii.customer_label(customer, full=True) == "Customer 42, +919811122233"
        staff = User(pk=7, name="", email="ops@jivo.test", is_staff=True)
        assert pii.person_label(staff, full=False) == "ops@jivo.test"
        assert pii.person_label(customer, full=False) == "Customer 42, +91 XXXXXX2233"
        assert pii.person_label(None, full=True) == "-"


class TestGatewayData:
    ENTITY = {
        "id": "pay_1",
        "status": "captured",
        "amount": 30000,
        "method": "upi",
        "vpa": "asha@okaxis",
        "email": "asha@example.com",
        "contact": "+919811122233",
        "card": {"last4": "4242"},
        "notes": {"x": "y"},
        "acquirer_data": {"rrn": "123"},
    }

    def test_only_allow_listed_scalars(self):
        assert pii.gateway_fields(self.ENTITY) == [
            ("id", "pay_1"),
            ("status", "captured"),
            ("method", "upi"),
            ("amount", "30000"),
        ]
        assert pii.gateway_fields("not a dict") == []

    def test_webhook_entities(self):
        payload = {"event": "payment.captured", "payload": {"payment": {"entity": self.ENTITY}}}
        entities = pii.webhook_entities(payload)
        assert [name for name, _ in entities] == ["payment"]
        assert "asha@okaxis" not in str(entities)
        assert pii.webhook_entities({"payload": "oops"}) == []
        assert pii.webhook_entities(None) == []


@pytest.mark.django_db
class TestPhase3Navigation:
    @pytest.fixture(autouse=True)
    def _roles(self):
        roles.sync_roles()

    LINKS = {
        "Orders": ORDER_VIEW_ROLES,
        "Payments": PAYMENT_VIEW_ROLES,
        "Refunds": PAYMENT_VIEW_ROLES,
        "Payment webhooks": WEBHOOK_ROLES,
        "Coupons": COUPON_VIEW_ROLES,
        "Coupon redemptions": COUPON_VIEW_ROLES,
        "Pricing config": PRICING_VIEW_ROLES,
    }

    @pytest.mark.parametrize("principal", [*ROLES, SUPERUSER])
    def test_links_per_role(self, principal):
        titles = {
            item["title"]
            for section in navigation.visible_sections(make_principal(principal))
            for item in section["items"]
        }
        for title, allowed in self.LINKS.items():
            assert (title in titles) is (principal in allowed), (principal, title)

    def test_links_resolve(self):
        urls = {
            item.title: item.url()
            for section in navigation.MODULES
            for item in section.items
            if item.title in self.LINKS
        }
        assert set(urls) == set(self.LINKS)
        assert all(url.startswith("/admin/") for url in urls.values())
