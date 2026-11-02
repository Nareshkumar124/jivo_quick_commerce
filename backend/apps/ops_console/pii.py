"""PII display policy for the panel (05 §3 "Customers (PII)", 09 §3.3).

Super Admin, Ops / Dispatch and Support see customers in full: they hold
`accounts.view_customer`. Store Manager and Store Staff are "limited": a name and a masked phone
(on orders, from Phase 4). The check is by permission, never by group name, so a role edited in
`apps.accounts.roles` changes what it sees without template changes.
"""

FULL_PII_PERMISSIONS = ("accounts.view_customer",)

INDIA_PREFIX = "+91"
VISIBLE_DIGITS = 4


def can_view_full_phone(user) -> bool:
    if not (user.is_active and user.is_staff):
        return False
    return any(user.has_perm(perm) for perm in FULL_PII_PERMISSIONS)


def mask_phone(phone: str | None) -> str:
    """`+919811122233` -> `+91 XXXXXX2233`: the country code and the last four digits only."""
    if not phone:
        return ""
    prefix = INDIA_PREFIX if phone.startswith(INDIA_PREFIX) else ""
    rest = phone[len(prefix) :]
    if len(rest) <= VISIBLE_DIGITS:
        return f"{prefix} {'X' * len(rest)}".strip()
    hidden = "X" * (len(rest) - VISIBLE_DIGITS)
    return f"{prefix} {hidden}{rest[-VISIBLE_DIGITS:]}".strip()


def display_phone(user, phone: str | None) -> str:
    return (phone or "") if can_view_full_phone(user) else mask_phone(phone)
