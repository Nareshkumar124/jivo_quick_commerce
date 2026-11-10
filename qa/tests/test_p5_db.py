"""Phase 5 read-only SQL invariants (08 §1, §3, §6.1; 07 slice 5.3 constraints).

Read-only session, aggregates and ids only (no personal data printed). Run after every P5 run.
Stage 1 scaffold (2026-11-05), not executed: gated by p5_support.requires_53.
"""

from __future__ import annotations

import pytest

from p5_support import P5_53, QA02_ID
from qa_support import db_query

pytestmark = [*P5_53, pytest.mark.db]

ACTIVE_TASK = "('ASSIGNED','AT_STORE','PICKED_UP','AT_CUSTOMER','RETURNING')"


def none(sql: str, params: tuple = ()) -> list[tuple]:
    rows = db_query(sql, params)
    assert rows == [], rows[:10]
    return rows


def test_p5_tc66_stock_invariants_qa02():
    """P5-TC-66 🔥 08 §6.1 at QA-02: no negative stock; reserved = Σ ACTIVE reservations;
    SALE units = units delivered; no SALE on a CANCELLED order."""
    none("select variant_id from inventory_storeinventory where store_id=%s and (on_hand<0 or reserved<0)", (QA02_ID,))
    none(
        """select i.variant_id, i.reserved, coalesce(sum(r.quantity),0)
             from inventory_storeinventory i
             left join inventory_stockreservation r
               on r.store_id=i.store_id and r.variant_id=i.variant_id and r.status='ACTIVE'
            where i.store_id=%s
            group by i.variant_id, i.reserved
           having i.reserved <> coalesce(sum(r.quantity),0)""",
        (QA02_ID,),
    )
    none(
        """select o.id from orders_order o
            where o.store_id=%s and o.status in ('OUT_FOR_DELIVERY','DELIVERED','DELIVERY_FAILED','RETURNED')
              and (select coalesce(-sum(m.delta),0) from inventory_stockmovement m
                    where m.order_id=o.id and m.type='SALE')
               <> (select coalesce(sum(it.quantity - it.quantity_unavailable),0) from orders_orderitem it
                    where it.order_id=o.id)""",
        (QA02_ID,),
    )
    none(
        """select o.id from orders_order o join inventory_stockmovement m on m.order_id=o.id
            where o.status='CANCELLED' and m.type='SALE'"""
    )


def test_p5_tc98_cash_ledger_invariants():
    """P5-TC-98 🔥 append-only chain: balance_after = previous balance + amount in id order;
    cash_in_hand = last balance; one COD_COLLECTED per order; never negative."""
    none(
        """select id from (
             select id, balance_after, amount,
                    lag(balance_after) over (partition by rider_id order by id) as prev
               from delivery_ridercashledger) x
            where balance_after <> coalesce(prev,0) + amount"""
    )
    none(
        """select r.id from delivery_rider r
             join lateral (select balance_after from delivery_ridercashledger l
                            where l.rider_id=r.id order by l.id desc limit 1) last on true
            where r.cash_in_hand <> last.balance_after"""
    )
    none(
        """select order_id from delivery_ridercashledger where entry_type='COD_COLLECTED'
            group by order_id having count(*) > 1"""
    )
    none("select id from delivery_ridercashledger where balance_after < 0")


def test_p5_tc128_task_order_consistency():
    """P5-TC-128 🔥 one active task per rider; ≤ 1 PENDING offer per task and per rider; order
    and task states agree; every task from ASSIGNED on has a rider."""
    none(f"select rider_id from delivery_deliverytask where status in {ACTIVE_TASK} group by rider_id having count(*)>1")
    none("select task_id from delivery_deliveryoffer where status='PENDING' group by task_id having count(*)>1")
    none("select rider_id from delivery_deliveryoffer where status='PENDING' group by rider_id having count(*)>1")
    pairs = {
        "DELIVERED": "('DELIVERED')",
        "OUT_FOR_DELIVERY": "('PICKED_UP','AT_CUSTOMER')",
        "DELIVERY_FAILED": "('RETURNING','FAILED')",
        "RETURNED": "('RETURNED')",
        "CANCELLED": "('CANCELLED')",
    }
    for order_status, task_states in pairs.items():
        none(
            f"""select o.id from orders_order o join delivery_deliverytask t on t.order_id=o.id
                 where o.status=%s and t.status not in {task_states}""",
            (order_status,),
        )
    none(
        """select t.id from delivery_deliverytask t join orders_order o on o.id=t.order_id
            where t.status in ('PICKED_UP','AT_CUSTOMER','DELIVERED') and o.status not in
                  ('OUT_FOR_DELIVERY','DELIVERED','DELIVERY_FAILED','RETURNED')"""
    )
    none(
        f"""select id from delivery_deliverytask
             where (status in {ACTIVE_TASK} or status in ('DELIVERED','RETURNED')) and rider_id is null"""
    )
