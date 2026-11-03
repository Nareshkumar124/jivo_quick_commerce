"""Money helpers. Amounts are `Decimal`, rounded half-up to the paisa (08 §6.2); the API sends
them as 2-decimal strings (`money_str`). `rupees()` is only for display text in messages."""

from decimal import ROUND_HALF_UP, Decimal

CENT = Decimal("0.01")
ZERO = Decimal("0.00")


def round_money(value) -> Decimal:
    return Decimal(value).quantize(CENT, rounding=ROUND_HALF_UP)


def money_str(value) -> str:
    """API form: "249.00"."""
    return str(round_money(value))


def _indian_grouping(whole: int) -> str:
    digits = str(whole)
    if len(digits) <= 3:
        return digits
    head, tail = digits[:-3], digits[-3:]
    groups = []
    while len(head) > 2:
        groups.insert(0, head[-2:])
        head = head[:-2]
    if head:
        groups.insert(0, head)
    return ",".join([*groups, tail])


def rupees(value) -> str:
    """Display text with Indian digit grouping: ₹74, ₹2,000, ₹1,00,000, ₹716.50."""
    amount = round_money(value)
    sign = "-" if amount < 0 else ""
    amount = abs(amount)
    whole = int(amount)
    paise = int((amount - whole) * 100)
    text = _indian_grouping(whole)
    return f"{sign}₹{text}" if paise == 0 else f"{sign}₹{text}.{paise:02d}"
