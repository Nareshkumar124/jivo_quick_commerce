"""Unit tests without the database: validators, masks, encryption, required documents."""

import pytest
from cryptography.fernet import Fernet
from django.core.exceptions import ImproperlyConfigured, ValidationError
from django.test import override_settings

from apps.core import crypto
from apps.delivery import validators as v
from apps.delivery.choices import required_documents


@pytest.mark.parametrize("number", ["2341 2341 2346", "234123412346", "2341-2341-2346"])
def test_aadhaar_accepts_valid_numbers(number):
    assert v.aadhaar_number(number) == "234123412346"


@pytest.mark.parametrize("number", ["234123412345", "134123412346", "23412341234", "abcd"])
def test_aadhaar_rejects_bad_check_digit_prefix_or_length(number):
    with pytest.raises(ValidationError):
        v.aadhaar_number(number)


def test_pan_dl_vehicle_formats():
    assert v.pan_number("abcde1234f") == "ABCDE1234F"
    assert v.driving_licence_number("HR-06 2019 0012345") == "HR0620190012345"
    assert v.vehicle_number("hr 26 dq 1234") == "HR26DQ1234"
    assert v.vehicle_number("22 BH 1234 AA") == "22BH1234AA"
    for func, bad in [
        (v.pan_number, "ABCD1234F"),
        (v.driving_licence_number, "HRABCDEFGHIJ"),
        (v.vehicle_number, "1234"),
    ]:
        with pytest.raises(ValidationError):
            func(bad)


def test_bank_fields():
    assert v.ifsc_code("hdfc0001234") == "HDFC0001234"
    assert v.bank_account_number("5010 0123 4567 89") == "50100123456789"
    assert v.upi_id(" Ravi.Kumar@OkHdfcBank ") == "ravi.kumar@okhdfcbank"
    for func, bad in [
        (v.ifsc_code, "HDFC1001234"),
        (v.bank_account_number, "12345678"),
        (v.upi_id, "no-at-sign"),
    ]:
        with pytest.raises(ValidationError):
            func(bad)


def test_masks():
    assert v.mask_document_number("AADHAAR_FRONT", "234123412346") == "XXXX XXXX 2346"
    assert v.mask_document_number("PAN", "ABCDE1234F") == "ABXXXXXX4F"
    assert v.mask_document_number("DL", "HR0620190012345") == "XXXXXXXXXXX2345"
    assert v.mask_tail("123") == "123"
    assert v.mask_account_number("50100123456789") == "XXXXXX6789"


def test_required_documents_follow_the_vehicle():
    base = ["PHOTO", "AADHAAR_FRONT", "AADHAAR_BACK", "PAN"]
    assert required_documents("BICYCLE") == base
    assert required_documents("E_BIKE") == base
    assert required_documents("SCOOTER") == [*base, "DL", "RC"]


def test_encryption_round_trip_and_key_rotation():
    token = crypto.encrypt("50100123456789")
    assert token
    assert "50100123456789" not in token
    assert crypto.decrypt(token) == "50100123456789"
    assert crypto.encrypt("") == ""
    assert crypto.decrypt("") == ""
    old_key = Fernet.generate_key().decode()
    new_key = Fernet.generate_key().decode()
    with override_settings(FIELD_ENCRYPTION_KEYS=[old_key]):
        old_token = crypto.encrypt("ABCDE1234F")
    with override_settings(FIELD_ENCRYPTION_KEYS=[new_key, old_key]):
        assert crypto.decrypt(old_token) == "ABCDE1234F"  # rotation: old keys still decrypt
    with (
        override_settings(FIELD_ENCRYPTION_KEYS=[new_key]),
        pytest.raises(crypto.DecryptionError),
    ):
        crypto.decrypt(old_token)


def test_encryption_refuses_deployed_environments_without_keys():
    crypto._fernet.cache_clear()
    with (
        override_settings(FIELD_ENCRYPTION_KEYS=[], APP_ENVIRONMENT="production"),
        pytest.raises(ImproperlyConfigured),
    ):
        crypto.encrypt("x")
    with (
        override_settings(FIELD_ENCRYPTION_KEYS=["not-a-key"]),
        pytest.raises(ImproperlyConfigured),
    ):
        crypto.encrypt("x")


def test_deploy_check_requires_keys():
    from apps.delivery.checks import check_field_encryption_keys

    with override_settings(
        APP_ENVIRONMENT="production", FIELD_ENCRYPTION_KEYS=[], ALLOWED_HOSTS=["api.jivo.in"]
    ):
        assert [e.id for e in check_field_encryption_keys(None)] == ["delivery.E001"]
    with override_settings(
        APP_ENVIRONMENT="production", FIELD_ENCRYPTION_KEYS=[], ALLOWED_HOSTS=["api.example.com"]
    ):
        assert check_field_encryption_keys(None) == []  # CI dry run
    with override_settings(APP_ENVIRONMENT="local", FIELD_ENCRYPTION_KEYS=[]):
        assert check_field_encryption_keys(None) == []
