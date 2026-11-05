"""Saved addresses (03 §2.4, 06 §2.2): soft delete and exactly one default per user.

Every write locks the user row first, so concurrent changes to one user's addresses are
serialised (the partial unique constraint is the backstop), and every decision is made from rows
read under that lock, never from the object the view loaded before it (BUG-0007).

Phase 2: the pin is written to `location` (PostGIS) and to the `lat`/`lng` decimals together;
`is_serviceable` is computed on read (`with_serviceability`). T-205: an empty
`receiver_name`/`receiver_phone` resets it to the user's own.
"""

from django.conf import settings
from django.db import transaction
from django.db.models import QuerySet
from django.utils import timezone

from apps.accounts.models import Address, User, to_coordinate
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError
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


def _locked_live(address: Address) -> Address:
    """Under the user lock: the address must still be live (not deleted meanwhile)."""
    current = live_addresses(address.user).filter(pk=address.pk).values("is_default").first()
    if current is None:
        raise ApiError(ErrorCode.NOT_FOUND)
    address.is_default = current["is_default"]  # the value read under the lock, not before it
    return address


def _apply(address: Address, data: dict, user: User) -> set[str]:
    """Copy `data` onto `address`; returns the model fields that changed (never `is_default`
    or `is_deleted`, which only the default/delete rules below write)."""
    changed = set()
    for key in _FIELDS:
        if key in data:
            setattr(address, key, data[key])
            changed.add(key)
    # T-205: "" means "the user's own" (the generated client drops nulls).
    if "receiver_name" in data and not data["receiver_name"]:
        address.receiver_name = user.name
    if "receiver_phone" in data and not data["receiver_phone"]:
        address.receiver_phone = user.phone or ""
    if "lat" in data or "lng" in data:
        for key in ("lat", "lng"):
            if key in data:
                setattr(address, key, to_coordinate(data[key]))
                changed.add(key)
        # `Address.save()` writes `location` from lat/lng (review #7).
        address.__dict__.pop("is_serviceable", None)  # stale annotation: recomputed on output
    return changed


MSG_TOO_MANY = "You can save up to {limit} addresses. Delete one to add another."


def create_address(user: User, data: dict) -> Address:
    """T-814 (L10): at most `MAX_ADDRESSES_PER_USER` live addresses (counted under the user
    lock): 400 `VALIDATION_ERROR` above it."""
    with transaction.atomic():
        _lock_user(user)
        limit = settings.MAX_ADDRESSES_PER_USER
        if live_addresses(user).count() >= limit:
            raise ApiError(
                ErrorCode.VALIDATION_ERROR,
                details={"non_field_errors": [MSG_TOO_MANY.format(limit=limit)]},
            )
        address = Address(user=user)
        _apply(address, data, user)
        address.receiver_name = data.get("receiver_name") or user.name
        address.receiver_phone = data.get("receiver_phone") or (user.phone or "")
        address.is_default = not live_addresses(user).filter(is_default=True).exists()
        address.save()
    return address


def update_address(address: Address, data: dict) -> Address:
    """Writes only the edited fields, under the user lock: a concurrent set-default or delete
    is never overwritten with this request's stale `is_default` / `is_deleted`."""
    with transaction.atomic():
        _lock_user(address.user)
        _locked_live(address)
        changed = _apply(address, data, address.user)
        if changed:
            address.save(update_fields=[*changed, "updated_at"])
    return address


def delete_address(address: Address) -> None:
    """Soft delete. If it was the default, the most recently updated remaining one takes over.
    `was_default` is read under the user lock (BUG-0007); deleting an address that a
    concurrent request already deleted is a no-op."""
    with transaction.atomic():
        _lock_user(address.user)
        current = live_addresses(address.user).filter(pk=address.pk).values("is_default").first()
        if current is None:
            return
        now = timezone.now()
        Address.objects.filter(pk=address.pk).update(
            is_deleted=True, is_default=False, updated_at=now
        )
        address.is_deleted, address.is_default, address.updated_at = True, False, now
        if current["is_default"]:
            successor = live_addresses(address.user).order_by("-updated_at", "-pk").first()
            if successor is not None:
                successor.is_default = True
                successor.save(update_fields=["is_default", "updated_at"])


def set_default(address: Address) -> Address:
    """Make `address` the user's only default (BUG-0007). Decided under the user lock: the
    other defaults are unset and this row is set unconditionally, never from the in-memory flag
    read before the lock. 404 if the address was deleted meanwhile."""
    with transaction.atomic():
        _lock_user(address.user)
        live = live_addresses(address.user)
        now = timezone.now()
        live.filter(is_default=True).exclude(pk=address.pk).update(is_default=False)
        if not live.filter(pk=address.pk).update(is_default=True, updated_at=now):
            raise ApiError(ErrorCode.NOT_FOUND)
        address.is_default, address.updated_at = True, now
    return address
