"""Routes under /api/v1/. Each phase includes its apps' URLconfs here."""

from django.urls import include, path

urlpatterns = [
    path("", include("apps.accounts.urls")),  # auth, me, addresses (Phase 1)
    path("", include("apps.cms.urls")),  # config/app (Phase 1)
]
