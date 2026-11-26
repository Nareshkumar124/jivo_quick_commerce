"""`manage.py import_pincode_boundaries [--file <geojson>] [--commit] [--source <label>]`

ADR 0004 §1: load pincode outlines into `stores.PincodeBoundary`. A dry run by default: it
reports what would change and saves nothing. `--commit` saves. Idempotent. Without `--file` it
loads the bundled Delhi file (`apps/stores/data/pincodes_delhi.geojson`, see the README there).
"""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.stores.boundaries import (
    DEFAULT_FILE,
    BoundaryFileError,
    import_pincode_boundaries,
    read_features,
)

SHOW_SKIPPED = 10


class Command(BaseCommand):
    help = "Load pincode outlines from a GeoJSON file (dry run unless --commit)."

    def add_arguments(self, parser):
        parser.add_argument(
            "--file",
            default=str(DEFAULT_FILE),
            help="GeoJSON FeatureCollection; each feature has a `pincode` property. Default: "
            "the bundled Delhi file.",
        )
        parser.add_argument("--commit", action="store_true", help="Save (default: dry run).")
        parser.add_argument(
            "--source", help="Label saved on each outline (default: each feature's `source`)."
        )

    def handle(self, *args, **options):
        path = Path(options["file"])
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        try:
            features = read_features(path)
        except (BoundaryFileError, ValueError) as error:
            raise CommandError(f"{path.name}: {error}") from error
        commit = options["commit"]
        result = import_pincode_boundaries(features, commit=commit, source=options["source"])
        verb = "Saved" if commit else "Dry run, nothing saved"
        self.stdout.write(
            f"{verb}: {result.read} features read; "
            f"{'added' if commit else 'would add'} {len(result.created)}, "
            f"{'updated' if commit else 'would update'} {len(result.updated)}, "
            f"unchanged {len(result.unchanged)}, skipped {len(result.skipped)}."
        )
        for number, reason in result.skipped[:SHOW_SKIPPED]:
            self.stdout.write(f"  skipped feature {number}: {reason}")
        if len(result.skipped) > SHOW_SKIPPED:
            self.stdout.write(f"  ... and {len(result.skipped) - SHOW_SKIPPED} more skipped")
        if not commit and (result.created or result.updated):
            self.stdout.write("Run again with --commit to save.")
