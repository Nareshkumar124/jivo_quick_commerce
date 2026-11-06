"""Phase 4 R2: order processing (08 T6, T7, T8, T8a, T11, T12), the customer cancel window (08
§7), refunds per 08 §6.4 defaults, auto-accept and the acceptance SLA, and the 05 §3 role
matrix with store scoping. P4 test cases: no catalogue exists yet; tests name the 08 rule."""

from datetime import timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.core.exceptions import ApiError
from apps.core.models import AuditLog
from apps.inventory.models import ReservationStatus, StockReservation, StoreInventory
from apps.orders import services, store_ops
from apps.orders.models import Order, OrderStatusHistory
from apps.payments.models import Refund, RefundStatus
from apps.promotions.models import Coupon, CouponRedemption, RedemptionStatus
from apps.stores.services import grant_store_access

pytestmark = pytest.mark.django_db

D = Decimal


@pytest.fixture
def make_staff():
    def make(role, *stores):
        user = StaffUserFactory()
        user.groups.add(Group.objects.get(name=role))
        for store in stores:
            grant_store_access(user, store)
        return user

    return make


@pytest.fixture
def staff(make_staff, shop):
    return make_staff(roles.STORE_STAFF, shop.store_model)


@pytest.fixture
def manager(make_staff, shop):
    return make_staff(roles.STORE_MANAGER, shop.store_model)


def reserved(shop, variant) -> int:
    return StoreInventory.objects.get(store=shop.store_model, variant=variant).reserved


def place(checkout, shop, method="COD", lines=None, capture=None):
    checkout.fill(*(lines or [(shop.canola_1l, 2)]))
    placement = checkout.place(method)
    if method == "ONLINE":
        checkout.verify(placement)
    return Order.objects.get(pk=placement["order"]["id"])


def to_packing(order, user):
    store_ops.accept_order(order.pk, by=user)
    store_ops.start_packing(order.pk, by=user)
    order.refresh_from_db()
    return order


class TestTransitions:
    def test_t6_t7_t8(self, checkout, shop, staff):
        """08 T6/T7/T8: history rows, timestamps, pickup code, audit log."""
        order = place(checkout, shop)
        store_ops.accept_order(order.pk, by=staff)
        order.refresh_from_db()
        assert order.status == "ACCEPTED"
        assert order.accepted_at
        assert len(order.pickup_code) == 4
        store_ops.start_packing(order.pk, by=staff)
        store_ops.mark_packed(order.pk, by=staff)
        order.refresh_from_db()
        assert order.status == "PACKED"
        assert order.packing_started_at
        assert order.packed_at
        assert list(
            OrderStatusHistory.objects.filter(order=order).values_list("to_status", flat=True)
        ) == ["PLACED", "ACCEPTED", "PACKING", "PACKED"]
        assert set(
            OrderStatusHistory.objects.filter(order=order).values_list("actor_type", flat=True)
        ) == {"customer", "store"}
        assert list(
            AuditLog.objects.filter(object_id=str(order.pk)).values_list("action", flat=True)
        ) == ["order.packed", "order.start_packing", "order.accept"]
        assert reserved(shop, shop.canola_1l) == 2  # still only reserved until pickup (T9)

    def test_out_of_order_moves_are_refused(self, checkout, shop, staff):
        order = place(checkout, shop)
        with pytest.raises(ApiError) as exc:
            store_ops.start_packing(order.pk, by=staff)
        assert exc.value.error_code == "INVALID_STATE_TRANSITION"
        with pytest.raises(ApiError):
            store_ops.mark_packed(order.pk, by=staff)
        store_ops.accept_order(order.pk, by=staff)
        with pytest.raises(ApiError):
            store_ops.accept_order(order.pk, by=staff)

    def test_transition_table_refuses_unlisted_moves(self, checkout, shop):
        from django.db import transaction

        order = place(checkout, shop)
        with transaction.atomic(), pytest.raises(ApiError):
            services.transition(order, "PACKED", actor_type="store")
        with transaction.atomic(), pytest.raises(ApiError):
            services.transition(order, "DELIVERED", actor_type="store")

    def test_pickup_codes_are_unique_per_store(self, checkout, shop, staff):
        first = place(checkout, shop)
        second = place(checkout, shop, lines=[(shop.chia, 2)])
        for order in (first, second):
            store_ops.accept_order(order.pk, by=staff)
        first.refresh_from_db()
        second.refresh_from_db()
        assert first.pickup_code != second.pickup_code


class TestRoleMatrix:
    """05 §3: packing console and cancel permissions, and store scoping (IDOR)."""

    def test_store_staff_of_another_store_cannot_see_the_order(self, checkout, shop, make_staff):
        order = place(checkout, shop)
        other = make_staff(roles.STORE_STAFF, shop.other_store_model)
        with pytest.raises(ValidationError):
            store_ops.accept_order(order.pk, by=other)
        order.refresh_from_db()
        assert order.status == "PLACED"

    @pytest.mark.parametrize("role", [roles.CATALOG_MANAGER, roles.FINANCE, roles.SUPPORT])
    def test_roles_without_the_packing_console(self, checkout, shop, make_staff, role):
        order = place(checkout, shop)
        with pytest.raises(PermissionDenied):
            store_ops.accept_order(order.pk, by=make_staff(role))

    def test_ops_and_superuser_process_any_store(self, checkout, shop, make_staff, superuser):
        order = place(checkout, shop)
        ops = make_staff(roles.OPS)
        store_ops.accept_order(order.pk, by=ops)
        store_ops.start_packing(order.pk, by=superuser)
        assert OrderStatusHistory.objects.filter(order=order, actor_type="ops").count() == 2

    def test_customer_is_not_staff(self, checkout, shop, user):
        order = place(checkout, shop)
        with pytest.raises(PermissionDenied):
            store_ops.accept_order(order.pk, by=user)

    @pytest.mark.parametrize(
        ("role", "allowed"),
        [
            (roles.STORE_MANAGER, True),
            (roles.OPS, True),
            (roles.SUPPORT, True),
            (roles.STORE_STAFF, False),
            (roles.FINANCE, False),
            (roles.CATALOG_MANAGER, False),
        ],
    )
    def test_cancel_permission(self, checkout, shop, make_staff, role, allowed):
        order = place(checkout, shop)
        user = make_staff(role, shop.store_model)
        if allowed:
            store_ops.cancel_by_staff(order.pk, by=user, reason="CUSTOMER_REQUEST")
            order.refresh_from_db()
            assert order.status == "CANCELLED"
        else:
            with pytest.raises(PermissionDenied):
                store_ops.cancel_by_staff(order.pk, by=user, reason="CUSTOMER_REQUEST")

    def test_manager_of_another_store_cannot_cancel(self, checkout, shop, make_staff):
        order = place(checkout, shop)
        other = make_staff(roles.STORE_MANAGER, shop.other_store_model)
        with pytest.raises(ValidationError):
            store_ops.cancel_by_staff(order.pk, by=other, reason="CUSTOMER_REQUEST")

    def test_role_permissions(self):
        perms = {
            name: set(
                Group.objects.get(name=name).permissions.values_list(
                    "content_type__app_label", "codename"
                )
            )
            for name in (roles.STORE_STAFF, roles.SUPPORT, roles.FINANCE, roles.OPS)
        }
        assert ("orders", "process_order") in perms[roles.STORE_STAFF]
        assert ("orders", "cancel_order") not in perms[roles.STORE_STAFF]
        assert ("payments", "issue_refund") in perms[roles.SUPPORT]
        assert ("payments", "issue_refund") in perms[roles.FINANCE]
        assert ("payments", "issue_refund") not in perms[roles.OPS]
        assert ("core", "view_auditlog") in perms[roles.FINANCE]


class TestItemsUnavailable:
    """08 T8a / §6.3."""

    def test_online_refund_of_the_difference(
        self, checkout, shop, staff, django_capture_on_commit_callbacks
    ):
        order = place(checkout, shop, "ONLINE", [(shop.canola_1l, 2), (shop.chia, 1)])
        assert order.amount_paid == order.grand_total == D("677.00")
        to_packing(order, staff)
        line = order.items.get(variant=shop.canola_1l)
        with django_capture_on_commit_callbacks(execute=True):
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
        order.refresh_from_db()
        line.refresh_from_db()
        assert line.quantity_unavailable == 1
        assert line.line_total == D("279.00")
        assert order.item_total == D("398.00")
        assert order.grand_total == D("398.00")
        assert order.mrp_total == D("499.00")  # 349 + 150
        refund = Refund.objects.get(order=order)
        assert refund.amount == D("279.00")
        assert refund.reason == "item_unavailable"
        assert refund.status == RefundStatus.PROCESSED
        assert order.payment_status == "PARTIALLY_REFUNDED"
        assert order.amount_refunded == D("279.00")
        assert order.amount_paid == D("677.00")
        assert reserved(shop, shop.canola_1l) == 1
        assert StockReservation.objects.get(order=order, variant=shop.canola_1l).quantity == 1

    def test_fees_never_increase(self, checkout, shop, staff):
        """Removing a unit takes the item total below free delivery: the delivery fee stays 0."""
        order = place(checkout, shop, "ONLINE", [(shop.canola_1l, 2)])
        assert order.delivery_fee == 0
        to_packing(order, staff)
        line = order.items.get()
        store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
        order.refresh_from_db()
        assert order.item_total == D("279.00") < D("299.00")
        assert order.delivery_fee == 0
        assert order.grand_total == D("279.00")
        assert Refund.objects.get(order=order).amount == D("279.00")

    def test_coupon_discount_is_kept_and_capped(self, checkout, shop, staff):
        Coupon.objects.create(
            code="FLAT50", title="Flat 50", discount_type="FLAT", value=D("50.00")
        )
        checkout.fill((shop.canola_1l, 2), (shop.flax, 1))
        response = checkout.client.post(
            "/api/v1/cart/coupon/", {"code": "FLAT50"}, headers=checkout.headers
        )
        assert response.status_code == 200, response.content
        order = Order.objects.get(pk=checkout.place("COD")["order"]["id"])
        assert order.coupon_discount == D("50.00")
        to_packing(order, staff)
        line = order.items.get(variant=shop.canola_1l)
        store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=2, by=staff)
        order.refresh_from_db()
        assert order.item_total == D("79.00")
        assert order.coupon_discount == D("50.00")  # kept (customer not penalised)
        # small-cart fee would apply below 149 but was 0 on the order: capped at 0
        assert order.small_cart_fee == 0
        assert order.delivery_fee == 0
        assert order.grand_total == D("29.00")
        assert not Refund.objects.filter(order=order).exists()  # COD: reduced amount due

    def test_cod_reduces_the_amount_due(self, checkout, shop, staff):
        order = place(checkout, shop, "COD", [(shop.canola_1l, 2), (shop.chia, 2)])
        to_packing(order, staff)
        line = order.items.get(variant=shop.chia)
        store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
        order.refresh_from_db()
        assert order.grand_total == D("677.00")
        assert order.payment_status == "COD_PENDING"
        assert not Refund.objects.filter(order=order).exists()

    def test_nothing_left_cancels_the_order(
        self, checkout, shop, staff, django_capture_on_commit_callbacks
    ):
        order = place(checkout, shop, "ONLINE", [(shop.canola_1l, 2)])
        store_ops.accept_order(order.pk, by=staff)
        line = order.items.get()
        with django_capture_on_commit_callbacks(execute=True):
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=2, by=staff)
        order.refresh_from_db()
        line.refresh_from_db()
        assert order.status == "CANCELLED"
        assert order.cancel_reason == "ITEMS_UNAVAILABLE"
        assert line.quantity_unavailable == 0  # the line keeps its quantities
        assert order.grand_total == D("558.00")
        assert order.payment_status == "REFUNDED"
        assert order.amount_refunded == D("558.00")
        assert reserved(shop, shop.canola_1l) == 0

    def test_validation_and_idempotency(self, checkout, shop, staff):
        order = place(checkout, shop, "COD", [(shop.canola_1l, 2), (shop.chia, 1)])
        line = order.items.get(variant=shop.canola_1l)
        with pytest.raises(ApiError):  # still PLACED
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
        to_packing(order, staff)
        store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
        store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)  # no-op
        order.refresh_from_db()
        assert order.item_total == D("398.00")
        with pytest.raises(ValidationError):
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=0, by=staff)
        with pytest.raises(ValidationError):
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=3, by=staff)
        with pytest.raises(ValidationError):
            store_ops.mark_item_unavailable(order.pk, 999999, unavailable=1, by=staff)
        store_ops.mark_packed(order.pk, by=staff)
        with pytest.raises(ApiError):  # 08 T8a: not after PACKED
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=2, by=staff)


class TestCancellation:
    def test_t12_from_packed_releases_stock_and_refunds(
        self, checkout, shop, staff, manager, django_capture_on_commit_callbacks
    ):
        order = place(checkout, shop, "ONLINE", [(shop.canola_1l, 2)])
        to_packing(order, staff)
        store_ops.mark_packed(order.pk, by=staff)
        with django_capture_on_commit_callbacks(execute=True):
            store_ops.cancel_by_staff(
                order.pk, by=manager, reason="STORE_CLOSING", note="Power cut"
            )
        order.refresh_from_db()
        assert order.status == "CANCELLED"
        assert order.cancelled_by_type == "store"
        assert order.cancel_reason == "STORE_CLOSING"
        assert reserved(shop, shop.canola_1l) == 0
        assert not StockReservation.objects.filter(
            order=order, status=ReservationStatus.ACTIVE
        ).exists()
        refund = Refund.objects.get(order=order)
        assert refund.amount == D("558.00")
        assert refund.reason == "staff_cancel"
        assert refund.initiated_by == manager
        assert order.payment_status == "REFUNDED"
        assert AuditLog.objects.filter(action="order.cancel", object_id=str(order.pk)).exists()

    def test_t12_needs_a_reason(self, checkout, shop, manager):
        order = place(checkout, shop)
        with pytest.raises(ValidationError):
            store_ops.cancel_by_staff(order.pk, by=manager, reason="BORED")

    def test_cancel_after_a_partial_refund_refunds_the_rest(
        self, checkout, shop, staff, manager, django_capture_on_commit_callbacks
    ):
        order = place(checkout, shop, "ONLINE", [(shop.canola_1l, 2), (shop.chia, 1)])
        to_packing(order, staff)
        line = order.items.get(variant=shop.chia)
        with django_capture_on_commit_callbacks(execute=True):
            store_ops.mark_item_unavailable(order.pk, line.pk, unavailable=1, by=staff)
            store_ops.cancel_by_staff(order.pk, by=manager, reason="CUSTOMER_REQUEST")
        order.refresh_from_db()
        amounts = sorted(Refund.objects.filter(order=order).values_list("amount", flat=True))
        assert amounts == [D("119.00"), D("558.00")]
        assert order.amount_refunded == order.amount_paid == D("677.00")
        assert order.payment_status == "REFUNDED"

    def test_cod_cancel_is_not_paid(self, checkout, shop, manager):
        order = place(checkout, shop)
        store_ops.cancel_by_staff(order.pk, by=manager, reason="ADDRESS_ISSUE")
        order.refresh_from_db()
        assert order.payment_status == "FAILED"
        assert not Refund.objects.filter(order=order).exists()


class TestCustomerCancel:
    """08 §7 / T11 through the API."""

    def cancel(self, checkout, order, reason="CHANGED_MIND"):
        return checkout.client.post(f"/api/v1/orders/{order.pk}/cancel/", {"reason": reason})

    def test_paid_order_is_refunded_in_full(
        self, checkout, shop, django_capture_on_commit_callbacks
    ):
        Coupon.objects.create(code="FLAT20", title="Flat 20", discount_type="FLAT", value=20)
        checkout.fill((shop.canola_1l, 2))
        checkout.client.post("/api/v1/cart/coupon/", {"code": "FLAT20"}, headers=checkout.headers)
        placement = checkout.place("ONLINE")
        checkout.verify(placement)
        order = Order.objects.get(pk=placement["order"]["id"])
        detail = checkout.client.get(f"/api/v1/orders/{order.pk}/").json()
        assert detail["can_cancel"] is True
        with django_capture_on_commit_callbacks(execute=True):
            response = self.cancel(checkout, order)
        assert response.status_code == 200, response.content
        body = checkout.client.get(f"/api/v1/orders/{order.pk}/").json()
        assert body["status"] == "CANCELLED"
        assert body["payment_status"] == "REFUNDED"
        assert body["cancellation"]["reason"] == "CHANGED_MIND"
        assert body["cancellation"]["cancelled_by"] == "customer"
        assert body["amount_refunded"] == "538.00"
        assert body["refunds"] == [
            {
                "id": body["refunds"][0]["id"],
                "amount": "538.00",
                "status": "PROCESSED",
                "reason": "ORDER_CANCELLED",
                "created_at": body["refunds"][0]["created_at"],
                "processed_at": body["refunds"][0]["processed_at"],
            }
        ]
        assert [step["status"] for step in body["timeline"]] == [
            "PAYMENT_PENDING",
            "PLACED",
            "CANCELLED",
        ]
        assert body["can_cancel"] is False
        assert CouponRedemption.objects.get(order=order).status == RedemptionStatus.REVERSED
        assert reserved(shop, shop.canola_1l) == 0
        assert self.cancel(checkout, order).status_code == 409

    def test_accepted_cod_order(self, checkout, shop, staff):
        order = place(checkout, shop)
        store_ops.accept_order(order.pk, by=staff)
        response = self.cancel(checkout, order)
        assert response.status_code == 200
        assert response.json()["payment_status"] == "FAILED"

    def test_not_from_packing(self, checkout, shop, staff):
        order = place(checkout, shop)
        to_packing(order, staff)
        response = self.cancel(checkout, order)
        assert response.status_code == 409
        assert response.json()["error"]["details"] == {"status": "PACKING"}
        assert checkout.client.get(f"/api/v1/orders/{order.pk}/").json()["can_cancel"] is False

    def test_window_setting(self, checkout, shop, staff, settings):
        settings.CUSTOMER_CANCEL_UNTIL = "PLACED"
        order = place(checkout, shop)
        store_ops.accept_order(order.pk, by=staff)
        assert self.cancel(checkout, order).status_code == 409

    def test_another_users_order_is_404(self, checkout, shop, make_auth_client):
        from apps.accounts.tests.factories import UserFactory

        order = place(checkout, shop)
        other = make_auth_client(UserFactory())
        assert (
            other.post(f"/api/v1/orders/{order.pk}/cancel/", {"reason": "OTHER"}).status_code == 404
        )
        order.refresh_from_db()
        assert order.status == "PLACED"


class TestAutoAcceptAndSla:
    def test_auto_accept_store(self, checkout, shop, django_capture_on_commit_callbacks):
        shop.store_model.auto_accept_orders = True
        shop.store_model.save()
        checkout.fill((shop.canola_1l, 1), (shop.chia, 1))
        with django_capture_on_commit_callbacks(execute=True):
            placement = checkout.place("COD")
        order = Order.objects.get(pk=placement["order"]["id"])
        assert order.status == "ACCEPTED"
        assert order.status_history.last().actor_type == "system"
        assert len(order.pickup_code) == 4

    def test_manual_store_waits_and_alerts_once(
        self, checkout, shop, django_capture_on_commit_callbacks, caplog
    ):
        with django_capture_on_commit_callbacks(execute=True):
            order = place(checkout, shop)
        order.refresh_from_db()
        assert order.status == "PLACED"
        assert store_ops.acceptance_sla_alert(order.pk) == "not_due"
        later = timezone.now() + timedelta(minutes=2)
        assert store_ops.acceptance_sla_alert(order.pk, later) == "alerted"
        assert store_ops.acceptance_sla_alert(order.pk, later) == "already"
        assert store_ops.sweep_placed_orders(later) == {"already": 1}

    def test_auto_accept_skips(self, checkout, shop, staff):
        order = place(checkout, shop)
        assert store_ops.auto_accept(order.pk) == "skipped"  # store setting off
        shop.store_model.auto_accept_orders = True
        shop.store_model.save()
        assert store_ops.sweep_placed_orders() == {"accepted": 1}
        assert store_ops.auto_accept(order.pk) == "skipped"  # already accepted
        assert store_ops.acceptance_sla_alert(order.pk) == "skipped"
