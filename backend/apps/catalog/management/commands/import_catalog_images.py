"""`manage.py import_catalog_images --manifest <csv> --root <images folder> [--commit]`: create
product and variant images from an image manifest, through the same processing as an admin
upload. Idempotent by the file's SHA-256. Dry run unless --commit (plus --yes for a database that
is not on this machine). Each image is saved on its own: a row that fails while saving is reported
and the others are saved; running the same command again finishes the job. See
apps.catalog.bulk_load."""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.bulk_load import import_images
from apps.catalog.management.commands._common import (
    add_commit_arguments,
    check_database,
    finish,
)


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
        check_database(self, options)
        result = import_images(manifest, root, commit=options["commit"])
        if not result.errors:
            verb = "" if result.committed else "would be "
            summary = (
                f"images: {result.count('create')} {verb}created, "
                f"{result.count('update')} {verb}updated (sort order / alt text), "
                f"{result.count('unchanged')} unchanged, "
                f"{result.count('duplicate')} duplicate row(s) ignored"
            )
            if result.count("existing"):
                summary += f", {result.count('existing')} already added by another run"
            if result.count("failed"):
                summary += f", {result.count('failed')} failed"
            self.stdout.write(summary)
        finish(self, result.errors, result.committed)
        if result.save_errors:
            for error in result.save_errors:
                self.stderr.write(f"  {error}")
            raise CommandError(
                f"{len(result.save_errors)} error(s) while saving: those images were not saved "
                "(and their stored files were removed); the other images were saved. Fix the "
                "problem and run the same command again: images already saved are skipped."
            )
        if result.committed:
            self.stdout.write(self.style.SUCCESS("Saved."))
