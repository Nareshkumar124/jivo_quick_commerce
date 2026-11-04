"""Coupon edits guarded against live usage (T-406c, admin half of the T-304 review minors 3-4):

- the total limit cannot go below the uses already counted (HELD + APPLIED);
- the code is read-only once the coupon is used (and a crafted POST cannot rename it);
- two admins saving the same code at once: the loser gets a form error, not a 500.
"""

from decimal import Decimal

import pytest
from django.urls import reverse

from apps.accounts import roles
from apps.ops_console.tests.helpers import staff_in_role
from apps.promotions import admin as promotions_admin
from apps.promotions.admin import MSG_CODE_LOCKED, MSG_CODE_TAKEN, CouponAdminForm
from apps.promotions.models import Coupon, RedemptionStatus
from apps.promotions.tests.test_admin import (  # noqa: F401 - fixtures
    _roles_synced,
    coupon,
    form_data,
    redemption,
)

pytestmark = pytest.mark.django_db

FLAT = {"discount_type": "FLAT", "max_discount": ""}


@pytest.fixture
def manager(client):
    user = staff_in_role(roles.CATALOG_MANAGER)
    client.force_login(user)
    return user


def change_url(obj) -> str:
    return reverse("admin:promotions_coupon_change", args=[obj.pk])


def test_limit_below_counted_uses_is_refused(client, manager, coupon, redemption):  # noqa: F811
    data = form_data(code="JIVO50", usage_limit_total="0", **FLAT)
    response = client.post(change_url(coupon), data)
    assert response.status_code == 200
    errors = response.context["adminform"].form.errors["usage_limit_total"]
    assert "already been used 1 time(s)" in errors[0]
    coupon.refresh_from_db()
    assert coupon.usage_limit_total is None


def test_limit_equal_to_uses_is_fine(client, manager, coupon, redemption):  # noqa: F811
    response = client.post(change_url(coupon), form_data(usage_limit_total="1", **FLAT))
    assert response.status_code == 302
    coupon.refresh_from_db()
    assert coupon.usage_limit_total == 1


def test_released_uses_do_not_count(client, manager, coupon, redemption):  # noqa: F811
    redemption.status = RedemptionStatus.RELEASED
    redemption.save(update_fields=["status"])
    response = client.post(change_url(coupon), form_data(usage_limit_total="0", **FLAT))
    assert response.status_code == 302


def test_code_is_read_only_once_used(client, manager, coupon, redemption):  # noqa: F811
    response = client.get(change_url(coupon))
    assert "code" not in response.context["adminform"].form.fields
    # A crafted POST with another code: the field is not on the form, so it is ignored.
    response = client.post(change_url(coupon), form_data(code="NEWCODE", **FLAT))
    assert response.status_code == 302
    coupon.refresh_from_db()
    assert coupon.code == "JIVO50"


def test_unused_coupon_code_stays_editable(client, manager, coupon):  # noqa: F811
    response = client.post(change_url(coupon), form_data(code="JIVO60", **FLAT))
    assert response.status_code == 302
    coupon.refresh_from_db()
    assert coupon.code == "JIVO60"


def test_form_refuses_rename_of_used_coupon(coupon, redemption):  # noqa: F811
    """The form-level guard, for any caller that renders `code` anyway."""
    data = form_data(code="OTHER", **FLAT)
    form = CouponAdminForm(data=data, instance=coupon)
    assert not form.is_valid()
    assert MSG_CODE_LOCKED in form.errors["code"]


def test_code_race_becomes_a_form_error(client, manager, monkeypatch):
    """Another admin saved the same code after this form checked it: the database refuses
    (`coupon_code_unique_ci`) and the page shows the code as taken."""
    Coupon.objects.create(
        code="RACE10", title="Rival", discount_type="FLAT", value=Decimal("10.00")
    )
    calls = {"n": 0}
    real = CouponAdminForm.code_taken

    def first_check_misses(self, code):
        calls["n"] += 1
        return False if calls["n"] == 1 else real(self, code)

    monkeypatch.setattr(CouponAdminForm, "code_taken", first_check_misses)
    # Django's model validation checks the constraint too; the race is past both checks.
    real_constraints = Coupon.validate_constraints
    seen = {"n": 0}

    def first_constraints_pass(self, exclude=None):
        seen["n"] += 1
        if seen["n"] > 1:
            real_constraints(self, exclude=exclude)

    monkeypatch.setattr(Coupon, "validate_constraints", first_constraints_pass)
    response = client.post(reverse("admin:promotions_coupon_add"), form_data(code="race10", **FLAT))
    assert response.status_code == 200
    form = response.context["adminform"].form
    assert MSG_CODE_TAKEN in form.errors.get("code", []), (form.errors, calls)
    assert Coupon.objects.filter(code="RACE10").count() == 1


def test_other_integrity_errors_are_not_hidden(monkeypatch):
    from django.db import IntegrityError

    assert promotions_admin._is_code_conflict(IntegrityError("coupon_code_unique_ci")) is True
    assert promotions_admin._is_code_conflict(IntegrityError("coupon_value_positive")) is False
