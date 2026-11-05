"""`manage.py loadtest_cleanup [--yes]`: remove the load-test data (T-812).

Without --yes it is a dry run that changes nothing. Staging only: refused unless
LOADTEST_DATA_ALLOWED=true, and always in production. Run it after the load test has stopped
and the Celery queue has drained. Re-runnable: rows kept the first time are retried.
"""

from django.core.management.base import BaseCommand, CommandError

from apps.loadtest import services


class Command(BaseCommand):
    help = (
        "Cancel and delete the load-test customers' orders, delete the customers "
        "(+9190000002xx) and their OTP requests, and reverse the seed's stock top-ups. Dry run "
        "unless --yes. Staging only (LOADTEST_DATA_ALLOWED)."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument("--yes", action="store_true", help="Really delete (default: dry run).")
        parser.add_argument(
            "--keep-stock",
            action="store_true",
            help="Leave the seed's stock top-ups in place.",
        )

    def handle(self, *args, **options) -> None:
        try:
            result = services.cleanup(
                execute=options["yes"], reverse_stock=not options["keep_stock"]
            )
        except services.LoadtestRefused as exc:
            raise CommandError(str(exc)) from exc

        verb = "" if result.executed else "would be "
        out = self.stdout
        if not result.executed:
            out.write("loadtest_cleanup: DRY RUN (nothing changed; add --yes to delete)")
        out.write(
            f"loadtest_cleanup: orders {result.orders_found} found, {result.orders_cancelled} "
            f"{verb}cancelled, {result.orders_deleted} {verb}deleted, "
            f"{len(result.kept_orders)} kept"
        )
        out.write(
            f"loadtest_cleanup: customers {result.users_found} found, {result.users_deleted} "
            f"{verb}deleted, {len(result.kept_users)} kept; OTP requests "
            f"{result.otp_requests_deleted} {verb}deleted"
        )
        out.write(
            f"loadtest_cleanup: stock top-ups {verb}reversed on {result.stock_rows_reversed} "
            f"rows, {result.units_reversed} units"
        )
        for number, reason in sorted(result.kept_orders.items()):
            out.write(self.style.WARNING(f"  kept order {number}: {reason}"))
        for phone, reason in sorted(result.kept_users.items()):
            out.write(self.style.WARNING(f"  kept customer {phone}: {reason}"))
        out.write(self.style.SUCCESS("loadtest_cleanup: done."))
