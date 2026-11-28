"""Add a phone number or verify an email on a signed-in account (2026-11-28).

- **Add phone** (`POST /me/phone/otp/` then `POST /me/phone/verify/`): a customer who signed up
  with email has no login phone and may add one, proved by an SMS OTP. A phone, once set, is not
  changed in v1.
- **Delivery contact** (`has_delivery_contact`): an order needs a number the rider and the store
  can call. The account's login phone or the delivery address's `receiver_phone` (a valid Indian
  mobile, typed in the address form, never verified by OTP) is enough; only when neither exists
  does `POST /orders/` answer 422 `PHONE_REQUIRED`. This lets email-only customers order while
  SMS does not deliver. The receiver phone is a contact number only, never a login.
- **Verify email** (`POST /me/email/otp/` then `POST /me/email/verify/`): proves the user owns an
  email, so it can be used for email OTP sign-in. Sets the email as well (replacing an
  unverified one).

Both use the same OTP rules, limits and lockouts as sign-in. The OTP is bound to the address it
was sent to; whoever can read it owns that address. Conflicts are only reported after the
code is verified, so the request step never reveals whether another account uses an address.
"""

import re

from django.db import IntegrityError, transaction
from django.utils import timezone

from apps.accounts.choices import OtpPurpose
from apps.accounts.managers import normalise_email
from apps.accounts.models import User
from apps.accounts.services import otp
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError

_INDIAN_MOBILE = re.compile(r"^\+91[6-9][0-9]{9}\Z")  # as `indian_mobile_validator`

MSG_PHONE_ALREADY_SET = "Your account already has a phone number."
MSG_EMAIL_ALREADY_VERIFIED = "This email is already verified on your account."


def has_delivery_contact(user: User, address) -> bool:
    """True when an order to `address` has a number to call: the user's login phone, or the
    address's `receiver_phone` when it is a valid Indian mobile (E.164)."""
    if user.phone:
        return True
    return address is not None and bool(_INDIAN_MOBILE.match(address.receiver_phone or ""))


def _phone_already_set() -> ApiError:
    return ApiError(ErrorCode.VALIDATION_ERROR, details={"phone": [MSG_PHONE_ALREADY_SET]})


def request_add_phone(
    user: User, *, phone: str, app: str, ip: str | None, user_agent: str = ""
) -> dict:
    if user.phone:
        raise _phone_already_set()
    return otp.request_otp(
        phone=phone, app=app, purpose=OtpPurpose.ADD_PHONE, ip=ip, user_agent=user_agent
    )


def verify_add_phone(user: User, *, phone: str, code: str, app: str, ip: str | None) -> User:
    """Sets the caller's phone. 409 `PHONE_IN_USE` if another account has it (sign in with that
    number instead; accounts are never merged)."""
    if user.phone:
        raise _phone_already_set()
    otp.verify_otp(phone=phone, purpose=OtpPurpose.ADD_PHONE, code=code, ip=ip, app=app)
    with transaction.atomic():
        locked = User.objects.select_for_update().get(pk=user.pk)
        if locked.phone:
            raise _phone_already_set()
        if User.objects.filter(phone=phone).exclude(pk=user.pk).exists():
            raise ApiError(ErrorCode.PHONE_IN_USE)
        locked.phone = phone
        try:
            with transaction.atomic():
                locked.save(update_fields=["phone", "updated_at"])
        except IntegrityError as exc:  # lost a race for the same phone
            raise ApiError(ErrorCode.PHONE_IN_USE) from exc
        audit.record(locked, "account.phone_added", locked, {"via": "sms_otp"}, ip=ip)
    return locked


def request_verify_email(
    user: User, *, email: str, app: str, ip: str | None, user_agent: str = ""
) -> dict:
    email = normalise_email(email)
    if user.email == email and user.email_verified_at is not None:
        raise ApiError(ErrorCode.VALIDATION_ERROR, details={"email": [MSG_EMAIL_ALREADY_VERIFIED]})
    return otp.request_otp(
        email=email, app=app, purpose=OtpPurpose.VERIFY_EMAIL, ip=ip, user_agent=user_agent
    )


def verify_email(user: User, *, email: str, code: str, app: str, ip: str | None) -> User:
    """Sets the caller's email, verified. 409 `EMAIL_IN_USE` if another account has it verified
    or is a staff account; an unverified copy on another (non-staff) account is only a claim and
    is removed (audited as `auth.unverified_email_released`)."""
    email = normalise_email(email)
    otp.verify_otp(email=email, purpose=OtpPurpose.VERIFY_EMAIL, code=code, ip=ip, app=app)
    now = timezone.now()
    with transaction.atomic():
        locked = User.objects.select_for_update().get(pk=user.pk)
        other = User.objects.select_for_update().filter(email=email).exclude(pk=user.pk).first()
        if other is not None:
            if other.is_staff or other.email_verified_at is not None:
                raise ApiError(ErrorCode.EMAIL_IN_USE)
            other.email = None
            other.save(update_fields=["email", "updated_at"])
            audit.record(
                None, "auth.unverified_email_released", other, {"reason": "email_verify"}, ip=ip
            )
        locked.email = email
        locked.email_verified_at = now
        try:
            with transaction.atomic():
                locked.save(update_fields=["email", "email_verified_at", "updated_at"])
        except IntegrityError as exc:  # lost a race for the same email
            raise ApiError(ErrorCode.EMAIL_IN_USE) from exc
        audit.record(locked, "account.email_verified", locked, {"via": "email_otp"}, ip=ip)
    return locked


def mark_email_verified(user: User, *, actor=None, ip: str | None = None) -> User:
    """For the admin: mark the user's current email as verified (staff checked it some other
    way). Audited as `account.email_verified` with `via: staff`."""
    if not user.email:
        raise ValueError("The user has no email.")
    with transaction.atomic():
        locked = User.objects.select_for_update().get(pk=user.pk)
        if locked.email_verified_at is None:
            locked.email_verified_at = timezone.now()
            locked.save(update_fields=["email_verified_at", "updated_at"])
            audit.record(actor, "account.email_verified", locked, {"via": "staff"}, ip=ip)
    return locked
