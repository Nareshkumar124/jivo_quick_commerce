"""Load profiles. Each is a list of stages for Locust's LoadTestShape: until `until_s` seconds
into the run, ramp to `users` sessions at `spawn_rate` new sessions per second.

Sessions are of two kinds:
- buyers (`buyers`, at most 100, one per load-test phone): log in, browse, fill the cart, check
  out (COD or online), poll the order and sometimes cancel it, one order every `pacing_s`
  seconds each, so all buyers together place `orders_per_min`;
- riders (`riders`, at most 100, one per load-test rider phone): the rider app on shift,
  uploading GPS batches at the server's interval, polling for offers and sending heartbeats;
- browsers (every other session): anonymous app sessions that check serviceability, open home,
  browse the catalog and search, like users who have not logged in yet.
"""

from dataclasses import dataclass, replace

from jivo_loadtest.config import MAX_BUYERS, MAX_RIDERS


@dataclass(frozen=True)
class Stage:
    until_s: int
    users: int
    spawn_rate: float


@dataclass(frozen=True)
class Profile:
    name: str
    description: str
    stages: tuple[Stage, ...]
    buyers: int
    orders_per_min: float
    measure_from_s: int  # the steady state starts here; throughput is measured from here
    min_order_rate: float | None = None  # fraction of orders_per_min the hold must reach
    riders: int = 0

    def __post_init__(self) -> None:
        if not self.stages:
            raise ValueError("a profile needs at least one stage")
        if not 1 <= self.buyers <= MAX_BUYERS:
            raise ValueError(f"buyers must be 1-{MAX_BUYERS} (one per load-test phone)")
        if not 0 <= self.riders <= MAX_RIDERS:
            raise ValueError(f"riders must be 0-{MAX_RIDERS} (one per load-test rider phone)")
        if self.buyers + self.riders > self.peak_users:
            raise ValueError("buyers and riders cannot exceed the peak number of sessions")
        ends = [s.until_s for s in self.stages]
        if ends != sorted(set(ends)):
            raise ValueError("stages must end at strictly increasing times")
        if not 0 <= self.measure_from_s < self.duration_s:
            raise ValueError("measure_from_s must fall inside the run")
        if self.orders_per_min <= 0:
            raise ValueError("orders_per_min must be positive")

    @property
    def duration_s(self) -> int:
        return self.stages[-1].until_s

    @property
    def peak_users(self) -> int:
        return max(s.users for s in self.stages)

    @property
    def pacing_s(self) -> float:
        """Seconds between two orders of one buyer."""
        return self.buyers * 60.0 / self.orders_per_min

    @property
    def min_orders_per_min(self) -> float | None:
        if self.min_order_rate is None:
            return None
        return self.orders_per_min * self.min_order_rate

    def tick(self, run_time_s: float) -> tuple[int, float] | None:
        """(users, spawn_rate) at this moment of the run, or None when it is over."""
        for stage in self.stages:
            if run_time_s < stage.until_s:
                return stage.users, stage.spawn_rate
        return None


PROFILES: dict[str, Profile] = {
    "smoke": Profile(
        name="smoke",
        description=(
            "10 sessions for 60 s (3 buyers, 2 riders, 6 orders/min): proves the flows work."
        ),
        stages=(Stage(60, 10, 5),),
        buyers=3,
        riders=2,
        orders_per_min=6,
        measure_from_s=10,
    ),
    "ramp": Profile(
        name="ramp",
        description=(
            "Step ramp 100 -> 500 sessions, +100 every 2 minutes, then 5 minutes at 500 "
            "(100 buyers, 40 riders, 50 orders/min): shows where latency starts to climb."
        ),
        stages=(
            Stage(120, 100, 10),
            Stage(240, 200, 10),
            Stage(360, 300, 10),
            Stage(480, 400, 10),
            Stage(780, 500, 10),
        ),
        buyers=100,
        riders=40,
        orders_per_min=50,
        measure_from_s=480,
    ),
    "target": Profile(
        name="target",
        description=(
            "09 §1 capacity: ramp to 500 sessions over about 4 minutes, then hold 15 minutes at "
            "500 with 100 buyers placing 50 orders/min and 40 riders on shift. The release gate."
        ),
        stages=(Stage(300, 500, 2), Stage(1200, 500, 2)),
        buyers=100,
        riders=40,
        orders_per_min=50,
        measure_from_s=300,
        min_order_rate=0.9,
    ),
}


def get(name: str, *, riders: int | None = None) -> Profile:
    """The named profile; `riders` replaces its rider count (e.g. 0 on a server without P5)."""
    try:
        profile = PROFILES[name]
    except KeyError:
        raise ValueError(f"Unknown profile {name!r}; use one of: {', '.join(PROFILES)}.") from None
    return profile if riders is None else replace(profile, riders=riders)
