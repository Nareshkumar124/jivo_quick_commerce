"""`manage.py deactivate_skus --csv <file> [--commit]`: deactivate the listed variants (column
`sku`) and every product left with no active variant. Dry run unless --commit. See
apps.catalog.bulk_load."""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.bulk_load import deactivate_variants, read_sku_list
from apps.catalog.management.commands._common import add_commit_arguments, finish


class Command(BaseCommand):
    help = (
        "Deactivate the variants listed in a CSV (column sku) and products left without an "
        "active variant. Dry run unless --commit."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument("--csv", required=True, type=Path, help="CSV with a sku column.")
        add_commit_arguments(parser)

    def handle(self, *args, **options) -> None:
        path: Path = options["csv"]
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        skus, errors = read_sku_list(path)
        if errors:
            finish(self, errors, committed=False)
        result = deactivate_variants(skus, commit=options["commit"])
        verb = "deactivated" if result.committed else "would be deactivated"
        for sku in result.variants:
            self.stdout.write(f"variant {sku}: {verb}")
        for slug in result.products:
            self.stdout.write(f"product {slug}: {verb} (no active variant left)")
        for sku in result.already_inactive:
            self.stdout.write(f"variant {sku}: already inactive")
        for sku in result.not_found:
            self.stdout.write(self.style.WARNING(f"variant {sku}: not found, ignored"))
        self.stdout.write(
            f"variants: {len(result.variants)} {verb}, {len(result.already_inactive)} already "
            f"inactive, {len(result.not_found)} not found; products: {len(result.products)} {verb}"
        )
        finish(self, [], result.committed)
        if result.committed:
            self.stdout.write(self.style.SUCCESS("Saved."))
