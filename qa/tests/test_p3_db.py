"""Phase 3 read-only database invariants (08 §6, 07): money and stock never corrupt, no
duplicate financial transaction. Aggregates only; never prints rows with personal data."""

from __future__ import annotations

import pytest

from qa_support import db_query

pytestmark = pytest.mark.db


@pytest.mark.smoke
def test_p3_tc48_order_money_consistent():
    """P3-TC-48 🔥 Every order: grand_total = item_total - coupon + fees + tip;
    product_discount = mrp_total - item_total; item_total = sum of its line totals; coupon <=
    item_total; all amounts >= 0."""
    bad = db_query(
        """
        select count(*) filter (where grand_total <> item_total - coupon_discount + delivery_fee + small_cart_fee + handling_fee + tip),
               count(*) filter (where product_discount <> mrp_total - item_total),
               count(*) filter (where coupon_discount > item_total),
               count(*) filter (where least(grand_total, item_total, coupon_discount, delivery_fee, small_cart_fee, handling_fee, tip) < 0),
               count(*) filter (where item_total <> (select coalesce(sum(line_total), 0) from orders_orderitem i where i.order_id = o.id))
        from orders_order o
        """
    )[0]
    assert bad == (0, 0, 0, 0, 0), bad


@pytest.mark.smoke
def test_p3_tc49_stock_consistent():
    """P3-TC-49 🔥 0 <= reserved <= on_hand and reserved >= the sum of ACTIVE reservations for
    every stock row; no ACTIVE reservation on a terminal (failed/cancelled) order."""
    rows = db_query(
        """
        select count(*) filter (where i.reserved < 0 or i.on_hand < 0 or i.reserved > i.on_hand),
               count(*) filter (where i.reserved < coalesce(r.active, 0))
        from inventory_storeinventory i
        left join (select store_id, variant_id, sum(quantity) active from inventory_stockreservation
                   where status = 'ACTIVE' group by 1, 2) r
          on r.store_id = i.store_id and r.variant_id = i.variant_id
        """
    )[0]
    assert rows == (0, 0), rows
    orphan = db_query(
        "select count(*) from inventory_stockreservation r join orders_order o on o.id = r.order_id "
        "where r.status = 'ACTIVE' and o.status in ('CANCELLED', 'PAYMENT_FAILED')"
    )[0][0]
    assert orphan == 0


@pytest.mark.smoke
def test_p3_tc50_no_duplicate_financial_transactions():
    """P3-TC-50 🔥 No gateway payment id recorded twice; no order with two un-refunded
    captures; no capture refunded twice; webhook event ids unique; a PAID order has a capture;
    a PAYMENT_FAILED/CANCELLED order is never PAID."""
    dup_pay = db_query(
        "select count(*) from (select gateway_payment_id from payments_payment where gateway_payment_id is not null "
        "and gateway_payment_id <> '' group by 1 having count(*) > 1) d"
    )[0][0]
    two_captures = db_query(
        "select count(*) from (select p.order_id from payments_payment p left join payments_refund r on r.payment_id = p.id "
        "where p.status = 'CAPTURED' and r.id is null group by 1 having count(*) > 1) d"
    )[0][0]
    double_refund = db_query(
        "select count(*) from (select payment_id from payments_refund group by 1 having count(*) > 1) d"
    )[0][0]
    dup_evt = db_query(
        "select count(*) from (select event_id from payments_paymentwebhookevent group by 1 having count(*) > 1) d"
    )[0][0]
    paid_no_capture = db_query(
        "select count(*) from orders_order o where payment_status = 'PAID' and not exists "
        "(select 1 from payments_payment p where p.order_id = o.id and p.status = 'CAPTURED')"
    )[0][0]
    dead_paid = db_query(
        "select count(*) from orders_order where status in ('CANCELLED', 'PAYMENT_FAILED') and payment_status = 'PAID'"
    )[0][0]
    assert (dup_pay, two_captures, double_refund, dup_evt, paid_no_capture, dead_paid) == (0, 0, 0, 0, 0, 0)


def test_p3_tc51_history_and_coupon_counts():
    """P3-TC-51 Every order has a creation history row and its last history row matches its
    status; a coupon never has more counted (HELD+APPLIED) redemptions than usage_limit_total,
    nor per user than usage_limit_per_user."""
    mismatched = db_query(
        """
        select count(*) from orders_order o
        where o.status <> (select h.to_status from orders_orderstatushistory h where h.order_id = o.id order by h.id desc limit 1)
           or not exists (select 1 from orders_orderstatushistory h where h.order_id = o.id and h.from_status = '')
        """
    )[0][0]
    assert mismatched == 0
    over_total = db_query(
        "select count(*) from promotions_coupon c where c.usage_limit_total is not null and "
        "(select count(*) from promotions_couponredemption r where r.coupon_id = c.id and r.status in ('HELD','APPLIED')) > c.usage_limit_total"
    )[0][0]
    over_user = db_query(
        "select count(*) from (select r.coupon_id, r.user_id, count(*) n from promotions_couponredemption r "
        "where r.status in ('HELD','APPLIED') group by 1, 2) x join promotions_coupon c on c.id = x.coupon_id "
        "where c.usage_limit_per_user is not null and x.n > c.usage_limit_per_user"
    )[0][0]
    assert (over_total, over_user) == (0, 0)
