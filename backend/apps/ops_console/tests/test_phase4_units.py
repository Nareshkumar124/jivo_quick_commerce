"""Phase 4 building blocks: the 05 §3 capabilities per role, and the `order_actions` adapter
(service lookup by name, `NotImplementedError` while missing, error mapping)."""

import importlib
import inspect

import pytest
from django.core.exceptions import PermissionDenied as DjangoPermissionDenied
from django.core.exceptions import ValidationError as DjangoValidationError
from rest_framework.exceptions import ValidationError as DrfValidationError

from apps.accounts import roles
from apps.ops_console import capabilities, order_actions
from apps.ops_console.tests.helpers import (
    AUDIT_LOG_ROLES,
    CANCEL_ORDER_ROLES,
    CASH_ROLES,
    DISPATCH_ROLES,
    LIVE_BOARD_ROLES,
    PACKING_ROLES,
    PAYOUT_ROLES,
    PRINCIPALS,
    RECEIVE_RETURN_ROLES,
    RETRY_REFUND_ROLES,
    TOGGLE_STORE_ROLES,
    make_principal,
)
from apps.ops_console.tests.orders_support import (  # noqa: F401 - fixture
    fake_services,
    invalid_transition,
    make_order,
)
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

EXPECTED = {
    capabilities.LIVE_BOARD: LIVE_BOARD_ROLES,
    capabilities.PACKING: PACKING_ROLES,
    capabilities.CANCEL_ORDER: CANCEL_ORDER_ROLES,
    capabilities.RETRY_REFUND: RETRY_REFUND_ROLES,
    capabilities.ISSUE_REFUND: RETRY_REFUND_ROLES,  # same permission: payments.issue_refund
    capabilities.TOGGLE_STORE: TOGGLE_STORE_ROLES,
    capabilities.AUDIT_LOG: AUDIT_LOG_ROLES,
    capabilities.DISPATCH: DISPATCH_ROLES,
    capabilities.RECEIVE_RETURN: RECEIVE_RETURN_ROLES,
    capabilities.CASH_DEPOSIT: CASH_ROLES,
    capabilities.PAYOUTS: PAYOUT_ROLES,
    # P7 (05 §3 "Reports", "Support tickets"); also pinned in test_p7_reports / test_p7_support.
    capabilities.REPORTS: frozenset(
        {roles.SUPER_ADMIN, "superuser flag", roles.OPS, roles.STORE_MANAGER, roles.FINANCE}
    ),
    capabilities.PRODUCT_REPORT: frozenset(
        {
            roles.SUPER_ADMIN,
            "superuser flag",
            roles.OPS,
            roles.STORE_MANAGER,
            roles.FINANCE,
            roles.CATALOG_MANAGER,
        }
    ),
    capabilities.SUPPORT_TICKETS: frozenset(
        {roles.SUPER_ADMIN, "superuser flag", roles.OPS, roles.SUPPORT}
    ),
}


@pytest.mark.parametrize("principal", [p for p in PRINCIPALS if p != "anonymous"])
def test_capability_matrix(principal):
    """The permission combinations select exactly the 05 §3 roles."""
    user = make_principal(principal)
    for capability, allowed in EXPECTED.items():
        assert capabilities.allowed(user, capability) is (principal in allowed), (
            principal,
            capability,
        )


def test_inactive_staff_has_no_capability():
    user = make_principal("superuser flag")
    user.is_active = False
    assert not any(capabilities.capability_flags(user).values())


# --------------------------------------------------------------------------- adapter


def test_every_capability_has_a_rule():
    assert set(capabilities.DEDICATED) == set(EXPECTED)


def test_missing_order_services_are_unavailable(monkeypatch):
    """A service missing on the branch: button hidden, crafted call -> NotImplementedError."""
    monkeypatch.setitem(
        order_actions.SERVICES, order_actions.ACCEPT, ("apps.orders.store_ops", "no_such_service")
    )
    assert order_actions.available(order_actions.ACCEPT) is False
    order = make_order(DarkStoreFactory())
    with pytest.raises(NotImplementedError):
        order_actions.accept(order, actor=None)
    monkeypatch.setitem(
        order_actions.SERVICES, order_actions.ACCEPT, ("apps.no_such_module", "accept_order")
    )
    assert order_actions.available(order_actions.ACCEPT) is False


def test_existing_services_are_available():
    assert order_actions.available(order_actions.SET_ACCEPTING) is True


def test_fakes_make_them_available(fake_services):  # noqa: F811
    for action in ("accept", "start_packing", "mark_unavailable", "mark_packed", "cancel"):
        assert order_actions.available(action), action
    assert ("OTHER_STAFF", "Cancelled by the store") in order_actions.cancel_reasons()


def test_adapter_calls_with_the_real_signatures(fake_services):  # noqa: F811
    order = make_order(DarkStoreFactory())
    staff = object()
    order_actions.accept(order, actor=staff)
    order_actions.mark_unavailable(order, 12, 1, actor=staff)
    order_actions.cancel(order, actor=staff, reason="OTHER_STAFF", note="x")
    assert fake_services.calls == [
        ("accept_order", order.pk, (), {"by": staff}),
        ("mark_item_unavailable", order.pk, (12,), {"unavailable": 1, "by": staff}),
        ("cancel_by_staff", order.pk, (), {"by": staff, "reason": "OTHER_STAFF", "note": "x"}),
    ]


@pytest.mark.parametrize(
    ("error", "message", "status"),
    [
        (invalid_transition(), "This order is already packed.", 409),
        (DjangoPermissionDenied("You do not have permission to do this."), None, 403),
        (DjangoValidationError("Order not found."), "Order not found.", 404),
        (DjangoValidationError("This item is not part of the order."), None, 404),
        (DjangoValidationError("Enter a number of units from 0 to 2."), None, 400),
        (DrfValidationError({"quantity": ["Too many units."]}), "Too many units.", 400),
    ],
)
def test_service_errors_become_refusals(fake_services, error, message, status):  # noqa: F811
    fake_services.refuse_with = error
    order = make_order(DarkStoreFactory())
    with pytest.raises(order_actions.ActionRefused) as refused:
        order_actions.mark_packed(order, actor=None)
    assert refused.value.status == status
    if message:
        assert refused.value.message == message


def test_unexpected_errors_are_not_swallowed(fake_services):  # noqa: F811
    fake_services.refuse_with = RuntimeError("bug")
    order = make_order(DarkStoreFactory())
    with pytest.raises(RuntimeError):
        order_actions.start_packing(order, actor=None)


def test_service_refusal_status_reaches_the_view(client, fake_services):  # noqa: F811
    from django.urls import reverse

    from apps.accounts import roles
    from apps.ops_console.tests.helpers import login_with_stores

    store = DarkStoreFactory(code="GGN-07")
    order = make_order(store)
    login_with_stores(client, roles.STORE_STAFF, store)
    url = reverse("ops:packing-step", args=[store.code, order.pk, "accept"])
    fake_services.refuse_with = DjangoPermissionDenied("You do not have permission to do this.")
    response = client.post(url, HTTP_HX_REQUEST="true")
    assert response.status_code == 403
    assert "permission" in response["X-Ops-Message"]
    fake_services.refuse_with = DjangoValidationError("Order not found.")
    assert client.post(url, HTTP_HX_REQUEST="true").status_code == 404


# --------------------------------------------------------------------------- contract

# What the adapter calls: (module, name) -> (positional parameter names, keyword-only names).
CONTRACT = {
    ("apps.orders.store_ops", "accept_order"): (["order_id"], {"by"}),
    ("apps.orders.store_ops", "start_packing"): (["order_id"], {"by"}),
    ("apps.orders.store_ops", "mark_packed"): (["order_id"], {"by"}),
    ("apps.orders.store_ops", "mark_item_unavailable"): (
        ["order_id", "item_id"],
        {"unavailable", "by"},
    ),
    ("apps.orders.store_ops", "cancel_by_staff"): (["order_id"], {"by", "reason", "note"}),
    ("apps.payments.order_refunds", "retry_refund"): (["refund_id"], {"by"}),
    ("apps.stores.services", "set_accepting_orders"): (["store", "accepting"], {"actor"}),
    ("apps.accounts.services.customers", "set_cod_blocked"): (["user_id", "blocked"], {"by"}),
}


@pytest.mark.parametrize(("module", "name"), sorted(CONTRACT))
def test_backend_service_signatures_match_the_adapter(module, name):
    """The real services (backend Phase 4) take exactly what `order_actions` passes. Skipped
    while a service is not on this branch yet; must pass after the backend merge."""
    try:
        function = getattr(importlib.import_module(module), name)
    except (ModuleNotFoundError, AttributeError):
        pytest.skip(f"{module}.{name} is not on this branch yet")
    assert order_actions.SERVICES[_action_for(module, name)] == (module, name)
    positional, keywords = CONTRACT[(module, name)]
    params = inspect.signature(function).parameters.values()
    found_positional = [
        p.name for p in params if p.kind in (p.POSITIONAL_ONLY, p.POSITIONAL_OR_KEYWORD)
    ]
    found_keywords = {p.name for p in params if p.kind == p.KEYWORD_ONLY}
    assert found_positional == positional
    assert keywords <= found_keywords
    required = {p.name for p in params if p.kind == p.KEYWORD_ONLY and p.default is p.empty}
    assert required <= keywords


def _action_for(module: str, name: str) -> str:
    return next(
        action for action, target in order_actions.SERVICES.items() if target == (module, name)
    )


def test_staff_cancel_reasons_are_the_backend_enum():
    try:
        from apps.orders.choices import StaffCancelReason
    except ImportError:
        pytest.skip("StaffCancelReason is not on this branch yet")
    assert order_actions.cancel_reasons() == list(StaffCancelReason.choices)


# --------------------------------------------------------------------------- one-time tokens


def test_one_time_token_is_consumed_once():
    from apps.accounts.tests.factories import StaffUserFactory
    from apps.ops_console import once

    user = StaffUserFactory()
    token = once.new_token(once.MANUAL_REFUND)
    assert once.consume(user, once.MANUAL_REFUND, token) is True
    assert once.consume(user, once.MANUAL_REFUND, token) is False
    other = once.new_token(once.MANUAL_REFUND)
    assert once.consume(user, once.REFUND_RETRY, other) is False  # wrong purpose
    assert once.consume(user, once.MANUAL_REFUND, "not-signed") is False
    assert once.consume(user, once.MANUAL_REFUND, None) is False
