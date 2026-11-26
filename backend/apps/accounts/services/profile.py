"""Profile update and push-device registration."""

from django.db import IntegrityError, transaction
from django.utils import timezone

from apps.accounts.managers import normalise_email
from apps.accounts.models import Device, User
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError

# Deliberately generic: must not confirm that another account uses the address.
EMAIL_UNAVAILABLE = "This email can't be used."

_EDITABLE = ("name", "email", "marketing_opt_in", "business_category", "business_name")
# Sending any of these submits the complete-profile screen (03 §2.2).
_PROFILE_SCREEN_FIELDS = ("name", "business_category", "business_name")


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
    if user.profile_completed_at is None and any(key in data for key in _PROFILE_SCREEN_FIELDS):
        user.profile_completed_at = timezone.now()
    try:
        with transaction.atomic():
            user.save()
    except IntegrityError as exc:  # lost a race for the same email
        raise _email_unavailable() from exc
    return user


def skip_profile_prompt(user: User) -> User:
    """Skip on the complete-profile screen (03 §2.2): remembered, so it is not asked again.
    Idempotent in effect: once the prompt is skipped or submitted, a repeat changes nothing
    (two calls racing at the same moment may each write a time; the later one is kept)."""
    if not user.is_profile_complete:
        user.profile_prompt_skipped_at = timezone.now()
        user.save(update_fields=["profile_prompt_skipped_at", "updated_at"])
    return user


def unregister_device(user: User, *, fcm_token: str) -> None:
    """Deactivate the caller's device with this token (no push any more). Idempotent; a token
    of another user, or an unknown one, changes nothing (never revealed)."""
    Device.objects.filter(user=user, fcm_token=fcm_token).update(
        is_active=False, updated_at=timezone.now()
    )


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
