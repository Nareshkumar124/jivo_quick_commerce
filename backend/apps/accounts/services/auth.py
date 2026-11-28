"""OTP login, tokens, logout, account deletion and anonymisation (06 §2.1, 09 §3.1, 07 §4)."""

import logging
from dataclasses import dataclass
from datetime import timedelta

from django.conf import settings
from django.db import IntegrityError, transaction
from django.utils import timezone
from django.utils.translation import gettext_lazy as _
from rest_framework_simplejwt.exceptions import AuthenticationFailed, TokenBackendError, TokenError
from rest_framework_simplejwt.settings import api_settings as jwt_settings
from rest_framework_simplejwt.state import token_backend
from rest_framework_simplejwt.token_blacklist.models import BlacklistedToken, OutstandingToken
from rest_framework_simplejwt.tokens import RefreshToken
from rest_framework_simplejwt.utils import datetime_from_epoch

from apps.accounts.choices import AppName, LoginMethod, OtpPurpose, RiderStatus
from apps.accounts.managers import normalise_email
from apps.accounts.models import Address, Device, OTPRequest, User
from apps.accounts.services.login_methods import ensure_login_method
from apps.accounts.services.otp import request_otp, verify_otp
from apps.core import audit
from apps.core.errors import ErrorCode
from apps.core.exceptions import ApiError

security_log = logging.getLogger("jqc.security")

MSG_BLACKLISTED = "Token is blacklisted"


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
    ensure_login_method(app, LoginMethod.PHONE)
    verify_otp(phone=phone, purpose=OtpPurpose.LOGIN, code=code, ip=ip, app=app)
    with transaction.atomic():
        user, is_new_user = _get_or_create_by_phone(phone)
        return _complete_login(user, is_new_user, app=app, terms_version=terms_version)


MSG_STAFF_EMAIL_LOGIN = "Staff accounts can't sign in with an email code. Use your phone number."


def _customer_by_email(email: str, *, ip: str | None) -> tuple[User, bool]:
    """The customer whose verified email this is, or a new customer with this email (verified,
    no phone). An unverified copy of the email on another account is only a claim: the person
    who just proved they own the address wins, and the claim is removed from that account
    (audited as `auth.unverified_email_released`)."""
    now = timezone.now()
    user = User.objects.select_for_update().filter(email=email).first()
    if user is not None and user.is_staff:
        raise ApiError(ErrorCode.PERMISSION_DENIED, MSG_STAFF_EMAIL_LOGIN)
    if user is not None and user.email_verified_at is not None:
        return user, False
    if user is not None:
        user.email = None
        user.save(update_fields=["email", "updated_at"])
        audit.record(None, "auth.unverified_email_released", user, {"reason": "email_otp"}, ip=ip)
    try:
        with transaction.atomic():
            return User.objects.create_user(email=email, email_verified_at=now), True
    except IntegrityError:  # a concurrent verify created it first
        return User.objects.select_for_update().get(email=email), False


def _rider_by_email(email: str) -> User:
    """Rider app: only an existing rider (a rider profile, so a phone on file) whose verified
    email this is. Email never creates a rider account: new riders register with their phone."""
    user = (
        User.objects.select_for_update()
        .filter(email=email, email_verified_at__isnull=False)
        .first()
    )
    if user is not None and user.is_staff:
        raise ApiError(ErrorCode.PERMISSION_DENIED, MSG_STAFF_EMAIL_LOGIN)
    if user is None or not user.phone or user.rider_status == RiderStatus.NONE:
        raise ApiError(ErrorCode.EMAIL_NOT_REGISTERED)
    return user


def login_with_email_otp(
    *, email: str, code: str, app: str, terms_version: str, ip: str | None
) -> LoginResult:
    """Email OTP sign-in (2026-11-28). Customer app: the user with this verified email, else a
    new customer with this email and no phone (`user.has_phone` false: a phone must be added
    before the first order). Rider app: see `_rider_by_email`."""
    ensure_login_method(app, LoginMethod.EMAIL)
    email = normalise_email(email)
    verify_otp(email=email, purpose=OtpPurpose.LOGIN, code=code, ip=ip, app=app)
    with transaction.atomic():
        if app == AppName.RIDER:
            user, is_new_user = _rider_by_email(email), False
        else:
            user, is_new_user = _customer_by_email(email, ip=ip)
        return _complete_login(user, is_new_user, app=app, terms_version=terms_version)


def _complete_login(user: User, is_new_user: bool, *, app: str, terms_version: str) -> LoginResult:
    """The shared end of every OTP sign-in. Runs inside the caller's transaction."""
    now = timezone.now()
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
    if is_new_user and app == AppName.CUSTOMER:
        # ADR 0002 §7: a new customer account gets its one welcome reward (free carton) in
        # the transaction that creates it. Accounts created before (or by the rider app)
        # get none; the database keeps at most one per customer.
        from apps.promotions.rewards import grant_welcome_reward

        grant_welcome_reward(user, now=now)
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


def rotate_refresh_token(raw: str, *, ip: str | None = None) -> tuple[str, str]:
    """`POST /auth/token/refresh/`: redeem a refresh token exactly once (BUG-0003).

    Returns `(access, new_refresh)`. The new refresh token keeps the old one's claims (`app`).
    Redemption is atomic: the token's outstanding row is locked and the blacklist row is
    inserted under that lock, so of several concurrent requests with one token exactly one
    succeeds and the rest get "Token is blacklisted". Raises `TokenError` (invalid, expired or
    already used) or `AuthenticationFailed` (blocked, deleted or unknown user); the view maps
    both to 401 `TOKEN_INVALID`.

    T-814 (M2): presenting a validly signed refresh token that is already revoked is treated as
    token theft (OAuth refresh-token reuse detection): every refresh token of the user is
    revoked (`revoke_all_tokens`, all devices sign in again) and a security event is logged and
    audited, without the token itself.
    """
    try:
        token = RefreshToken(raw)  # signature, expiry, and a fast blacklist check
    except TokenError:
        _detect_reuse(raw, ip=ip)
        raise
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
        if created:
            access = str(token.access_token)
            token.set_jti()
            token.set_exp()
            token.set_iat()
            token.outstand()
    if not created:  # outside the transaction: the revocation must not roll back with the 401
        _detect_reuse(raw, ip=ip)
        raise TokenError(_(MSG_BLACKLISTED))
    return access, str(token)


def _detect_reuse(raw: str, *, ip: str | None) -> bool:
    """T-814 (M2): if `raw` is a validly signed, unexpired refresh token that is already
    blacklisted, revoke all the user's tokens and record a security event. False otherwise
    (malformed, expired, wrong type or simply unknown tokens are not reuse)."""
    try:
        payload = token_backend.decode(raw, verify=True)
    except TokenBackendError:
        return False
    if payload.get(jwt_settings.TOKEN_TYPE_CLAIM) != "refresh":
        return False
    jti = payload.get(jwt_settings.JTI_CLAIM)
    user_id = payload.get(jwt_settings.USER_ID_CLAIM)
    if not jti or not user_id:
        return False
    if not BlacklistedToken.objects.filter(token__jti=jti).exists():
        return False
    user = User.objects.filter(pk=user_id).first()
    if user is None:
        return False
    with transaction.atomic():
        revoked = revoke_all_tokens(user)
        audit.record(
            None,
            "auth.refresh_token_reuse",
            user,
            {"revoked_tokens": revoked, "app": str(payload.get("app", ""))[:16]},
            ip=ip,
        )
    # Never the token or its jti: only who, which app, and how many sessions were ended.
    security_log.warning(
        "Refresh token reuse: user %s (app %s); %s refresh token(s) revoked",
        user.pk,
        payload.get("app", ""),
        revoked,
    )
    return True


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
    """Confirmed by a `delete_account` OTP sent to the user's own phone (03 §2.2), or, for an
    account without a phone (email sign-up, 2026-11-28), to its verified email."""
    if user.is_staff or not (user.phone or (user.email and user.email_verified_at)):
        raise ApiError(
            ErrorCode.PERMISSION_DENIED, "Staff accounts are deleted by an administrator."
        )
    target = {"phone": user.phone} if user.phone else {"email": user.email}
    verify_otp(**target, purpose=OtpPurpose.DELETE_ACCOUNT, code=code, ip=ip)
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
        phone, email = user.phone, user.email
        user.phone = None
        user.email = None
        user.name = ""
        user.business_name = ""
        user.business_category = None
        user.deletion_reason = ""
        user.marketing_opt_in = False
        user.is_active = False
        user.anonymised_at = timezone.now()
        user.set_unusable_password()
        user.save()
        Address.objects.filter(user=user).delete()
        _scrub_free_text(user)  # T-814 (M4, DL-60)
        Device.objects.filter(user=user).delete()
        if phone:
            OTPRequest.objects.filter(phone=phone).delete()
        if email:
            OTPRequest.objects.filter(email=email).delete()
        revoke_all_tokens(user)
        _scrub_admin_log(user)
        # Phase 5: the rider profile's personal data (DPDP); KYC files follow D-14 retention.
        from apps.delivery.services.privacy import scrub_rider

        scrub_rider(user)
    return True


def _scrub_free_text(user: User) -> None:
    """T-814 (M4, DL-60 ⚠ Jivo): free text the customer typed is erased: their orders' delivery
    instructions, the bodies of the support messages they sent (staff replies and the
    ticket rows stay for the support history) and the comments of their ratings (stars and tags
    stay: the rider average and the reports need them). `Order.address_snapshot` is kept for
    invoiced orders (tax retention, 07 §4)."""
    from apps.orders.models import Order, Rating
    from apps.support.models import TicketMessage

    Order.objects.filter(user=user).exclude(instructions={}).update(
        instructions={}, updated_at=timezone.now()
    )
    TicketMessage.objects.filter(ticket__user=user, is_staff=False).update(body=ERASED_TEXT)
    Rating.objects.filter(user=user).exclude(comment="").update(
        comment=ERASED_TEXT, updated_at=timezone.now()
    )


ERASED_TEXT = "[removed: account deleted]"


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


def request_sign_in_otp(
    *,
    app: str,
    purpose: str,
    ip: str | None,
    phone: str | None = None,
    email: str | None = None,
    user_agent: str = "",
) -> dict:
    """`POST /auth/otp/request/` and `/auth/email-otp/request/`: a `login` OTP needs that
    method switched on for the app (403 `LOGIN_METHOD_DISABLED`); `delete_account` always works,
    so an account can be deleted whatever the switch says."""
    if purpose == OtpPurpose.LOGIN:
        ensure_login_method(app, LoginMethod.EMAIL if email is not None else LoginMethod.PHONE)
    return request_otp(
        phone=phone, email=email, app=app, purpose=purpose, ip=ip, user_agent=user_agent
    )
