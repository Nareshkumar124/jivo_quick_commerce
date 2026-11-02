"""TimeStampedModel, exercised through User (the first concrete subclass)."""

from datetime import UTC, datetime

import pytest
from freezegun import freeze_time

from apps.accounts.tests.factories import UserFactory


@pytest.mark.django_db
def test_created_and_updated_timestamps():
    with freeze_time("2026-11-02T10:15:00Z"):
        user = UserFactory()
    assert user.created_at == datetime(2026, 11, 2, 10, 15, tzinfo=UTC)
    assert user.updated_at == user.created_at

    with freeze_time("2026-11-03T08:00:00Z"):
        user.name = "Renamed"
        user.save()
    user.refresh_from_db()
    assert user.created_at == datetime(2026, 11, 2, 10, 15, tzinfo=UTC)
    assert user.updated_at == datetime(2026, 11, 3, 8, 0, tzinfo=UTC)
