"""Load the launch policy pages (terms, privacy, refund-policy, delivery-policy, contact,
delete-account).

    manage.py load_legal_pages [--base-url https://quick.jivo.in] [--dry-run]

Upserts the published `cms.Page` rows from `apps/cms/legal_pages.py` (the text of
`docs/legal/policies.md`). With `--base-url`, also sets `AppConfig` support phone/email, the
terms/privacy/refund URLs (`<base>/legal/<slug>/`) and `terms_version`. Idempotent and safe in
production: it creates no demo data and touches no other rows.

Warning: re-running overwrites admin edits to these six pages (title, body, published flag).
Edit `apps/cms/legal_pages.py` instead, or do not re-run after editing them in the admin.
"""

from urllib.parse import urlsplit

from django.core.management.base import BaseCommand, CommandError

from apps.cms.services import load_legal_pages


def _base_url(value: str) -> str:
    parts = urlsplit(value.strip())
    if parts.scheme != "https" or not parts.netloc or parts.query or parts.fragment:
        raise CommandError(
            f"--base-url must be an https URL such as https://quick.jivo.in: {value}"
        )
    return value.strip().rstrip("/")


class Command(BaseCommand):
    help = (
        "Create or update the six launch policy pages (and, with --base-url, the app config "
        "links). Re-running overwrites admin edits to those six pages; use --dry-run first."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument(
            "--base-url",
            help="Public site, e.g. https://quick.jivo.in. Also updates AppConfig support "
            "contacts, policy URLs and terms_version.",
        )
        parser.add_argument(
            "--dry-run", action="store_true", help="Print what would change; write nothing."
        )

    def handle(self, *args, **options) -> None:
        base_url = _base_url(options["base_url"]) if options["base_url"] else None
        dry_run = options["dry_run"]
        changes = load_legal_pages(base_url=base_url, dry_run=dry_run)
        for change in changes:
            line = f"  {change.action:<6} {change.target}"
            if change.detail:
                line += f"  ({change.detail})"
            self.stdout.write(line)
        written = sum(change.action != "same" for change in changes)
        if dry_run:
            self.stdout.write(self.style.WARNING(f"Dry run: {written} change(s) not written."))
        else:
            self.stdout.write(self.style.SUCCESS(f"Done: {written} change(s) written."))
