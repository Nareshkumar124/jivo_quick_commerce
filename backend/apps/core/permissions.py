from django.conf import settings
from rest_framework.permissions import BasePermission


class ApiDocsPermission(BasePermission):
    """/api/schema/ and /api/docs/: public when API_DOCS_PUBLIC (local), else staff only (02 §5).

    Read at request time so the setting can differ per environment and in tests.
    """

    def has_permission(self, request, view) -> bool:
        if settings.API_DOCS_PUBLIC:
            return True
        user = request.user
        return bool(user and user.is_authenticated and user.is_staff)
