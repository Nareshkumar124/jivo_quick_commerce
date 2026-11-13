"""`manage.py set_price_tiers --file <json> [--commit] [--yes]`: set variants' volume (slab)
prices, and optionally their MRP and selling price, from a JSON file (ADR 0001; format in
`apps.catalog.price_tiers`). Dry run unless --commit (plus --yes for a database that is not on
this machine). Idempotent. The Jivo Water slabs: `apps/catalog/data/jivo_water_price_tiers.json`.
"""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.management.commands._common import (
    add_commit_arguments,
    check_database,
    finish,
)
from apps.catalog.price_tiers import read_plan, set_price_tiers


class Command(BaseCommand):
    help = (
        "Set variants' volume price tiers (and optionally MRP and selling price) from a JSON "
        "file. Dry run unless --commit."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument("--file", required=True, type=Path, help="The JSON file.")
        add_commit_arguments(parser)

    def handle(self, *args, **options) -> None:
        path: Path = options["file"]
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        check_database(self, options)
        plans, errors = read_plan(path)
        if errors:
            finish(self, errors, committed=False)
        result = set_price_tiers(plans, commit=options["commit"])
        for line in result.lines:
            self.stdout.write(line)
        finish(self, result.errors, result.committed)
        if result.committed:
            self.stdout.write(self.style.SUCCESS("Saved."))
