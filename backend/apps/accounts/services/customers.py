"""Customer moderation for the panel (05 §2 Customers): block and unblock.

The admin's Customers actions call these (one call per selected customer). Each one:
- runs in one transaction and locks the user row (`select_for_update`);
- refuses staff accounts and anonymised accounts with a `ValidationError` (message for the
  admin's flash), and an unknown id the same way;
- returns True when it changed something, False when the customer was already in that state;
- records the actor as an admin `LogEntry` on the Customer (shown in the admin's History).

Why `LogEntry` and not model history: the full `AuditLog` (05 §5, 07 §2.10) arrives with
Phases 4-8. Until then the built-in admin log records who did what and when without a new table
or migration. Its `object_repr` never holds personal data ("Customer 42", not the phone), and
`auth.anonymise_user()` scrubs it anyway. django-simple-history on `User` would copy the phone,
name and email into every history row, which anonymisation would then have to rewrite.

Permission checks belong to the caller (the admin action requires `accounts.change_customer`;
"Anonymise now" requires `accounts.anonymise_customer`, DL-35: Super Admin only).
"""

from django.contrib.admin.models import CHANGE, LogEntry
from django.contrib.contenttypes.models import ContentType
from django.core.exceptions import ValidationError
from django.db import transaction
from django.utils import timezone

from apps.accounts.models import Customer, Device, User
from apps.accounts.services.auth import revoke_all_tokens

MSG_NOT_FOUND = "This customer does not exist."
MSG_STAFF = "Staff accounts are managed under Staff users, not blocked as customers."
MSG_ANONYMISED = "This account has been anonymised; it cannot be blocked or unblocked."
LOG_BLOCKED = "Blocked: deactivated, signed out everywhere, push devices deactivated."
LOG_UNBLOCKED = "Unblocked: can sign in again."


def customer_log_repr(user_id: int) -> str:
    """The `LogEntry.object_repr` used for customers: no personal data."""
    return f"Customer {user_id}"


def _locked_customer(user_id: int) -> User:
    user = User.objects.select_for_update().filter(pk=user_id).first()
    if user is None:
        raise ValidationError(MSG_NOT_FOUND, code="not_found")
    if user.is_staff or user.is_superuser:
        raise ValidationError(MSG_STAFF, code="staff")
    if user.anonymised_at is not None:
        raise ValidationError(MSG_ANONYMISED, code="anonymised")
    return user


def _record(by: User, user: User, message: str) -> None:
    if by is None or by.pk is None:
        raise ValueError("block/unblock need the acting staff user (`by`).")
    LogEntry.objects.create(
        user_id=by.pk,
        content_type=ContentType.objects.get_for_model(Customer, for_concrete_model=False),
        object_id=str(user.pk),
        object_repr=customer_log_repr(user.pk),
        action_flag=CHANGE,
        change_message=message,
    )


def block_customer(user_id: int, *, by: User) -> bool:
    """Deactivate the customer, revoke every refresh token and deactivate their push devices.
    Access tokens stop working at once (inactive users fail authentication). False if the
    customer was already blocked."""
    with transaction.atomic():
        user = _locked_customer(user_id)
        if not user.is_active:
            return False
        user.is_active = False
        user.save(update_fields=["is_active", "updated_at"])
        Device.objects.filter(user=user, is_active=True).update(
            is_active=False, updated_at=timezone.now()
        )
        revoke_all_tokens(user)
        _record(by, user, LOG_BLOCKED)
    return True


def unblock_customer(user_id: int, *, by: User) -> bool:
    """Reactivate a blocked customer. They sign in again with an OTP (tokens stay revoked;
    devices re-register after login). False if the customer was not blocked."""
    with transaction.atomic():
        user = _locked_customer(user_id)
        if user.is_active:
            return False
        user.is_active = True
        user.save(update_fields=["is_active", "updated_at"])
        _record(by, user, LOG_UNBLOCKED)
    return True
