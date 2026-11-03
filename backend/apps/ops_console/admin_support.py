"""Shared admin building blocks (docs/admin-panel-architecture.md §4, §5).

- `add_service_errors()`: show a backend service's `ValidationError` (field -> message dict, see
  `apps.inventory.services`) on a form instead of a 500, mapping service argument names to form
  fields.
- `dry_run()`: run a service inside a transaction that is always rolled back, so a form can be
  validated by the service itself (one source of rules) before the real call. `on_commit`
  callbacks registered inside it (alerts, cache bumps) are discarded with the rollback.
- `ReadOnlyHistoryAdmin`: django-simple-history's history pages, read-only and scoped.
  Stock vanilla `SimpleHistoryAdmin` (a) falls back to the historical record when the object is
  outside `get_queryset()`, which would show another store's history, and (b) accepts a POST on
  the version page that saves the old version through `save_model` ("revert") even when revert
  is disabled in the template. Panel changes go through services, so history is view-only.
- `ImportExportPermissionsMixin`: django-import-export lets any staff user import when the
  `IMPORT_EXPORT_IMPORT_PERMISSION_CODE` setting is absent. Import needs add and change on the
  model; export needs view.
"""

from collections.abc import Callable, Mapping
from typing import Any

from django.contrib.admin.utils import unquote
from django.core.exceptions import PermissionDenied, ValidationError
from django.db import transaction
from django.shortcuts import get_object_or_404
from simple_history.admin import SimpleHistoryAdmin


def add_service_errors(form, error: ValidationError, field_map: Mapping[str, str] | None = None):
    """Attach `error` to `form`: each service key goes to the mapped form field (or the field of
    the same name); anything else becomes a form-wide error."""
    field_map = field_map or {}
    if not hasattr(error, "error_dict"):
        for message in error.messages:
            form.add_error(None, message)
        return
    for key, messages in error.message_dict.items():
        target = field_map.get(key, key)
        if target not in form.fields:
            target = None
        for message in messages:
            form.add_error(target, message)


def dry_run(service: Callable[..., Any], *args, **kwargs) -> Any:
    """Call `service` and roll everything back. Returns its result or raises its error."""
    with transaction.atomic():
        result = service(*args, **kwargs)
        transaction.set_rollback(True)
    return result


class ReadOnlyHistoryAdmin(SimpleHistoryAdmin):
    """History list and version pages for objects the user can see; never a revert."""

    def _visible_or_404(self, request, object_id):
        return get_object_or_404(self.get_queryset(request), pk=unquote(object_id))

    def history_view(self, request, object_id, extra_context=None):
        self._visible_or_404(request, object_id)
        return super().history_view(request, object_id, extra_context)

    def history_form_view(self, request, object_id, version_id, extra_context=None):
        self._visible_or_404(request, object_id)
        if request.method != "GET":
            raise PermissionDenied  # no revert: changes go through the services
        return super().history_form_view(request, object_id, version_id, extra_context)

    def revert_disabled(self, request, obj=None) -> bool:
        return True


class ImportExportPermissionsMixin:
    """For ImportExportModelAdmin / ExportMixin admins."""

    def has_import_permission(self, request) -> bool:
        return self.has_add_permission(request) and self.has_change_permission(request)

    def has_export_permission(self, request) -> bool:
        return self.has_view_permission(request)
