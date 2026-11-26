"""Business profile (03 §2.2, 2026-11-26), data step.

1. Seed the default business categories (idempotent: existing slugs are left alone, so admin
   edits survive a re-run).
2. Only sign-ups after this change are asked for the business profile: every user that already
   exists is marked done (`profile_completed_at` = now), so `is_profile_complete` is true for them.

The reverse is intentionally a no-op: 0008's reverse drops the table and columns anyway, and
un-marking users could not tell migrated users from ones who really submitted.
"""

from django.db import migrations
from django.utils import timezone

DEFAULT_CATEGORIES = [
    ("retail-shop", "Retail shop"),
    ("restaurant-cafe", "Restaurant / Café"),
    ("hotel", "Hotel"),
    ("office", "Office"),
    ("hospital-clinic", "Hospital / Clinic"),
    ("school-college", "School / College"),
    ("home-use", "Home use"),
    ("other", "Other"),
]


def forwards(apps, schema_editor):
    BusinessCategory = apps.get_model("accounts", "BusinessCategory")
    User = apps.get_model("accounts", "User")
    for index, (slug, name) in enumerate(DEFAULT_CATEGORIES, start=1):
        BusinessCategory.objects.get_or_create(
            slug=slug, defaults={"name": name, "sort_order": index * 10}
        )
    User.objects.filter(
        profile_completed_at__isnull=True, profile_prompt_skipped_at__isnull=True
    ).update(profile_completed_at=timezone.now())


class Migration(migrations.Migration):
    dependencies = [
        ("accounts", "0008_user_business_profile"),
    ]

    operations = [
        migrations.RunPython(forwards, migrations.RunPython.noop),
    ]
