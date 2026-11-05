"""The **one** door from the panel to the backend services that change orders, refunds, store
switches and customers' COD setting (docs/admin-panel-architecture.md §5). Views and admin
actions call these functions and nothing else; this module calls the owning app's service by
name and never writes a model.

Services (Phase 4, final names; `tests/test_phase4_units.py` checks their signatures):

    orders.store_ops.accept_order(order_id, *, by) -> Order                                T6
    orders.store_ops.start_packing(order_id, *, by) -> Order                               T7
    orders.store_ops.mark_item_unavailable(order_id, item_id, *, unavailable, by) -> Order T8a
        one call per line; `unavailable` is the line's new total (0..quantity)
    orders.store_ops.mark_packed(order_id, *, by) -> Order                                 T8
    orders.store_ops.cancel_by_staff(order_id, *, by, reason, note="") -> Order            T12
        reason: one of orders.choices.StaffCancelReason
    payments.order_refunds.retry_refund(refund_id, *, by) -> Refund        T-401c
    stores.services.set_accepting_orders(store, accepting, *, actor) -> bool
    accounts.services.customers.set_cod_blocked(user_id, blocked, *, by) -> bool

The services check the role, scope the order to the caller's stores, lock, transition and
audit. The panel still scopes first (another store's order is a 404 before any call). A service
not on this branch makes `available(action)` False (button hidden or disabled) and a crafted
POST gets `ActionUnavailable` (a `NotImplementedError`), never a half-done change.

Refusals come back as `ActionRefused(message, code)`, `code` one of:
- `forbidden`: Django `PermissionDenied` (role) -> 403
- `not_found`: "Order not found." / the line or refund is not there -> 404
- `invalid`: Django / DRF validation errors (bad input) -> 400
- `state`: `ApiError` (`INVALID_STATE_TRANSITION` and other API errors) -> 409
"""

import importlib
from collections.abc import Callable
from typing import Any

from django.core.exceptions import PermissionDenied
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework.exceptions import APIException
from rest_framework.exceptions import NotFound as DrfNotFound

ACCEPT = "accept"
START_PACKING = "start_packing"
MARK_UNAVAILABLE = "mark_unavailable"
MARK_PACKED = "mark_packed"
CANCEL = "cancel"
RETRY_REFUND = "retry_refund"
SET_ACCEPTING = "set_accepting"
SET_COD_BLOCKED = "set_cod_blocked"

STORE_OPS = "apps.orders.store_ops"
SERVICES: dict[str, tuple[str, str]] = {
    ACCEPT: (STORE_OPS, "accept_order"),
    START_PACKING: (STORE_OPS, "start_packing"),
    MARK_UNAVAILABLE: (STORE_OPS, "mark_item_unavailable"),
    MARK_PACKED: (STORE_OPS, "mark_packed"),
    CANCEL: (STORE_OPS, "cancel_by_staff"),
    RETRY_REFUND: ("apps.payments.order_refunds", "retry_refund"),
    SET_ACCEPTING: ("apps.stores.services", "set_accepting_orders"),
    SET_COD_BLOCKED: ("apps.accounts.services.customers", "set_cod_blocked"),
}

# Staff cancellation reasons (T12 "reason required"): an enum the backend owns.
CANCEL_REASONS = ("apps.orders.choices", "StaffCancelReason")

MSG_UNAVAILABLE = "This action is not available yet."
# Service messages that mean "not in your scope" (store_ops, order_refunds).
NOT_FOUND_MESSAGES = frozenset(
    {
        "Order not found.",
        "This item is not part of the order.",
        "Refund not found.",
    }
)

FORBIDDEN = "forbidden"
NOT_FOUND = "not_found"
INVALID = "invalid"
STATE = "state"
HTTP_STATUS = {FORBIDDEN: 403, NOT_FOUND: 404, INVALID: 400, STATE: 409}


class ActionUnavailable(NotImplementedError):
    """The backend service for this action is not on this branch yet."""


class ActionRefused(Exception):
    """The service refused. `message` is for staff; `code` picks the HTTP status."""

    def __init__(self, message: str, code: str = STATE):
        super().__init__(message)
        self.message = message
        self.code = code

    @property
    def status(self) -> int:
        return HTTP_STATUS.get(self.code, 409)


def _lookup(module: str, name: str) -> Any:
    try:
        return getattr(importlib.import_module(module), name, None)
    except ModuleNotFoundError:
        return None


def _service(action: str) -> Callable:
    function = _lookup(*SERVICES[action])
    if function is None or not callable(function):
        module, name = SERVICES[action]
        raise ActionUnavailable(f"{module}.{name} does not exist yet.")
    return function


def cancel_reasons() -> list[tuple[str, str]] | None:
    enum = _lookup(*CANCEL_REASONS)
    return list(enum.choices) if enum is not None else None


def available(action: str) -> bool:
    if _lookup(*SERVICES[action]) is None:
        return False
    if action == CANCEL:
        return cancel_reasons() is not None
    return True


def availability() -> dict[str, bool]:
    """For templates: `actions.accept`, `actions.cancel`, ..."""
    return {action: available(action) for action in SERVICES}


def _detail_text(detail) -> str:
    if isinstance(detail, dict):
        parts = []
        for value in detail.values():
            parts.extend(value if isinstance(value, list) else [value])
        return " ".join(str(part) for part in parts)
    if isinstance(detail, list):
        return " ".join(str(part) for part in detail)
    return str(detail)


def refusal(error: Exception) -> ActionRefused:
    """A service exception as an `ActionRefused`."""
    if isinstance(error, PermissionDenied):
        return ActionRefused(str(error) or "You do not have permission to do this.", FORBIDDEN)
    if isinstance(error, DjangoValidationError):
        message = " ".join(error.messages)
        return ActionRefused(message, NOT_FOUND if message in NOT_FOUND_MESSAGES else INVALID)
    if isinstance(error, DrfNotFound):
        return ActionRefused(_detail_text(error.detail), NOT_FOUND)
    # ApiError (has .message) and other DRF errors.
    message = getattr(error, "message", None) or _detail_text(error.detail)
    code = INVALID if getattr(error, "status_code", 409) == 400 else STATE
    return ActionRefused(str(message), code)


def _call(action: str, *args, **kwargs):
    function = _service(action)
    try:
        return function(*args, **kwargs)
    except (APIException, DjangoValidationError, PermissionDenied) as error:
        raise refusal(error) from error


# --------------------------------------------------------------------------- orders


def accept(order, *, actor):
    return _call(ACCEPT, order.pk, by=actor)


def start_packing(order, *, actor):
    return _call(START_PACKING, order.pk, by=actor)


def mark_unavailable(order, item_id: int, unavailable: int, *, actor):
    return _call(MARK_UNAVAILABLE, order.pk, item_id, unavailable=unavailable, by=actor)


def mark_packed(order, *, actor):
    return _call(MARK_PACKED, order.pk, by=actor)


def cancel(order, *, actor, reason: str, note: str = ""):
    if cancel_reasons() is None:
        raise ActionUnavailable("orders.choices.StaffCancelReason does not exist yet.")
    return _call(CANCEL, order.pk, by=actor, reason=reason, note=note)


# --------------------------------------------------------------------------- refunds, stores


def retry_refund(refund, *, actor):
    return _call(RETRY_REFUND, refund.pk, by=actor)


def set_accepting(store, accepting: bool, *, actor) -> bool:
    return _call(SET_ACCEPTING, store, accepting, actor=actor)


def set_cod_blocked(user_id: int, blocked: bool, *, actor) -> bool:
    return _call(SET_COD_BLOCKED, user_id, blocked, by=actor)
