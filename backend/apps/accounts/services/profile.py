"""Profile update and push-device registration."""

from django.db import IntegrityError, transaction
from django.utils import timezone

from apps.accounts.managers import normalise_email
from apps.accounts.models import Device, User
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError

# Deliberately generic: must not confirm that another account uses the address.
EMAIL_UNAVAILABLE = "This email can't be used."

_EDITABLE = ("name", "email", "marketing_opt_in")


def _email_unavailable() -> ApiError:
    return ApiError(ErrorCode.VALIDATION_ERROR, details={"email": [EMAIL_UNAVAILABLE]})


def update_profile(user: User, data: dict) -> User:
    changes = {key: data[key] for key in _EDITABLE if key in data}
    if "email" in changes:
        changes["email"] = normalise_email(changes["email"])
        if (
            changes["email"]
            and User.objects.filter(email=changes["email"]).exclude(pk=user.pk).exists()
        ):
            raise _email_unavailable()
    for key, value in changes.items():
        setattr(user, key, value)
    try:
        with transaction.atomic():
            user.save()
    except IntegrityError as exc:  # lost a race for the same email
        raise _email_unavailable() from exc
    return user


def register_device(
    user: User, *, fcm_token: str, app: str, platform: str, app_version: str
) -> Device:
    """Upsert on `fcm_token`; a token registered to another user moves to this one."""
    defaults = {
        "user": user,
        "app": app,
        "platform": platform,
        "app_version": app_version,
        "is_active": True,
        "last_seen_at": timezone.now(),
    }
    try:
        with transaction.atomic():
            device, _ = Device.objects.update_or_create(fcm_token=fcm_token, defaults=defaults)
    except IntegrityError:  # concurrent first registration of the same token
        device, _ = Device.objects.update_or_create(fcm_token=fcm_token, defaults=defaults)
    return device
