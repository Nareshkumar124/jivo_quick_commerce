"""Run settings, read from the environment (the CLI sets them from its flags) so the locustfile
and the CLI agree. Every value has a default that fits the staging server (jqc.jivo.in).

The customer location (`LOADTEST_LAT` / `LOADTEST_LNG`, or `--lat` / `--lng`) must fall inside
the load-test store's service area. The default is the staging store point
(`DEFAULT_LAT`, `DEFAULT_LNG`); for the local demo store GGN-01 pass `GGN01_LAT`, `GGN01_LNG`."""

import os
from dataclasses import dataclass, field
from decimal import Decimal

# The dedicated load-test customers: +919000000200 .. +919000000299 ("+9190000002xx"). The
# backend's `manage.py loadtest_seed` creates them and `loadtest_cleanup` removes them; the
# server must list them in OTP_TEST_NUMBERS (non-production only, D-15).
PHONE_PREFIX = "+919000000"
PHONE_FIRST = 200
MAX_BUYERS = 100
PHONES: tuple[str, ...] = tuple(f"{PHONE_PREFIX}{PHONE_FIRST + i}" for i in range(MAX_BUYERS))

# Load-test riders: +919000000300 .. +919000000399 ("+9190000003xx"), ACTIVE riders whose home
# store is the load-test store, also listed in OTP_TEST_NUMBERS. They go online, upload GPS
# batches, poll for offers and send heartbeats; they never accept an offer.
RIDER_PHONE_FIRST = 300
MAX_RIDERS = 100
RIDER_PHONES: tuple[str, ...] = tuple(
    f"{PHONE_PREFIX}{RIDER_PHONE_FIRST + i}" for i in range(MAX_RIDERS)
)

API = "/api/v1"

# The staging store point (inside its service area): the default customer location.
DEFAULT_LAT = Decimal("28.631878")
DEFAULT_LNG = Decimal("77.128798")
# The seed_demo store GGN-01 (local servers).
GGN01_LAT = Decimal("28.471000")
GGN01_LNG = Decimal("77.044000")


def _env(name: str, default: str) -> str:
    return os.environ.get(name, default).strip() or default


@dataclass(frozen=True)
class RunConfig:
    profile: str = "smoke"
    lat: Decimal = DEFAULT_LAT  # LOADTEST_LAT / --lat
    lng: Decimal = DEFAULT_LNG  # LOADTEST_LNG / --lng
    otp: str = "123456"
    app_version: str = "1.0.0"
    platform: str = "android"
    online_share: float = 0.3  # share of checkouts paid ONLINE (the rest COD)
    cancel_share: float = 0.3  # share of placed orders the customer cancels afterwards
    polls: int = 3  # GET /orders/{id}/ polls per order (the app's fallback polling)
    riders: int | None = None  # overrides the profile's rider sessions when set
    heartbeat_every_s: float = 60.0  # rider app: a heartbeat about every minute while online
    # GET /rider/offers/current/ each interval. Off until the backend's P5 slice 5.3 ships it
    # (it answers 503 "not available yet" before that): LOADTEST_RIDER_OFFER_POLL=false.
    rider_offer_poll: bool = True
    search_terms: tuple[str, ...] = field(
        default=("oil", "olive", "canola", "mustard", "jivo", "seeds", "ghee", "juice")
    )
    results_dir: str = "results"

    @classmethod
    def from_env(cls) -> "RunConfig":
        terms = tuple(t.strip() for t in _env("LOADTEST_SEARCH_TERMS", "").split(",") if t.strip())
        return cls(
            profile=_env("LOADTEST_PROFILE", cls.profile),
            lat=Decimal(_env("LOADTEST_LAT", str(cls.lat))),
            lng=Decimal(_env("LOADTEST_LNG", str(cls.lng))),
            otp=_env("LOADTEST_OTP", cls.otp),
            app_version=_env("LOADTEST_APP_VERSION", cls.app_version),
            online_share=float(_env("LOADTEST_ONLINE_SHARE", str(cls.online_share))),
            cancel_share=float(_env("LOADTEST_CANCEL_SHARE", str(cls.cancel_share))),
            polls=int(_env("LOADTEST_POLLS", str(cls.polls))),
            riders=int(os.environ["LOADTEST_RIDERS"])
            if os.environ.get("LOADTEST_RIDERS")
            else None,
            search_terms=terms or cls().search_terms,
            rider_offer_poll=_env("LOADTEST_RIDER_OFFER_POLL", "true").lower()
            not in {"0", "false", "no", "off"},
            results_dir=_env("LOADTEST_RESULTS_DIR", cls.results_dir),
        )
