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


# --------------------------------------------------------------------------- people on records
# Order screens never render `str(user)`: for a customer it is the phone.


def customer_label(customer, *, full: bool) -> str:
    """ "Asha Verma, +919811122233" (full) or "Asha Verma, +91 XXXXXX2233" (limited). Without a
    name: "Customer 42"."""
    if customer is None:
        return "-"
    name = (customer.name or "").strip() or f"Customer {customer.pk}"
    phone = customer.phone if full else mask_phone(customer.phone)
    return f"{name}, {phone}" if phone else name


def person_label(person, *, full: bool) -> str:
    """Who acted on a record (order history actor, refund initiator): staff by name or email,
    anyone else as a customer (`customer_label`)."""
    if person is None:
        return "-"
    if person.is_staff or person.is_superuser:
        return (person.name or "").strip() or person.email or f"User {person.pk}"
    return customer_label(person, full=full)


# Address snapshot keys (07 §2.6 `Order.address_snapshot`: the Address API fields, no id).
ADDRESS_STREET_KEYS = ("house", "building_street", "landmark")
ADDRESS_LOCALITY_KEYS = ("area", "city", "state", "pincode")


def address_lines(snapshot: dict | None, *, full: bool) -> list[str]:
    """A delivery address snapshot as display lines.

    Full: receiver, phone, house / street / landmark, then area, city, state and pincode.
    Limited (05 §3 "name, masked phone"): receiver name, masked phone and the locality (area,
    city, state, pincode) only; never the house, street, landmark or the pin coordinates."""
    if not snapshot:
        return []
    get = lambda key: str(snapshot.get(key) or "").strip()  # noqa: E731
    lines = []
    receiver = get("receiver_name")
    phone = get("receiver_phone")
    phone = phone if full else mask_phone(phone)
    lines.append(", ".join(part for part in (receiver, phone) if part))
    if full:
        lines.extend(part for part in (get(key) for key in ADDRESS_STREET_KEYS) if part)
    area, city, state, pincode = (get(key) for key in ADDRESS_LOCALITY_KEYS)
    lines.append(", ".join(part for part in (area, city) if part))
    lines.append(" ".join(part for part in (state, pincode) if part))
    return [line for line in lines if line]


# --------------------------------------------------------------------------- gateway data
# `Payment.raw` and `PaymentWebhookEvent.payload` are Razorpay entities, which carry the
# customer's contact, email, VPA (UPI id), card and bank details. The panel never renders them;
# it shows only these scalar keys of each entity (allow-list, so a new gateway field stays
# hidden until someone decides it is safe).
GATEWAY_SAFE_KEYS = (
    "id",
    "entity",
    "order_id",
    "payment_id",
    "status",
    "method",
    "amount",
    "amount_refunded",
    "currency",
    "captured",
    "refund_status",
    "error_code",
    "error_reason",
    "error_source",
    "error_step",
    "created_at",
)


def gateway_fields(entity) -> list[tuple[str, str]]:
    """(key, value) pairs of `entity`'s allow-listed scalar keys, in GATEWAY_SAFE_KEYS order.
    Nested objects and every other key are dropped."""
    if not isinstance(entity, dict):
        return []
    pairs = []
    for key in GATEWAY_SAFE_KEYS:
        value = entity.get(key)
        if value is None or isinstance(value, dict | list):
            continue
        pairs.append((key, str(value)))
    return pairs


def webhook_entities(payload) -> list[tuple[str, list[tuple[str, str]]]]:
    """Razorpay webhook body -> [(entity name, safe fields)], e.g. ("payment", [...]). Only
    `payload.<name>.entity` objects are read."""
    if not isinstance(payload, dict) or not isinstance(payload.get("payload"), dict):
        return []
    entities = []
    for name, wrapper in payload["payload"].items():
        entity = wrapper.get("entity") if isinstance(wrapper, dict) else None
        fields = gateway_fields(entity)
        if fields:
            entities.append((str(name), fields))
    return entities
