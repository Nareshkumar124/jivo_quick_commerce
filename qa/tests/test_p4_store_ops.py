"""Phase 4 store operations (QA T-416): packing console (05 §1.3), live board (05 §1.2), Orders
admin, refunds, audit log and the 05 §3 role matrix; 08 T6, T7, T8, T8a, T12; §6.3; §6.4.

All of these need the backend P4 R2 (`apps.orders.store_ops`, `apps.payments.order_refunds`) and
admin's P4 screens merged into develop. The Ops Console URLs and form fields are not published
yet (server-rendered, not in the OpenAPI schema), so every case is a stub with its steps and
oracle in the docstring; they are bound to the console when the admin R2 merges.

Staff log in with the seeded role accounts (`p3_admin.staff_login`, password from the
environment, never printed); store scoping uses the demo store GGN-01 and, for the cross-store
cases, a second store the Store Manager/Staff accounts are not assigned to."""

from __future__ import annotations

import pytest

R2 = pytest.mark.skip(reason="awaiting P4 R2 merge (backend store_ops + admin packing console)")


@R2
@pytest.mark.smoke
def test_p4_tc19_accept_t6():
    """P4-TC-19 🔥 Store Staff (GGN-01) accepts a PLACED COD order on the packing console:
    ACCEPTED; history row (actor = that staff user, actor_type store); audit log row; the
    customer's timeline adds "Order confirmed"; accepting again is refused (INVALID_STATE_TRANSITION
    message, no second history row)."""


@R2
@pytest.mark.smoke
def test_p4_tc20_start_packing_and_pack_t7_t8():
    """P4-TC-20 🔥 Start packing (T7) then Mark packed (T8): PACKING then PACKED; a 4-character
    pickup code is set and shown on the slip; can_cancel false from PACKING on; the pick list
    shows every line with its quantity."""


@R2
def test_p4_tc21_transition_guards():
    """P4-TC-21 Out-of-order actions are refused without a state change: pack from PLACED or
    ACCEPTED, start packing from PLACED, accept a PACKING order, any action on CANCELLED or
    PAYMENT_PENDING. History unchanged."""


@R2
@pytest.mark.smoke
def test_p4_tc22_item_unavailable_online():
    """P4-TC-22 🔥 T8a on a paid ONLINE order in PACKING: mark 1 of 2 units of a line unavailable.
    Oracle (08 §6.3, independent of the server): item_total recomputed; coupon discount kept,
    capped at the new item_total; fees recomputed but never above the old ones; refund = old
    grand_total - new grand_total (reason ITEMS_UNAVAILABLE, one Refund row); reserved -1;
    line.quantity_unavailable 1, line_total and item_count count only the units coming; the
    customer's `bill` is the reduced bill."""


@R2
def test_p4_tc23_item_unavailable_cod():
    """P4-TC-23 T8a on a COD order: the bill (amount due) is reduced, no Refund row,
    payment_status still COD_PENDING; reserved -1."""


@R2
def test_p4_tc24_all_units_unavailable_cancels():
    """P4-TC-24 T8a with every unit unavailable: the order is CANCELLED (cancellation reason
    ITEMS_UNAVAILABLE, cancelled_by store); ONLINE gets a full refund (refunds sum to the
    grand_total paid, never more); the whole reservation is released."""


@R2
def test_p4_tc25_fees_never_increase():
    """P4-TC-25 T8a that drops item_total below the free-delivery threshold (and below the
    small-cart threshold): delivery_fee and small_cart_fee are not raised; new grand_total <=
    old; refund >= 0. Checked against the oracle with the store's PricingConfig."""


@R2
def test_p4_tc26_coupon_kept_after_unavailability():
    """P4-TC-26 T8a on an order with a FLAT coupon whose min order is no longer met: the original
    discount is kept (capped at the new item_total); the coupon redemption stays REDEEMED."""


@R2
def test_p4_tc27_unavailability_guards_and_idempotency():
    """P4-TC-27 Item unavailable on a PACKED order, unavailable > quantity, negative, 0, an item
    of another order: refused, nothing changed. Submitting the same adjustment twice (double
    click) refunds once."""


@R2
def test_p4_tc28_staff_cancel_t12():
    """P4-TC-28 Store Manager cancels (reason required) in PLACED, ACCEPTED, PACKING and PACKED:
    CANCELLED; cancelled_by store; full refund for paid orders; reservation released with no
    StockMovement and no on_hand change; audit log row. Ops / Support cancel the same way
    (cancelled_by ops)."""


@R2
def test_p4_tc29_staff_cancel_requires_reason():
    """P4-TC-29 Staff cancel without a reason or with a customer-only reason: refused."""


@R2
@pytest.mark.smoke
def test_p4_tc30_store_scoping():
    """P4-TC-30 🔥 Store Staff / Store Manager of GGN-01 open another store's console URL and
    post accept / cancel / unavailable for another store's order id: 404 (or 403), nothing
    changes; the other store's orders never appear on their live board or queue."""


@R2
@pytest.mark.smoke
def test_p4_tc31_role_matrix():
    """P4-TC-31 🔥 05 §3 P4 rows, 7 roles: live board (Super, Ops all, Store Manager own, Support
    view; Store Staff, Catalog, Finance no), packing console (Super, Ops, SM own, SS own),
    cancel (Super, Ops, SM own before pickup, Support before pickup), refund (Super, Support up
    to SUPPORT_REFUND_LIMIT, Finance), audit log (Super; Finance view). Pages and POST actions,
    enforced server-side (a hidden button is not enough)."""


@R2
def test_p4_tc32_support_refund_limit():
    """P4-TC-32 Support refunds 500.00 (allowed) and 500.01 (refused); Finance has no limit; a
    refund above the refundable amount is refused (cap); two concurrent manual refunds never
    exceed the refundable amount."""


@R2
def test_p4_tc33_manual_refund():
    """P4-TC-33 Manual partial then full refund (GOODWILL) on a delivered-or-paid order:
    PARTIALLY_REFUNDED then REFUNDED; amount_refunded = sum of processed refunds; a double
    submit makes one refund."""


@R2
def test_p4_tc34_retry_failed_refund():
    """P4-TC-34 A FAILED refund (refund.failed webhook, receipt-matched) is retried from the ops
    screen: a new refund `<key>:retry-1`; only FAILED refunds can be retried; the customer sees
    the refund as PENDING throughout (never FAILED)."""


@R2
def test_p4_tc35_sync_refund_status():
    """P4-TC-35 A refund PENDING with no gateway answer for longer than REFUND_STUCK_MINUTES is
    sent again by `sync_refund_status`; the gateway lookup prevents a second refund."""


@R2
def test_p4_tc36_auto_accept():
    """P4-TC-36 A store with auto-accept: a new PLACED order is ACCEPTED by the system after
    AUTO_ACCEPT_DELAY_SECONDS (history actor_type system). Needs a QA-owned store setting."""


@R2
def test_p4_tc37_acceptance_sla_alert():
    """P4-TC-37 An order not accepted within STORE_ACCEPTANCE_SLA_SECONDS raises the ops alert
    once (not again on the next sweep), and none for an order accepted in time."""


@R2
def test_p4_tc38_live_board():
    """P4-TC-38 /ops/orders/live/: columns Placed, Accepted, Packing, Packed, Out for delivery and
    the exceptions lane; card fields; filters store / payment / SLA breach; the 10 s HTMX poll
    returns the partial; no full customer phone on cards."""


@R2
def test_p4_tc39_packing_console_page():
    """P4-TC-39 /ops/store/<store>/: new-orders queue with the SLA countdown, pick list, slip
    with order number, 4-character code, QR and item count; the accepting-orders switch for the
    Store Manager only."""


@R2
def test_p4_tc40_orders_admin():
    """P4-TC-40 Orders admin: filters (store, status, payment, date, coupon); detail with
    timeline, payments, refunds, task; cancel and refund actions only with permission; CSV
    export with formula-injection escaping."""


@R2
@pytest.mark.smoke
def test_p4_tc41_audit_log():
    """P4-TC-41 🔥 Every staff action (accept, start packing, pack, unavailable, cancel, refund)
    writes one audit row with actor, action, object and changes, without customer PII; the audit
    log is read-only; only Super Admin and Finance can open it."""


@R2
def test_p4_tc42_console_csrf_and_safe_methods():
    """P4-TC-42 Console POST actions without a CSRF token: 403, nothing changes; GET pages never
    change state (no action on GET)."""
