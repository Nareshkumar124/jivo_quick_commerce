import pytest

from apps.accounts import roles


@pytest.fixture(autouse=True)
def _roles_synced(db):
    """The seven roles with their Phase 1 permissions, exactly as after `migrate`."""
    roles.sync_roles()
