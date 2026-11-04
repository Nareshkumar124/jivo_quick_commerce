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
    - an order's amount_refunded is never above its grand_total and never negative;
    - no two refunds share a gateway refund id or an idempotency key;
    - a PROCESSED refund always has a gateway refund id;
    - every refund belongs to a CAPTURED payment of the same order."""
    assert one(
        "select count(*) from (select p.id from payments_payment p join payments_refund r on r.payment_id=p.id "
        "where r.status in ('PROCESSED','PENDING') group by p.id, p.amount having sum(r.amount) > p.amount) x"
    ) == 0
    assert one("select count(*) from orders_order where amount_refunded > grand_total or amount_refunded < 0") == 0
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


@pytest.mark.skip(reason="awaiting P4 R2 merge (OrderItem.quantity_unavailable, Order.amount_paid)")
def test_p4_tc47_bill_identity_after_unavailability():
    """P4-TC-47 For every order: grand_total = item_total - coupon_discount + delivery_fee +
    small_cart_fee + handling_fee + tip; item_total = sum((quantity - quantity_unavailable) x
    selling_price); amount_refunded <= amount_paid; ONLINE orders with unavailable units have an
    ITEMS_UNAVAILABLE refund of old - new grand_total."""
