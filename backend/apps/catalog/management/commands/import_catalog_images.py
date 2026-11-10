"""`manage.py import_catalog_images --manifest <csv> --root <images folder> [--commit]`: create
product and variant images from an image manifest, through the same processing as an admin
upload. Idempotent by the file's SHA-256. Dry run unless --commit. See apps.catalog.bulk_load."""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.bulk_load import import_images
from apps.catalog.management.commands._common import add_commit_arguments, finish


class Command(BaseCommand):
    help = (
        "Create ProductImage rows from a manifest CSV (product_slug, sku, sort_order, file, "
        "sha256, alt_text). Dry run unless --commit."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument("--manifest", required=True, type=Path, help="Manifest CSV.")
        parser.add_argument(
            "--root", required=True, type=Path, help="Folder the manifest's `file` paths start in."
        )
        add_commit_arguments(parser)

    def handle(self, *args, **options) -> None:
        manifest: Path = options["manifest"]
        root: Path = options["root"]
        if not manifest.is_file():
            raise CommandError(f"Manifest not found: {manifest}")
        if not root.is_dir():
            raise CommandError(f"Not a folder: {root}")
        result = import_images(manifest, root, commit=options["commit"])
        if not result.errors:
            verb = "" if result.committed else "would be "
            self.stdout.write(
                f"images: {result.count('create')} {verb}created, "
                f"{result.count('update')} {verb}updated (sort order / alt text), "
                f"{result.count('unchanged')} unchanged, "
                f"{result.count('duplicate')} duplicate row(s) ignored"
            )
        finish(self, result.errors, result.committed)
        if result.committed:
            self.stdout.write(self.style.SUCCESS("Saved."))
