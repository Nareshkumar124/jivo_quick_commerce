from django.urls import path

from apps.catalog import views

urlpatterns = [
    path("home/", views.HomeView.as_view(), name="home"),
    path("categories/", views.CategoryTreeView.as_view(), name="category-tree"),
    path("products/", views.ProductListView.as_view(), name="product-list"),
    path("products/<str:id_or_slug>/", views.ProductDetailView.as_view(), name="product-detail"),
    path("search/", views.SearchView.as_view(), name="search"),
    path("search/suggest/", views.SearchSuggestView.as_view(), name="search-suggest"),
    path(
        "collections/<slug:slug>/",
        views.CollectionDetailView.as_view(),
        name="collection-detail",
    ),
]
