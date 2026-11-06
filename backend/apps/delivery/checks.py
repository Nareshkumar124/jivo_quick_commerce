from django.conf import settings
from django.core.checks import Error, Tags, register


@register(Tags.security, deploy=True)
def check_field_encryption_keys(app_configs, **kwargs):
    """09 §3: staging and production encrypt bank and KYC numbers with their own keys, never a
    key derived from SECRET_KEY. Skipped for CI's dry run on reserved example hosts."""
    from apps.core.crypto import DEPLOYED_ENVIRONMENTS
    from apps.payments.checks import is_dry_run_deployment

    if settings.APP_ENVIRONMENT not in DEPLOYED_ENVIRONMENTS or is_dry_run_deployment():
        return []
    if [key for key in settings.FIELD_ENCRYPTION_KEYS if key.strip()]:
        return []
    return [
        Error(
            "FIELD_ENCRYPTION_KEYS is not set: rider bank and KYC numbers cannot be stored.",
            hint="Set Fernet keys (comma-separated, newest first). See apps.core.crypto.",
            id="delivery.E001",
        )
    ]
