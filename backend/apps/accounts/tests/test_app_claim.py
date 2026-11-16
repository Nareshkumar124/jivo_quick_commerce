"""T-219: the access token's `app` claim decides which app a request belongs to
(`apps.accounts.app_access`, 06 §2.1 "App tokens").

- Rider endpoints need a rider-app token, customer endpoints a customer-app token, shared ones
  take both (P5-TC-107, P7-TC-07: a customer-app token on `/rider/*` is 403).
- `X-App-Name` must agree with the claim (403 `PERMISSION_DENIED`, `APP_HEADER_MISMATCH`).
- Every token carries the claim from login on, and refresh keeps it (P1-TC-21, P1-TC-27).
- The rider socket rule is unchanged (P6-TC-19: `apps/realtime/tests/test_consumers.py`,
  `test_rider_socket_refuses_a_customer_app_token`, re-checked below).
"""

import re

import pytest
from django.contrib.auth.models import Group
from django.urls import URLPattern, URLResolver, get_resolver
from rest_framework.test import APIClient
from rest_framework_simplejwt.tokens import AccessToken, RefreshToken

from apps.accounts import app_access, roles
from apps.accounts.services import auth
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.delivery.tests.factories import RiderFactory

pytestmark = pytest.mark.django_db

SHARED, CUSTOMER, RIDER = None, "customer", "rider"
API = "api/v1/"

# 06 §2.1 "App tokens": every endpoint group under /api/v1/ and its class. A new group must be
# classified there, in `app_access.APP_ONLY_PREFIXES` when app-only, and here.
GROUPS = {
    "auth/": SHARED,
    "me/": SHARED,
    "addresses/": SHARED,
    "config/": SHARED,
    "pages/": SHARED,
    "faqs/": SHARED,
    "serviceability/": SHARED,
    "home/": SHARED,
    "categories/": SHARED,
    "products/": SHARED,
    "search/": SHARED,
    "collections/": SHARED,
    "support/": SHARED,
    "cart/": CUSTOMER,
    "orders/": CUSTOMER,
    "payments/": CUSTOMER,
    "account/": CUSTOMER,  # referral (2026-11-13)
    "rider/": RIDER,
}
# App-only routes that take no token at all (server to server).
PUBLIC_APP_ONLY_ROUTES = {"api/v1/payments/razorpay/webhook/"}
METHODS = ("get", "post", "put", "patch", "delete")
CONVERTER = re.compile(r"<(?:(?P<converter>\w+):)?\w+>")


def _walk(patterns, prefix=""):
    for pattern in patterns:
        if isinstance(pattern, URLResolver):
            yield from _walk(pattern.url_patterns, prefix + str(pattern.pattern))
        elif isinstance(pattern, URLPattern):
            yield prefix + str(pattern.pattern), pattern.callback


def api_routes() -> list[tuple[str, str, type]]:
    """(route, concrete path, view class) of every /api/v1/ endpoint in the URLconf."""
    routes = []
    for route, callback in _walk(get_resolver().url_patterns):
        if route.startswith(API):
            path = "/" + CONVERTER.sub(lambda m: "1" if m["converter"] == "int" else "x", route)
            routes.append((route, path, callback.view_class))
    return routes


def methods(view) -> list[str]:
    return [method for method in METHODS if hasattr(view, method)]


def error(response) -> dict:
    return response.json()["error"]


def assert_wrong_app(response, required: str, token_app: str | None) -> None:
    assert response.status_code == 403, response.content
    assert error(response) == {
        "code": "PERMISSION_DENIED",
        "message": app_access.MSG_WRONG_APP_TOKEN[required],
        "details": {"reason": "WRONG_APP_TOKEN", "required_app": required, "token_app": token_app},
    }


def assert_header_mismatch(response, header: str, token_app: str | None) -> None:
    assert response.status_code == 403, response.content
    assert error(response) == {
        "code": "PERMISSION_DENIED",
        "message": app_access.MSG_APP_HEADER_MISMATCH,
        "details": {"reason": "APP_HEADER_MISMATCH", "header_app": header, "token_app": token_app},
    }


def claimless_client(user) -> APIClient:
    """A signed access token without an `app` claim (never issued by `issue_tokens`)."""
    client = APIClient()
    client.credentials(HTTP_AUTHORIZATION=f"Bearer {AccessToken.for_user(user)}")
    return client


# --------------------------------------------------------------------------- the route table


class TestEndpointClasses:
    def test_required_app_by_path(self):
        assert app_access.required_app("/api/v1/rider/me/") == RIDER
        assert app_access.required_app("/api/v1/rider/tasks/1/pickup/") == RIDER
        assert app_access.required_app("/api/v1/rider/ratings/") == RIDER  # in apps.orders
        assert app_access.required_app("/api/v1/cart/items/1/") == CUSTOMER
        assert app_access.required_app("/api/v1/orders/1/track/") == CUSTOMER
        assert app_access.required_app("/api/v1/payments/razorpay/verify/") == CUSTOMER
        for shared in ("/api/v1/me/", "/api/v1/support/tickets/", "/api/v1/riders/", "/admin/"):
            assert app_access.required_app(shared) is SHARED

    def test_every_api_route_is_in_a_documented_group(self):
        routes = api_routes()
        assert len(routes) > 60
        for route, path, view in routes:
            groups = [g for g in GROUPS if route.removeprefix(API).startswith(g)]
            assert len(groups) == 1, f"{route}: classify its group in 06 §2.1 and GROUPS"
            assert app_access.required_app(path) == GROUPS[groups[0]], route
            if GROUPS[groups[0]] is not SHARED and view.authentication_classes == []:
                assert route in PUBLIC_APP_ONLY_ROUTES, f"{route} is app-only but public"

    def test_every_app_only_route_refuses_the_other_apps_token(self, make_auth_client):
        """(b), (c): each rider route with a customer-app token and each customer route with a
        rider-app token (the same person) is 403 `WRONG_APP_TOKEN`, before any other check;
        no view's own permission classes can skip it."""
        person = RiderFactory().user
        clients = {app: make_auth_client(person, app) for app in (CUSTOMER, RIDER)}
        checked = {CUSTOMER: 0, RIDER: 0}
        for route, path, view in api_routes():
            required = app_access.required_app(path)
            if required is SHARED or route in PUBLIC_APP_ONLY_ROUTES:
                continue
            other = RIDER if required == CUSTOMER else CUSTOMER
            for method in methods(view):
                response = getattr(clients[other], method)(path, {})
                assert_wrong_app(response, required, other)
                checked[required] += 1
        assert checked[RIDER] >= 26
        assert checked[CUSTOMER] >= 15


# --------------------------------------------------------------------------- the right token


class TestRightToken:
    def test_rider_endpoints_take_a_rider_app_token(self, make_auth_client):
        """(b): P1-TC-21 / P5-TC-16: a rider-app token reaches the rider rules; the rider
        profile check still applies after the app check."""
        rider = RiderFactory()
        client = make_auth_client(rider.user, RIDER)
        assert client.get("/api/v1/rider/me/").status_code == 200
        assert client.get("/api/v1/rider/me/", headers={"X-App-Name": "rider"}).status_code == 200
        assert client.get("/api/v1/rider/ratings/").status_code == 200
        no_profile = make_auth_client(UserFactory(), RIDER).get(
            "/api/v1/rider/me/", headers={"X-App-Name": "rider"}
        )
        assert no_profile.status_code == 403
        assert error(no_profile)["details"]["rider_status"] == "NONE"

    def test_customer_endpoints_take_a_customer_app_token(self, make_auth_client):
        """(c): a rider who also shops uses the customer app for orders."""
        client = make_auth_client(RiderFactory().user, CUSTOMER)
        assert client.get("/api/v1/orders/").status_code == 200
        headers = {"X-App-Name": "customer"}
        assert client.get("/api/v1/orders/", headers=headers).status_code == 200

    def test_a_customer_app_token_on_rider_endpoints_is_403(self, make_auth_client):
        """P5-TC-107 / P7-TC-07 (OBS-06): the same person's customer-app token is refused on
        `/rider/*`, also with a matching `X-App-Name: customer`."""
        client = make_auth_client(RiderFactory().user, CUSTOMER)
        assert_wrong_app(client.get("/api/v1/rider/ratings/"), RIDER, CUSTOMER)
        response = client.get("/api/v1/rider/me/", headers={"X-App-Name": "customer"})
        assert_wrong_app(response, RIDER, CUSTOMER)

    @pytest.mark.parametrize(
        "path",
        [
            "/api/v1/me/",
            "/api/v1/me/notifications/unread-count/",
            "/api/v1/support/tickets/",
            "/api/v1/addresses/",
        ],
    )
    def test_shared_endpoints_take_both(self, make_auth_client, path):
        """(d): shared endpoints accept both apps' tokens (each with its own header)."""
        person = RiderFactory().user
        for app in (CUSTOMER, RIDER):
            response = make_auth_client(person, app).get(path, headers={"X-App-Name": app})
            assert response.status_code == 200, (app, response.content)


# --------------------------------------------------------------------------- X-App-Name


class TestAppHeader:
    def test_the_t219_case_customer_token_with_rider_header(self, make_auth_client):
        """The reported bug: a customer-app token plus `X-App-Name: rider` on a rider route."""
        client = make_auth_client(RiderFactory().user, CUSTOMER)
        response = client.get("/api/v1/rider/me/", headers={"X-App-Name": "rider"})
        assert_header_mismatch(response, RIDER, CUSTOMER)

    @pytest.mark.parametrize(
        ("token", "header", "path"),
        [
            (CUSTOMER, "rider", "/api/v1/me/"),  # shared
            (RIDER, "customer", "/api/v1/me/notifications/"),  # shared
            (RIDER, "customer", "/api/v1/orders/"),  # customer route, header checked first
            (RIDER, "customer", "/api/v1/rider/me/"),  # the right token, a wrong header
            (CUSTOMER, "rider", "/api/v1/auth/logout/"),
        ],
    )
    def test_header_naming_the_other_app_is_403(self, make_auth_client, token, header, path):
        """(e)"""
        client = make_auth_client(RiderFactory().user, token)
        method = "post" if path.endswith("logout/") else "get"
        response = getattr(client, method)(path, headers={"X-App-Name": header})
        assert_header_mismatch(response, header, token)

    def test_optional_auth_endpoints_check_the_header_when_a_token_is_sent(self, make_auth_client):
        """Home authenticates a token when one is sent (optional auth), so the check runs."""
        client = make_auth_client(UserFactory(), CUSTOMER)
        response = client.get("/api/v1/home/", headers={"X-App-Name": "rider"})
        assert_header_mismatch(response, RIDER, CUSTOMER)

    def test_public_endpoints_never_read_the_token(self, make_auth_client):
        client = make_auth_client(UserFactory(), CUSTOMER)
        headers = {"X-App-Name": "rider", "X-Platform": "android"}
        assert client.get("/api/v1/config/app/", headers=headers).status_code == 200

    @pytest.mark.parametrize("header", ["", "hacker", "admin", "x" * 500])
    def test_unknown_or_empty_header_names_no_app_and_is_ignored(self, make_auth_client, header):
        """P0-TC-13: unknown client-info values are never an error."""
        client = make_auth_client(UserFactory(), CUSTOMER)
        assert client.get("/api/v1/me/", headers={"X-App-Name": header}).status_code == 200

    def test_header_is_trimmed_and_case_insensitive(self, make_auth_client):
        client = make_auth_client(RiderFactory().user, RIDER)
        response = client.get("/api/v1/rider/me/", headers={"X-App-Name": " Rider "})
        assert response.status_code == 200


# --------------------------------------------------------------------------- the claim itself


class TestClaim:
    def test_access_and_refresh_tokens_carry_the_claim_and_refresh_keeps_it(self):
        """(f), P1-TC-21 / P1-TC-27: `issue_tokens` (the only place tokens are made) puts `app`
        in both tokens; a rotation keeps it."""
        user = UserFactory()
        for app in (CUSTOMER, RIDER):
            access, refresh = auth.issue_tokens(user, app)
            assert AccessToken(access)["app"] == app
            assert RefreshToken(refresh)["app"] == app
            new_access, new_refresh = auth.rotate_refresh_token(refresh)
            assert AccessToken(new_access)["app"] == app
            assert RefreshToken(new_refresh)["app"] == app

    def test_a_token_without_the_claim_fits_no_app_only_endpoint(self):
        """(f): treated like the other app's token on rider and customer endpoints."""
        client = claimless_client(RiderFactory().user)
        assert_wrong_app(client.get("/api/v1/rider/me/"), RIDER, None)
        assert_wrong_app(client.get("/api/v1/orders/"), CUSTOMER, None)

    def test_a_token_without_the_claim_on_shared_endpoints(self):
        """(d), (e): allowed without `X-App-Name`; a header naming an app cannot be matched."""
        client = claimless_client(UserFactory())
        assert client.get("/api/v1/me/").status_code == 200
        response = client.get("/api/v1/me/", headers={"X-App-Name": "customer"})
        assert_header_mismatch(response, CUSTOMER, None)

    def test_an_unknown_claim_value_counts_as_no_claim(self):
        token = AccessToken.for_user(UserFactory())
        token["app"] = "admin"
        assert app_access.token_app(token) is None


# --------------------------------------------------------------------------- unaffected


class TestUnaffected:
    def test_staff_session_ignores_the_app_header(self, client):
        """(g): the admin uses the Django session, never a JWT."""
        roles.sync_roles()
        staff = StaffUserFactory()
        staff.groups.add(*Group.objects.filter(name=roles.OPS))
        client.force_login(staff)
        assert client.get("/admin/", headers={"X-App-Name": "rider"}).status_code == 200

    def test_rider_socket_still_needs_a_rider_app_token(self):
        """P6-TC-19 (unchanged, no header involved): `RiderConsumer.authorize` refuses a
        customer-app token; the socket authenticates without `app_access`."""
        from apps.realtime.auth import authenticate_token

        user = RiderFactory().user
        customer_access, _ = auth.issue_tokens(user, CUSTOMER)
        rider_access, _ = auth.issue_tokens(user, RIDER)
        assert authenticate_token(customer_access).app == CUSTOMER
        assert authenticate_token(rider_access).app == RIDER


# --------------------------------------------------------------------------- OpenAPI


@pytest.fixture(scope="module")
def schema():
    from drf_spectacular.generators import SchemaGenerator

    return SchemaGenerator().get_schema(request=None, public=True)


def examples(operation, code="403") -> dict:
    return operation["responses"][code]["content"]["application/json"]["examples"]


class TestSchema:
    def test_app_only_operations_document_the_wrong_app_403(self, schema):
        cart = schema["paths"]["/api/v1/cart/"]["get"]
        assert set(examples(cart)) == {"WRONGAPPTOKEN", "APPHEADERMISMATCH"}
        body = examples(cart)["WRONGAPPTOKEN"]["value"]
        assert body == {
            "error": {
                "code": "PERMISSION_DENIED",
                "message": app_access.MSG_WRONG_APP_TOKEN[CUSTOMER],
                "details": {
                    "reason": "WRONG_APP_TOKEN",
                    "required_app": "customer",
                    "token_app": "rider",
                },
            }
        }
        assert "WRONG_APP_TOKEN" in cart["responses"]["403"]["description"]
        assert list(cart["responses"]).index("403") == list(cart["responses"]).index("401") + 1

    def test_an_operations_own_403_keeps_its_examples(self, schema):
        rider_me = schema["paths"]["/api/v1/rider/me/"]["get"]
        assert {"NOTARIDER", "WRONGAPPTOKEN", "APPHEADERMISMATCH"} <= set(examples(rider_me))
        description = rider_me["responses"]["403"]["description"]
        assert description.startswith("The caller has no rider profile")
        assert "WRONG_APP_TOKEN" in description

    def test_shared_operations_document_only_the_header_mismatch(self, schema):
        me = schema["paths"]["/api/v1/me/"]["get"]
        assert set(examples(me)) == {"APPHEADERMISMATCH"}
        assert examples(me)["APPHEADERMISMATCH"]["value"]["error"]["details"] == {
            "reason": "APP_HEADER_MISMATCH",
            "header_app": "rider",
            "token_app": "customer",
        }

    def test_public_operations_get_no_403(self, schema):
        assert "403" not in schema["paths"]["/api/v1/config/app/"]["get"]["responses"]
        webhook = schema["paths"]["/api/v1/payments/razorpay/webhook/"]["post"]
        assert "403" not in webhook["responses"]
        assert "ErrorEnvelope" in schema["components"]["schemas"]
