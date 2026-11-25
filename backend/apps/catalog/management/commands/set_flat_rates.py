"""`manage.py set_flat_rates --file <json> [--commit] [--yes]`: give variants one flat rate
(MRP = selling price = rate) and remove their volume price tiers (ADR 0002; format in
`apps.catalog.flat_rates`). Dry run unless --commit (plus --yes for a database that is not on
this machine). Idempotent. Jivo Water: `apps/catalog/data/jivo_water_flat_rates.json`.
"""

from pathlib import Path

from django.core.management.base import BaseCommand, CommandError

from apps.catalog.flat_rates import read_rates, set_flat_rates
from apps.catalog.management.commands._common import (
    add_commit_arguments,
    check_database,
    finish,
)


class Command(BaseCommand):
    help = (
        "Set variants' flat rate (MRP = selling price) and remove their volume price tiers, "
        "from a JSON file. Dry run unless --commit."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument("--file", required=True, type=Path, help="The JSON file.")
        add_commit_arguments(parser)

    def handle(self, *args, **options) -> None:
        path: Path = options["file"]
        if not path.is_file():
            raise CommandError(f"File not found: {path}")
        check_database(self, options)
        plans, errors = read_rates(path)
        if errors:
            finish(self, errors, committed=False)
        result = set_flat_rates(plans, commit=options["commit"])
        for line in result.lines:
            self.stdout.write(line)
        finish(self, result.errors, result.committed)
        if result.committed:
            self.stdout.write(self.style.SUCCESS("Saved."))
