"""Pass/fail thresholds (docs/09 §1) and their evaluation.

09 §1 targets used directly:
- serviceability check p95 < 150 ms
- read endpoints (home, catalog, cart) p95 < 300 ms
- order placement p95 < 800 ms
- 50 orders/min and 500 concurrent sessions "without degradation" (the `target` profile)

Derived here, because 09 §1 names no number for them (change them in one place if Jivo sets
one):
- every other read the apps make while browsing or polling (search, product detail, orders,
  addresses, profile, app config) is held to the read target, 300 ms;
- every other write (OTP, cart changes, payment verify, cancel, address, profile) is held to
  the order-placement target, 800 ms;
- error rate: at most 1% of all requests, and of each endpoint, may fail;
- "without degradation" at 50 orders/min: the hold phase must reach 90% of the target rate.
"""

from dataclasses import dataclass

from jivo_loadtest.config import API

SERVICEABILITY_P95_MS = 150
READ_P95_MS = 300
ORDER_P95_MS = 800
WRITE_P95_MS = 800
ERROR_RATE_MAX = 0.01

HTTP_METHODS = frozenset({"GET", "POST", "PATCH", "PUT", "DELETE"})
SERVICEABILITY = f"{API}/serviceability/"
ORDERS = f"{API}/orders/"


@dataclass(frozen=True)
class EndpointResult:
    method: str
    name: str
    requests: int
    failures: int
    p95_ms: float


@dataclass(frozen=True)
class Breach:
    kind: str  # "p95", "error_rate", "journey", "throughput", "no_traffic"
    subject: str
    actual: float
    limit: float

    def __str__(self) -> str:
        if self.kind == "error_rate":
            return f"{self.subject}: error rate {self.actual:.2%} > {self.limit:.2%}"
        if self.kind == "journey":
            return f"{self.subject}: {self.actual:.0f} journeys failed"
        if self.kind == "throughput":
            return f"{self.subject}: {self.actual:.1f} orders/min < {self.limit:.1f} orders/min"
        if self.kind == "no_traffic":
            return f"{self.subject}: no requests were made"
        return f"{self.subject}: p95 {self.actual:.0f} ms > {self.limit:.0f} ms"


def p95_limit(method: str, name: str) -> tuple[int, str]:
    """(limit in ms, the 09 §1 row it comes from) for one endpoint."""
    method = method.upper()
    if method == "GET" and name == SERVICEABILITY:
        return SERVICEABILITY_P95_MS, "09 §1 serviceability"
    if method == "POST" and name == ORDERS:
        return ORDER_P95_MS, "09 §1 order placement"
    if method == "GET":
        return READ_P95_MS, "09 §1 read endpoints"
    return WRITE_P95_MS, "derived: writes held to the order-placement target"


def evaluate(
    results: list[EndpointResult],
    *,
    error_rate_max: float = ERROR_RATE_MAX,
    orders_per_min: float | None = None,
    min_orders_per_min: float | None = None,
) -> list[Breach]:
    """Every breached threshold. An empty list means the run passed.

    `results` are Locust's stats rows. HTTP rows are checked for p95 and error rate; other rows
    (request type `JOURNEY`, recorded by the flows when a checkout could not go ahead) count
    towards the overall error rate and each one with failures is listed."""
    total = sum(r.requests for r in results)
    if total == 0:
        return [Breach("no_traffic", "run", 0, 1)]
    breaches: list[Breach] = []
    failures = sum(r.failures for r in results)
    if failures / total > error_rate_max:
        breaches.append(Breach("error_rate", "all requests", failures / total, error_rate_max))
    for r in sorted(results, key=lambda r: (r.name, r.method)):
        subject = f"{r.method.upper()} {r.name}"
        if r.method.upper() not in HTTP_METHODS:
            if r.failures:
                breaches.append(Breach("journey", subject, r.failures, 0))
            continue
        if not r.requests:
            continue
        limit, _ = p95_limit(r.method, r.name)
        if r.p95_ms > limit:
            breaches.append(Breach("p95", subject, r.p95_ms, limit))
        if r.failures / r.requests > error_rate_max:
            breaches.append(Breach("error_rate", subject, r.failures / r.requests, error_rate_max))
    if min_orders_per_min is not None and (orders_per_min or 0) < min_orders_per_min:
        breaches.append(
            Breach("throughput", "orders placed", orders_per_min or 0, min_orders_per_min)
        )
    return breaches
