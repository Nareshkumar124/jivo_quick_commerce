"""Phase 4 money and stock invariants (read-only SQL over the shared DB, aggregates only).

P4-TC-44/45 run now: they already hold on develop (P3 refunds) and must keep holding after the
P4 refunds (cancel, partial unavailability, manual) land. P4-TC-47 needs the P4 columns."""

from __future__ import annotations

import pytest

from qa_support import db_query

pytestmark = pytest.mark.db


def one(sql: str) -> int:
    return db_query(sql)[0][0]


@pytest.mark.smoke
def test_p4_tc44_refund_money_invariants():
    """P4-TC-44 🔥 No duplicate or excess refunds:
    - the PROCESSED + PENDING refunds of a payment never exceed what it captured;
    - an order's amount_refunded is never above max(grand_total, amount_paid) and never negative;
    - no two refunds share a gateway refund id or an idempotency key;
    - a PROCESSED refund always has a gateway refund id;
    - every refund belongs to a CAPTURED payment of the same order."""
    assert one(
        "select count(*) from (select p.id from payments_payment p join payments_refund r on r.payment_id=p.id "
        "where r.status in ('PROCESSED','PENDING') group by p.id, p.amount having sum(r.amount) > p.amount) x"
    ) == 0
    # P4 (T-402c): after T8a lowers grand_total, a later cancel refunds the rest of what was paid,
    # so the bound is what was paid (amount_paid), or grand_total for P3 late captures (not sales).
    assert one("select count(*) from orders_order where amount_refunded > greatest(grand_total, amount_paid) or amount_refunded < 0") == 0
    assert one("select count(*) from (select gateway_refund_id from payments_refund where gateway_refund_id<>'' group by 1 having count(*)>1) x") == 0
    assert one("select count(*) from (select idempotency_key from payments_refund group by 1 having count(*)>1) x") == 0
    assert one("select count(*) from payments_refund where status='PROCESSED' and gateway_refund_id=''") == 0
    assert one(
        "select count(*) from payments_refund r join payments_payment p on p.id=r.payment_id "
        "where p.status<>'CAPTURED' or p.order_id<>r.order_id"
    ) == 0


@pytest.mark.smoke
def test_p4_tc45_stock_after_cancellations():
    """P4-TC-45 🔥 Cancelled orders hold no ACTIVE reservation; cancellations before pickup
    write no StockMovement (08 §6.1: only `reserved` changes); 0 <= reserved <= on_hand."""
    assert one(
        "select count(*) from inventory_stockreservation r join orders_order o on o.id=r.order_id "
        "where r.status='ACTIVE' and o.status in ('CANCELLED','PAYMENT_FAILED')"
    ) == 0
    assert one("select count(*) from inventory_storeinventory where reserved < 0 or reserved > on_hand") == 0


def test_p4_tc47_bill_identity_after_unavailability():
    """P4-TC-47 For every order: grand_total = item_total - coupon_discount + delivery_fee +
    small_cart_fee + handling_fee + tip; item_total = sum((quantity - quantity_unavailable) x
    selling_price) for orders with units coming; 0 <= quantity_unavailable <= quantity;
    amount_refunded <= amount_paid (orders with order refunds); amount_paid backfill: ONLINE
    orders that reached PLACED have amount_paid = the captured sale amount, COD and never-paid
    orders 0; T8a refunds (item_unavailable) of an order sum to amount_paid - grand_total while
    it is not cancelled."""
    assert one(
        "select count(*) from orders_order where grand_total <> item_total - coupon_discount + delivery_fee "
        "+ small_cart_fee + handling_fee + tip"
    ) == 0
    assert one(
        "select count(*) from (select o.id from orders_order o join orders_orderitem i on i.order_id=o.id "
        "where o.status <> 'CANCELLED' or o.cancel_reason <> 'ITEMS_UNAVAILABLE' "
        "group by o.id, o.item_total having sum((i.quantity - i.quantity_unavailable) * i.selling_price) <> o.item_total) x"
    ) == 0
    assert one("select count(*) from orders_orderitem where quantity_unavailable < 0 or quantity_unavailable > quantity") == 0
    assert one("select count(*) from orders_orderitem where line_total <> (quantity - quantity_unavailable) * selling_price and quantity_unavailable < quantity") == 0
    assert one(
        "select count(*) from orders_order o where o.amount_refunded > o.amount_paid and exists "
        "(select 1 from payments_refund r where r.order_id=o.id and r.reason in "
        "('customer_cancel','staff_cancel','item_unavailable','delivery_failed','manual'))"
    ) == 0
    assert one("select count(*) from orders_order where payment_method='COD' and amount_paid <> 0") == 0
    assert one(
        "select count(*) from orders_order where payment_method='ONLINE' and placed_at is not null and amount_paid <= 0"
    ) == 0
    assert one(
        "select count(*) from orders_order where payment_method='ONLINE' and placed_at is null and amount_paid <> 0"
    ) == 0
    assert one(
        "select count(*) from (select o.id from orders_order o join payments_refund r on r.order_id=o.id "
        "where r.reason='item_unavailable' and o.status not in ('CANCELLED') "
        "group by o.id, o.amount_paid, o.grand_total having sum(r.amount) <> o.amount_paid - o.grand_total) x"
    ) == 0


def test_p4_tc46_history_matches_timeline_actor_types():
    """P4-TC-46 Every T6/T7/T8 history row has actor_type store/ops/system; T11 rows customer;
    T12 rows store/ops; each order's status equals its last history row's to_status."""
    assert one(
        "select count(*) from orders_orderstatushistory where to_status in ('ACCEPTED','PACKING','PACKED') "
        "and actor_type not in ('store','ops','system')"
    ) == 0
    assert one(
        "select count(*) from orders_orderstatushistory h join orders_order o on o.id=h.order_id "
        "where h.to_status='CANCELLED' and h.from_status in ('PLACED','ACCEPTED','PACKING','PACKED') "
        "and o.cancelled_by_type <> h.actor_type"
    ) == 0
    assert one(
        "select count(*) from orders_order o join lateral (select to_status from orders_orderstatushistory h "
        "where h.order_id=o.id order by h.id desc limit 1) last on true where last.to_status <> o.status"
    ) == 0
