"""Business profile on the complete-profile screen (03 §2.2, user request 2026-11-26):
business categories, PATCH /me/ business fields, Skip, and `is_profile_complete`."""

import importlib
from io import StringIO

import pytest
from django.apps import apps as django_apps
from django.db import connection
from django.test.utils import CaptureQueriesContext
from freezegun import freeze_time

from apps.accounts.models import BusinessCategory
from apps.accounts.seed import BUSINESS_CATEGORIES, seed_business_categories
from apps.accounts.services import auth as auth_service
from apps.accounts.tests.factories import StaffUserFactory, UserFactory
from apps.delivery.tests.factories import RiderFactory

pytestmark = pytest.mark.django_db

ME = "/api/v1/me/"
SKIP = "/api/v1/me/profile-prompt/skip/"
CATEGORIES = "/api/v1/business-categories/"


def error(response, status):
    assert response.status_code == status, response.content
    return response.json()["error"]


@pytest.fixture
def category(db):
    return BusinessCategory.objects.create(name="Test Bakery", slug="test-bakery", sort_order=5)


@pytest.fixture
def new_user(db):
    """A fresh sign-up: no name, has neither submitted nor skipped."""
    return UserFactory(name="", profile_completed_at=None)


class TestBusinessCategories:
    def test_lists_active_only_in_order(self, auth_client):
        BusinessCategory.objects.create(name="Zz Second", slug="zz-second", sort_order=2)
        BusinessCategory.objects.create(name="Aa First", slug="aa-first", sort_order=1)
        BusinessCategory.objects.create(name="Hidden", slug="hidden", is_active=False)
        response = auth_client.get(CATEGORIES)
        assert response.status_code == 200
        body = response.json()
        slugs = [row["slug"] for row in body]
        assert "hidden" not in slugs
        assert slugs.index("aa-first") < slugs.index("zz-second")
        assert set(body[0]) == {"id", "name", "slug"}
        expected = list(
            BusinessCategory.objects.filter(is_active=True)
            .order_by("sort_order", "name")
            .values_list("slug", flat=True)
        )
        assert slugs == expected

    def test_needs_login(self, api_client):
        assert error(api_client.get(CATEGORIES), 401)["code"] == "AUTH_REQUIRED"

    def test_query_count(self, auth_client):
        """One query for the list, whatever its length (on top of the auth/app overhead)."""

        def count(path):
            with CaptureQueriesContext(connection) as ctx:
                assert auth_client.get(path).status_code == 200
            return len(ctx.captured_queries)

        count(CATEGORIES)  # warm caches
        baseline = count(ME)
        listed = count(CATEGORIES)
        BusinessCategory.objects.create(name="Q1", slug="q1")
        BusinessCategory.objects.create(name="Q2", slug="q2")
        assert count(CATEGORIES) == listed <= baseline + 1


class TestSubmit:
    def test_new_user_is_incomplete(self, new_user, make_auth_client):
        body = make_auth_client(new_user).get(ME).json()
        assert body["is_profile_complete"] is False
        assert body["business_category"] is None
        assert body["business_category_name"] is None
        assert body["business_name"] == ""

    def test_submit_with_business(self, new_user, make_auth_client, category):
        with freeze_time("2026-11-26T08:00:00Z"):
            response = make_auth_client(new_user).patch(
                ME,
                {
                    "name": "Asha Verma",
                    "business_category": category.pk,
                    "business_name": "  Asha's Kitchen ",
                },
                format="json",
            )
        assert response.status_code == 200, response.content
        body = response.json()
        assert body["name"] == "Asha Verma"
        assert body["business_category"] == category.pk
        assert body["business_category_name"] == "Test Bakery"
        assert body["business_name"] == "Asha's Kitchen"
        assert body["is_profile_complete"] is True
        new_user.refresh_from_db()
        assert new_user.business_category == category
        assert new_user.profile_completed_at.isoformat() == "2026-11-26T08:00:00+00:00"

    def test_submit_name_only_completes(self, new_user, make_auth_client):
        response = make_auth_client(new_user).patch(ME, {"name": "Ravi"}, format="json")
        assert response.json()["is_profile_complete"] is True
        assert response.json()["business_category"] is None

    def test_other_fields_do_not_complete(self, new_user, make_auth_client):
        response = make_auth_client(new_user).patch(ME, {"marketing_opt_in": True}, format="json")
        assert response.status_code == 200
        assert response.json()["is_profile_complete"] is False

    def test_resending_current_deactivated_category_is_kept(self, user, auth_client, category):
        """Review fix: only switching TO an inactive category is refused."""
        user.business_category = category
        user.save()
        category.is_active = False
        category.save()
        response = auth_client.patch(
            ME,
            {"name": "Asha", "business_category": category.pk, "business_name": "Shop"},
            format="json",
        )
        assert response.status_code == 200, response.content
        assert response.json()["business_category"] == category.pk
        other = BusinessCategory.objects.create(name="Old", slug="old", is_active=False)
        body = error(auth_client.patch(ME, {"business_category": other.pk}, format="json"), 400)
        assert body["details"] == {
            "business_category": ["Choose a business category from the list."]
        }

    def test_inactive_category_rejected(self, new_user, make_auth_client, category):
        category.is_active = False
        category.save()
        response = make_auth_client(new_user).patch(
            ME, {"name": "Ravi", "business_category": category.pk}, format="json"
        )
        body = error(response, 400)
        assert body["code"] == "VALIDATION_ERROR"
        assert body["details"] == {
            "business_category": ["Choose a business category from the list."]
        }
        new_user.refresh_from_db()
        assert new_user.profile_completed_at is None
        assert new_user.name == ""

    def test_unknown_category_and_long_name_rejected(self, auth_client):
        response = auth_client.patch(
            ME, {"business_category": 999999, "business_name": "x" * 121}, format="json"
        )
        details = error(response, 400)["details"]
        assert set(details) == {"business_category", "business_name"}

    def test_clear_business_fields(self, user, auth_client, category):
        user.business_category = category
        user.business_name = "Shop"
        user.save()
        response = auth_client.patch(
            ME, {"business_category": None, "business_name": ""}, format="json"
        )
        assert response.status_code == 200
        user.refresh_from_db()
        assert user.business_category is None
        assert user.business_name == ""

    def test_deleted_category_is_cleared_from_users(self, user, category):
        user.business_category = category
        user.save()
        category.delete()
        user.refresh_from_db()
        assert user.business_category is None

    def test_existing_completion_time_is_kept(self, user, auth_client):
        before = user.profile_completed_at
        auth_client.patch(ME, {"name": "New Name"}, format="json")
        user.refresh_from_db()
        assert user.profile_completed_at == before


class TestSkip:
    def test_skip_is_remembered(self, new_user, make_auth_client):
        with freeze_time("2026-11-26T09:00:00Z"):
            client = make_auth_client(new_user)
            response = client.post(SKIP)
        assert response.status_code == 200
        assert response.json()["is_profile_complete"] is True
        assert response.json()["name"] == ""
        # Remembered: a later read (any device) still says complete.
        assert make_auth_client(new_user).get(ME).json()["is_profile_complete"] is True
        new_user.refresh_from_db()
        assert new_user.profile_prompt_skipped_at.isoformat() == "2026-11-26T09:00:00+00:00"
        assert new_user.profile_completed_at is None

    def test_skip_is_idempotent(self, new_user, make_auth_client):
        with freeze_time("2026-11-26T09:00:00Z"):
            assert make_auth_client(new_user).post(SKIP).status_code == 200
        with freeze_time("2026-11-26T10:00:00Z"):
            response = make_auth_client(new_user).post(SKIP)
        assert response.status_code == 200
        new_user.refresh_from_db()
        assert new_user.profile_prompt_skipped_at.isoformat() == "2026-11-26T09:00:00+00:00"

    def test_skip_after_submit_does_nothing(self, user, auth_client):
        response = auth_client.post(SKIP)
        assert response.status_code == 200
        assert response.json()["is_profile_complete"] is True
        user.refresh_from_db()
        assert user.profile_prompt_skipped_at is None

    def test_submit_after_skip(self, new_user, make_auth_client, category):
        client = make_auth_client(new_user)
        client.post(SKIP)
        response = client.patch(ME, {"business_category": category.pk}, format="json")
        assert response.json()["business_category_name"] == "Test Bakery"
        new_user.refresh_from_db()
        assert new_user.profile_completed_at is not None

    def test_needs_login(self, api_client):
        assert error(api_client.post(SKIP), 401)["code"] == "AUTH_REQUIRED"


class TestRidersAndStaff:
    """Riders and staff never get the customer prompt: always complete."""

    def test_rider_me_is_complete(self, make_auth_client):
        rider = RiderFactory(user__name="", user__profile_completed_at=None)
        body = make_auth_client(rider.user, "rider").get(ME).json()
        assert body["is_profile_complete"] is True
        assert body["rider_status"] != "NONE"

    def test_staff_is_complete(self):
        staff = StaffUserFactory(profile_completed_at=None)
        assert staff.is_profile_complete is True

    def test_rider_app_user_before_registering_is_not_special(self, new_user):
        assert new_user.is_profile_complete is False


class TestDataMigration:
    def test_marks_existing_users_and_seeds_categories(self, new_user):
        skipped = UserFactory(name="", profile_completed_at=None)
        skipped.profile_prompt_skipped_at = skipped.created_at
        skipped.save()
        done = UserFactory()
        done_at = done.profile_completed_at
        migration = importlib.import_module(
            "apps.accounts.migrations.0009_seed_business_categories_mark_existing_users"
        )
        migration.forwards(django_apps, None)
        migration.forwards(django_apps, None)  # idempotent

        new_user.refresh_from_db()
        skipped.refresh_from_db()
        done.refresh_from_db()
        assert new_user.is_profile_complete is True
        assert skipped.profile_completed_at is None  # already done by skipping
        assert done.profile_completed_at == done_at
        slugs = set(BusinessCategory.objects.values_list("slug", flat=True))
        assert {slug for slug, _ in migration.DEFAULT_CATEGORIES} <= slugs
        assert migration.DEFAULT_CATEGORIES == BUSINESS_CATEGORIES  # seed_demo uses the same

    def test_seed_demo_step_is_idempotent(self):
        seed_business_categories(StringIO(), {})
        BusinessCategory.objects.filter(slug="hotel").update(name="Hotel (renamed)")
        seed_business_categories(StringIO(), {})
        assert BusinessCategory.objects.filter(
            slug__in=[s for s, _ in BUSINESS_CATEGORIES]
        ).count() == len(BUSINESS_CATEGORIES)
        assert BusinessCategory.objects.get(slug="hotel").name == "Hotel (renamed)"


def test_anonymise_clears_business_profile(user, category):
    from django.utils import timezone

    user.business_category = category
    user.business_name = "Shop"
    user.deleted_at = timezone.now()
    user.save()
    assert auth_service.anonymise_user(user.pk) is True
    user.refresh_from_db()
    assert user.business_name == ""
    assert user.business_category is None
