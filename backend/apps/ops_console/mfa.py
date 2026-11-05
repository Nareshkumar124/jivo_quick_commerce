"""Staff two-factor authentication (OWASP review H2, DL-59): TOTP for privileged staff on the
panel (`/admin/` and `/ops/`). Interim until Jivo SSO (D-04) replaces staff login.

- **Who:** superusers and the Super Admin, Finance and Support roles; Ops / Dispatch too when
  `STAFF_MFA_INCLUDE_OPS` is on. Other roles are not asked. Off when `STAFF_MFA_ENFORCED` is
  off (the test settings; the MFA tests turn it on).
- **Library:** django-otp 1.7.5 (`otp_totp` devices, `otp_static` recovery codes). Its
  `OTPMiddleware` gives `request.user.is_verified()`; verifying a code stores the device in the
  session (the "verified" flag), so it holds for the rest of that login only.
- **Flow:** a privileged staff member who is signed in but not verified is sent to
  `/ops/mfa/setup/` (no confirmed device: QR code plus the key to type by hand, then a code to
  confirm; 10 recovery codes shown once) or `/ops/mfa/verify/` (an authenticator code or a
  recovery code, each recovery code works once). HTMX requests get 401 + `HX-Redirect`.
- **Reset:** Super Admin, from the Staff users admin ("Reset two-factor device"), through
  `reset_devices()`, which deletes the devices and writes the audit log.
- **Secrets:** the TOTP key is shown only on the setup page (never cached) and is never logged;
  recovery codes are shown once and kept by django-otp, as it stores them.
"""

from urllib.parse import urlencode

from django import forms
from django.conf import settings
from django.contrib.auth.views import redirect_to_login
from django.db import transaction
from django.http import HttpResponse
from django.shortcuts import redirect, render
from django.urls import reverse
from django.utils.http import url_has_allowed_host_and_scheme
from django.views.decorators.cache import never_cache
from django.views.decorators.debug import sensitive_post_parameters
from django_otp import login as otp_login
from django_otp import match_token
from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
from django_otp.plugins.otp_totp.models import TOTPDevice
from unfold.widgets import UnfoldAdminTextInputWidget

from apps.accounts import roles

PANEL_PREFIXES = ("/admin/", "/ops/")
# Exact paths only (review: a prefix such as "/admin/login/" would also exempt
# "/admin/login/anything"). Resolved lazily from the URL names.
EXEMPT_URL_NAMES = (
    "admin:login",
    "admin:logout",
    "admin:jsi18n",
    "ops:mfa-setup",
    "ops:mfa-verify",
    "ops:csp-report",
)
RECOVERY_CODES = 10
SESSION_CODES = "ops_mfa_new_recovery_codes"
DEVICE_NAME = "Authenticator app"
RECOVERY_NAME = "Recovery codes"

MSG_WRONG = "That code is not right. Check the time on your phone and try the newest code."


def enforced() -> bool:
    return bool(getattr(settings, "STAFF_MFA_ENFORCED", True))


def mfa_roles() -> frozenset[str]:
    base = {roles.SUPER_ADMIN, roles.FINANCE, roles.SUPPORT}
    if getattr(settings, "STAFF_MFA_INCLUDE_OPS", False):
        base.add(roles.OPS)
    return frozenset(base)


def requires_mfa(user) -> bool:
    if not (user.is_authenticated and user.is_active and user.is_staff):
        return False
    if user.is_superuser:
        return True
    return bool(set(user.groups.values_list("name", flat=True)) & mfa_roles())


def exempt_paths() -> frozenset[str]:
    return frozenset(reverse(name) for name in EXEMPT_URL_NAMES)


def has_device(user) -> bool:
    return TOTPDevice.objects.filter(user=user, confirmed=True).exists()


def _is_verified(request) -> bool:
    check = getattr(request.user, "is_verified", None)
    return bool(check and check())


def _next(request, default: str) -> str:
    target = request.POST.get("next") or request.GET.get("next") or ""
    if target and url_has_allowed_host_and_scheme(
        target, allowed_hosts={request.get_host()}, require_https=request.is_secure()
    ):
        return target
    return default


def staff_mfa_middleware(get_response):
    """After django-otp's OTPMiddleware: privileged staff must verify before using the panel."""

    def middleware(request):
        path = request.path
        if (
            enforced()
            and path.startswith(PANEL_PREFIXES)
            and path not in exempt_paths()
            and requires_mfa(request.user)
            and not _is_verified(request)
        ):
            name = "ops:mfa-verify" if has_device(request.user) else "ops:mfa-setup"
            target = f"{reverse(name)}?{urlencode({'next': request.get_full_path()})}"
            if request.headers.get("HX-Request") == "true":
                response = HttpResponse(status=401)
                response["HX-Redirect"] = target
                return response
            return redirect(target)
        return get_response(request)

    return middleware


# --------------------------------------------------------------------------- views


class CodeForm(forms.Form):
    code = forms.CharField(
        label="Code",
        max_length=16,
        widget=UnfoldAdminTextInputWidget(
            attrs={"autocomplete": "one-time-code", "inputmode": "numeric", "autofocus": True}
        ),
    )


def _staff_only(view):
    def wrapper(request, *args, **kwargs):
        user = request.user
        if not (user.is_authenticated and user.is_active and user.is_staff):
            return redirect_to_login(request.get_full_path(), reverse("admin:login"))
        return view(request, *args, **kwargs)

    wrapper.__name__ = view.__name__
    wrapper.__doc__ = view.__doc__
    return never_cache(wrapper)


def _page(request, template: str, **context):
    context.setdefault("title", "Two-step sign-in")
    return render(request, template, context)


def _key_groups(device: TOTPDevice) -> str:
    """The base32 key in groups of four, for typing by hand."""
    from base64 import b32encode

    key = b32encode(device.bin_key).decode().rstrip("=")
    return " ".join(key[index : index + 4] for index in range(0, len(key), 4))


def _new_recovery_codes(user) -> list[str]:
    StaticDevice.objects.filter(user=user).delete()
    device = StaticDevice.objects.create(user=user, name=RECOVERY_NAME, confirmed=True)
    codes = [StaticToken.random_token() for _ in range(RECOVERY_CODES)]
    StaticToken.objects.bulk_create(StaticToken(device=device, token=code) for code in codes)
    return codes


@_staff_only
@sensitive_post_parameters("code")
def setup(request):
    """Enrol an authenticator app: QR code (or the key typed by hand), then one code."""
    user = request.user
    if has_device(user):
        return redirect(f"{reverse('ops:mfa-verify')}?{urlencode({'next': _next(request, '')})}")
    device = TOTPDevice.objects.filter(user=user, confirmed=False).order_by("pk").first()
    if device is None:
        device = TOTPDevice.objects.create(user=user, name=DEVICE_NAME, confirmed=False)
    form = CodeForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        if device.verify_token(form.cleaned_data["code"].replace(" ", "")):
            with transaction.atomic():
                device.confirmed = True
                device.save(update_fields=["confirmed"])
                TOTPDevice.objects.filter(user=user, confirmed=False).delete()
                codes = _new_recovery_codes(user)
            otp_login(request, device)
            request.session[SESSION_CODES] = codes
            return redirect(
                f"{reverse('ops:mfa-recovery')}?{urlencode({'next': _next(request, '')})}"
            )
        form.add_error("code", MSG_WRONG)
    return _page(
        request,
        "ops/mfa/setup.html",
        form=form,
        config_url=device.config_url,
        manual_key=_key_groups(device),
        next=_next(request, ""),
        title="Set up two-step sign-in",
    )


@_staff_only
@sensitive_post_parameters("code")
def verify(request):
    """An authenticator code, or one recovery code (each works once)."""
    user = request.user
    if not has_device(user):
        return redirect(f"{reverse('ops:mfa-setup')}?{urlencode({'next': _next(request, '')})}")
    form = CodeForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        device = match_token(user, form.cleaned_data["code"].replace(" ", ""))
        if device is not None:
            otp_login(request, device)
            return redirect(_next(request, reverse("admin:index")))
        form.add_error("code", MSG_WRONG)
    return _page(request, "ops/mfa/verify.html", form=form, next=_next(request, ""))


@_staff_only
def recovery(request):
    """The new recovery codes, shown once (popped from the session). Only after verifying: the
    page is not exempt from the MFA middleware, and checks again here."""
    if requires_mfa(request.user) and enforced() and not _is_verified(request):
        return redirect(f"{reverse('ops:mfa-verify')}?{urlencode({'next': request.path})}")
    codes = request.session.pop(SESSION_CODES, None)
    return _page(
        request,
        "ops/mfa/recovery.html",
        codes=codes,
        next=_next(request, reverse("admin:index")),
        title="Your recovery codes",
    )


# --------------------------------------------------------------------------- reset


def reset_devices(user, *, by, ip: str | None = None) -> int:
    """Super Admin: remove a staff member's authenticator and recovery codes (lost phone); they
    enrol again at their next sign-in. Audited (`staff.mfa_reset`, device count only)."""
    from apps.core import audit

    with transaction.atomic():
        totp, _ = TOTPDevice.objects.filter(user=user).delete()
        static, _ = StaticDevice.objects.filter(user=user).delete()
        audit.record(by, "staff.mfa_reset", user, {"devices": totp + static}, ip=ip)
    return totp + static
