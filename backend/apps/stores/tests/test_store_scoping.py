"""`stores_for()` (05 §3) fails closed: P2 code review #2 (a Store Manager in any extra group
used to see every store, and `can_adjust_stock()` relied on it)."""

import pytest
from django.contrib.auth.models import Group

from apps.accounts import roles
from apps.accounts.tests.factories import StaffUserFactory, SuperUserFactory
from apps.inventory.services import can_adjust_stock
from apps.stores.services import grant_store_access, stores_for
from apps.stores.tests.factories import DarkStoreFactory

pytestmark = pytest.mark.django_db


@pytest.fixture
def stores():
    roles.sync_roles()
    return DarkStoreFactory(), DarkStoreFactory()


def _staff(*group_names):
    user = StaffUserFactory()
    for name in group_names:
        group, _ = Group.objects.get_or_create(name=name)
        user.groups.add(group)
    return user


def test_manager_in_an_extra_unknown_group_still_sees_only_their_store(stores):
    own, other = stores
    manager = _staff(roles.STORE_MANAGER, "Newsletter editors")
    grant_store_access(manager, own)
    assert list(stores_for(manager)) == [own]
    assert can_adjust_stock(manager, own)
    assert not can_adjust_stock(manager, other)


@pytest.mark.parametrize("role", sorted(roles.GLOBAL_ROLES))
def test_global_roles_see_every_store(stores, role):
    assert set(stores_for(_staff(role))) == set(stores)


@pytest.mark.parametrize("role", sorted(roles.GLOBAL_ROLES))
def test_a_store_role_keeps_its_scoping_even_with_a_global_role(stores, role):
    """Stricter role wins for mixed global + store roles (PM decision, 2026-11-03)."""
    own, _ = stores
    user = _staff(roles.STORE_STAFF, role)
    grant_store_access(user, own)
    assert list(stores_for(user)) == [own]


def test_unknown_groups_alone_never_widen_access(stores):
    assert list(stores_for(_staff("Some future role"))) == []


def test_superuser_and_inactive(stores):
    assert set(stores_for(SuperUserFactory())) == set(stores)
    inactive = _staff(roles.OPS)
    inactive.is_active = False
    assert list(stores_for(inactive)) == []


def test_every_role_is_classified():
    """A new role must be added to GLOBAL_ROLES or STORE_SCOPED_ROLES deliberately."""
    assert set(roles.ROLE_PERMISSIONS) == roles.GLOBAL_ROLES | roles.STORE_SCOPED_ROLES
    assert not roles.GLOBAL_ROLES & roles.STORE_SCOPED_ROLES


# --------------------------------------------------------------------------- set_accepting_orders


class TestSetAcceptingOrders:
    """Panel store screen: pause / resume orders (actor recorded, caches refreshed)."""

    def test_pause_and_resume(self, django_capture_on_commit_callbacks):
        from django.contrib.admin.models import LogEntry
        from django.core.cache import cache

        from apps.catalog.cache import STORE_VERSION_KEY
        from apps.stores.services import (
            LOG_PAUSED,
            LOG_RESUMED,
            check_serviceability,
            set_accepting_orders,
        )

        store, ops = DarkStoreFactory(), StaffUserFactory()
        key = STORE_VERSION_KEY.format(store_id=store.pk)
        cache.set(key, 1, timeout=None)
        with django_capture_on_commit_callbacks(execute=True):
            assert set_accepting_orders(store, False, actor=ops) is True
        store.refresh_from_db()
        assert store.is_accepting_orders is False
        assert cache.get(key) > 1  # the store's catalog cache is invalidated
        assert check_serviceability(28.45, 77.05)["store"]["is_open"] is False  # snapshot fresh
        assert set_accepting_orders(store, False, actor=ops) is False  # already paused
        assert set_accepting_orders(store, True, actor=ops) is True
        messages = list(
            LogEntry.objects.filter(object_id=str(store.pk))
            .order_by("pk")
            .values_list("user_id", "change_message")
        )
        assert messages == [(ops.pk, LOG_PAUSED), (ops.pk, LOG_RESUMED)]

    def test_requires_an_actor(self):
        from apps.stores.services import set_accepting_orders

        store = DarkStoreFactory()
        with pytest.raises(ValueError, match="acting staff user"):
            set_accepting_orders(store, False, actor=None)
        store.refresh_from_db()
        assert store.is_accepting_orders is True
