"""OTP login, tokens, logout, account deletion and anonymisation (06 §2.1, 09 §3.1, 07 §4)."""

from dataclasses import dataclass
from datetime import timedelta

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from rest_framework_simplejwt.exceptions import AuthenticationFailed, TokenError
from rest_framework_simplejwt.settings import api_settings as jwt_settings
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import datetime_from_epoch

from apps.accounts.choices import OtpPurpose
from apps.accounts.models import Address, Device, OTPRequest, User
from apps.accounts.services.otp import verify_otp
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError


@dataclass(frozen=True)
class LoginResult:
    user: User
    access: str
    refresh: str
    is_new_user: bool
    deletion_cancelled: bool


def issue_tokens(user: User, app: str) -> tuple[str, str]:
    """A rotating refresh token (recorded for revoke-all) and its access token.

    The `app` claim records which app the session belongs to (02 §6).
    """
    refresh = RefreshToken.for_user(user)
    refresh["app"] = app
    return str(refresh.access_token), str(refresh)


def _get_or_create_by_phone(phone: str) -> tuple[User, bool]:
    user = User.objects.select_for_update().filter(phone=phone).first()
    if user is not None:
        return user, False
    try:
        with transaction.atomic():
            return User.objects.create_user(phone=phone), True
    except IntegrityError:  # a concurrent verify created it first
        return User.objects.select_for_update().get(phone=phone), False


def login_with_otp(
    *, phone: str, code: str, app: str, terms_version: str, ip: str | None
) -> LoginResult:
    verify_otp(phone=phone, purpose=OtpPurpose.LOGIN, code=code, ip=ip, app=app)
    now = timezone.now()
    with transaction.atomic():
        user, is_new_user = _get_or_create_by_phone(phone)
        if not user.is_active:
            raise ApiError(ErrorCode.PERMISSION_DENIED, "This account is deactivated.")
        deletion_cancelled = user.deleted_at is not None
        if deletion_cancelled:  # login during the grace period restores the account
            user.deleted_at = None
            user.deletion_reason = ""
        if user.terms_version != terms_version:
            user.terms_version = terms_version
            user.terms_accepted_at = now
        user.last_login = now
        user.save()
    access, refresh = issue_tokens(user, app)
    return LoginResult(user, access, refresh, is_new_user, deletion_cancelled)


def _outstanding_row(token: RefreshToken) -> OutstandingToken:
    """The token's `OutstandingToken` row, locked (`SELECT ... FOR UPDATE`). Every token this
    app issues has one; a validly signed token without one gets it created first."""
    jti = token.payload[jwt_settings.JTI_CLAIM]
    row = OutstandingToken.objects.select_for_update().filter(jti=jti).first()
    if row is not None:
        return row
    user_id = token.payload.get(jwt_settings.USER_ID_CLAIM)
    OutstandingToken.objects.get_or_create(
        jti=jti,
        defaults={
            "user": User.objects.filter(pk=user_id).first() if user_id else None,
            "created_at": token.current_time,
            "token": str(token),
            "expires_at": datetime_from_epoch(token.payload["exp"]),
        },
    )
    return OutstandingToken.objects.select_for_update().get(jti=jti)


def rotate_refresh_token(raw: str) -> tuple[str, str]:
    """`POST /auth/token/refresh/`: redeem a refresh token exactly once (BUG-0003).

    Returns `(access, new_refresh)`. The new refresh token keeps the old one's claims (`app`).
    Redemption is atomic: the token's outstanding row is locked and the blacklist row is
    inserted under that lock, so of several concurrent requests with one token exactly one
    succeeds and the rest get "Token is blacklisted". Raises `TokenError` (invalid, expired or
    already used) or `AuthenticationFailed` (blocked, deleted or unknown user); the view maps
    both to 401 `TOKEN_INVALID`.
    """
    token = RefreshToken(raw)  # signature, expiry, and a fast blacklist check
    user_id = token.payload.get(jwt_settings.USER_ID_CLAIM)
    user = User.objects.filter(pk=user_id).first() if user_id else None
    if not jwt_settings.USER_AUTHENTICATION_RULE(user):
        raise AuthenticationFailed(
            _("No active account found for the given token."), "no_active_account"
        )
    with transaction.atomic():
        _blacklisted, created = BlacklistedToken.objects.get_or_create(
            token=_outstanding_row(token)
        )
        if not created:
            raise TokenError(_("Token is blacklisted"))
        access = str(token.access_token)
        token.set_jti()
        token.set_exp()
        token.set_iat()
        token.outstand()
    return access, str(token)


def revoke_all_tokens(user: User) -> int:
    """Blacklist every outstanding refresh token of the user (logout everywhere)."""
    tokens = OutstandingToken.objects.filter(user=user, blacklistedtoken__isnull=True)
    created = BlacklistedToken.objects.bulk_create(
        [BlacklistedToken(token=token) for token in tokens], ignore_conflicts=True
    )
    return len(created)


def logout(user: User, *, refresh: str, fcm_token: str | None) -> None:
    """Idempotent: unknown, expired, revoked or foreign refresh tokens are ignored."""
    try:
        token = RefreshToken(refresh)
    except TokenError:
        token = None
    if token is not None and str(token.get("user_id")) == str(user.pk):
        token.blacklist()
    if fcm_token:
        Device.objects.filter(user=user, fcm_token=fcm_token).update(
            is_active=False, updated_at=timezone.now()
        )


def anonymise_after(user: User):
    return user.deleted_at + timedelta(days=settings.ACCOUNT_DELETION_GRACE_DAYS)


def delete_account(user: User, *, code: str, reason: str, ip: str | None) -> User:
    """Confirmed by a `delete_account` OTP sent to the user's own phone (03 §2.2)."""
    if user.is_staff or not user.phone:
        raise ApiError(
            ErrorCode.PERMISSION_DENIED, "Staff accounts are deleted by an administrator."
        )
    verify_otp(phone=user.phone, purpose=OtpPurpose.DELETE_ACCOUNT, code=code, ip=ip)
    with transaction.atomic():
        user.deleted_at = timezone.now()
        user.deletion_reason = reason
        user.save(update_fields=["deleted_at", "deletion_reason", "updated_at"])
        Device.objects.filter(user=user).update(is_active=False, updated_at=timezone.now())
        revoke_all_tokens(user)
    return user


def anonymise_user(user_id: int) -> bool:
    """Erase personal data of a deleted account. Idempotent: returns False if nothing to do."""
    with transaction.atomic():
        user = User.objects.select_for_update().filter(pk=user_id).first()
        if user is None or user.deleted_at is None or user.anonymised_at is not None:
            return False
        phone = user.phone
        user.phone = None
        user.email = None
        user.name = ""
        user.deletion_reason = ""
        user.marketing_opt_in = False
        user.is_active = False
        user.anonymised_at = timezone.now()
        user.set_unusable_password()
        user.save()
        Address.objects.filter(user=user).delete()
        Device.objects.filter(user=user).delete()
        if phone:
            OTPRequest.objects.filter(phone=phone).delete()
        revoke_all_tokens(user)
        _scrub_admin_log(user)
    return True


def _scrub_admin_log(user: User) -> None:
    """Admin `LogEntry` rows about this user (block/unblock, staff edits) keep who did what and
    when, but their `object_repr` (Django fills it with `str(user)`, i.e. the phone) is
    replaced with a neutral label."""
    from django.contrib.admin.models import LogEntry
    from django.contrib.contenttypes.models import ContentType

    from apps.accounts.models import Customer

    content_types = [
        ContentType.objects.get_for_model(User),
        ContentType.objects.get_for_model(Customer, for_concrete_model=False),
    ]
    LogEntry.objects.filter(content_type__in=content_types, object_id=str(user.pk)).update(
        object_repr=f"Customer {user.pk}"
    )


def anonymise_due_accounts() -> int:
    """Anonymise accounts whose deletion grace period (07 §4) has passed."""
    cutoff = timezone.now() - timedelta(days=settings.ACCOUNT_DELETION_GRACE_DAYS)
    due = User.objects.filter(deleted_at__lte=cutoff, anonymised_at__isnull=True).values_list(
        "pk", flat=True
    )
    return sum(anonymise_user(pk) for pk in list(due))
