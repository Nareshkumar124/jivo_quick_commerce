from django.apps import AppConfig
from django.db.models.signals import post_delete, post_save


class StoresConfig(AppConfig):
    name = "apps.stores"
    label = "stores"
    verbose_name = "Stores & serviceability"

    def ready(self) -> None:
        """Serviceability snapshot invalidation (apps.stores.services.store_areas)."""
        from apps.stores.models import DarkStore, StoreTiming
        from apps.stores.services import bump_stores_version

        for model in (DarkStore, StoreTiming):
            uid = f"stores-areas-{model.__name__}"
            post_save.connect(bump_stores_version, sender=model, dispatch_uid=f"{uid}-s")
            post_delete.connect(bump_stores_version, sender=model, dispatch_uid=f"{uid}-d")
