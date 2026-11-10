"""Locust entry point for the Jivo Quick Commerce load test (T-812). Run it through the CLI:

    uv run jivo-loadtest run --host https://<staging-api> --profile target

Running `locust -f locustfile.py` directly works too, with the same safety checks: a --host is
required and must be listed in LOADTEST_ALLOWED_HOSTS (see jivo_loadtest/safety.py). The profile
comes from LOADTEST_PROFILE (default smoke). See README.md.
"""

import logging
import os
import sys
import time
from pathlib import Path

import gevent
from locust import FastHttpUser, LoadTestShape, between, constant_pacing, events, task
from locust.runners import MasterRunner, WorkerRunner

sys.path.insert(0, str(Path(__file__).resolve().parent))

from jivo_loadtest import profiles, report
from jivo_loadtest.config import PHONES, RIDER_PHONES, RunConfig
from jivo_loadtest.flows import RECORDER, Reply, RiderSession, Session
from jivo_loadtest.safety import UnsafeTarget, check_target
from jivo_loadtest.thresholds import EndpointResult, evaluate

logger = logging.getLogger("jivo_loadtest")

CFG = RunConfig.from_env()
PROFILE = profiles.get(CFG.profile, riders=CFG.riders)
_free_phones = list(PHONES[: PROFILE.buyers])
_free_rider_phones = list(RIDER_PHONES[: PROFILE.riders])


class LocustHttp:
    """`flows.Http` on top of a Locust client: every request is a stats row named after its
    path template, and a status outside `expect` is a failure with the API error code."""

    def __init__(self, user: FastHttpUser) -> None:
        self.user = user

    def request(self, method, path, *, name, json=None, headers=None, expect=(200,)):
        with self.user.client.request(
            method, path, name=name, json=json, headers=headers, catch_response=True
        ) as response:
            body = None
            try:
                body = response.json() if response.text else None
            except ValueError:
                body = None
            reply = Reply(response.status_code, body)
            if response.status_code in expect:
                response.success()
            else:
                response.failure(f"{response.status_code} {reply.error_code or ''}".strip())
            return reply

    def journey_failed(self, name, message):
        self.user.environment.events.request.fire(
            request_type="JOURNEY",
            name=name,
            response_time=0,
            response_length=0,
            exception=RuntimeError(message),
            context={},
        )


class Buyer(FastHttpUser):
    """A logged-in customer (one load-test phone each) placing one order per pacing period."""

    fixed_count = PROFILE.buyers
    wait_time = constant_pacing(PROFILE.pacing_s)

    def on_start(self) -> None:
        if not _free_phones:
            raise RuntimeError("More buyers than load-test phones (+9190000002xx).")
        self.phone = _free_phones.pop(0)
        self.session = Session(LocustHttp(self), CFG, phone=self.phone, pause=gevent.sleep)

    def on_stop(self) -> None:
        _free_phones.append(self.phone)

    @task
    def place_an_order(self) -> None:
        self.session.buyer_journey()


class Rider(FastHttpUser):
    """A load-test rider (one +9190000003xx phone each) on shift: GPS batches at the server's
    interval, offer polling and a heartbeat about once a minute. Never accepts an offer."""

    fixed_count = PROFILE.riders
    # fixed_count 0 would make Locust spawn riders by weight instead: no riders means no class.
    abstract = PROFILE.riders == 0

    def wait_time(self) -> float:
        return self.session.next_wait()

    def on_start(self) -> None:
        if not _free_rider_phones:
            raise RuntimeError("More riders than load-test rider phones (+9190000003xx).")
        self.phone = _free_rider_phones.pop(0)
        self.session = RiderSession(LocustHttp(self), CFG, phone=self.phone, pause=gevent.sleep)

    def on_stop(self) -> None:
        self.session.end_shift()
        _free_rider_phones.append(self.phone)

    @task
    def stay_online(self) -> None:
        self.session.rider_journey()


class Browser(FastHttpUser):
    """An anonymous app session browsing the catalog."""

    weight = 1
    wait_time = between(5, 15)

    def on_start(self) -> None:
        self.session = Session(LocustHttp(self), CFG, pause=gevent.sleep)

    @task
    def browse(self) -> None:
        self.session.browser_journey()


class ProfileShape(LoadTestShape):
    def tick(self):
        return PROFILE.tick(self.get_run_time())


def _refuse(message: str) -> None:
    logger.error("Load test refused: %s", message)
    sys.stderr.write(f"Load test refused: {message}\n")
    sys.stderr.flush()
    os._exit(2)  # before any user starts; an exception here would only be logged


@events.init.add_listener
def _check_safety(environment, **kwargs) -> None:
    if isinstance(environment.runner, MasterRunner | WorkerRunner):
        _refuse("distributed runs are not supported (one phone per buyer); run one process.")
    try:
        check_target(environment.host)
    except UnsafeTarget as exc:
        _refuse(str(exc))


@events.test_start.add_listener
def _start(environment, **kwargs) -> None:
    RECORDER.reset()
    logger.info(
        "Profile %s: %s sessions peak, %s buyers, %s riders, one order per %.0f s each, %s s",
        PROFILE.name,
        PROFILE.peak_users,
        PROFILE.buyers,
        PROFILE.riders,
        PROFILE.pacing_s,
        PROFILE.duration_s,
    )


def collect(environment) -> list[EndpointResult]:
    return [
        EndpointResult(
            method=entry.method,
            name=entry.name,
            requests=entry.num_requests,
            failures=entry.num_failures,
            p95_ms=float(entry.get_response_time_percentile(0.95) or 0),
        )
        for entry in environment.stats.entries.values()
    ]


@events.quitting.add_listener
def _enforce_thresholds(environment, **kwargs) -> None:
    run_seconds = time.monotonic() - RECORDER.started_at
    results = collect(environment)
    orders_per_min = RECORDER.orders_per_min(PROFILE.measure_from_s, run_seconds)
    breaches = evaluate(
        results,
        orders_per_min=orders_per_min,
        min_orders_per_min=PROFILE.min_orders_per_min,
    )
    summary = report.build(
        host=environment.host or "",
        profile=PROFILE,
        results=results,
        breaches=breaches,
        orders_per_min=orders_per_min,
        outcomes=dict(RECORDER.outcomes),
        run_seconds=run_seconds,
    )
    directory = Path(os.environ.get("LOADTEST_RUN_DIR") or Path(CFG.results_dir) / "latest")
    _json_path, md_path = report.write(summary, directory)
    for line in (
        f"Thresholds: {'PASS' if not breaches else 'FAIL'}",
        *(f"  breached: {b}" for b in breaches),
        f"Orders/min (from {PROFILE.measure_from_s} s): {orders_per_min:.1f}",
        f"Summary: {md_path}",
    ):
        logger.info(line)
    environment.process_exit_code = 1 if breaches else 0
