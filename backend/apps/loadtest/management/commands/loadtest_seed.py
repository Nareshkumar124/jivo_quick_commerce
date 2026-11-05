"""`manage.py loadtest_seed --store GGN-01`: load-test customers and stock (T-812).

Staging only: refused unless LOADTEST_DATA_ALLOWED=true, and always in production. Idempotent.
See loadtest/README.md for the whole run.
"""

from decimal import Decimal, InvalidOperation

from django.core.management.base import BaseCommand, CommandError

from apps.loadtest import services
from apps.stores.models import DarkStore


def _coordinate(value: str) -> Decimal:
    try:
        return Decimal(value)
    except InvalidOperation as exc:
        raise CommandError(f"Not a coordinate: {value!r}") from exc


class Command(BaseCommand):
    help = (
        "Create the load-test customers (+9190000002xx) with a default address, optionally "
        "ACTIVE load-test riders (+9190000003xx) at the store, and top the store's stock up "
        "for the run. Staging only (LOADTEST_DATA_ALLOWED)."
    )

    def add_arguments(self, parser) -> None:
        parser.add_argument("--store", required=True, help="Store code, e.g. GGN-01.")
        parser.add_argument(
            "--users",
            type=int,
            default=services.MAX_USERS,
            help=f"How many load-test customers (1-{services.MAX_USERS}, default all).",
        )
        parser.add_argument("--lat", type=_coordinate, help="Address latitude (default: store).")
        parser.add_argument("--lng", type=_coordinate, help="Address longitude (default: store).")
        parser.add_argument(
            "--stock-floor",
            type=int,
            default=5000,
            help="Top each sellable stock row up to this many free units (default 5000).",
        )
        parser.add_argument(
            "--riders",
            type=int,
            default=0,
            help=f"ACTIVE load-test riders, home store --store (0-{services.MAX_RIDERS}).",
        )
        parser.add_argument(
            "--approver",
            help="Email of the staff user who approves the riders' KYC (needed with --riders).",
        )
        parser.add_argument(
            "--print-otp-env",
            action="store_true",
            help="Print the OTP_TEST_NUMBERS value that adds the load-test numbers.",
        )

    def handle(self, *args, **options) -> None:
        try:
            services.ensure_allowed()
        except services.LoadtestRefused as exc:
            raise CommandError(str(exc)) from exc
        store = DarkStore.objects.filter(code=options["store"]).first()
        if store is None:
            raise CommandError(f"No store with code {options['store']!r}.")
        if (options["lat"] is None) != (options["lng"] is None):
            raise CommandError("Give both --lat and --lng, or neither.")
        try:
            services.rider_phones(options["riders"])  # range first (ValueError)
            approver = services.resolve_approver(options["approver"]) if options["riders"] else None
            result = services.seed(
                store=store,
                users=options["users"],
                lat=options["lat"],
                lng=options["lng"],
                stock_floor=options["stock_floor"],
                riders=options["riders"],
                approver=approver,
            )
        except (ValueError, services.LoadtestRefused) as exc:
            raise CommandError(str(exc)) from exc

        out = self.stdout
        out.write(
            f"loadtest_seed: users {result.users_created} created, {result.users_existing} "
            f"existing; {result.addresses_created} addresses created"
        )
        out.write(
            f"loadtest_seed: stock at {store.code}: {result.stock_rows_topped_up} rows topped "
            f"up, {result.units_added} units added (reason {services.REASON_TOPUP!r})"
        )
        if options["riders"]:
            out.write(
                f"loadtest_seed: riders {result.riders_created} approved now, "
                f"{result.riders_existing} already ACTIVE (home store {store.code})"
            )
        if not result.point_in_store_area:
            out.write(
                self.style.WARNING(
                    "loadtest_seed: the address point is outside this store's service area; "
                    "orders will fail with NOT_SERVICEABLE."
                )
            )
        if result.missing_otp_numbers:
            out.write(
                self.style.WARNING(
                    f"loadtest_seed: {len(result.missing_otp_numbers)} load-test numbers are not "
                    "in OTP_TEST_NUMBERS; their logins will need a real SMS. Use "
                    "--print-otp-env and restart the web process."
                )
            )
        if options["print_otp_env"]:
            value = services.otp_env_value(options["users"], riders=options["riders"])
            out.write(f"OTP_TEST_NUMBERS={value}")
        out.write(self.style.SUCCESS("loadtest_seed: done."))
