"""Saved addresses (03 §2.4, 06 §2.2): soft delete and exactly one default per user.

Every function locks the user row first, so concurrent changes to one user's default address
are serialised (the partial unique constraint is the backstop).

Phase 2: the pin is written to `location` (PostGIS) and to the `lat`/`lng` decimals together;
`is_serviceable` is computed on read (`with_serviceability`). T-205: an empty
`receiver_name`/`receiver_phone` resets it to the user's own.
"""

from django.contrib.gis.geos import Point
from django.db import transaction
from django.db.models import QuerySet

from apps.accounts.models import Address, User, to_coordinate
from apps.stores.services import address_point_expression, serviceable_exists

_FIELDS = (
    "label",
    "custom_label",
    "receiver_name",
    "receiver_phone",
    "house",
    "building_street",
    "landmark",
    "area",
    "city",
    "state",
    "pincode",
)


def live_addresses(user: User):
    """The caller's addresses. Every address query starts here (requester scoping)."""
    return Address.objects.filter(user=user, is_deleted=False)


def with_serviceability(queryset: QuerySet[Address]) -> QuerySet[Address]:
    """Annotate `is_serviceable`: inside an active store's service area (one EXISTS subquery
    per row, no extra queries)."""
    return queryset.annotate(address_point=address_point_expression()).annotate(
        is_serviceable=serviceable_exists("address_point")
    )


def _lock_user(user: User) -> None:
    User.objects.select_for_update().filter(pk=user.pk).first()


def _apply(address: Address, data: dict, user: User) -> None:
    for key in _FIELDS:
        if key in data:
            setattr(address, key, data[key])
    # T-205: "" means "the user's own" (the generated client drops nulls).
    if "receiver_name" in data and not data["receiver_name"]:
        address.receiver_name = user.name
    if "receiver_phone" in data and not data["receiver_phone"]:
        address.receiver_phone = user.phone or ""
    if "lat" in data or "lng" in data:
        for key in ("lat", "lng"):
            if key in data:
                setattr(address, key, to_coordinate(data[key]))
        address.location = Point(float(address.lng), float(address.lat), srid=4326)
        address.__dict__.pop("is_serviceable", None)  # stale annotation: recomputed on output


def create_address(user: User, data: dict) -> Address:
    with transaction.atomic():
        _lock_user(user)
        address = Address(user=user)
        _apply(address, data, user)
        address.receiver_name = data.get("receiver_name") or user.name
        address.receiver_phone = data.get("receiver_phone") or (user.phone or "")
        address.is_default = not live_addresses(user).filter(is_default=True).exists()
        address.save()
    return address


def update_address(address: Address, data: dict) -> Address:
    _apply(address, data, address.user)
    address.save()
    return address


def delete_address(address: Address) -> None:
    """Soft delete. If it was the default, the most recently updated remaining one takes over."""
    with transaction.atomic():
        _lock_user(address.user)
        was_default = address.is_default
        address.is_deleted = True
        address.is_default = False
        address.save(update_fields=["is_deleted", "is_default", "updated_at"])
        if was_default:
            successor = live_addresses(address.user).order_by("-updated_at", "-pk").first()
            if successor is not None:
                successor.is_default = True
                successor.save(update_fields=["is_default", "updated_at"])


def set_default(address: Address) -> Address:
    with transaction.atomic():
        _lock_user(address.user)
        live_addresses(address.user).filter(is_default=True).exclude(pk=address.pk).update(
            is_default=False
        )
        if not address.is_default:
            address.is_default = True
            address.save(update_fields=["is_default", "updated_at"])
    return address
