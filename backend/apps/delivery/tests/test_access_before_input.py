"""BUG-0013, P5-TC-16 (06 §3 Access): the rider access check runs before the body or the query
string is read.

- No rider profile: 403 `PERMISSION_DENIED` with `details.rider_status` NONE on every rider
  operation except stores and register, even when the input is invalid.
- A rider who is not ACTIVE: 403 `RIDER_NOT_ACTIVE` on the shift, location, offer and task
  operations, even when the input is invalid.
- A staff account: 403 on register, even when the body is invalid.

The same input from an ACTIVE rider is a 400, which proves every input below really is invalid
(so the 403s are not just the result of a valid body).
"""

import pytest

from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.delivery.tests.factories import RiderFactory, active_rider, jpeg_upload

pytestmark = pytest.mark.django_db

R = "/api/v1/rider"
PAN_WITHOUT_NUMBER = "PAN_WITHOUT_NUMBER"  # built per request: an upload is read only once

# (method, path, invalid input, format). For GET the input is the query string.
ANY_STATUS = [
    ("patch", f"{R}/me/", {"dob": "not-a-date"}, "json"),
    ("post", f"{R}/documents/", PAN_WITHOUT_NUMBER, "multipart"),
    ("put", f"{R}/bank-account/", {}, "json"),
    ("get", f"{R}/tasks/history/", {"from": "yesterday"}, None),
    ("get", f"{R}/earnings/", {"from": "yesterday"}, None),
    ("get", f"{R}/cash/ledger/", {"before_id": "abc"}, None),
    ("get", f"{R}/ratings/", {"before_id": "abc"}, None),
]
ACTIVE_ONLY = [
    ("post", f"{R}/shift/start/", {"lat": "north"}, "json"),
    ("post", f"{R}/locations/", {"points": "x"}, "json"),
    ("post", f"{R}/offers/999999/reject/", {"reason": "NOT_A_REASON"}, "json"),
    ("post", f"{R}/tasks/999999/arrived-store/", {"lat": "north"}, "json"),
    ("post", f"{R}/tasks/999999/pickup/", {}, "json"),
    ("post", f"{R}/tasks/999999/arrived-customer/", {"lat": "north"}, "json"),
    ("post", f"{R}/tasks/999999/deliver/", {"otp": "abc"}, "json"),
    ("post", f"{R}/tasks/999999/fail/", {"reason": "NOT_A_REASON"}, "multipart"),
]
# No input to validate: listed so every rider operation is checked for the profile.
NO_INPUT = [
    ("get", f"{R}/me/"),
    ("post", f"{R}/shift/end/"),
    ("post", f"{R}/heartbeat/"),
    ("get", f"{R}/offers/current/"),
    ("post", f"{R}/offers/999999/accept/"),
    ("get", f"{R}/tasks/current/"),
    ("post", f"{R}/tasks/999999/cod-qr/"),
    ("get", f"{R}/tasks/history/999999/"),
    ("get", f"{R}/payouts/"),
]


def ids(cases):
    return [f"{case[0]} {case[1]}" for case in cases]


def call(client, method, path, data, fmt):
    if data == PAN_WITHOUT_NUMBER:
        data = {"doc_type": "PAN", "file": jpeg_upload("pan.png", fmt="PNG")}
    if method == "get":
        return client.get(path, data)
    return getattr(client, method)(path, data, format=fmt)


@pytest.fixture
def client_for(make_auth_client):
    return lambda user: make_auth_client(user, "rider")


def assert_error(response, status: int, code: str) -> dict:
    assert response.status_code == status, response.content
    error = response.json()["error"]
    assert error["code"] == code, error
    return error


@pytest.mark.parametrize(
    ("method", "path", "data", "fmt"), ANY_STATUS + ACTIVE_ONLY, ids=ids(ANY_STATUS + ACTIVE_ONLY)
)
def test_no_profile_with_invalid_input_is_403_rider_status_none(
    client_for, method, path, data, fmt
):
    """BUG-0013, P5-TC-16: the profile check comes before the body (was 400 on documents and
    bank-account)."""
    response = call(client_for(UserFactory()), method, path, data, fmt)
    error = assert_error(response, 403, "PERMISSION_DENIED")
    assert error["details"] == {"rider_status": "NONE"}


@pytest.mark.parametrize(("method", "path"), NO_INPUT, ids=ids(NO_INPUT))
def test_no_profile_is_403_on_every_operation_without_input(client_for, method, path):
    """P5-TC-16: every rider operation except stores and register needs a rider profile."""
    response = getattr(client_for(UserFactory()), method)(path, {"x": "y"}, format="json")
    error = assert_error(response, 403, "PERMISSION_DENIED")
    assert error["details"] == {"rider_status": "NONE"}


@pytest.mark.parametrize(("method", "path", "data", "fmt"), ACTIVE_ONLY, ids=ids(ACTIVE_ONLY))
def test_rider_not_active_with_invalid_input_is_403_rider_not_active(
    client_for, method, path, data, fmt
):
    """P5-TC-16: shift, location, offer and task operations need an ACTIVE rider, checked
    before the body."""
    rider = RiderFactory()  # PENDING_KYC
    response = call(client_for(rider.user), method, path, data, fmt)
    error = assert_error(response, 403, "PERMISSION_DENIED")
    assert error["details"] == {"reason": "RIDER_NOT_ACTIVE", "rider_status": "PENDING_KYC"}


@pytest.mark.parametrize(
    ("method", "path", "data", "fmt"), ANY_STATUS + ACTIVE_ONLY, ids=ids(ANY_STATUS + ACTIVE_ONLY)
)
def test_the_same_input_from_an_active_rider_is_400(client_for, method, path, data, fmt):
    """Control for the tests above: each input really is invalid."""
    rider = active_rider()
    response = call(client_for(rider.user), method, path, data, fmt)
    assert_error(response, 400, "VALIDATION_ERROR")


def test_staff_with_an_invalid_register_body_is_403(client_for):
    """BUG-0013 (same pattern): staff cannot register, whatever the body."""
    staff = StaffUserFactory(phone="+919811100002")
    response = client_for(staff).post(f"{R}/register/", {}, format="json")
    assert_error(response, 403, "PERMISSION_DENIED")


def test_a_customer_with_an_invalid_register_body_still_gets_400(client_for):
    """Register is open to any signed-in user, so its body is validated as before."""
    response = client_for(UserFactory()).post(f"{R}/register/", {}, format="json")
    assert_error(response, 400, "VALIDATION_ERROR")
