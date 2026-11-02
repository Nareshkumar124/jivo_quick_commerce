"""seed_demo step: app configuration with version policies that never force an update locally."""

from apps.accounts.choices import AppName, Platform
from apps.cms.models import AppConfig, AppVersionPolicy

POLICIES = [
    (
        AppName.CUSTOMER,
        Platform.ANDROID,
        "https://play.google.com/store/apps/details?id=in.jivo.quick",
    ),
    (AppName.CUSTOMER, Platform.IOS, "https://apps.apple.com/in/app/jivo"),
    (
        AppName.RIDER,
        Platform.ANDROID,
        "https://play.google.com/store/apps/details?id=in.jivo.rider",
    ),
]


def seed_app_config(stdout, options) -> None:
    config = AppConfig.load()
    for app, platform, store_url in POLICIES:
        AppVersionPolicy.objects.get_or_create(
            app=app,
            platform=platform,
            defaults={
                "config": config,
                "min_supported_version": "0.0.0",
                "latest_version": "1.0.0",
                "store_url": store_url,
            },
        )
    stdout.write(f"  app config with {config.versions.count()} version policies")
