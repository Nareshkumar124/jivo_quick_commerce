"""BUG-0012: dispatch must not depend on a test-only Celery setting."""

from unittest import mock

import pytest

from apps.delivery.services import dispatch


@pytest.mark.django_db(transaction=True)
def test_later_schedules_when_eager_setting_is_absent(settings):
    """BUG-0012: base/local/prod settings don't define CELERY_TASK_ALWAYS_EAGER."""
    del settings.CELERY_TASK_ALWAYS_EAGER
    task = mock.Mock()
    dispatch._later(task, (7,), 30)
    task.apply_async.assert_called_once_with((7,), countdown=30)


def test_later_is_skipped_under_eager_celery(settings):
    settings.CELERY_TASK_ALWAYS_EAGER = True
    task = mock.Mock()
    dispatch._later(task, (7,), 30)
    task.apply_async.assert_not_called()
