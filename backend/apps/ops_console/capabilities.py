"""Panel capabilities: the 05 §3 rows behind the Phase 4 order, refund and audit screens.

The backend's Phase 4 roles (`apps.accounts.roles`) grant:
- `orders.process_order`: packing console (Super Admin, Ops, Store Manager own, Store Staff own);
- `orders.cancel_order`: 08 T12 (Super Admin, Ops, Store Manager own, Support);
- `payments.issue_refund`: manual refund / retry (Super Admin, Finance; Support up to
  `SUPPORT_REFUND_LIMIT`, enforced by the service);
- `core.view_auditlog`: audit log (Super Admin, Finance).

Capabilities map onto them (`DEDICATED`):
- Live order board (Super Admin, Ops, Store Manager own, Support view) = order view + cancel:
  exactly the board roles (Store Staff processes but never sees the board; Finance neither).
- Store "Accepting orders" switch (05 §1.3 "Store Manager can toggle", §3 Stores: Super
  Admin): `stores.change_darkstore`, or store view + stock adjustment, which only Store Manager
  (and Super Admin) hold. No dedicated permission exists yet (reported).

Before the backend's roles are on this branch (`roles.ORDER_PROCESS` missing) the same rows are
selected from the Phase 3 grants (`INTERIM`), so the screens work either way. Checks are by
permission, never by group name. The role sets are pinned in `tests/helpers.py`.
"""

LIVE_BOARD = "live_board"
PACKING = "packing"
CANCEL_ORDER = "cancel_order"
RETRY_REFUND = "retry_refund"
TOGGLE_STORE = "toggle_store"
AUDIT_LOG = "audit_log"

Rule = tuple[tuple[str, ...], ...]  # any of (all of (...))

_TOGGLE: Rule = (
    ("stores.change_darkstore",),
    ("stores.view_darkstore", "inventory.adjust_stock"),
)

DEDICATED: dict[str, Rule] = {
    LIVE_BOARD: (("orders.view_order", "orders.cancel_order"),),
    PACKING: (("orders.process_order",),),
    CANCEL_ORDER: (("orders.cancel_order",),),
    RETRY_REFUND: (("payments.issue_refund",),),
    TOGGLE_STORE: _TOGGLE,
    AUDIT_LOG: (("core.view_auditlog",),),
}

INTERIM: dict[str, Rule] = {
    LIVE_BOARD: (
        ("orders.view_order", "stores.view_darkstore"),
        ("orders.view_order", "accounts.view_customer"),
    ),
    PACKING: (("orders.view_order", "catalog.view_product", "inventory.view_storeinventory"),),
    CANCEL_ORDER: (
        ("orders.view_order", "stores.view_darkstore"),
        ("orders.view_order", "accounts.view_customer"),
    ),
    RETRY_REFUND: (("payments.view_refund", "payments.view_paymentwebhookevent"),),
    TOGGLE_STORE: _TOGGLE,
    AUDIT_LOG: (("payments.view_paymentwebhookevent",),),
}


def dedicated_active() -> bool:
    """True once the backend's Phase 4 roles are on this branch."""
    from apps.accounts import roles

    return hasattr(roles, "ORDER_PROCESS")


def rules() -> dict[str, Rule]:
    return DEDICATED if dedicated_active() else INTERIM


def allowed(user, capability: str) -> bool:
    """True when the active staff `user` holds `capability` (05 §3)."""
    if not (user.is_authenticated and user.is_active and user.is_staff):
        return False
    return any(user.has_perms(perms) for perms in rules()[capability])


def capability_flags(user) -> dict[str, bool]:
    """Every capability for templates: `caps.packing`, `caps.cancel_order`, ..."""
    return {name: allowed(user, name) for name in DEDICATED}
