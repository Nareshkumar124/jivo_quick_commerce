from django.apps import AppConfig
from django.db.models.signals import post_migrate


class AccountsConfig(AppConfig):
    name = "apps.accounts"
    label = "accounts"
    verbose_name = "Accounts"

    def ready(self) -> None:
        from apps.accounts import checks, schema  # noqa: F401 - registers checks and extension
        from apps.accounts.roles import sync_roles

        post_migrate.connect(sync_roles, sender=self, dispatch_uid="accounts-sync-roles")
