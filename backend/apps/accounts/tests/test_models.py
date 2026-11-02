"""Custom User (07 §2.1): phone users for the apps, email users for staff, auth_id reserved."""

import pytest
from django.contrib.auth import authenticate, get_user_model
from django.core.exceptions import ValidationError
from django.db import IntegrityError
from django.test import RequestFactory

from apps.accounts.tests.factories import UserFactory

User = get_user_model()

pytestmark = pytest.mark.django_db


class TestCreateUser:
    def test_phone_only_customer(self):
        user = User.objects.create_user(phone="+919876543210")
        assert user.pk is not None
        assert user.email is None
        assert user.auth_id is None
        assert not user.has_usable_password()
        assert not user.is_staff
        assert not user.is_superuser
        assert user.is_active
        assert not user.marketing_opt_in
        assert user.deleted_at is None
        assert str(user) == "+919876543210"

    def test_many_phone_only_users_have_null_emails(self):
        User.objects.create_user(phone="+919876543210")
        User.objects.create_user(phone="+919876543211", email="  ")
        assert User.objects.filter(email__isnull=True).count() == 2

    def test_needs_phone_or_email(self):
        with pytest.raises(ValueError, match="phone number or an email"):
            User.objects.create_user()
        with pytest.raises(ValueError, match="phone number or an email"):
            User.objects.create_user(phone=" ", email="")

    def test_email_user_with_password(self):
        user = User.objects.create_user(email=" Ops.Lead@Jivo.TEST ", password="a-strong-pass-1")
        assert user.email == "ops.lead@jivo.test"
        assert user.phone is None
        assert user.check_password("a-strong-pass-1")
        assert str(user) == "ops.lead@jivo.test"

    def test_str_falls_back_to_id(self):
        user = UserFactory()
        user.phone = None
        assert str(user) == f"User {user.pk}"


class TestCreateSuperuser:
    def test_superuser(self):
        admin = User.objects.create_superuser(email="root@jivo.test", password="a-strong-pass-1")
        assert admin.is_staff
        assert admin.is_superuser
        assert admin.has_usable_password()

    @pytest.mark.parametrize(
        ("email", "password"), [("", "a-strong-pass-1"), ("root@jivo.test", "")]
    )
    def test_requires_email_and_password(self, email, password):
        with pytest.raises(ValueError, match="email address and a password"):
            User.objects.create_superuser(email=email, password=password)

    def test_cannot_downgrade_flags(self):
        with pytest.raises(ValueError, match="is_staff=True"):
            User.objects.create_superuser(
                email="root@jivo.test", password="a-strong-pass-1", is_staff=False
            )

    def test_createsuperuser_command(self, monkeypatch):
        from django.core.management import call_command

        monkeypatch.setenv("DJANGO_SUPERUSER_PASSWORD", "a-strong-pass-1")
        call_command("createsuperuser", "--noinput", "--email", "cli@jivo.test")
        admin = User.objects.get(email="cli@jivo.test")
        assert admin.is_superuser
        assert admin.check_password("a-strong-pass-1")


class TestUniqueness:
    def test_phone_is_unique(self):
        User.objects.create_user(phone="+919876543210")
        with pytest.raises(IntegrityError):
            User.objects.create_user(phone="+919876543210")

    def test_email_is_unique_case_insensitively(self):
        User.objects.create_user(email="a@jivo.test")
        with pytest.raises(IntegrityError):
            User.objects.create_user(email="A@JIVO.TEST")

    def test_auth_id_is_unique_when_set_and_blank_becomes_null(self):
        first = UserFactory(auth_id="jivo-auth-1")
        second = UserFactory(auth_id="")
        third = UserFactory(auth_id=None)
        assert first.auth_id == "jivo-auth-1"
        assert second.auth_id is None
        assert third.auth_id is None
        with pytest.raises(IntegrityError):
            UserFactory(auth_id="jivo-auth-1")


class TestValidation:
    @pytest.mark.parametrize("phone", ["+919876543210", "+14155550123", "+4420791234"])
    def test_valid_phones(self, phone):
        UserFactory.build(phone=phone).full_clean(exclude=["password"])

    @pytest.mark.parametrize(
        "phone", ["9876543210", "+09876543210", "+91 98765 43210", "+91987654321012345"]
    )
    def test_invalid_phones(self, phone):
        with pytest.raises(ValidationError) as excinfo:
            UserFactory.build(phone=phone).full_clean(exclude=["password"])
        assert "phone" in excinfo.value.message_dict

    def test_clean_normalises_blank_identifiers(self):
        user = UserFactory.build(phone="+919876543210", email="", auth_id="  ")
        user.full_clean(exclude=["password"])
        assert user.email is None
        assert user.auth_id is None


class TestStaffLogin:
    """Staff authenticate with email + password (Django sessions) until Jivo Auth (D-04).
    django-axes needs the request on every authenticate() call."""

    @staticmethod
    def login(username, password):
        return authenticate(
            RequestFactory().post("/admin/login/"), username=username, password=password
        )

    def test_email_login_is_case_insensitive(self):
        user = User.objects.create_user(
            email="store.manager@jivo.test", password="a-strong-pass-1", is_staff=True
        )
        assert self.login("Store.Manager@JIVO.test", "a-strong-pass-1") == user

    def test_wrong_password_and_phone_users_cannot_password_login(self):
        User.objects.create_user(email="x@jivo.test", password="a-strong-pass-1")
        User.objects.create_user(phone="+919876543210")
        assert self.login("x@jivo.test", "wrong-pass") is None
        assert self.login("+919876543210", "") is None
        assert self.login(None, "a-strong-pass-1") is None
