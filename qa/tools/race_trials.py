"""Repeated race trials for concurrency fixes (QA instance only; QA numbers only).

    uv run python tools/race_trials.py default 30     # BUG-0007: concurrent set-default
    uv run python tools/race_trials.py refresh 20     # BUG-0003: concurrent refresh-token reuse

Each trial uses fresh state and prints one line; the summary is the evidence for the bug file.
Writes go only through the API with QA test accounts (addresses are soft-deleted afterwards).
"""

from __future__ import annotations

import sys
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

import httpx

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests"))

from conftest import ADDRESS, login  # noqa: E402
from qa_support import APP_HEADERS, BASE_URL, QA_PHONES, db_query  # noqa: E402


class EnvError(Exception):
    """Setup failed for an environmental reason (e.g. remote-DB connect timeout -> 500)."""


def default_trial(n: int) -> tuple[int, int, int]:
    s = login(QA_PHONES["c"])
    with httpx.Client(base_url=BASE_URL, headers={**APP_HEADERS, **s.headers}, timeout=60) as c:
        for a in c.get("/api/v1/addresses/?page_size=100").json()["results"]:
            c.delete(f"/api/v1/addresses/{a['id']}/")
        ids = []
        for i in range(5):
            r = c.post("/api/v1/addresses/", json={**ADDRESS, "house": f"QA race {n}-{i}"})
            if r.status_code != 201:
                raise EnvError(f"setup create -> {r.status_code}")
            ids.append(r.json()["id"])

        def set_default(address_id):
            with httpx.Client(base_url=BASE_URL, headers={**APP_HEADERS, **s.headers}, timeout=60) as cc:
                return cc.post(f"/api/v1/addresses/{address_id}/set-default/").status_code

        with ThreadPoolExecutor(10) as pool:
            codes = list(pool.map(set_default, ids * 2))
        if any(code >= 500 for code in codes):
            for address_id in ids:
                c.delete(f"/api/v1/addresses/{address_id}/")
            raise EnvError(f"5xx during the race: {codes}")
        api_defaults = sum(a["is_default"] for a in c.get("/api/v1/addresses/?page_size=100").json()["results"])
        ((db_defaults,),) = db_query(
            "select count(*) from accounts_address where user_id = %s and is_default and not is_deleted",
            (s.user["id"],),
        )
        for address_id in ids:
            c.delete(f"/api/v1/addresses/{address_id}/")
    return codes.count(200), api_defaults, db_defaults


def refresh_trial(n: int) -> tuple[int, int, int]:
    s = login(QA_PHONES["a"])

    def call(_):
        with httpx.Client(base_url=BASE_URL, headers=APP_HEADERS, timeout=30) as c:
            return c.post("/api/v1/auth/token/refresh/", json={"refresh": s.refresh})

    with ThreadPoolExecutor(10) as pool:
        responses = list(pool.map(call, range(10)))
    codes = [r.status_code for r in responses]
    if any(code >= 500 for code in codes):
        raise EnvError(f"5xx during the race: {codes}")
    losers_ok = sum(
        1 for r in responses if r.status_code == 401 and r.json()["error"]["code"] == "TOKEN_INVALID"
    )
    return codes.count(200), losers_ok, len(set(codes) - {200, 401})


def main() -> None:
    kind, trials = sys.argv[1], int(sys.argv[2])
    bad = env = 0
    for n in range(trials):
        try:
            bad += _one_trial(kind, n)
        except (EnvError, httpx.HTTPError, AssertionError) as exc:
            env += 1
            print(f"trial {n:02d}: ENVIRONMENT ERROR (not counted): {exc}", flush=True)
    print(f"SUMMARY {kind}: {trials - bad - env}/{trials - env} valid trials correct, {bad} failed, {env} environment errors", flush=True)


def _one_trial(kind: str, n: int) -> int:
    if True:
        if kind == "default":
            ok, api_d, db_d = default_trial(n)
            fail = not (ok == 10 and api_d == 1 and db_d == 1)
            print(f"trial {n:02d}: 200s={ok}/10 api_defaults={api_d} db_defaults={db_d}{'  <-- FAIL' if fail else ''}", flush=True)
        else:
            wins, losers_ok, other = refresh_trial(n)
            fail = not (wins == 1 and losers_ok == 9 and other == 0)
            print(f"trial {n:02d}: successes={wins}/10 losers_401_TOKEN_INVALID={losers_ok} other_statuses={other}{'  <-- FAIL' if fail else ''}", flush=True)
        return int(fail)


if __name__ == "__main__":
    main()
