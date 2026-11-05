"""Routes under /api/v1/. Each phase includes its apps' URLconfs here."""

from django.urls import include, path

urlpatterns = [
    path("", include("apps.accounts.urls")),  # auth, me, addresses (Phase 1)
    path("", include("apps.cms.urls")),  # config/app (Phase 1)
    path("", include("apps.stores.urls")),  # serviceability, notify-me (Phase 2)
    path("", include("apps.catalog.urls")),  # home, categories, products, search (Phase 2)
    path("", include("apps.cart.urls")),  # cart, coupons (Phase 3)
    path("", include("apps.orders.urls")),  # orders (Phase 3)
    path("", include("apps.payments.urls")),  # payment verify, Razorpay webhook (Phase 3)
    path("", include("apps.delivery.urls")),  # rider app (Phase 5)
    path("", include("apps.support.urls")),  # support tickets (Phase 7)
]
