"""`jivo-loadtest`: run the Locust load test with the safety checks, or inspect the plan.

    uv run jivo-loadtest run --host https://<staging-api> --profile target
    uv run jivo-loadtest run --host ... --profile smoke --dry-run
    uv run jivo-loadtest check-host --host ...
    uv run jivo-loadtest profiles
    uv run jivo-loadtest otp-env

The exit code of `run` is Locust's, which the locustfile sets to 1 when a 09 §1 threshold is
breached and 0 when all pass; 2 means the run was refused before it started.
"""

import argparse
import os
import subprocess
import sys
from datetime import UTC, datetime
from pathlib import Path

from jivo_loadtest import profiles
from jivo_loadtest.config import PHONES, RIDER_PHONES, RunConfig
from jivo_loadtest.safety import ALLOWED_HOSTS_ENV, UnsafeTarget, check_target
from jivo_loadtest.thresholds import (
    ERROR_RATE_MAX,
    ORDER_P95_MS,
    READ_P95_MS,
    SERVICEABILITY_P95_MS,
    WRITE_P95_MS,
)

LOCUSTFILE = Path(__file__).resolve().parent.parent / "locustfile.py"
REFUSED = 2


def _parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="jivo-loadtest", description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    run = sub.add_parser("run", help="Run a profile against --host (headless).")
    run.add_argument("--host", required=True, help="Server root, e.g. https://staging-api.x")
    run.add_argument("--profile", default="smoke", choices=sorted(profiles.PROFILES))
    run.add_argument("--results-dir", default="results", help="Where run folders go.")
    run.add_argument("--lat", help="Customer location latitude (default: GGN-01).")
    run.add_argument("--lng", help="Customer location longitude (default: GGN-01).")
    run.add_argument("--online-share", type=float, help="Share of ONLINE checkouts (0.3).")
    run.add_argument("--cancel-share", type=float, help="Share of orders cancelled (0.3).")
    run.add_argument(
        "--riders", type=int, help="Rider sessions instead of the profile's (0: no riders)."
    )
    run.add_argument("--otp", help="The fixed OTP of the load-test numbers (123456).")
    run.add_argument("--app-version", help="X-App-Version to send (1.0.0).")
    run.add_argument(
        "--dry-run", action="store_true", help="Check the host and print the plan; send nothing."
    )

    check = sub.add_parser("check-host", help="Only check that --host is allowed.")
    check.add_argument("--host", required=True)

    sub.add_parser("profiles", help="List the load profiles and thresholds.")

    otp = sub.add_parser("otp-env", help="Print the OTP_TEST_NUMBERS entries for the server.")
    otp.add_argument("--count", type=int, default=len(PHONES), help="Customer numbers (100).")
    otp.add_argument("--riders", type=int, default=0, help="Rider numbers to add (0-100).")
    otp.add_argument("--otp", default=RunConfig.otp)
    return parser


def _env_for(args) -> dict[str, str]:
    env = dict(os.environ)
    env["LOADTEST_PROFILE"] = args.profile
    for flag, name in (
        ("lat", "LOADTEST_LAT"),
        ("lng", "LOADTEST_LNG"),
        ("online_share", "LOADTEST_ONLINE_SHARE"),
        ("cancel_share", "LOADTEST_CANCEL_SHARE"),
        ("riders", "LOADTEST_RIDERS"),
        ("otp", "LOADTEST_OTP"),
        ("app_version", "LOADTEST_APP_VERSION"),
    ):
        value = getattr(args, flag)
        if value is not None:
            env[name] = str(value)
    return env


def locust_argv(host: str, run_dir: Path) -> list[str]:
    return [
        sys.executable,
        "-m",
        "locust",
        "-f",
        str(LOCUSTFILE),
        "--headless",
        "--host",
        host,
        "--stop-timeout",
        "20",
        "--html",
        str(run_dir / "report.html"),
        "--only-summary",
    ]


def describe(profile: profiles.Profile) -> str:
    stages = ", ".join(f"{s.users} by {s.until_s}s" for s in profile.stages)
    gate = (
        f"; must reach {profile.min_orders_per_min:.0f} orders/min"
        if profile.min_orders_per_min
        else ""
    )
    return (
        f"{profile.name}: {profile.description}\n"
        f"  sessions: {stages} ({profile.duration_s}s); buyers {profile.buyers}, "
        f"riders {profile.riders}, "
        f"{profile.orders_per_min:g} orders/min (one per {profile.pacing_s:.0f}s each){gate}"
    )


def thresholds_text() -> str:
    return (
        f"Thresholds (09 §1): serviceability p95 < {SERVICEABILITY_P95_MS} ms; reads p95 < "
        f"{READ_P95_MS} ms; order placement p95 < {ORDER_P95_MS} ms; other writes p95 < "
        f"{WRITE_P95_MS} ms; error rate <= {ERROR_RATE_MAX:.0%} (overall and per endpoint)."
    )


def main(argv: list[str] | None = None) -> int:
    args = _parser().parse_args(argv)

    if args.command == "profiles":
        for profile in profiles.PROFILES.values():
            print(describe(profile))
        print(thresholds_text())
        return 0

    if args.command == "otp-env":
        count = max(1, min(args.count, len(PHONES)))
        riders = max(0, min(args.riders, len(RIDER_PHONES)))
        numbers = (*PHONES[:count], *RIDER_PHONES[:riders])
        print(",".join(f"{phone}:{args.otp}" for phone in numbers))
        return 0

    try:
        target = check_target(args.host)
    except UnsafeTarget as exc:
        print(f"Refused: {exc}", file=sys.stderr)
        return REFUSED
    if args.command == "check-host":
        print(f"OK: {target} is allowed by {ALLOWED_HOSTS_ENV}.")
        return 0

    try:
        profile = profiles.get(args.profile, riders=args.riders)
    except ValueError as exc:
        print(f"Refused: {exc}", file=sys.stderr)
        return REFUSED
    stamp = datetime.now(UTC).strftime("%Y%m%dT%H%M%SZ")
    run_dir = Path(args.results_dir).resolve() / f"{stamp}-{profile.name}"
    argv_ = locust_argv(args.host, run_dir)
    env = _env_for(args)
    env["LOADTEST_RUN_DIR"] = str(run_dir)
    print(f"Target {target} (allowed by {ALLOWED_HOSTS_ENV})")
    print(describe(profile))
    print(thresholds_text())
    if args.dry_run:
        print("Dry run: would run " + " ".join(argv_[1:]))
        return 0
    run_dir.mkdir(parents=True, exist_ok=True)
    print(f"Results: {run_dir}")
    return subprocess.call(argv_, env=env)


if __name__ == "__main__":
    sys.exit(main())
