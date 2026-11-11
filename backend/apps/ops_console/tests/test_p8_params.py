"""P8 audit m2: ids and codes from URLs and query strings never cause a 500.

`str.isdigit()` is true for "²" and "①" (then `int()` fails), a 19-digit number is above
PostgreSQL's bigint, and psycopg refuses a NUL byte (`%00`). Every site goes through
`apps.ops_console.params`: a bad id means "no match" (admin filters), "no filter" (Ops store
pickers) or a 404 (URL segments); a normal id still works.
"""

from decimal import Decimal

import pytest
from django.contrib.admin.models import CHANGE, LogEntry
from django.urls import reverse
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import UserFactory
from apps.catalog.tests.factories import VariantFactory
from apps.core import audit
from apps.inventory.tests.factories import stock
from apps.ops_console.params import has_nul, parse_ascii_id, text_param_or_404
from apps.ops_console.tests.helpers import HAS_CASH_54, login_as, staff_in_role
from apps.ops_console.tests.orders_support import make_order
from apps.orders.choices import OrderStatus
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus
from apps.stores.tests.factories import DarkStoreFactory
from apps.support.choices import TicketCategory, TicketStatus
from apps.support.models import CannedReply, SupportTicket, TicketAttachment, TicketMessage

pytestmark = pytest.mark.django_db

# The audit's cases: superscript two, circled one, a NUL byte, and a 19-digit number.
BAD = ("²", "①", "\x00", "9" * 19)
BAD_IDS = pytest.mark.parametrize("value", BAD, ids=["superscript", "circled", "nul", "19-digits"])
HX = {"HTTP_HX_REQUEST": "true"}


# --------------------------------------------------------------------------- the helper


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        ("42", 42),
        ("0", 0),
        ("007", 7),
        ("9" * 18, int("9" * 18)),
        ("9" * 19, None),
        ("²", None),
        ("①", None),
        ("٣", None),
        ("\x00", None),
        ("1\x00", None),
        ("", None),
        (" 1", None),
        ("1 ", None),
        ("1\n", None),
        ("-1", None),
        ("+1", None),
        ("1.0", None),
        (None, None),
        (42, None),
    ],
)
def test_parse_ascii_id(value, expected):
    assert parse_ascii_id(value) == expected


def test_nul_text_param_is_404():
    from django.http import Http404

    assert has_nul("ab\x00c")
    assert text_param_or_404("GGN-01") == "GGN-01"
    with pytest.raises(Http404):
        text_param_or_404("GGN\x00")


# --------------------------------------------------------------------------- admin list filters


def result_count(client, url_name: str, param: str, value: str) -> int:
    response = client.get(reverse(url_name), {param: value})
    assert response.status_code == 200, (param, value, response.status_code)
    return response.context["cl"].result_count


@pytest.fixture
def store():
    return DarkStoreFactory(code="GGN-01")


class TestInventoryVariantFilter:
    """inventory/admin.py VariantFilter (`lookups` and `queryset`): the ledger's `?variant=`."""

    @BAD_IDS
    def test_bad_value_shows_nothing(self, client, store, value):
        stock(store, VariantFactory(), 5)
        login_as(client, roles.SUPER_ADMIN)
        url = "admin:inventory_stockmovement_changelist"
        assert result_count(client, url, "variant", value) == 0

    def test_normal_id(self, client, store):
        variant = VariantFactory()
        stock(store, variant, 5)
        stock(store, VariantFactory(), 3)
        login_as(client, roles.SUPER_ADMIN)
        url = "admin:inventory_stockmovement_changelist"
        assert result_count(client, url, "variant", str(variant.pk)) == 1
        page = client.get(reverse(url), {"variant": str(variant.pk)}).content.decode()
        assert variant.sku in page  # the filter's label (lookups)


class TestStaffActorFilters:
    """ops_console/admin.py StaffActorFilter: admin history and audit log `?actor=`."""

    @pytest.fixture
    def entries(self):
        actor = staff_in_role(roles.OPS)
        LogEntry.objects.log_actions(
            user_id=actor.pk,
            queryset=[actor],
            action_flag=CHANGE,
            change_message="Changed name.",
            single_object=True,
        )
        audit.record(actor, "test.action", actor, {"n": 1})
        return actor

    @pytest.mark.parametrize(
        "url", ["admin:admin_logentry_changelist", "admin:core_auditlog_changelist"]
    )
    @BAD_IDS
    def test_bad_value_shows_nothing(self, client, entries, url, value):
        login_as(client, roles.SUPER_ADMIN)
        assert result_count(client, url, "actor", value) == 0

    @pytest.mark.parametrize(
        "url", ["admin:admin_logentry_changelist", "admin:core_auditlog_changelist"]
    )
    def test_normal_id(self, client, entries, url):
        login_as(client, roles.SUPER_ADMIN)
        assert result_count(client, url, "actor", str(entries.pk)) >= 1


class TestScopedStoreAndCustomerFilters:
    """scoping.py ScopedStoreFilter (`?store=`) and orders/admin.py CustomerFilter
    (`?customer=`) on the orders list."""

    @pytest.mark.parametrize("param", ["store", "customer"])
    @BAD_IDS
    def test_bad_value_shows_nothing(self, client, store, param, value):
        make_order(store)
        login_as(client, roles.OPS)
        assert result_count(client, "admin:orders_order_changelist", param, value) == 0

    def test_normal_ids(self, client, store):
        order = make_order(store)
        make_order(DarkStoreFactory(code="NOI-18"))
        login_as(client, roles.OPS)
        url = "admin:orders_order_changelist"
        assert result_count(client, url, "store", str(store.pk)) == 1
        assert result_count(client, url, "customer", str(order.user_id)) == 1


class TestCouponFilter:
    """promotions/admin.py CouponFilter: redemptions `?coupon=`."""

    @pytest.fixture
    def redemption(self, store):
        coupon = Coupon.objects.create(
            code="JIVO50", title="Flat 50", discount_type="FLAT", value=Decimal("50.00")
        )
        customer = UserFactory()
        order = make_order(store, user=customer, coupon=coupon, coupon_code=coupon.code)
        return CouponRedemption.objects.create(
            coupon=coupon,
            user=customer,
            order=order,
            discount_amount=Decimal("50.00"),
            status=RedemptionStatus.APPLIED,
        )

    @BAD_IDS
    def test_bad_value_shows_nothing(self, client, redemption, value):
        login_as(client, roles.SUPER_ADMIN)
        url = "admin:promotions_couponredemption_changelist"
        assert result_count(client, url, "coupon", value) == 0

    def test_normal_id(self, client, redemption):
        login_as(client, roles.SUPER_ADMIN)
        url = "admin:promotions_couponredemption_changelist"
        assert result_count(client, url, "coupon", str(redemption.coupon_id)) == 1


# --------------------------------------------------------------------------- Ops store pickers


class TestDispatchStorePicker:
    """dispatch_views._store_id: a bad `?store=` means no store filter (the whole board)."""

    @pytest.mark.parametrize("url", ["ops:dispatch", "ops:dispatch-board"])
    @BAD_IDS
    def test_bad_value_is_ignored(self, client, store, url, value):
        login_as(client, roles.OPS)
        response = client.get(reverse(url), {"store": value}, **HX)
        assert response.status_code == 200
        assert response.context["store_id"] is None

    def test_normal_id(self, client, store):
        login_as(client, roles.OPS)
        response = client.get(reverse("ops:dispatch"), {"store": str(store.pk)})
        assert response.status_code == 200
        assert response.context["store_id"] == store.pk


@pytest.mark.skipif(not HAS_CASH_54, reason="the cash screen needs the slice 5.4 services")
class TestCashStorePicker:
    """delivery_ops_views._store_id: the cash screen's `?store=` (GET or POST)."""

    @pytest.mark.parametrize("url", ["ops:cash", "ops:cash-riders"])
    @BAD_IDS
    def test_bad_value_is_ignored(self, client, store, url, value):
        DarkStoreFactory(code="NOI-18")  # two stores: no single-store default
        login_as(client, roles.OPS)
        response = client.get(reverse(url), {"store": value}, **HX)
        assert response.status_code == 200
        assert response.context["store_id"] is None

    def test_normal_id(self, client, store):
        DarkStoreFactory(code="NOI-18")
        login_as(client, roles.OPS)
        response = client.get(reverse("ops:cash"), {"store": str(store.pk)})
        assert response.status_code == 200
        assert response.context["store_id"] == store.pk


# --------------------------------------------------------------------------- support console


def make_ticket():
    customer = UserFactory()
    ticket = SupportTicket.objects.create(
        user=customer,
        category=TicketCategory.OTHER,
        subject="Other",
        status=TicketStatus.OPEN,
        last_activity_at=timezone.now(),
    )
    TicketMessage.objects.create(ticket=ticket, sender=customer, is_staff=False, body="Help")
    return ticket


class TestCannedReplyId:
    """support_views.canned_reply: a bad `?reply=` gives an empty reply box."""

    @BAD_IDS
    def test_bad_value_gives_an_empty_box(self, client, value):
        ticket = make_ticket()
        CannedReply.objects.create(title="Hello", body="Hi about {{ticket_number}}")
        login_as(client, roles.SUPPORT)
        url = reverse("ops:support-canned-reply", args=[ticket.pk])
        response = client.get(url, {"reply": value}, **HX)
        assert response.status_code == 200
        assert "Hi about" not in response.content.decode()

    def test_normal_id(self, client):
        ticket = make_ticket()
        reply = CannedReply.objects.create(title="Hello", body="Hi about {{ticket_number}}")
        login_as(client, roles.SUPPORT)
        url = reverse("ops:support-canned-reply", args=[ticket.pk])
        response = client.get(url, {"reply": str(reply.pk)}, **HX)
        assert f"Hi about {ticket.number}" in response.content.decode()


class TestAttachmentKey:
    """support_views.attachment `<str:key>`: a NUL byte is a 404, not a 500."""

    @BAD_IDS
    def test_bad_key_is_404(self, client, value):
        ticket = make_ticket()
        login_as(client, roles.SUPPORT)
        url = reverse("ops:support-attachment", args=[ticket.pk, value])
        assert client.get(url).status_code == 404

    def test_normal_key(self, client):
        ticket = make_ticket()
        key = "a" * 32
        TicketAttachment.objects.create(
            key=key,
            ticket=ticket,
            message=ticket.messages.first(),
            uploaded_by=ticket.user,
            file=f"support/{key}.webp",
            size=10,
        )
        login_as(client, roles.SUPPORT)
        url = reverse("ops:support-attachment", args=[ticket.pk, key])
        assert client.get(url).status_code == 302


# --------------------------------------------------------------------------- packing console


class TestStoreCode:
    """packing.store_for `<str:code>` (every /ops/store/<code>/ page): a NUL byte is a 404."""

    @pytest.mark.parametrize(
        "url", ["ops:packing", "ops:packing-queues", "ops:store-returns", "ops:store-returns-list"]
    )
    @BAD_IDS
    def test_bad_code_is_404(self, client, store, url, value):
        login_as(client, roles.OPS)
        assert client.get(reverse(url, args=[value]), **HX).status_code == 404

    def test_nul_on_a_post_is_404(self, client, store):
        login_as(client, roles.STORE_MANAGER)
        order = make_order(store, OrderStatus.PLACED)
        url = reverse("ops:packing-step", args=["\x00", order.pk, "accept"])
        assert client.post(url, **HX).status_code == 404
        order.refresh_from_db()
        assert order.status == OrderStatus.PLACED

    def test_normal_code(self, client, store):
        login_as(client, roles.OPS)
        assert client.get(reverse("ops:packing", args=[store.code])).status_code == 200
