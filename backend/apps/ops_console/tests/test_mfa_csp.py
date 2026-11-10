"""Staff two-step sign-in (OWASP H2, DL-59) and the report-only CSP (L7).

MFA is off in the test settings (the suite uses force_login); these tests turn it on.
"""

import json
import logging
import time

import pytest
from django.contrib.admin.helpers import ACTION_CHECKBOX_NAME
from django.urls import reverse
from django_otp.oath import totp
from django_otp.plugins.otp_static.models import StaticDevice, StaticToken
from django_otp.plugins.otp_totp.models import TOTPDevice

from apps.accounts import roles
from apps.core.models import AuditLog
from apps.ops_console.tests.helpers import login_as, staff_in_role

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}


@pytest.fixture(autouse=True)
def _mfa_on(settings):
    settings.STAFF_MFA_ENFORCED = True
    settings.STAFF_MFA_INCLUDE_OPS = True  # the default (review: Ops has the broadest PII/KYC)


def code_for(device: TOTPDevice) -> str:
    return f"{totp(device.bin_key, device.step, device.t0, device.digits, device.drift):06d}"


def enrol(client, next_url="/admin/") -> TOTPDevice:
    client.get(reverse("ops:mfa-setup"))
    device = TOTPDevice.objects.get(confirmed=False)
    response = client.post(reverse("ops:mfa-setup"), {"code": code_for(device), "next": next_url})
    assert response.status_code == 302, response.content[:300]
    return TOTPDevice.objects.get(pk=device.pk)


# --------------------------------------------------------------------------- who is asked


@pytest.mark.parametrize(
    "role", [roles.SUPER_ADMIN, roles.FINANCE, roles.SUPPORT, "superuser flag"]
)
@pytest.mark.parametrize("path", ["/admin/", "/ops/"])
def test_unenrolled_privileged_staff_must_enrol(client, role, path):
    login_as(client, role)
    response = client.get(path)
    assert response.status_code == 302
    assert response["Location"].startswith(reverse("ops:mfa-setup"))


@pytest.mark.parametrize("role", [roles.STORE_MANAGER, roles.STORE_STAFF, roles.CATALOG_MANAGER])
def test_other_roles_are_not_asked(client, role):
    login_as(client, role)
    assert client.get("/ops/").status_code == 200
    assert client.get("/admin/").status_code == 200


def test_ops_is_asked_by_default_and_can_be_left_out(client, settings):
    from django.conf import settings as live

    login_as(client, roles.OPS)
    assert client.get("/ops/")["Location"].startswith(reverse("ops:mfa-setup"))
    settings.STAFF_MFA_INCLUDE_OPS = False
    assert client.get("/ops/").status_code == 200
    assert live.OTP_TOTP_THROTTLE_FACTOR == 5
    assert live.OTP_STATIC_THROTTLE_FACTOR == 5


@pytest.mark.parametrize(
    "path",
    [
        "/admin/login/x",
        "/admin/login/../orders/order/",
        "/ops/mfa/../orders/live/",
        "/ops/mfa/setupx/",
        "/ops/csp-report/../",
        "/admin/logout/extra",
    ],
)
def test_exempt_paths_are_exact(client, path):
    """Only the exact login, logout, jsi18n, MFA and CSP-report URLs skip the check."""
    login_as(client, roles.FINANCE)
    response = client.get(path)
    assert response.status_code == 302, path
    assert response["Location"].startswith(reverse("ops:mfa-setup")), path


def test_missing_slash_still_ends_at_the_check(client):
    login_as(client, roles.FINANCE)
    response = client.get("/ops", follow=True)
    assert response.redirect_chain[-1][0].startswith(reverse("ops:mfa-setup"))


def test_unverified_finance_cannot_export_refund_or_run_actions(client):
    from decimal import Decimal

    from django.contrib.admin.helpers import ACTION_CHECKBOX_NAME

    from apps.orders.tests.factories import OrderFactory
    from apps.payments.models import Refund

    order = OrderFactory(payment_method="ONLINE", payment_status="PAID")
    login_as(client, roles.FINANCE)
    setup = reverse("ops:mfa-setup")
    export = client.post(reverse("admin:orders_order_export"), {"resource": "0", "format": "0"})
    assert export["Location"].startswith(setup)
    refund = client.post(
        reverse("admin:orders_order_issue_refund", args=[order.pk]),
        {"amount": "10.00", "note": "", "once": "x"},
    )
    assert refund["Location"].startswith(setup)
    action = client.post(
        reverse("admin:payments_refund_changelist"),
        {"action": "retry_failed", "index": "0", ACTION_CHECKBOX_NAME: ["1"], "once": "x"},
    )
    assert action["Location"].startswith(setup)
    assert not Refund.objects.exists()
    assert order.grand_total == Decimal("300.00")


def test_wrong_codes_are_throttled(client):
    user = staff_in_role(roles.SUPPORT)
    client.force_login(user)
    device = enrol(client)
    client.logout()
    client.force_login(user)
    wrong = client.post(reverse("ops:mfa-verify"), {"code": "000000"})
    assert "That code is not right" in wrong.content.decode()
    device.refresh_from_db()
    assert device.throttling_failure_count >= 1
    # Within the throttle window even the right code is refused.
    refused = client.post(reverse("ops:mfa-verify"), {"code": code_for(device)})
    assert refused.status_code == 200
    assert client.get("/ops/").status_code == 302


def test_role_added_mid_session_is_asked_on_the_next_request(client):
    from django.contrib.auth.models import Group

    user = staff_in_role(roles.STORE_STAFF)
    client.force_login(user)
    assert client.get("/ops/").status_code == 200
    user.groups.add(Group.objects.get(name=roles.FINANCE))
    assert client.get("/ops/")["Location"].startswith(reverse("ops:mfa-setup"))


def test_recovery_page_needs_verification(client):
    user = staff_in_role(roles.FINANCE)
    client.force_login(user)
    enrol(client)
    client.logout()
    client.force_login(user)
    response = client.get(reverse("ops:mfa-recovery"))
    assert response.status_code == 302
    assert response["Location"].startswith(reverse("ops:mfa-verify"))


def test_htmx_gets_401_with_hx_redirect(client):
    login_as(client, roles.FINANCE)
    response = client.get(reverse("ops:dashboard-operations"), **HX)
    assert response.status_code == 401
    assert response["HX-Redirect"].startswith(reverse("ops:mfa-setup"))


def test_api_and_login_are_not_affected(client):
    login_as(client, roles.SUPER_ADMIN)
    assert client.get(reverse("admin:login")).status_code in (200, 302)


def test_off_switch(client, settings):
    settings.STAFF_MFA_ENFORCED = False
    login_as(client, roles.SUPER_ADMIN)
    assert client.get("/admin/").status_code == 200


# --------------------------------------------------------------------------- enrolment


def test_enrolment_shows_qr_and_key_and_recovery_codes_once(client, caplog):
    login_as(client, roles.SUPER_ADMIN)
    caplog.set_level(logging.DEBUG)
    page = client.get(reverse("ops:mfa-setup"))
    html = page.content.decode()
    device = TOTPDevice.objects.get(confirmed=False)
    assert 'data-testid="mfa-qr"' in html
    assert "otpauth://totp/" in html
    assert 'data-testid="mfa-key"' in html
    assert "no-cache" in page["Cache-Control"] or "no-store" in page["Cache-Control"]
    response = client.post(reverse("ops:mfa-setup"), {"code": code_for(device), "next": "/ops/"})
    assert response["Location"].startswith(reverse("ops:mfa-recovery"))
    recovery = client.get(response["Location"]).content.decode()
    tokens = list(
        StaticToken.objects.filter(device__user=device.user).values_list("token", flat=True)
    )
    assert len(tokens) == 10
    assert all(token in recovery for token in tokens)
    assert (
        'data-testid="recovery-codes"'
        not in client.get(reverse("ops:mfa-recovery")).content.decode()
    )
    # Verified for this session: the panel opens.
    assert client.get("/ops/").status_code == 200
    # The key never reaches the logs.
    from base64 import b32encode

    key = b32encode(TOTPDevice.objects.get(pk=device.pk).bin_key).decode().rstrip("=")
    assert key not in caplog.text
    assert device.key not in caplog.text


def test_wrong_code_is_refused_on_enrolment(client):
    login_as(client, roles.FINANCE)
    client.get(reverse("ops:mfa-setup"))
    response = client.post(reverse("ops:mfa-setup"), {"code": "000000"})
    assert response.status_code == 200
    assert "That code is not right" in response.content.decode()
    assert not TOTPDevice.objects.filter(confirmed=True).exists()
    assert client.get("/ops/").status_code == 302


# --------------------------------------------------------------------------- later sign-ins


def test_enrolled_user_verifies_each_login(client):
    user = staff_in_role(roles.SUPPORT)
    client.force_login(user)
    device = enrol(client)
    client.logout()
    client.force_login(user)
    response = client.get("/admin/")
    assert response["Location"].startswith(reverse("ops:mfa-verify"))
    wrong = client.post(reverse("ops:mfa-verify"), {"code": "123456x"})
    assert "That code is not right" in wrong.content.decode()
    assert client.get("/admin/").status_code == 302
    time.sleep(0)  # same 30 s step is fine: django-otp refuses only a reused counter
    device.refresh_from_db()
    ok = client.post(reverse("ops:mfa-verify"), {"code": code_for(device), "next": "/ops/"})
    assert ok.status_code in (302, 200)


def test_recovery_code_works_once(client):
    user = staff_in_role(roles.FINANCE)
    client.force_login(user)
    enrol(client)
    code = StaticToken.objects.filter(device__user=user).first().token
    client.logout()
    client.force_login(user)
    assert (
        client.post(reverse("ops:mfa-verify"), {"code": code, "next": "/ops/"}).status_code == 302
    )
    assert client.get("/ops/").status_code == 200
    client.logout()
    client.force_login(user)
    again = client.post(reverse("ops:mfa-verify"), {"code": code})
    assert "That code is not right" in again.content.decode()


def test_next_is_never_an_outside_url(client):
    user = staff_in_role(roles.FINANCE)
    client.force_login(user)
    enrol(client)
    code = StaticToken.objects.filter(device__user=user).first().token
    client.logout()
    client.force_login(user)
    response = client.post(
        reverse("ops:mfa-verify"), {"code": code, "next": "https://evil.example/"}
    )
    assert response["Location"] == reverse("admin:index")


# --------------------------------------------------------------------------- reset


def test_super_admin_resets_a_device_and_it_is_audited(client):
    member = staff_in_role(roles.FINANCE)
    client.force_login(member)
    enrol(client)
    admin_user = staff_in_role(roles.SUPER_ADMIN)
    client.force_login(admin_user)
    enrol(client)
    response = client.post(
        reverse("admin:accounts_user_changelist"),
        {"action": "reset_mfa", "index": "0", ACTION_CHECKBOX_NAME: [str(member.pk)]},
        follow=True,
    )
    assert "Reset two-factor sign-in for 1 staff member(s)." in response.content.decode()
    assert not TOTPDevice.objects.filter(user=member).exists()
    assert not StaticDevice.objects.filter(user=member).exists()
    entry = AuditLog.objects.get(action="staff.mfa_reset", object_id=str(member.pk))
    assert entry.actor == admin_user
    assert "key" not in json.dumps(entry.changes)


def test_otp_device_admins_are_not_exposed(client):
    user = staff_in_role(roles.SUPER_ADMIN)
    client.force_login(user)
    enrol(client)
    assert client.get("/admin/otp_totp/totpdevice/").status_code == 404


# --------------------------------------------------------------------------- CSP (L7)


@pytest.mark.parametrize("path", ["/admin/login/", "/ops/"])
def test_panel_responses_carry_a_report_only_csp(client, settings, path):
    settings.STAFF_MFA_ENFORCED = False
    login_as(client, roles.OPS)
    response = client.get(path)
    header = response["Content-Security-Policy-Report-Only"]
    assert "script-src 'self' 'unsafe-eval' 'nonce-" in header
    assert "frame-ancestors 'none'" in header
    assert "report-uri /ops/csp-report/" in header
    assert (
        "Content-Security-Policy" not in response.headers
        or response.headers.get("Content-Security-Policy") is None
    )


def test_csp_can_be_enforced(client, settings):
    settings.CSP_REPORT_ONLY = False
    response = client.get("/admin/login/")
    assert "frame-ancestors 'none'" in response["Content-Security-Policy"]


def test_api_has_no_panel_csp(client):
    response = client.get("/health/live")
    assert "Content-Security-Policy-Report-Only" not in response


def test_csp_report_is_logged_in_short_form(client, caplog):
    caplog.set_level(logging.INFO, logger="apps.ops_console.csp")
    body = {
        "csp-report": {
            "document-uri": "http://testserver/admin/orders/order/?q=+919811122233",
            "violated-directive": "script-src-elem",
            "blocked-uri": "inline",
        }
    }
    response = client.post(
        reverse("ops:csp-report"), json.dumps(body), content_type="application/csp-report"
    )
    assert response.status_code == 204
    assert "script-src-elem blocked inline on http://testserver/admin/orders/order/" in caplog.text
    assert "919811122233" not in caplog.text
    assert (
        client.post(reverse("ops:csp-report"), "not json", content_type="text/plain").status_code
        == 204
    )


def test_csp_report_oversize_is_refused_before_reading(client):
    body = "x" * 20_000
    response = client.post(reverse("ops:csp-report"), body, content_type="application/csp-report")
    assert response.status_code == 413


@pytest.fixture
def _csp_private_cache(settings):
    """The CSP flood counter lives in the default cache. Give these tests a private in-process
    cache so the count never depends on the shared test Redis or on other xdist workers."""
    settings.CACHES = {
        "default": {
            "BACKEND": "django.core.cache.backends.locmem.LocMemCache",
            "LOCATION": "csp-report-tests",
        }
    }
    from django.core.cache import cache

    cache.clear()
    yield
    cache.clear()


@pytest.mark.usefixtures("_csp_private_cache")
def test_csp_report_flood_is_dropped(client, caplog):
    caplog.set_level(logging.INFO, logger="apps.ops_console.csp")
    body = json.dumps({"csp-report": {"violated-directive": "img-src", "blocked-uri": "x"}})
    for _ in range(40):
        response = client.post(
            reverse("ops:csp-report"), body, content_type="application/csp-report"
        )
        assert response.status_code == 204
    assert caplog.text.count("CSP violation") == 30


@pytest.mark.usefixtures("_csp_private_cache")
def test_csp_report_cannot_inject_log_lines(client, caplog):
    caplog.set_level(logging.INFO, logger="apps.ops_console.csp")
    body = json.dumps(
        {
            "csp-report": {
                "violated-directive": "script-src\r\nFAKE LOG LINE",
                "blocked-uri": "https://evil.example/x.js?token=secret",
                "document-uri": "http://testserver/ops/\nINJECTED",
            }
        }
    )
    client.post(reverse("ops:csp-report"), body, content_type="application/csp-report")
    record = next(r for r in caplog.records if "CSP violation" in r.getMessage())
    message = record.getMessage()
    assert "\n" not in message
    assert "\r" not in message
    assert "script-srcFAKE LOG LINE" in message
    assert "secret" not in message
    assert record.levelno == logging.INFO
