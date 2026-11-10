"""Shared options and output for the catalog loading commands (`apps.catalog.bulk_load`)."""

from django.core.management.base import CommandError

DRY_RUN_NOTE = "Dry run: nothing was saved. Run again with --commit to save."


def add_commit_arguments(parser) -> None:
    """Dry run by default; `--commit` saves. `--dry-run` is accepted to say so explicitly."""
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--commit", action="store_true", help="Save the changes (default: dry run).")
    group.add_argument(
        "--dry-run", action="store_true", help="Validate and report only (the default)."
    )


def finish(command, errors: list[str], committed: bool) -> None:
    """Print the row errors and fail the command (exit code 1) when there are any."""
    for error in errors:
        command.stderr.write(f"  {error}")
    if errors:
        raise CommandError(f"{len(errors)} error(s): nothing was saved.")
    if not committed:
        command.stdout.write(command.style.WARNING(DRY_RUN_NOTE))
