"""`manage.py simulate_rider`: sends location pings along a straight route, as the rider app
would (local and staging testing of tracking, auto-offline and later dispatch; 06 §5, P5/P6).

    uv run python manage.py simulate_rider --phone +919000000002 --to 28.4595,77.0266

The rider must be ACTIVE; `--go-online` starts a shift at the home store first. Points go
through the same service as `POST /rider/locations/`. Refused where seed_demo is refused.
"""

import time
from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand, CommandError
from django.utils import timezone

from apps.accounts.models import User
from apps.core.exceptions import ApiError
from apps.delivery.services import shifts


def _pair(value: str) -> tuple[float, float]:
    try:
        lat, lng = (float(part) for part in value.split(","))
    except ValueError:
        raise CommandError(f"Expected LAT,LNG, got {value!r}.") from None
    return lat, lng


class Command(BaseCommand):
    help = "Send rider location pings along a straight route (testing only)."

    def add_arguments(self, parser) -> None:
        parser.add_argument("--phone", required=True, help="The rider's login phone (E.164).")
        parser.add_argument("--to", required=True, help="Destination LAT,LNG.")
        parser.add_argument("--from", dest="start", help="Start LAT,LNG (default: last position).")
        parser.add_argument("--steps", type=int, default=20)
        parser.add_argument("--interval", type=float, default=5.0, help="Seconds between pings.")
        parser.add_argument("--go-online", action="store_true", help="Start a shift first.")

    def handle(self, *args, **options) -> None:
        if not settings.SEED_DEMO_ALLOWED:
            raise CommandError("simulate_rider is disabled in this environment.")
        user = User.objects.filter(phone=options["phone"]).first()
        if user is None or not hasattr(user, "rider_profile"):
            raise CommandError("No rider with that phone.")
        rider = user.rider_profile
        store = rider.home_store
        try:
            if options["go_online"]:
                if store is None:
                    raise CommandError("The rider has no home store.")
                shifts.start_shift(user, lat=store.location.y, lng=store.location.x)
            if options["start"]:
                start = _pair(options["start"])
            else:
                last = shifts.latest_location(rider) or {}
                start = (last.get("lat"), last.get("lng"))
                if start[0] is None:
                    start = (store.location.y, store.location.x)
            end = _pair(options["to"])
            steps = max(1, options["steps"])
            for step in range(1, steps + 1):
                fraction = step / steps
                point = {
                    "lat": start[0] + (end[0] - start[0]) * fraction,
                    "lng": start[1] + (end[1] - start[1]) * fraction,
                    "accuracy": 8.0,
                    "speed": 5.5,
                    "heading": None,
                    "recorded_at": timezone.now() + timedelta(microseconds=step),
                    "is_mocked": False,
                }
                result = shifts.ingest_locations(user, [point])
                self.stdout.write(
                    f"ping {step}/{steps}: {point['lat']:.6f},{point['lng']:.6f} {result}"
                )
                if step < steps and options["interval"] > 0:
                    time.sleep(options["interval"])
        except ApiError as exc:
            raise CommandError(f"{exc.error_code}: {exc.message}") from None
        self.stdout.write(self.style.SUCCESS("simulate_rider: done."))
