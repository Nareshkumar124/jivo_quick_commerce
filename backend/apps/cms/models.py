from django.core.validators import MaxValueValidator, MinValueValidator, RegexValidator
from django.db import models

from apps.accounts.choices import AppName, Platform
from apps.core.models import TimeStampedModel

SINGLETON_ID = 1

release_version_validator = RegexValidator(
    regex=r"^[0-9]{1,5}(\.[0-9]{1,5}){0,3}$", message='Enter a version such as "1.4.0".'
)


class AppConfig(TimeStampedModel):
    """Global app configuration (07 §2.9), a single row edited in the admin.

    Served by `GET /api/v1/config/app/` and used by the force-update / maintenance guard.
    Per app+platform versions live in `AppVersionPolicy` rows.
    """

    maintenance = models.BooleanField(
        default=False, help_text="Apps show the maintenance screen; the API answers 503."
    )
    maintenance_message = models.TextField(blank=True)
    support_phone = models.CharField(max_length=20, blank=True)
    support_email = models.EmailField(default="support@jivo.in")
    terms_url = models.URLField(default="https://jivo.in/terms")
    privacy_url = models.URLField(default="https://jivo.in/privacy")
    refund_url = models.URLField(default="https://jivo.in/refund-policy")
    terms_version = models.CharField(
        max_length=32,
        default="2026-11-01",
        help_text="Current Terms & Privacy version. Apps send it on login (DPDP consent).",
    )
    payment_window_minutes = models.PositiveSmallIntegerField(
        default=15,
        validators=[MinValueValidator(5), MaxValueValidator(60)],
        help_text=(
            "Minutes an online order waits for payment before it fails and its stock is "
            "released (01 §5, 08 T4). Applies to orders placed after a change."
        ),
    )
    rider_location_active_interval_seconds = models.PositiveSmallIntegerField(default=10)
    rider_location_idle_interval_seconds = models.PositiveSmallIntegerField(default=30)
    feature_flags = models.JSONField(
        default=dict, blank=True, help_text='Name -> true/false, e.g. {"new_home": true}.'
    )

    class Meta:
        verbose_name = "app configuration"
        verbose_name_plural = "app configuration"
        constraints = [
            models.CheckConstraint(
                condition=models.Q(id=SINGLETON_ID), name="cms_appconfig_singleton"
            )
        ]

    def __str__(self) -> str:
        return "App configuration"

    def save(self, *args, **kwargs) -> None:
        self.pk = SINGLETON_ID
        if self._state.adding:
            # Saving a new instance while the row exists updates that row (keep created_at).
            created_at = (
                AppConfig.objects.filter(pk=SINGLETON_ID)
                .values_list("created_at", flat=True)
                .first()
            )
            if created_at is not None:
                self.created_at = created_at
                self._state.adding = False
        super().save(*args, **kwargs)

    @classmethod
    def load(cls) -> "AppConfig":
        config, _ = cls.objects.get_or_create(pk=SINGLETON_ID)
        return config


class AppVersionPolicy(TimeStampedModel):
    """Force-update policy for one app on one platform (03 §2.1, 04 §2.1)."""

    config = models.ForeignKey(AppConfig, on_delete=models.CASCADE, related_name="versions")
    app = models.CharField(max_length=16, choices=AppName.choices)
    platform = models.CharField(max_length=16, choices=Platform.choices)
    min_supported_version = models.CharField(
        max_length=32,
        validators=[release_version_validator],
        help_text="Older apps get 426 APP_UPDATE_REQUIRED and a blocking update screen.",
    )
    latest_version = models.CharField(
        max_length=32,
        validators=[release_version_validator],
        help_text="Older apps get a dismissible update prompt.",
    )
    store_url = models.URLField()

    class Meta:
        verbose_name = "app version policy"
        verbose_name_plural = "app version policies"
        constraints = [
            models.UniqueConstraint(fields=["app", "platform"], name="cms_version_app_platform")
        ]

    def __str__(self) -> str:
        return f"{self.app} / {self.platform}"
