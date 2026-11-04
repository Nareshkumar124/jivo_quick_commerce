from django.core.validators import (
    MaxLengthValidator,
    MaxValueValidator,
    MinValueValidator,
    RegexValidator,
)
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


# --------------------------------------------------------------------------- P7: pages and FAQs

PAGE_SLUGS = ("about", "terms", "privacy", "refund-policy")
FAQ_ANSWER_MAX_LENGTH = 2000

_html_tag = RegexValidator(
    regex=r"<\s*[a-zA-Z/!]",
    inverse_match=True,
    message="Plain text only: the apps show this as text, so remove the HTML tags.",
)


class Page(TimeStampedModel):
    """A static page served by `GET /api/v1/pages/{slug}/` (07 §2.9, 03 §2.11).

    `body_html` is sanitised to the allow-list in `apps.cms.html` on every save, so whatever the
    admin's rich-text editor sends, only safe markup is stored and served.
    """

    slug = models.SlugField(
        max_length=60,
        unique=True,
        help_text="URL name the apps ask for: about, terms, privacy, refund-policy.",
    )
    title = models.CharField(max_length=120)
    body_html = models.TextField(
        help_text=(
            "Headings, paragraphs, lists, quotes, bold/italic and https/mailto/tel links only. "
            "Anything else is removed when the page is saved."
        )
    )
    is_published = models.BooleanField(
        default=True, help_text="Unpublished pages answer 404 in the apps."
    )

    class Meta:
        ordering = ["slug"]

    def __str__(self) -> str:
        return self.title

    def save(self, *args, **kwargs) -> None:
        from apps.cms.html import sanitize_html

        self.body_html = sanitize_html(self.body_html)
        update_fields = kwargs.get("update_fields")
        if update_fields is not None and "body_html" not in update_fields:
            kwargs["update_fields"] = [*update_fields, "body_html"]
        super().save(*args, **kwargs)


class FAQ(TimeStampedModel):
    """One question and answer for an app's help screen (07 §2.9).

    The apps group entries by `category`, in display order: categories by their smallest
    `sort_order`, entries by `sort_order`.
    """

    app = models.CharField(max_length=16, choices=AppName.choices)
    category = models.CharField(
        max_length=60, help_text='Heading shown in the app, e.g. "Orders", "Payments & refunds".'
    )
    question = models.CharField(max_length=300, validators=[_html_tag])
    answer = models.TextField(
        validators=[
            _html_tag,
            MaxLengthValidator(FAQ_ANSWER_MAX_LENGTH),
        ],
        help_text="Plain text (no HTML). Line breaks are kept.",
    )
    sort_order = models.PositiveSmallIntegerField(default=0)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name = "FAQ"
        verbose_name_plural = "FAQs"
        ordering = ["app", "sort_order", "id"]
        indexes = [
            models.Index(fields=["app", "is_active", "sort_order"], name="cms_faq_app_order")
        ]

    def __str__(self) -> str:
        return self.question
