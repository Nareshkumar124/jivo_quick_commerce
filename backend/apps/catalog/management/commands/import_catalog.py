"""`manage.py import_catalog --dir <folder> [--commit]`: load categories.csv, products.csv and
variants.csv (the admin import format, docs/admin-panel-architecture.md §10) from a folder on the
server. Dry run unless --commit; one transaction; nothing is saved if any row fails; never
deletes. See apps.catalog.bulk_load."""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.bulk_load import import_catalog
from apps.catalog.management.commands._common import add_commit_arguments, finish


class Command(BaseCommand):
    help = (
        "Import categories.csv, products.csv and variants.csv from a folder (upsert by slug/SKU, "
        "never deletes). Dry run unless --commit."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument("--dir", required=True, type=Path, help="Folder with the CSV files.")
        add_commit_arguments(parser)

    def handle(self, *args, **options) -> None:
        directory: Path = options["dir"]
        if not directory.is_dir():
            raise CommandError(f"Not a folder: {directory}")
        result = import_catalog(directory, commit=options["commit"])
        if not any(item.found for item in result.files):
            raise CommandError(f"No categories.csv, products.csv or variants.csv in {directory}")
        errors: list[str] = []
        for item in result.files:
            if not item.found:
                self.stdout.write(f"{item.name}: not found, skipped")
                continue
            self.stdout.write(
                f"{item.name}: {item.new} created, {item.updated} updated, "
                f"{item.skipped} unchanged, {len(item.errors)} error(s)"
            )
            errors.extend(f"{item.name} {error}" for error in item.errors)
        finish(self, errors, result.committed)
        if result.committed:
            self.stdout.write(self.style.SUCCESS("Saved."))
