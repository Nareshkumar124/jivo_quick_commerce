from django.contrib import admin
from django.urls import include, path
from drf_spectacular.views import SpectacularJSONAPIView, SpectacularSwaggerView

from apps.core.views import HealthLiveView, HealthReadyView

urlpatterns = [
    # Probes (09 §2). No trailing slash, exactly as documented.
    path("health/live", HealthLiveView.as_view(), name="health-live"),
    path("health/ready", HealthReadyView.as_view(), name="health-ready"),
    # OpenAPI (02 §5): JSON schema and Swagger UI. Staff-only outside local.
    path("api/schema/", SpectacularJSONAPIView.as_view(), name="api-schema"),
    path("api/docs/", SpectacularSwaggerView.as_view(url_name="api-schema"), name="api-docs"),
    path("api/v1/", include("config.api_v1")),
    path("admin/", admin.site.urls),
    path("ops/", include("apps.ops_console.urls")),  # Ops Console (05 §1)
]

# JSON error envelope for /api/ and /health/ paths when DEBUG is off; HTML elsewhere.
handler404 = "apps.core.views.handler404"
handler500 = "apps.core.views.handler500"
