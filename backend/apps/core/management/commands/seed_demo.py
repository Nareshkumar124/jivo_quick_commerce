"""`manage.py seed_demo`: idempotent demo data for local and staging (10 §3).

Each phase appends its seed steps to SEED_STEPS as dotted paths to functions taking
`(stdout, options)` and creating data with get_or_create/update_or_create, so running the
command any number of times leaves the same data. All steps run in one transaction.

Staff passwords come only from SEED_DEMO_STAFF_PASSWORD; `--reset-staff-passwords` applies it to
staff users that already exist.
"""

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.db import transaction
from django.utils.module_loading import import_string

SEED_STEPS: list[str] = [
    # Phase 1: roles (05 §3), staff per role, test customer + fixed-OTP phones, app config
    "apps.accounts.seed.seed_roles",
    "apps.accounts.seed.seed_staff",
    "apps.accounts.seed.seed_test_customers",
    "apps.cms.seed.seed_app_config",
    # Phase 2: demo store GGN-01 (Gurugram polygon), ~20 products, stock through the ledger
    "apps.stores.seed.seed_stores",
    "apps.catalog.seed.seed_catalog",
    "apps.inventory.seed.seed_stock",
]


class Command(BaseCommand):
    help = "Create or update idempotent demo data for manual testing (extended every phase)."

    def add_arguments(self, parser) -> None:
        parser.add_argument(
            "--reset-staff-passwords",
            action="store_true",
            help="Set SEED_DEMO_STAFF_PASSWORD on the seeded staff users that already exist.",
        )

    def handle(self, *args, **options) -> None:
        if not settings.SEED_DEMO_ALLOWED:
            raise CommandError("seed_demo is disabled in this environment (SEED_DEMO_ALLOWED).")

        steps = [import_string(path) for path in SEED_STEPS]
        with transaction.atomic():
            for step in steps:
                self.stdout.write(f"seed_demo: {step.__module__}.{step.__name__}")
                step(self.stdout, options)

        if not steps:
            self.stdout.write("seed_demo: nothing to seed yet (Phase 0).")
        self.stdout.write(self.style.SUCCESS("seed_demo: done."))
