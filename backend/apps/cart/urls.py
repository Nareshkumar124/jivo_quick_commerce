from django.urls import path

from apps.cart import views

urlpatterns = [
    path("cart/", views.CartView.as_view(), name="cart"),
    path("cart/items/", views.CartItemListView.as_view(), name="cart-items"),
    path("cart/items/<int:id>/", views.CartItemDetailView.as_view(), name="cart-item-detail"),
    path("cart/coupons/", views.CartCouponListView.as_view(), name="cart-coupons"),
    path("cart/coupon/", views.CartCouponView.as_view(), name="cart-coupon"),
]
