from django.apps import AppConfig as DjangoAppConfig
from django.db.models.signals import post_delete, post_save


class CmsConfig(DjangoAppConfig):
    name = "apps.cms"
    label = "cms"
    verbose_name = "CMS & app config"

    def ready(self) -> None:
        from apps.cms.models import FAQ, AppConfig, AppVersionPolicy, Page
        from apps.cms.services import invalidate_app_config, invalidate_faqs, invalidate_page

        for model in (AppConfig, AppVersionPolicy):
            post_save.connect(invalidate_app_config, sender=model, dispatch_uid=f"cms-{model}-save")
            post_delete.connect(
                invalidate_app_config, sender=model, dispatch_uid=f"cms-{model}-delete"
            )
        # P7: cached page and FAQ bodies.
        for model, handler in ((Page, invalidate_page), (FAQ, invalidate_faqs)):
            post_save.connect(handler, sender=model, dispatch_uid=f"cms-{model}-save")
            post_delete.connect(handler, sender=model, dispatch_uid=f"cms-{model}-delete")
