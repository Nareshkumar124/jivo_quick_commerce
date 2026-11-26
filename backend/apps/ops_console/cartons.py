"""Free cartons in words, for the panel (display only; ADR 0002, ADR 0003).

A FREE_UNIT reward's `Coupon.value` is its number of free cartons (ADR 0003: a whole number
from 1 to 10), and the referral settings hold the quantities new rewards get.
"""


def free_cartons(quantity) -> str:
    """'1 free carton', '2 free cartons'. `quantity` may be an int or a Decimal coupon value."""
    count = int(quantity or 0)
    return f"{count} free carton{'' if count == 1 else 's'}"
