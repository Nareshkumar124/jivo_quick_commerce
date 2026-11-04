"""Money in the panel: display and input only, never arithmetic (docs/admin-panel-architecture.md
§5). Amounts come from records written by `cart.services.compute_bill()` and the payment
services and are shown exactly as stored: two decimals, Indian digit grouping, a rupee sign.
"""

from decimal import Decimal, InvalidOperation

from unfold.widgets import UnfoldAdminTextInputWidget


def _group_indian(whole: str) -> str:
    """ "1234567" -> "12,34,567"."""
    if len(whole) <= 3:
        return whole
    head, tail = whole[:-3], whole[-3:]
    groups = []
    while len(head) > 2:
        groups.insert(0, head[-2:])
        head = head[:-2]
    if head:
        groups.insert(0, head)
    return ",".join([*groups, tail])


def inr(value) -> str:
    """`Decimal("1299.5")` -> "₹1,299.50"; None -> "-". Formatting only: the stored value is
    shown with two decimals (it already has two; nothing is rounded or added up here)."""
    if value is None or value == "":
        return "-"
    try:
        amount = Decimal(value)
    except (InvalidOperation, TypeError, ValueError):
        return str(value)
    sign = "-" if amount < 0 else ""
    whole, _, fraction = f"{abs(amount):.2f}".partition(".")
    return f"{sign}₹{_group_indian(whole)}.{fraction}"


class RupeeInput(UnfoldAdminTextInputWidget):
    """An unfold text input with a "₹" prefix, as a number field (two decimals, not negative)."""

    input_type = "number"

    def __init__(self, attrs: dict | None = None) -> None:
        super().__init__({"prefix": "₹", "step": "0.01", "min": "0", **(attrs or {})})
