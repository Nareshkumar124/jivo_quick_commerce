"""Panel capabilities: the 05 §3 rows behind the Phase 4 order, refund and audit screens.

The backend's Phase 4 roles (`apps.accounts.roles`) grant:
- `orders.process_order`: packing console (Super Admin, Ops, Store Manager own, Store Staff own);
- `orders.cancel_order`: 08 T12 (Super Admin, Ops, Store Manager own, Support);
- `payments.issue_refund`: manual refund (capability `issue_refund`) and retry (Super
  Admin, Finance; Support up to `SUPPORT_REFUND_LIMIT`, enforced by the service);
- `core.view_auditlog`: audit log (Super Admin, Finance).

Capabilities map onto them (`DEDICATED`):
- Live order board (Super Admin, Ops, Store Manager own, Support view) = order view + cancel:
  exactly the board roles (Store Staff processes but never sees the board; Finance neither).
- Store "Accepting orders" switch (05 §1.3 "Store Manager can toggle", §3 Stores: Super
  Admin): `stores.change_darkstore`, or store view + stock adjustment, which only Store Manager
  (and Super Admin) hold. No dedicated permission exists yet (reported).

Checks are by permission, never by group name. The role sets are pinned in `tests/helpers.py`.
"""

LIVE_BOARD = "live_board"
PACKING = "packing"
CANCEL_ORDER = "cancel_order"
RETRY_REFUND = "retry_refund"
ISSUE_REFUND = "issue_refund"
TOGGLE_STORE = "toggle_store"
AUDIT_LOG = "audit_log"
# Phase 5 (05 §3 "Manual dispatch": Super Admin, Ops, Store Manager own): dispatch board, task
# detail and the assign / unassign / retry buttons. DL-61 (user, 2026-11-05): every ops delivery
# action (force offline, unlock codes, retry / assign / unassign, ops-marked failed delivery,
# receive return, cash deposit, cash limit) is Super Admin, Ops and Store Manager (own store);
# Finance also records cash deposits; Support and Store Staff none.
DISPATCH = "dispatch"
# T14 receive return (DL-61): the dispatch roles, and the service's own orders.process_order.
RECEIVE_RETURN = "receive_return"
# SLICE 5.4 (DL-61 a; 05 §3 "Cash deposit entry", "Payouts"): `/ops/cash/` and `/ops/payouts/`.
# Both also need their 5.4 service module on the branch (`SERVICE_GATED`), so before the merge
# nobody sees them (not even a superuser).
CASH_DEPOSIT = "cash_deposit"
PAYOUTS = "payouts"

# Phase 7 (05 §3 "Reports": Super Admin, Ops, Store Manager own store, Finance; Catalog Mgr
# "catalog" = the product sales report only; §1.1 dashboard order cards use the same row). The
# backend's report permissions: `reports.view_reports` (Super Admin, Ops, Store Manager own,
# Finance) for the dashboard and REPORTS; "any report" (PRODUCT_REPORT: the index and the
# sidebar link) adds `view_catalog_reports` (Catalog Manager) and `view_finance_reports`
# (Finance). Each report re-checks its own permission and the store scope in the service.
REPORTS = "reports"
PRODUCT_REPORT = "product_report"
# 05 §3 "Support tickets" (Super Admin, Ops, Support; T-711 `support.handle_ticket`).
SUPPORT_TICKETS = "support_tickets"

Rule = tuple[tuple[str, ...], ...]  # any of (all of (...))

_REPORTS: Rule = (("reports.view_reports",),)
_PRODUCT_REPORT: Rule = (
    ("reports.view_reports",),
    ("reports.view_catalog_reports",),
    ("reports.view_finance_reports",),
)
_SUPPORT: Rule = (("support.handle_ticket", "support.view_supportticket"),)

_DISPATCH: Rule = (("delivery.dispatch_order", "delivery.view_deliverytask"),)

_RECEIVE_RETURN: Rule = (("orders.process_order", "delivery.dispatch_order"),)

# Cash: record (Super Admin, Ops, Store Manager own, Finance) or view the ledger (Finance "view").
_CASH: Rule = (("delivery.record_cash_deposit",), ("delivery.view_ridercashledger",))
_PAYOUTS: Rule = (("delivery.manage_payouts",),)

SERVICE_GATED: dict[str, tuple[str, str]] = {
    CASH_DEPOSIT: ("apps.delivery.services.cash", "staff_cash_riders"),
    PAYOUTS: ("apps.delivery.services.payouts", "create_payouts_for_period"),
}

_TOGGLE: Rule = (
    ("stores.change_darkstore",),
    ("stores.view_darkstore", "inventory.adjust_stock"),
)

DEDICATED: dict[str, Rule] = {
    LIVE_BOARD: (("orders.view_order", "orders.cancel_order"),),
    PACKING: (("orders.process_order",),),
    CANCEL_ORDER: (("orders.cancel_order",),),
    RETRY_REFUND: (("payments.issue_refund",),),
    ISSUE_REFUND: (("payments.issue_refund",),),
    TOGGLE_STORE: _TOGGLE,
    AUDIT_LOG: (("core.view_auditlog",),),
    DISPATCH: _DISPATCH,
    RECEIVE_RETURN: _RECEIVE_RETURN,
    CASH_DEPOSIT: _CASH,
    PAYOUTS: _PAYOUTS,
    REPORTS: _REPORTS,
    PRODUCT_REPORT: _PRODUCT_REPORT,
    SUPPORT_TICKETS: _SUPPORT,
}


def service_present(capability: str) -> bool:
    """SLICE 5.4: is the backend service behind a `SERVICE_GATED` capability on this branch?"""
    from apps.ops_console.order_actions import _lookup

    return callable(_lookup(*SERVICE_GATED[capability]))


def allowed(user, capability: str) -> bool:
    """True when the active staff `user` holds `capability` (05 §3)."""
    if not (user.is_authenticated and user.is_active and user.is_staff):
        return False
    if capability in SERVICE_GATED and not service_present(capability):
        return False
    return any(user.has_perms(perms) for perms in DEDICATED[capability])


def capability_flags(user) -> dict[str, bool]:
    """Every capability for templates: `caps.packing`, `caps.cancel_order`, ..."""
    return {name: allowed(user, name) for name in DEDICATED}
