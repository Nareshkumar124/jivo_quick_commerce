"""Slice 5.4 (T-514b): rider earnings (D-16 defaults), the cash ledger and deposits (05 §1.5),
payouts, with the role matrix (05 §3), IDOR and real-thread races.

Test case IDs are provisional backend IDs (P5-TC-50 to P5-TC-69) until QA's P5 repository
assigns its own."""

from datetime import date, timedelta
from decimal import Decimal

import pytest
from django.contrib.auth.models import Group
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import connection
from django.utils import timezone

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory
from apps.core.models import AuditLog
from apps.delivery.choices import CashEntryType, EarningType, PayoutStatus
from apps.delivery.models import (
    DeliveryTask,
    EarningRule,
    Payout,
    Rider,
    RiderCashLedger,
    RiderEarning,
)
from apps.delivery.services import cash, dispatch, earnings, payouts
from apps.delivery.tests.factories import active_rider
from apps.delivery.tests.test_task_flow import Flow
from apps.orders.models import Order
from apps.stores.services import grant_store_access
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

TODAY_API = "/api/v1/rider/me/"
EARNINGS = "/api/v1/rider/earnings/"
LEDGER = "/api/v1/rider/cash/ledger/"
PAYOUTS = "/api/v1/rider/payouts/"


@pytest.fixture(autouse=True)
def _roles():
    roles.sync_roles()


def staff(role, *stores):
    user = StaffUserFactory()
    user.groups.add(Group.objects.get(name=role))
    for store in stores:
        grant_store_access(user, store)
    return user


@pytest.fixture
def flow(place, make_rider, rider_client, store_steps):
    def make(method="COD", rider=None):
        order = place(method)
        store_steps.accept(order)
        rider = rider or make_rider()
        return Flow(order, rider, rider_client(rider), store_steps)

    return make


@pytest.fixture
def delivered(flow):
    """`delivered(method="COD", rider=None, tip=None) -> Flow` after T10 (cash for COD)."""

    def make(method="COD", rider=None, tip=None):
        f = flow(method, rider)
        if tip is not None:
            order = f.order
            Order.objects.filter(pk=order.pk).update(
                tip=Decimal(tip), grand_total=order.grand_total + Decimal(tip)
            )
            f.order.refresh_from_db()
        f.to_customer()
        response = f.deliver(cod="due" if method == "COD" else None)
        assert response.status_code == 200, response.json()
        f.rider.refresh_from_db()
        return f

    return make


# --------------------------------------------------------------------------- earnings


def test_delivery_records_earnings_d16(delivered, settings):
    """P5-TC-50: T10 records BASE (30.00), DISTANCE (5.00 x route km) and the TIP passed through;
    the delivered task shows them; `GET /rider/me/` today counts the order and the pay."""
    f = delivered(tip="20.00")
    task = DeliveryTask.objects.get(pk=f.task_id)
    lines = {line.type: line.amount for line in RiderEarning.objects.filter(task=task)}
    assert lines[EarningType.BASE] == Decimal("30.00")
    expected_distance = (Decimal("5.00") * task.distance_km).quantize(Decimal("0.01"))
    assert lines.get(EarningType.DISTANCE, Decimal("0.00")) == expected_distance
    assert lines[EarningType.TIP] == Decimal("20.00")
    body = f.client.get(f"/api/v1/rider/tasks/history/{task.pk}/").json()
    assert body["earnings"]["total"] == str(sum(lines.values()))
    today = f.client.get(TODAY_API).json()["today"]
    assert today["orders_delivered"] == 1
    assert today["earnings"] == str(sum(lines.values()))
    assert today["cash_in_hand"] == str(f.order.grand_total)
    # Recording again is a no-op (one line per type per task).
    assert earnings.record_trip_earnings(task, timezone.now()) == []
    assert earnings.record_tip(task, f.order, timezone.now()) == []


def test_earning_rule_in_force_drives_pay_and_estimate(db):
    """P5-TC-51: the newest EarningRule in force overrides the settings; free km come first."""
    assert earnings.estimate(Decimal("4.00")) == Decimal("50.00")  # 30 + 5 x 4
    EarningRule.objects.create(
        base_per_order=Decimal("25.00"),
        per_km_rate=Decimal("6.00"),
        per_km_after=Decimal("1.50"),
        effective_from=timezone.now() - timedelta(minutes=1),
    )
    EarningRule.objects.create(
        base_per_order=Decimal("99.00"),
        per_km_rate=Decimal("9.00"),
        effective_from=timezone.now() + timedelta(days=1),  # not yet
    )
    assert earnings.estimate(Decimal("4.00")) == Decimal("40.00")  # 25 + 6 x 2.5
    assert earnings.estimate(Decimal("1.00")) == Decimal("25.00")
    assert earnings.distance_pay(Decimal("2.333"), earnings.rule_at()) == Decimal("5.00")


def test_earnings_endpoint(delivered, rider_client, make_rider):
    """P5-TC-52: `GET /rider/earnings/` totals by type, orders with lines, adjustments; another
    rider sees nothing of it; range validation."""
    f = delivered()
    finance = staff(roles.FINANCE)
    earnings.add_adjustment(
        f.rider.pk, type=EarningType.INCENTIVE, amount="50", note="Rain bonus", by=finance
    )
    earnings.add_adjustment(
        f.rider.pk, type=EarningType.PENALTY, amount="10", note="Late return", by=finance
    )
    body = f.client.get(EARNINGS).json()
    assert body["orders_count"] == 1
    assert body["orders"][0]["order_number"] == f.order.order_number
    assert body["totals_by_type"]["INCENTIVE"] == "50.00"
    assert body["totals_by_type"]["PENALTY"] == "-10.00"
    assert {a["type"] for a in body["adjustments"]} == {"INCENTIVE", "PENALTY"}
    lines_total = sum(Decimal(line["amount"]) for line in body["orders"][0]["lines"])
    assert Decimal(body["total"]) == lines_total + Decimal("40.00")
    assert body["orders_truncated"] is False
    other = rider_client(make_rider((28.4510, 77.05)))
    assert other.get(EARNINGS).json()["total"] == "0.00"
    yesterday = (timezone.localdate() - timedelta(days=1)).isoformat()
    assert f.client.get(EARNINGS, {"from": yesterday, "to": yesterday}).json()["orders"] == []
    bad = f.client.get(EARNINGS, {"from": "2026-01-10", "to": "2026-01-01"})
    assert bad.status_code == 400
    assert f.client.get(EARNINGS, {"from": "2025-01-01", "to": "2026-01-10"}).status_code == 400


def test_records_need_a_rider_profile(auth_client, api_client):
    """Unauthenticated -> 401; a customer without a rider profile -> 403 NONE."""
    for url in (EARNINGS, LEDGER, PAYOUTS, "/api/v1/rider/tasks/history/"):
        assert api_client.get(url).status_code == 401
        response = auth_client.get(url, headers={"X-App-Name": "rider"})
        assert response.status_code == 403
        assert response.json()["error"]["details"]["rider_status"] == "NONE"


def test_adjustment_rules(make_rider):
    """P5-TC-53: incentives/penalties need `delivery.manage_payouts` (Super Admin, Finance);
    a reason and a positive amount; audited."""
    rider = make_rider(online=False)
    for role in (roles.OPS, roles.STORE_MANAGER, roles.SUPPORT):
        with pytest.raises(PermissionDenied):
            earnings.add_adjustment(
                rider.pk, type=EarningType.INCENTIVE, amount="5", note="x", by=staff(role)
            )
    finance = staff(roles.FINANCE)
    for kwargs in (
        {"type": EarningType.BASE, "amount": "5", "note": "x"},
        {"type": EarningType.INCENTIVE, "amount": "0", "note": "x"},
        {"type": EarningType.INCENTIVE, "amount": "abc", "note": "x"},
        {"type": EarningType.INCENTIVE, "amount": "5", "note": "  "},
    ):
        with pytest.raises(ValidationError):
            earnings.add_adjustment(rider.pk, by=finance, **kwargs)
    with pytest.raises(ValidationError):
        earnings.add_adjustment(999999, type="INCENTIVE", amount="5", note="x", by=finance)
    line = earnings.add_adjustment(
        rider.pk, type=EarningType.PENALTY, amount="12.5", note="Damaged bag", by=finance
    )
    assert line.amount == Decimal("-12.50")
    assert AuditLog.objects.filter(action="delivery.earning_adjustment").exists()
    assert earnings.staff_earnings(finance).filter(pk=line.pk).exists()
    assert not earnings.staff_earnings(staff(roles.OPS)).exists()


# --------------------------------------------------------------------------- cash ledger


def test_cash_ledger_endpoint_paging_and_scope(delivered, make_rider, rider_client):
    """P5-TC-55: the rider's own ledger, newest first, paged by `before_id`; another rider sees
    none of it (scoped queryset)."""
    rider = make_rider()
    first = delivered(rider=rider)
    second = delivered(rider=rider)
    page = second.client.get(LEDGER, {"page_size": 1}).json()
    assert page["count"] == 2
    assert page["results"][0]["order_number"] == second.order.order_number
    assert page["results"][0]["entry_type"] == "COD_COLLECTED"
    assert page["results"][0]["balance_after"] == str(
        first.order.grand_total + second.order.grand_total
    )
    assert "before_id=" in page["next"]
    older = second.client.get(page["next"]).json()
    assert older["results"][0]["order_number"] == first.order.order_number
    assert older["next"] is None
    other = rider_client(make_rider((28.4510, 77.05)))
    assert other.get(LEDGER).json()["count"] == 0
    assert second.client.get(LEDGER, {"before_id": 0}).status_code == 400


def test_deposit_by_store_manager(delivered, shop):
    """P5-TC-56: the Store Manager of the rider's store records the cash received: a DEPOSIT
    entry (-), cash in hand down, store set, audited; idempotent on the form key."""
    f = delivered()
    manager = staff(roles.STORE_MANAGER, shop.store_model)
    in_hand = f.rider.cash_in_hand
    entry = cash.record_deposit(
        f.rider.pk, "100.00", by=manager, note="Shift end", idempotency_key="form-1"
    )
    assert entry.entry_type == CashEntryType.DEPOSIT
    assert entry.amount == Decimal("-100.00")
    assert entry.store_id == shop.store_model.pk
    assert entry.balance_after == in_hand - Decimal("100.00")
    again = cash.record_deposit(f.rider.pk, "100.00", by=manager, idempotency_key="form-1")
    assert again.pk == entry.pk
    f.rider.refresh_from_db()
    assert f.rider.cash_in_hand == in_hand - Decimal("100.00")
    assert AuditLog.objects.filter(action="delivery.cash_deposit").count() == 1
    me = f.client.get(TODAY_API).json()["cash"]
    assert me["cash_in_hand"] == str(f.rider.cash_in_hand)


def test_deposit_guards(delivered, shop):
    """P5-TC-57: role matrix (DL-61 a, "Cash deposit entry": Super Admin, Ops, Store Manager
    own, Finance; not Store Staff or Support), store scope (another store's manager: not
    found), amount rules."""
    f = delivered()
    assert cash.record_deposit(f.rider.pk, "1.00", by=staff(roles.OPS)).amount == Decimal("-1.00")
    assert cash.record_deposit(f.rider.pk, "1.00", by=staff(roles.FINANCE)).store_id
    f.rider.refresh_from_db()
    for role in (roles.STORE_STAFF, roles.SUPPORT):
        with pytest.raises(PermissionDenied):
            cash.record_deposit(f.rider.pk, "1", by=staff(role, shop.store_model))
    elsewhere = staff(roles.STORE_MANAGER, DarkStoreFactory())
    with pytest.raises(ValidationError, match="Rider not found"):
        cash.record_deposit(f.rider.pk, "1", by=elsewhere)
    manager = staff(roles.STORE_MANAGER, shop.store_model)
    for amount in ("0", "-5", "abc", "NaN"):
        with pytest.raises(ValidationError):
            cash.record_deposit(f.rider.pk, amount, by=manager)
    with pytest.raises(ValidationError, match="only"):
        cash.record_deposit(f.rider.pk, f.rider.cash_in_hand + 1, by=manager)
    with pytest.raises(ValidationError, match="your stores"):
        cash.record_deposit(f.rider.pk, "1", by=manager, store_id=DarkStoreFactory().pk)
    admin = staff(roles.SUPER_ADMIN)
    entry = cash.record_deposit(f.rider.pk, f.rider.cash_in_hand, by=admin)
    assert entry.balance_after == Decimal("0.00")
    assert list(cash.staff_cash_riders(staff(roles.FINANCE))) == [f.rider]
    assert not cash.staff_cash_riders(elsewhere).exists()
    assert not cash.staff_cash_riders(staff(roles.SUPPORT)).exists()


def test_adjust_cash_super_admin_only(delivered):
    f = delivered()
    with pytest.raises(PermissionDenied):
        cash.adjust_cash(f.rider.pk, "-1", by=staff(roles.FINANCE), note="x")
    admin = staff(roles.SUPER_ADMIN)
    with pytest.raises(ValidationError):
        cash.adjust_cash(f.rider.pk, "0", by=admin, note="x")
    with pytest.raises(ValidationError):
        cash.adjust_cash(f.rider.pk, "-1", by=admin, note="")
    with pytest.raises(ValidationError, match="below zero"):
        cash.adjust_cash(f.rider.pk, -(f.rider.cash_in_hand + 1), by=admin, note="Recount")
    entry = cash.adjust_cash(f.rider.pk, "-10.00", by=admin, note="Recount")
    assert entry.entry_type == CashEntryType.ADJUSTMENT
    assert AuditLog.objects.filter(action="delivery.cash_adjustment").exists()


def test_store_day_report(delivered, shop):
    """P5-TC-58: 05 §1.5 day-end report: collected vs deposited per rider and in total."""
    f = delivered()
    manager = staff(roles.STORE_MANAGER, shop.store_model)
    cash.record_deposit(f.rider.pk, "50.00", by=manager)
    today = timezone.localdate()
    report = cash.store_day_report(manager, shop.store_model.pk, today)
    assert report["collected"] == str(f.order.grand_total)
    assert report["deposited"] == "50.00"
    assert report["difference"] == str(f.order.grand_total - Decimal("50.00"))
    assert report["riders"][0]["rider_id"] == f.rider.pk
    finance_view = cash.store_day_report(staff(roles.FINANCE), shop.store_model.pk, today)
    assert finance_view["collected"] == report["collected"]
    with pytest.raises(PermissionDenied):
        cash.store_day_report(staff(roles.SUPPORT), shop.store_model.pk, today)
    with pytest.raises(ValidationError):
        cash.store_day_report(manager, DarkStoreFactory().pk, today)


def test_cash_limit_reached_blocks_cod_offers(delivered, flow, make_rider, settings):
    """P5-TC-59: at the limit the rider is flagged (`limit_reached`) and gets no COD offer
    (08 §5), only prepaid ones."""
    rider = make_rider()
    f = delivered(rider=rider)
    Rider.objects.filter(pk=rider.pk).update(cash_limit=f.rider.cash_in_hand)
    me = f.client.get(TODAY_API).json()["cash"]
    assert me["limit_reached"] is True
    cod = flow(rider=rider)
    dispatch.dispatch_order(cod.order.pk)
    assert not cod.order.delivery_task.offers.filter(rider=rider).exists()


def test_ledger_is_append_only_and_never_negative(make_rider):
    rider = make_rider(online=False)
    with pytest.raises(ValueError, match="append-only"):
        RiderCashLedger.objects.all().update(note="x")
    with pytest.raises(ValidationError):
        cash.record_cash(rider, Decimal("-1.00"), CashEntryType.ADJUSTMENT)


# --------------------------------------------------------------------------- payouts


def test_payout_lifecycle(delivered, rider_client, make_rider):
    """P5-TC-60: Finance records a payout for the period (sum of unpaid lines), marks it paid
    with the UTR; the rider sees it; lines are not paid twice; void frees them."""
    f = delivered()
    finance = staff(roles.FINANCE)
    today = timezone.localdate()
    total = sum(line.amount for line in RiderEarning.objects.filter(rider=f.rider))
    payout = payouts.create_payout(f.rider.pk, today, today, by=finance)
    assert payout.amount == total
    assert payout.status == PayoutStatus.PENDING
    with pytest.raises(ValidationError, match="Nothing to pay"):
        payouts.create_payout(f.rider.pk, today, today, by=finance)
    body = f.client.get(PAYOUTS).json()
    assert body["count"] == 1
    assert body["results"][0]["amount"] == str(total)
    assert body["results"][0]["reference"] is None
    with pytest.raises(ValidationError):
        payouts.mark_paid(payout.pk, reference=" ", by=finance)
    paid = payouts.mark_paid(payout.pk, reference="UTR123", by=finance)
    assert paid.status == PayoutStatus.PAID
    assert payouts.mark_paid(payout.pk, reference="UTR123", by=finance).pk == payout.pk
    with pytest.raises(ValidationError):
        payouts.mark_paid(payout.pk, reference="OTHER", by=finance)
    with pytest.raises(ValidationError):
        payouts.void_payout(payout.pk, by=finance)
    assert f.client.get(PAYOUTS).json()["results"][0]["status"] == "PAID"
    other = rider_client(make_rider((28.4510, 77.05)))
    assert other.get(PAYOUTS).json()["count"] == 0


def test_payout_rules(delivered):
    f = delivered()
    today = timezone.localdate()
    for role in (roles.OPS, roles.STORE_MANAGER, roles.SUPPORT):
        with pytest.raises(PermissionDenied):
            payouts.create_payout(f.rider.pk, today, today, by=staff(role))
    finance = staff(roles.FINANCE)
    with pytest.raises(ValidationError):
        payouts.create_payout(f.rider.pk, today, today - timedelta(days=1), by=finance)
    with pytest.raises(ValidationError):
        payouts.create_payout(f.rider.pk, today, today + timedelta(days=1), by=finance)
    with pytest.raises(ValidationError):
        payouts.create_payout(999999, today, today, by=finance)
    with pytest.raises(ValidationError):
        payouts.mark_paid(999999, reference="x", by=finance)
    payout = payouts.create_payout(f.rider.pk, today, today, by=finance)
    payouts.void_payout(payout.pk, by=finance)
    assert not Payout.objects.filter(pk=payout.pk).exists()
    assert not RiderEarning.objects.filter(rider=f.rider, payout__isnull=False).exists()
    batch = payouts.create_payouts_for_period(today, today, by=finance)
    assert [p.rider_id for p in batch] == [f.rider.pk]
    assert payouts.create_payouts_for_period(date(2026, 1, 1), date(2026, 1, 7), by=finance) == []


def test_penalties_can_outweigh_pay(make_rider):
    rider = make_rider(online=False)
    finance = staff(roles.FINANCE)
    earnings.add_adjustment(rider.pk, type="PENALTY", amount="5", note="x", by=finance)
    today = timezone.localdate()
    with pytest.raises(ValidationError, match="Nothing to pay"):
        payouts.create_payout(rider.pk, today, today, by=finance)


# --------------------------------------------------------------------------- races


def _race(*jobs):
    from apps.orders.tests.test_concurrency import race

    return race(*jobs)


@pytest.mark.django_db(transaction=True)
def test_race_two_deposits_never_overdraw(shop):
    """P5-TC-61: two staff record deposits at once whose sum exceeds the cash in hand: the
    rider row lock serialises them; exactly one succeeds and the balance stays consistent."""
    roles.sync_roles()
    rider = active_rider(preferred_store=shop.store_model)
    cash.record_cash(rider, Decimal("100.00"), CashEntryType.ADJUSTMENT, note="seed")
    a = staff(roles.STORE_MANAGER, shop.store_model)
    b = staff(roles.SUPER_ADMIN)
    results = _race(
        lambda: cash.record_deposit(rider.pk, "70.00", by=a),
        lambda: cash.record_deposit(rider.pk, "60.00", by=b),
    )
    ok = [r for r in results if isinstance(r, RiderCashLedger)]
    errors = [r for r in results if isinstance(r, ValidationError)]
    assert len(ok) == 1, results
    assert len(errors) == 1, results
    rider.refresh_from_db()
    assert rider.cash_in_hand == Decimal("100.00") + ok[0].amount
    entries = list(RiderCashLedger.objects.filter(rider=rider).order_by("pk"))
    assert entries[-1].balance_after == rider.cash_in_hand
    connection.close()


@pytest.mark.django_db(transaction=True)
def test_race_same_deposit_key(shop):
    """A double-submitted deposit form (same key) records one deposit."""
    roles.sync_roles()
    rider = active_rider(preferred_store=shop.store_model)
    cash.record_cash(rider, Decimal("100.00"), CashEntryType.ADJUSTMENT, note="seed")
    manager = staff(roles.STORE_MANAGER, shop.store_model)
    results = _race(
        lambda: cash.record_deposit(rider.pk, "40.00", by=manager, idempotency_key="k1"),
        lambda: cash.record_deposit(rider.pk, "40.00", by=manager, idempotency_key="k1"),
    )
    assert all(isinstance(r, RiderCashLedger) for r in results), results
    assert results[0].pk == results[1].pk
    rider.refresh_from_db()
    assert rider.cash_in_hand == Decimal("60.00")


@pytest.mark.django_db(transaction=True)
def test_race_parallel_ledger_entries_keep_the_balance(shop):
    """Concurrent COD collections and a deposit: no lost update in `cash_in_hand`."""
    roles.sync_roles()
    rider = active_rider(preferred_store=shop.store_model)
    cash.record_cash(rider, Decimal("10.00"), CashEntryType.ADJUSTMENT, note="seed")
    manager = staff(roles.STORE_MANAGER, shop.store_model)

    def collect():
        from django.db import transaction

        with transaction.atomic():
            return cash.record_cash(
                Rider.objects.get(pk=rider.pk), Decimal("25.00"), CashEntryType.ADJUSTMENT
            )

    results = _race(
        collect, collect, collect, lambda: cash.record_deposit(rider.pk, "5", by=manager)
    )
    assert all(isinstance(r, RiderCashLedger) for r in results), results
    rider.refresh_from_db()
    assert rider.cash_in_hand == Decimal("80.00")
    running = Decimal("0.00")
    for entry in RiderCashLedger.objects.filter(rider=rider).order_by("pk"):
        running += entry.amount
        assert entry.balance_after == running  # each entry saw the one before it


@pytest.mark.django_db(transaction=True)
def test_race_two_payouts_never_pay_a_line_twice(shop):
    """P5-TC-62: two Finance users create the same payout at once: one payout, each line once."""
    roles.sync_roles()
    rider = active_rider(preferred_store=shop.store_model)
    finance = staff(roles.FINANCE)
    earnings.add_adjustment(rider.pk, type="INCENTIVE", amount="100", note="x", by=finance)
    today = timezone.localdate()
    results = _race(
        lambda: payouts.create_payout(rider.pk, today, today, by=finance),
        lambda: payouts.create_payout(rider.pk, today, today, by=staff(roles.SUPER_ADMIN)),
    )
    made = [r for r in results if isinstance(r, Payout)]
    assert len(made) == 1, results
    assert Payout.objects.filter(rider=rider).count() == 1
    assert RiderEarning.objects.get(rider=rider).payout_id == made[0].pk
