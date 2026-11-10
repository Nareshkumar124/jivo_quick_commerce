"""Ratings in the admin (05 §2 "Ratings": order and rider ratings, low-rating filter; P7).

Built on the backend's `orders.Rating` and `apps.orders.ratings.staff_ratings`:
- read-only for everyone, superusers included (ratings are written once by customers through
  `rate_order`; staff never edit or delete them);
- view = `orders.view_rating` (Super Admin, Ops, Support, Store Manager; backend roles);
- the queryset IS `staff_ratings(user)`: the user's stores only (`stores_for`), so a store
  manager never sees another store's rating, and an id outside it is a 404
  (`StoreScopedAdminMixin.get_object`);
- the customer is shown as "Customer <id>" (never `str(user)`, which is the phone) and the
  comment (personal data) only on the detail page; search is by order number only.
"""

from django.contrib import admin
from django.core.exceptions import PermissionDenied
from django.http import Http404
from unfold.admin import ModelAdmin
from unfold.decorators import display

from apps.orders.models import Rating
from apps.orders.ratings import LOW_RATING_MAX_STARS, staff_ratings


class LowRatingFilter(admin.SimpleListFilter):
    """`staff_ratings(low_only=True)`: at most the backend's LOW_RATING_MAX_STARS."""

    title = "rating"
    parameter_name = "low"

    def lookups(self, request, model_admin):
        return [("1", f"Low ({LOW_RATING_MAX_STARS} stars or fewer)")]

    def queryset(self, request, queryset):
        if self.value() == "1":
            return queryset.filter(stars__lte=LOW_RATING_MAX_STARS)
        return queryset


class RatingAdmin(ModelAdmin):
    list_display = ("order_number", "store", "target", "stars", "rider_name", "created_at")
    list_filter = (LowRatingFilter, "target", "stars")
    search_fields = ("order__order_number",)
    search_help_text = "Order number."
    ordering = ("-created_at", "-id")
    list_per_page = 50
    show_full_result_count = False
    fields = (
        "order_number",
        "store",
        "customer",
        "target",
        "rider_name",
        "stars",
        "tags",
        "comment",
        "created_at",
    )
    readonly_fields = fields

    def get_queryset(self, request):
        try:
            return staff_ratings(request.user)
        except PermissionDenied:  # a role without orders.view_rating
            return self.model.objects.none()

    def get_object(self, request, object_id, from_field=None):
        # Refuse a role without the view permission first (403), then an id outside
        # staff_ratings(user) is a 404 (IDOR rule), never a redirect.
        if not self.has_view_permission(request):
            raise PermissionDenied
        obj = super().get_object(request, object_id, from_field)
        if obj is None:
            raise Http404("No such record.")
        return obj

    def has_add_permission(self, request, obj=None) -> bool:
        return False

    def has_change_permission(self, request, obj=None) -> bool:
        return False

    def has_delete_permission(self, request, obj=None) -> bool:
        return False

    @display(description="Order", ordering="order__order_number")
    def order_number(self, obj):
        return obj.order.order_number

    @display(description="Store")
    def store(self, obj):
        return obj.order.store.code

    @display(description="Customer")
    def customer(self, obj):
        return f"Customer {obj.user_id}"

    @display(description="Rider")
    def rider_name(self, obj):
        if obj.rider_id is None:
            return "-"
        return getattr(obj.rider, "full_name", "") or f"Rider {obj.rider_id}"


def register(site=admin.site) -> bool:
    """Register the ratings admin on `site` (idempotent)."""
    if site.is_registered(Rating):
        return False
    site.register(Rating, RatingAdmin)
    return True
