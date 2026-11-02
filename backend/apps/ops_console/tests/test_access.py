"""Ops Console access per role (05 §3, 09 §3.1): staff only, then per-view permissions.

Allowed: 200. Not staff (or signed out): 302 to the admin login, like /admin/. Staff without the
view's permission: 403 page. HTMX requests never get a 302 (401 + HX-Redirect instead).
"""

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.ops_console.tests.helpers import (
    ANONYMOUS,
    CUSTOMER_ROLES,
    NON_STAFF,
    PRINCIPALS,
    STAFF_PRINCIPALS,
    login_as,
    staff_in_role,
)

pytestmark = pytest.mark.django_db

HX = {"HTTP_HX_REQUEST": "true"}

# url name -> principals that get 200 (the others: 302 if not staff, 403 if staff)
OPS_PAGES = {
    "ops:dashboard": STAFF_PRINCIPALS,
    "ops:dashboard-kpis": CUSTOMER_ROLES,
    "ops:dashboard-signups": CUSTOMER_ROLES,
}


def expected_status(principal, allowed) -> int:
    if principal in allowed:
        return 200
    if principal in (NON_STAFF, ANONYMOUS):
        return 302
    return 403


@pytest.mark.parametrize("url_name", sorted(OPS_PAGES))
@pytest.mark.parametrize("principal", PRINCIPALS)
def test_ops_page_matrix(client, principal, url_name):
    login_as(client, principal)
    url = reverse(url_name)
    response = client.get(url)
    expected = expected_status(principal, OPS_PAGES[url_name])
    assert response.status_code == expected, (principal, url_name)
    if expected == 302:
        assert response["Location"].startswith(reverse("admin:login"))
        assert "next=" in response["Location"]
    if expected == 403:
        assert response["X-Ops-Refused"] == "1"
        assert b"Access refused" in response.content


@pytest.mark.parametrize("principal", [NON_STAFF, ANONYMOUS])
def test_htmx_without_session_gets_hx_redirect_to_login(client, principal):
    """Session expiry: htmx would swap a 302's login page into the target, so 401 +
    HX-Redirect sends the whole page to the login, back to the page the user was on."""
    login_as(client, principal)
    response = client.get(
        reverse("ops:dashboard-signups"),
        HTTP_HX_CURRENT_URL="http://testserver/ops/?tab=1",
        **HX,
    )
    assert response.status_code == 401
    assert response["HX-Redirect"] == "/admin/login/?next=%2Fops%2F%3Ftab%3D1"


def test_htmx_refusal_is_a_403_partial(client):
    client.force_login(staff_in_role(roles.STORE_STAFF))
    response = client.get(reverse("ops:dashboard-signups"), **HX)
    assert response.status_code == 403
    assert response["X-Ops-Refused"] == "1"
    assert b"<html" not in response.content
    assert b"Access refused" in response.content


def test_inactive_staff_is_signed_out(client):
    user = staff_in_role(roles.OPS)
    client.force_login(user)
    user.is_active = False
    user.save()
    response = client.get(reverse("ops:dashboard"))
    assert response.status_code == 302


def test_ops_responses_are_never_cached(client):
    client.force_login(staff_in_role(roles.SUPPORT))
    response = client.get(reverse("ops:dashboard"))
    assert "no-cache" in response["Cache-Control"]
    assert "private" in response["Cache-Control"]


def test_staff_login_through_admin_form_then_ops(client):
    """One login for both layers: the admin form (axes-protected) then /ops/."""
    staff_in_role(roles.OPS, email="ops.login@jivo.test", password="a-strong-pass-1")
    response = client.post(
        reverse("admin:login"),
        {"username": "ops.login@jivo.test", "password": "a-strong-pass-1", "next": "/ops/"},
    )
    assert response.status_code == 302
    assert response["Location"] == "/ops/"
    assert client.get("/ops/").status_code == 200


def test_header_shows_user_and_roles(client):
    user = staff_in_role(roles.SUPPORT, name="Asha Support")
    client.force_login(user)
    content = client.get(reverse("ops:dashboard")).content.decode()
    assert "Asha Support" in content
    assert 'data-testid="ops-roles">Support<' in content


def test_logout_needs_post_with_csrf(client):
    client.force_login(staff_in_role(roles.OPS))
    content = client.get(reverse("ops:dashboard")).content.decode()
    assert f'action="{reverse("admin:logout")}"' in content
    assert "csrfmiddlewaretoken" in content
    assert "X-CSRFToken" in content  # hx-headers on <body>: every HTMX POST carries the token
