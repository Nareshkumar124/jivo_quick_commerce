from django.apps import AppConfig
from django.db.models.signals import m2m_changed, post_delete, post_save


class CatalogConfig(AppConfig):
    name = "apps.catalog"
    label = "catalog"
    verbose_name = "Catalog"

    def ready(self) -> None:
        """Catalog cache invalidation (apps.catalog.cache): any catalog change bumps the global
        version; a stock row change bumps its store's version. Both after commit."""
        from apps.catalog import models
        from apps.catalog.cache import invalidate_catalog_on_commit, invalidate_store_on_commit
        from apps.inventory.models import StoreInventory

        for model in (
            models.Category,
            models.Product,
            models.ProductVariant,
            models.ProductImage,
            models.Collection,
            models.CollectionItem,
            models.Banner,
            models.TrendingSearch,
        ):
            uid = f"catalog-cache-{model.__name__}"
            post_save.connect(invalidate_catalog_on_commit, sender=model, dispatch_uid=f"{uid}-s")
            post_delete.connect(invalidate_catalog_on_commit, sender=model, dispatch_uid=f"{uid}-d")
        for through in (models.Collection.stores.through, models.Banner.stores.through):
            m2m_changed.connect(
                invalidate_catalog_on_commit,
                sender=through,
                dispatch_uid=f"catalog-cache-{through.__name__}",
            )

        def store_row_changed(sender, instance, **kwargs) -> None:
            invalidate_store_on_commit(instance.store_id)

        post_save.connect(store_row_changed, sender=StoreInventory, dispatch_uid="inv-cache-s")
        post_delete.connect(store_row_changed, sender=StoreInventory, dispatch_uid="inv-cache-d")
        # Keep a reference: signal receivers are weak by default.
        self._store_row_changed = store_row_changed
