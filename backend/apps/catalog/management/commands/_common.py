"""Shared options and output for the catalog loading commands (`apps.catalog.bulk_load`).

Every run first prints which settings and which database it works on (host and name only: never
the database user or password). Saving (`--commit`) to a database that is not on this machine
needs `--yes`, or typing `yes` when the command runs in a terminal, so a command started with the
wrong settings or `.env` cannot quietly write to a shared or remote database.
"""

import ipaddress
import sys
from dataclasses import dataclass

from django.conf import settings
from django.core.management.base import CommandError
from django.db import DEFAULT_DB_ALIAS, connections

DRY_RUN_NOTE = "Dry run: nothing was saved. Run again with --commit to save."
CANCELLED = "Cancelled: nothing was saved."


def add_commit_arguments(parser) -> None:
    """Dry run by default; `--commit` saves. `--dry-run` is accepted to say so explicitly.
    `--yes` confirms a save to a database that is not on this machine."""
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--commit", action="store_true", help="Save the changes (default: dry run).")
    group.add_argument(
        "--dry-run", action="store_true", help="Validate and report only (the default)."
    )
    parser.add_argument(
        "--yes",
        action="store_true",
        help="With --commit: save to a database that is not on this machine without asking.",
    )


@dataclass(frozen=True)
class DatabaseTarget:
    """Where a command writes. Deliberately holds no user or password."""

    settings_module: str
    host: str
    port: str
    name: str

    @property
    def is_local(self) -> bool:
        return is_local_host(self.host)

    def describe(self) -> str:
        where = self.host or "localhost"
        if self.port:
            where = f"{where}:{self.port}"
        return f"{self.name} on {where}"


def is_local_host(host: str) -> bool:
    """Empty (the default socket), `localhost`, a loopback address or a Unix socket folder."""
    host = (host or "").strip().lower()
    if host in ("", "localhost") or host.startswith("/"):
        return True
    try:
        return ipaddress.ip_address(host).is_loopback
    except ValueError:  # any other host name
        return False


def _db_settings() -> dict:
    return connections[DEFAULT_DB_ALIAS].settings_dict


def database_target() -> DatabaseTarget:
    params = _db_settings()
    return DatabaseTarget(
        settings_module=settings.SETTINGS_MODULE or "(not set)",
        host=str(params.get("HOST") or ""),
        port=str(params.get("PORT") or ""),
        name=str(params.get("NAME") or ""),
    )


def _stdin_is_tty() -> bool:
    try:
        return sys.stdin is not None and sys.stdin.isatty()
    except (AttributeError, ValueError):  # replaced or closed stdin
        return False


def _ask(prompt: str) -> str:
    return input(prompt)


def check_database(command, options: dict) -> None:
    """Print the settings module and database, then, for `--commit` to a database that is not
    on this machine, require `--yes` or a typed `yes`. Call before any database work."""
    target = database_target()
    command.stdout.write(f"Settings: {target.settings_module}")
    command.stdout.write(f"Database: {target.describe()}")
    if not options.get("commit") or target.is_local or options.get("yes"):
        return
    if not _stdin_is_tty():
        raise CommandError(
            f"--commit would save to {target.describe()}, which is not on this machine. Check "
            "the settings and database above, then run again with --yes to confirm. Nothing "
            "was saved."
        )
    try:
        answer = _ask(f"Save to {target.describe()}? Type yes to continue: ")
    except (EOFError, KeyboardInterrupt):  # Ctrl-D / Ctrl-C at the prompt
        raise CommandError(CANCELLED) from None
    if answer.strip().lower() != "yes":
        raise CommandError(CANCELLED)


def finish(command, errors: list[str], committed: bool) -> None:
    """Print the row errors and fail the command (exit code 1) when there are any."""
    for error in errors:
        command.stderr.write(f"  {error}")
    if errors:
        raise CommandError(f"{len(errors)} error(s): nothing was saved.")
    if not committed:
        command.stdout.write(command.style.WARNING(DRY_RUN_NOTE))
