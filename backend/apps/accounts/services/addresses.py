"""Saved addresses (03 §2.4, 06 §2.2): soft delete and exactly one default per user.

Every function locks the user row first, so concurrent changes to one user's default address
are serialised (the partial unique constraint is the backstop).
"""

from django.db import transaction

from apps.accounts.models import Address, User, to_coordinate

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


def _lock_user(user: User) -> None:
    User.objects.select_for_update().filter(pk=user.pk).first()


def _apply(address: Address, data: dict) -> None:
    for key in _FIELDS:
        if key in data:
            setattr(address, key, data[key])
    for key in ("lat", "lng"):
        if key in data:
            setattr(address, key, to_coordinate(data[key]))


def create_address(user: User, data: dict) -> Address:
    with transaction.atomic():
        _lock_user(user)
        address = Address(user=user)
        _apply(address, data)
        address.receiver_name = data.get("receiver_name") or user.name
        address.receiver_phone = data.get("receiver_phone") or (user.phone or "")
        address.is_default = not live_addresses(user).filter(is_default=True).exists()
        address.save()
    return address


def update_address(address: Address, data: dict) -> Address:
    _apply(address, data)
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
