"""Store scoping for the admin and the Ops Console (05 §3, docs/admin-panel-architecture.md §4).

Store Manager and Store Staff see only the stores in their `StaffStoreAccess` rows; every other
role sees all stores. The rule lives in `apps.stores.services.stores_for(user)` (backend); this
module only applies it to querysets and list filters, so a screen never fetches by id and then
checks: the queryset is scoped first, and an object outside it simply does not exist.
"""

from django.contrib import admin
from django.db.models import QuerySet

from apps.stores.models import DarkStore
from apps.stores.services import stores_for


def visible_stores(user) -> QuerySet[DarkStore]:
    return stores_for(user)


def scope_to_stores(queryset: QuerySet, user, field: str = "store") -> QuerySet:
    """`queryset` limited to rows whose `field` is one of the user's stores."""
    return queryset.filter(**{f"{field}__in": stores_for(user)})


class StoreScopedAdminMixin:
    """ModelAdmin mixin: `get_queryset` is limited to the user's stores through `store_field`.

    The change, delete and history views look the object up in this queryset, so another
    store's row answers like a missing one (Django admin: redirect to the index with a
    "doesn't exist" message), and custom views use `get_object_or_404(self.get_queryset(...))`.
    """

    store_field = "store"

    def get_queryset(self, request):
        return scope_to_stores(super().get_queryset(request), request.user, self.store_field)


class ScopedStoreFilter(admin.SimpleListFilter):
    """A store filter that lists only the user's stores (the default related-field filter
    would show every store's name to store-scoped staff)."""

    title = "store"
    parameter_name = "store"
    field = "store"

    def lookups(self, request, model_admin):
        return [
            (str(store.pk), str(store)) for store in stores_for(request.user).only("code", "name")
        ]

    def queryset(self, request, queryset):
        value = self.value()
        if not value:
            return queryset
        if not value.isdigit():
            return queryset.none()
        return queryset.filter(**{f"{self.field}_id": int(value)})
