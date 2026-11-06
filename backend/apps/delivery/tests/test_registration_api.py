"""Slice 5.1 rider API (T-512): stores, register, me, documents, bank account."""

import io
from datetime import date

import pytest
from django.core.files.storage import default_storage
from PIL import Image

from apps.accounts.choices import RiderStatus
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.core.crypto import decrypt
from apps.delivery.choices import DocumentStatus
from apps.delivery.models import Rider, RiderDocument
from apps.delivery.tests.factories import (
    RiderDocumentFactory,
    RiderFactory,
    active_rider,
    add_bank,
    add_documents,
    jpeg_upload,
)
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db

REGISTER = "/api/v1/rider/register/"
ME = "/api/v1/rider/me/"
DOCS = "/api/v1/rider/documents/"
BANK = "/api/v1/rider/bank-account/"


def payload(store, **overrides):
    data = {
        "full_name": "  Ravi   Kumar ",
        "dob": "1998-04-12",
        "emergency_contact_name": "Sunita Devi",
        "emergency_contact_phone": "+919812345670",
        "preferred_store_id": store.pk,
        "vehicle_type": "MOTORBIKE",
        "vehicle_number": "hr 26 dq 1234",
    }
    data.update(overrides)
    return data


@pytest.fixture
def store():
    return DarkStoreFactory()


@pytest.fixture
def client_for(make_auth_client):
    return lambda user: make_auth_client(user, "rider")


# --------------------------------------------------------------------------- stores


def test_stores_lists_active_stores_only(client_for, store):
    DarkStoreFactory(is_active=False)
    response = client_for(UserFactory()).get("/api/v1/rider/stores/")
    assert response.status_code == 200
    assert response.json() == {
        "results": [{"id": store.pk, "name": store.name, "city": "Gurugram"}]
    }


# --------------------------------------------------------------------------- register


def test_register_creates_a_pending_profile(client_for, store):
    user = UserFactory(name="")
    response = client_for(user).post(REGISTER, payload(store), format="json")
    assert response.status_code == 201, response.json()
    body = response.json()
    assert body["status"] == "PENDING_KYC"
    assert body["full_name"] == "Ravi Kumar"
    assert body["vehicle_number"] == "HR26DQ1234"
    assert body["preferred_store"]["id"] == store.pk
    assert body["home_store"] is None
    assert body["missing_documents"] == [
        "PHOTO",
        "AADHAAR_FRONT",
        "AADHAAR_BACK",
        "PAN",
        "DL",
        "RC",
    ]
    assert body["ready_for_review"] is False
    assert body["cash"] == {
        "cash_in_hand": "0.00",
        "cash_limit": "5000.00",
        "limit_reached": False,
        "deposit_required": False,
    }
    assert body["today"]["online_seconds"] == 0
    user.refresh_from_db()
    assert user.name == "Ravi Kumar"
    assert user.rider_status == RiderStatus.PENDING_KYC
    # GET /me/ routes the rider app on rider_status.
    assert client_for(user).get("/api/v1/me/").json()["rider_status"] == "PENDING_KYC"


def test_register_bicycle_needs_no_vehicle_number(client_for, store):
    data = payload(store, vehicle_type="BICYCLE")
    del data["vehicle_number"]
    response = client_for(UserFactory()).post(REGISTER, data, format="json")
    assert response.status_code == 201
    assert response.json()["vehicle_number"] is None
    assert "DL" not in response.json()["required_documents"]


@pytest.mark.parametrize(
    ("overrides", "field"),
    [
        ({"dob": str(date.today().replace(year=date.today().year - 17))}, "dob"),
        ({"vehicle_number": ""}, "vehicle_number"),
        ({"vehicle_type": "E_BIKE"}, "vehicle_number"),  # a number with an e-bike
        ({"vehicle_number": "12"}, "vehicle_number"),
        ({"emergency_contact_phone": "12345"}, "emergency_contact_phone"),
        ({"preferred_store_id": 999999}, "preferred_store_id"),
        ({"full_name": " "}, "full_name"),
    ],
)
def test_register_validation_errors(client_for, store, overrides, field):
    response = client_for(UserFactory()).post(REGISTER, payload(store, **overrides), format="json")
    assert response.status_code == 400
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    assert field in response.json()["error"]["details"]


def test_register_refuses_own_number_as_emergency_contact(client_for, store):
    user = UserFactory(phone="+919811122233")
    response = client_for(user).post(
        REGISTER, payload(store, emergency_contact_phone="+919811122233"), format="json"
    )
    assert response.status_code == 400
    assert "emergency_contact_phone" in response.json()["error"]["details"]


def test_register_twice_is_409(client_for, store):
    rider = RiderFactory()
    response = client_for(rider.user).post(REGISTER, payload(store), format="json")
    assert response.status_code == 409
    assert response.json()["error"]["code"] == "INVALID_STATE_TRANSITION"
    assert response.json()["error"]["details"] == {"rider_status": "PENDING_KYC"}


def test_staff_cannot_register(client_for, store):
    staff = StaffUserFactory(phone="+919811100001")
    response = client_for(staff).post(REGISTER, payload(store), format="json")
    assert response.status_code == 403


@pytest.mark.parametrize(
    ("method", "path"),
    [
        ("get", "/api/v1/rider/stores/"),
        ("post", REGISTER),
        ("get", ME),
        ("patch", ME),
        ("post", DOCS),
        ("put", BANK),
    ],
)
def test_requires_a_token(api_client, method, path):
    response = getattr(api_client, method)(path, {}, format="json")
    assert response.status_code == 401
    assert response.json()["error"]["code"] == "AUTH_REQUIRED"


@pytest.mark.parametrize(("method", "path"), [("get", ME), ("patch", ME), ("put", BANK)])
def test_non_rider_gets_403_with_rider_status(client_for, method, path):
    response = getattr(client_for(UserFactory()), method)(
        path,
        {
            "holder_name": "A B",
            "account_number": "50100123456789",
            "ifsc": "HDFC0001234",
        },
        format="json",
    )
    assert response.status_code == 403
    assert response.json()["error"]["details"] == {"rider_status": "NONE"}


# --------------------------------------------------------------------------- me


def test_me_returns_masked_bank_and_documents(client_for):
    rider = active_rider()
    response = client_for(rider.user).get(ME)
    assert response.status_code == 200
    body = response.json()
    assert body["status"] == "ACTIVE"
    assert body["home_store"]["id"] == rider.home_store_id
    assert body["bank_account"]["account_number_masked"] == "XXXXXX6789"
    assert "50100123456789" not in response.content.decode()
    assert {d["status"] for d in body["documents"]} == {"APPROVED"}
    assert body["photo_url"]
    assert body["photo_url_expires_at"]
    assert body["missing_documents"] == []


def test_me_is_the_callers_own_profile_only(client_for):
    """IDOR: there is no id in the path; another rider's data never appears."""
    mine, theirs = active_rider(), active_rider()
    body = client_for(mine.user).get(ME).json()
    assert body["id"] == mine.pk
    assert body["id"] != theirs.pk


def test_patch_while_pending_changes_any_field(client_for):
    rider = RiderFactory()
    other = DarkStoreFactory()
    response = client_for(rider.user).patch(
        ME,
        {"vehicle_type": "BICYCLE", "vehicle_number": None, "preferred_store_id": other.pk},
        format="json",
    )
    assert response.status_code == 200, response.json()
    rider.refresh_from_db()
    assert rider.vehicle_type == "BICYCLE"
    assert rider.vehicle_number == ""
    assert rider.preferred_store_id == other.pk


def test_patch_switching_to_bicycle_drops_the_vehicle_number(client_for):
    rider = RiderFactory()
    response = client_for(rider.user).patch(ME, {"vehicle_type": "BICYCLE"}, format="json")
    assert response.status_code == 200
    assert response.json()["vehicle_number"] is None


def test_patch_when_active_only_changes_emergency_contact(client_for):
    rider = active_rider()
    client = client_for(rider.user)
    ok = client.patch(ME, {"emergency_contact_name": "Sunita Kumari"}, format="json")
    assert ok.status_code == 200
    assert ok.json()["emergency_contact_name"] == "Sunita Kumari"
    locked = client.patch(ME, {"vehicle_type": "SCOOTER", "full_name": "X Y"}, format="json")
    assert locked.status_code == 400
    assert set(locked.json()["error"]["details"]) == {"vehicle_type", "full_name"}
    # Sending an unchanged locked field is fine.
    same = client.patch(ME, {"vehicle_type": rider.vehicle_type}, format="json")
    assert same.status_code == 200


# --------------------------------------------------------------------------- documents


def upload(client, doc_type, number=None, file=None):
    data = {"doc_type": doc_type, "file": file or jpeg_upload()}
    if number is not None:
        data["number"] = number
    return client.post(DOCS, data, format="multipart")


def test_upload_aadhaar_keeps_only_the_masked_number(client_for):
    rider = RiderFactory()
    response = upload(client_for(rider.user), "AADHAAR_FRONT", "2341 2341 2346")
    assert response.status_code == 201, response.json()
    assert response.json()["doc_number_masked"] == "XXXX XXXX 2346"
    assert response.json()["status"] == "PENDING"
    document = RiderDocument.objects.get(rider=rider, doc_type="AADHAAR_FRONT")
    assert document.number_encrypted == ""  # never stored in full
    assert document.file.name.startswith(f"kyc/{rider.pk}/")


def test_upload_pan_is_encrypted_and_masked(client_for):
    rider = RiderFactory()
    response = upload(client_for(rider.user), "PAN", "abcde1234f")
    assert response.json()["doc_number_masked"] == "ABXXXXXX4F"
    document = RiderDocument.objects.get(rider=rider, doc_type="PAN")
    assert "ABCDE1234F" not in document.number_encrypted
    assert decrypt(document.number_encrypted) == "ABCDE1234F" == document.number()


def test_upload_strips_metadata(client_for):
    rider = RiderFactory()
    exif = Image.Exif()
    exif[0x010F] = "SecretPhoneMaker"  # Make
    response = upload(client_for(rider.user), "PHOTO", file=jpeg_upload(exif=exif.tobytes()))
    assert response.status_code == 201
    stored = RiderDocument.objects.get(rider=rider, doc_type="PHOTO")
    with default_storage.open(stored.file.name) as handle:
        data = handle.read()
    assert b"SecretPhoneMaker" not in data
    assert Image.open(io.BytesIO(data)).format == "JPEG"


def test_upload_png_is_stored_as_jpeg(client_for):
    rider = RiderFactory()
    response = upload(client_for(rider.user), "PHOTO", file=jpeg_upload("p.png", fmt="PNG"))
    assert response.status_code == 201


@pytest.mark.parametrize(
    ("doc_type", "number", "file", "field"),
    [
        ("AADHAAR_FRONT", "234123412345", None, "number"),
        ("AADHAAR_FRONT", None, None, "number"),
        ("PHOTO", "123", None, "number"),
        ("PHOTO", None, "text", "file"),
        ("PHOTO", None, "gif", "file"),
    ],
)
def test_upload_validation(client_for, doc_type, number, file, field):
    rider = RiderFactory()
    if file == "text":
        from django.core.files.uploadedfile import SimpleUploadedFile

        file = SimpleUploadedFile("x.jpg", b"not an image")
    elif file == "gif":
        file = jpeg_upload("x.gif", fmt="GIF")
    response = upload(client_for(rider.user), doc_type, number, file)
    assert response.status_code == 400
    assert field in response.json()["error"]["details"]


def test_upload_too_large(client_for, settings):
    settings.RIDER_DOCUMENT_MAX_BYTES = 100
    rider = RiderFactory()
    response = upload(client_for(rider.user), "PHOTO")
    assert response.status_code == 400
    assert response.json()["error"]["details"]["file"] == ["The image must be 1 MB or smaller."]


def test_upload_document_not_needed_for_the_vehicle(client_for):
    rider = RiderFactory(vehicle_type="BICYCLE", vehicle_number="")
    response = upload(client_for(rider.user), "DL", "HR0620190012345")
    assert response.status_code == 400
    assert "doc_type" in response.json()["error"]["details"]


def test_approved_document_cannot_be_replaced(client_for):
    rider = RiderFactory()
    RiderDocumentFactory(rider=rider, doc_type="PAN", status=DocumentStatus.APPROVED)
    response = upload(client_for(rider.user), "PAN", "ABCDE1234F")
    assert response.status_code == 409
    assert response.json()["error"]["details"] == {"doc_type": "PAN", "status": "APPROVED"}


def test_replacing_a_rejected_document_goes_back_to_review_and_deletes_the_old_file(
    client_for, django_capture_on_commit_callbacks
):
    rider = RiderFactory()
    old = RiderDocumentFactory(
        rider=rider, doc_type="PHOTO", status=DocumentStatus.REJECTED, review_note="Blurred"
    )
    old_name = old.file.name
    with django_capture_on_commit_callbacks(execute=True):
        response = upload(client_for(rider.user), "PHOTO")
    assert response.status_code == 201
    assert response.json()["status"] == "PENDING"
    assert response.json()["review_note"] == ""
    assert RiderDocument.objects.filter(rider=rider).count() == 1
    assert not default_storage.exists(old_name)


def test_rejected_rider_resubmits_when_nothing_is_missing(client_for):
    rider = RiderFactory(status=RiderStatus.REJECTED, rejection_reason="PAN unreadable")
    add_documents(rider, DocumentStatus.PENDING)
    add_bank(rider)
    RiderDocument.objects.filter(rider=rider, doc_type="PAN").update(status=DocumentStatus.REJECTED)
    client = client_for(rider.user)
    assert client.get(ME).json()["missing_documents"] == ["PAN"]
    response = upload(client, "PAN", "ABCDE1234F")
    assert response.status_code == 201
    rider.refresh_from_db()
    assert rider.status == RiderStatus.PENDING_KYC
    assert rider.rejection_reason == ""
    assert rider.submitted_at is not None
    assert client.get(ME).json()["ready_for_review"] is True


def test_active_rider_replaces_a_rejected_document_and_stays_active(client_for):
    """api-requests #25: ops reject one document of an ACTIVE rider."""
    rider = active_rider()
    RiderDocument.objects.filter(rider=rider, doc_type="DL").update(
        status=DocumentStatus.REJECTED, review_note="Expired"
    )
    response = upload(client_for(rider.user), "DL", "HR0620190012345")
    assert response.status_code == 201
    assert response.json()["status"] == "PENDING"
    rider.refresh_from_db()
    assert rider.status == RiderStatus.ACTIVE


# --------------------------------------------------------------------------- bank


def test_bank_account_is_encrypted_and_masked(client_for):
    rider = RiderFactory()
    response = client_for(rider.user).put(
        BANK,
        {
            "holder_name": "Ravi  Kumar",
            "account_number": "5010 0123 4567 89",
            "ifsc": "hdfc0001234",
            "upi_id": "",
        },
        format="json",
    )
    assert response.status_code == 200, response.json()
    assert response.json()["account_number_masked"] == "XXXXXX6789"
    assert response.json()["upi_id"] is None
    assert response.json()["holder_name"] == "Ravi Kumar"
    rider.refresh_from_db()
    assert "50100123456789" not in rider.bank_account_number_encrypted
    assert rider.bank_account_number() == "50100123456789"
    assert rider.ifsc == "HDFC0001234"
    # The change is in the rider's history (ciphertext only).
    assert rider.history.count() >= 2


def test_bank_account_validation(client_for):
    rider = RiderFactory()
    response = client_for(rider.user).put(
        BANK, {"holder_name": "R", "account_number": "12", "ifsc": "X"}, format="json"
    )
    assert response.status_code == 400
    assert set(response.json()["error"]["details"]) == {"holder_name", "account_number", "ifsc"}


def test_bank_completes_a_pending_application(client_for):
    rider = RiderFactory()
    add_documents(rider, DocumentStatus.PENDING)
    response = client_for(rider.user).put(
        BANK,
        {"holder_name": "Ravi Kumar", "account_number": "50100123456789", "ifsc": "HDFC0001234"},
        format="json",
    )
    assert response.status_code == 200
    assert Rider.objects.get(pk=rider.pk).submitted_at is not None


def test_home_store_has_its_position(client_for):
    """api-requests #40."""
    rider = active_rider()
    home = client_for(rider.user).get(ME).json()["home_store"]
    assert home["lat"] == pytest.approx(28.45)
    assert home["lng"] == pytest.approx(77.05)


def test_unregister_device(make_auth_client):
    from apps.accounts.models import Device

    user, other = UserFactory(), UserFactory()
    client = make_auth_client(user)
    body = {"fcm_token": "tok-1", "app": "rider", "platform": "android", "app_version": "1.0.0"}
    client.post("/api/v1/me/devices/", body, format="json")
    make_auth_client(other).post(
        "/api/v1/me/devices/", {**body, "fcm_token": "tok-2"}, format="json"
    )
    assert (
        client.delete("/api/v1/me/devices/", {"fcm_token": "tok-1"}, format="json").status_code
        == 204
    )
    # Another user's token is never touched (IDOR), and an unknown one is fine.
    assert (
        client.delete("/api/v1/me/devices/", {"fcm_token": "tok-2"}, format="json").status_code
        == 204
    )
    assert (
        client.delete("/api/v1/me/devices/", {"fcm_token": "nope"}, format="json").status_code
        == 204
    )
    assert Device.objects.get(fcm_token="tok-1").is_active is False
    assert Device.objects.get(fcm_token="tok-2").is_active is True
    assert client.delete("/api/v1/me/devices/", {}, format="json").status_code == 400
    assert make_auth_client(user).delete("/api/v1/me/devices/").status_code == 400
    from rest_framework.test import APIClient

    assert (
        APIClient().delete("/api/v1/me/devices/", {"fcm_token": "x"}, format="json").status_code
        == 401
    )
