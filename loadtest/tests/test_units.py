"""Safety guard, thresholds, profiles, the fake-gateway signature, the report and the CLI."""

import json

import pytest

from jivo_loadtest import cli, gateway, profiles, report
from jivo_loadtest.config import PHONES
from jivo_loadtest.safety import UnsafeTarget, check_target
from jivo_loadtest.thresholds import Breach, EndpointResult, evaluate, p95_limit

# --------------------------------------------------------------------------- safety


@pytest.mark.parametrize("host", [None, "", "   "])
def test_host_is_required(host):
    with pytest.raises(UnsafeTarget, match="--host is required"):
        check_target(host, "staging.example.com")


@pytest.mark.parametrize(
    "host",
    [
        "http://localhost:8001",
        "http://127.0.0.1:8001",
        "http://[::1]:8001",
        "http://0.0.0.0:8001",
        "http://127.0.0.1:8004",
        "http://localhost:8000",
    ],
)
def test_shared_local_servers_are_refused_even_when_listed(host):
    allowed = "localhost:8001,127.0.0.1:8001,[::1]:8001,0.0.0.0:8001,127.0.0.1:8004,localhost:8000"
    with pytest.raises(UnsafeTarget, match="shared server"):
        check_target(host, allowed)


def test_nothing_is_allowed_without_the_allow_list(monkeypatch):
    monkeypatch.delenv("LOADTEST_ALLOWED_HOSTS", raising=False)
    with pytest.raises(UnsafeTarget, match="LOADTEST_ALLOWED_HOSTS is not set"):
        check_target("https://staging.example.com")


@pytest.mark.parametrize(
    ("host", "allowed", "target"),
    [
        ("https://staging.example.com", "staging.example.com", "staging.example.com:443"),
        ("https://staging.example.com/", "https://staging.example.com/", "staging.example.com:443"),
        ("https://STAGING.example.com", "staging.example.com:443", "staging.example.com:443"),
        ("http://127.0.0.1:8005", "127.0.0.1:8005", "127.0.0.1:8005"),
    ],
)
def test_listed_hosts_are_allowed(host, allowed, target):
    assert check_target(host, allowed) == target


@pytest.mark.parametrize(
    ("host", "allowed"),
    [
        ("https://prod.example.com", "staging.example.com"),
        ("https://staging.example.com.evil.test", "staging.example.com"),
        ("http://127.0.0.1:8006", "127.0.0.1:8005"),
        ("https://staging.example.com:8443", "staging.example.com"),  # bare host = default port
    ],
)
def test_unlisted_hosts_are_refused(host, allowed):
    with pytest.raises(UnsafeTarget, match="not listed"):
        check_target(host, allowed)


@pytest.mark.parametrize(
    "host", ["staging.example.com", "ftp://x.example", "https://x.example/api/v1/", "http://x:abc"]
)
def test_malformed_hosts_are_refused(host):
    with pytest.raises(UnsafeTarget):
        check_target(host, "x.example,staging.example.com")


def test_env_allow_list(monkeypatch):
    monkeypatch.setenv("LOADTEST_ALLOWED_HOSTS", " a.example , 127.0.0.1:8005 ")
    assert check_target("http://127.0.0.1:8005") == "127.0.0.1:8005"


# --------------------------------------------------------------------------- thresholds


def row(method, name, requests=100, failures=0, p95=50.0):
    return EndpointResult(method, name, requests, failures, p95)


def test_limits_follow_09_section_1():
    assert p95_limit("GET", "/api/v1/serviceability/")[0] == 150
    assert p95_limit("GET", "/api/v1/home/")[0] == 300
    assert p95_limit("GET", "/api/v1/cart/")[0] == 300
    assert p95_limit("POST", "/api/v1/orders/")[0] == 800
    assert p95_limit("POST", "/api/v1/cart/items/")[0] == 800


def test_passing_run_has_no_breaches():
    results = [
        row("GET", "/api/v1/serviceability/", p95=149),
        row("GET", "/api/v1/home/", p95=300),
        row("POST", "/api/v1/orders/", p95=790),
    ]
    assert evaluate(results, orders_per_min=50, min_orders_per_min=45) == []


def test_each_threshold_is_reported():
    results = [
        row("GET", "/api/v1/serviceability/", p95=151),
        row("GET", "/api/v1/products/", p95=310),
        row("POST", "/api/v1/orders/", p95=900, failures=5),
        row("JOURNEY", "checkout blocked", requests=1, failures=1, p95=0),
    ]
    breaches = evaluate(results, orders_per_min=40, min_orders_per_min=45)
    kinds = {(b.kind, b.subject) for b in breaches}
    assert ("p95", "GET /api/v1/serviceability/") in kinds
    assert ("p95", "GET /api/v1/products/") in kinds
    assert ("p95", "POST /api/v1/orders/") in kinds
    assert ("error_rate", "POST /api/v1/orders/") in kinds
    assert ("error_rate", "all requests") in kinds
    assert ("journey", "JOURNEY checkout blocked") in kinds
    assert ("throughput", "orders placed") in kinds
    assert all(str(b) for b in breaches)


def test_error_rate_boundary():
    ok = [row("GET", "/api/v1/home/", requests=100, failures=1)]
    assert evaluate(ok) == []
    bad = [row("GET", "/api/v1/home/", requests=100, failures=2)]
    assert {b.kind for b in evaluate(bad)} == {"error_rate"}


def test_no_traffic_fails():
    assert [b.kind for b in evaluate([])] == ["no_traffic"]


def test_throughput_not_gated_without_a_minimum():
    assert evaluate([row("GET", "/api/v1/home/")], orders_per_min=0) == []


def test_breach_text():
    assert str(Breach("p95", "GET /x", 320, 300)) == "GET /x: p95 320 ms > 300 ms"
    assert "1.50%" in str(Breach("error_rate", "all", 0.015, 0.01))


# --------------------------------------------------------------------------- profiles


def test_target_profile_matches_09():
    target = profiles.get("target")
    assert target.peak_users == 500
    assert target.buyers == 100
    assert target.orders_per_min == 50
    assert target.pacing_s == pytest.approx(120)
    assert target.min_orders_per_min == pytest.approx(45)
    assert target.tick(0) == (500, 2)
    assert target.tick(target.duration_s) is None


def test_smoke_profile():
    smoke = profiles.get("smoke")
    assert (smoke.peak_users, smoke.duration_s) == (10, 60)
    assert smoke.min_orders_per_min is None


def test_ramp_steps():
    ramp = profiles.get("ramp")
    assert [ramp.tick(t)[0] for t in (0, 130, 250, 370, 490)] == [100, 200, 300, 400, 500]


def test_profile_validation():
    stage = profiles.Stage(60, 10, 1)
    with pytest.raises(ValueError, match="buyers"):
        profiles.Profile("x", "", (stage,), buyers=101, orders_per_min=1, measure_from_s=0)
    with pytest.raises(ValueError, match="exceed"):
        profiles.Profile("x", "", (stage,), buyers=11, orders_per_min=1, measure_from_s=0)
    with pytest.raises(ValueError, match="increasing"):
        profiles.Profile("x", "", (stage, stage), buyers=1, orders_per_min=1, measure_from_s=0)
    with pytest.raises(ValueError, match="inside the run"):
        profiles.Profile("x", "", (stage,), buyers=1, orders_per_min=1, measure_from_s=60)
    with pytest.raises(ValueError, match="Unknown profile"):
        profiles.get("huge")


# --------------------------------------------------------------------------- gateway


def test_fake_signature_matches_the_documented_example():
    """06 §2.6 worked example (also the schema's verify example)."""
    assert gateway.signature("order_Nq3uVxY7kL9pQe", "pay_Nq3vA1bC2dE3fG") == (
        "bc4bcc84a495aaddc2f52819146edd4d26728c1221e5621f23995c106721c977"
    )


def test_payment_ids_and_fake_detection():
    pid = gateway.new_payment_id()
    assert pid.startswith("pay_")
    assert len(pid) == 18
    assert gateway.is_fake_checkout({"key_id": "rzp_fake_jivo_local"})
    assert not gateway.is_fake_checkout({"key_id": "rzp_test_123"})
    assert not gateway.is_fake_checkout(None)


def test_phone_range_is_dedicated():
    assert PHONES[0] == "+919000000200"
    assert PHONES[-1] == "+919000000299"
    assert len(set(PHONES)) == 100


# --------------------------------------------------------------------------- report


def test_report_files(tmp_path):
    results = [row("GET", "/api/v1/home/", p95=320), row("JOURNEY", "login", 1, 1, 0)]
    breaches = evaluate(results)
    summary = report.build(
        host="http://127.0.0.1:8005",
        profile=profiles.get("smoke"),
        results=results,
        breaches=breaches,
        orders_per_min=6.0,
        outcomes={"order placed": 3},
        run_seconds=60.2,
    )
    json_path, md_path = report.write(summary, tmp_path / "run")
    data = json.loads(json_path.read_text(encoding="utf-8"))
    assert data["passed"] is False
    assert data["requests"] == 101
    text = md_path.read_text(encoding="utf-8")
    assert "**Thresholds: FAIL**" in text
    assert "| GET | `/api/v1/home/` | 100 | 0 | 320 | 300 | NO |" in text
    assert "| order placed | 3 |" in text


# --------------------------------------------------------------------------- CLI


def test_cli_refuses_without_allow_list(monkeypatch, capsys):
    monkeypatch.delenv("LOADTEST_ALLOWED_HOSTS", raising=False)
    called = []
    monkeypatch.setattr(cli.subprocess, "call", lambda *a, **k: called.append(a) or 0)
    assert cli.main(["run", "--host", "https://staging.example.com"]) == cli.REFUSED
    assert "LOADTEST_ALLOWED_HOSTS" in capsys.readouterr().err
    assert called == []


def test_cli_refuses_the_dev_server(monkeypatch, capsys):
    monkeypatch.setenv("LOADTEST_ALLOWED_HOSTS", "localhost:8001")
    monkeypatch.setattr(cli.subprocess, "call", lambda *a, **k: pytest.fail("ran locust"))
    assert cli.main(["run", "--host", "http://localhost:8001"]) == cli.REFUSED


def test_cli_requires_host(capsys):
    with pytest.raises(SystemExit):
        cli.main(["run"])


def test_cli_dry_run_prints_the_plan(monkeypatch, capsys, tmp_path):
    monkeypatch.setenv("LOADTEST_ALLOWED_HOSTS", "staging.example.com")
    monkeypatch.setattr(cli.subprocess, "call", lambda *a, **k: pytest.fail("ran locust"))
    code = cli.main(
        [
            "run",
            "--host",
            "https://staging.example.com",
            "--profile",
            "target",
            "--results-dir",
            str(tmp_path),
            "--dry-run",
        ]
    )
    out = capsys.readouterr().out
    assert code == 0
    assert "500 by 300s" in out
    assert "must reach 45 orders/min" in out
    assert "--headless --host https://staging.example.com" in out
    assert list(tmp_path.iterdir()) == []


def test_cli_run_passes_settings_to_locust(monkeypatch, tmp_path):
    monkeypatch.setenv("LOADTEST_ALLOWED_HOSTS", "127.0.0.1:8005")
    seen = {}

    def fake_call(argv, env):
        seen["argv"], seen["env"] = argv, env
        return 1

    monkeypatch.setattr(cli.subprocess, "call", fake_call)
    code = cli.main(
        [
            "run",
            "--host",
            "http://127.0.0.1:8005",
            "--results-dir",
            str(tmp_path),
            "--online-share",
            "0.5",
            "--lat",
            "28.47",
        ]
    )
    assert code == 1  # Locust's exit code (thresholds breached) is passed through
    assert seen["env"]["LOADTEST_PROFILE"] == "smoke"
    assert seen["env"]["LOADTEST_ONLINE_SHARE"] == "0.5"
    assert seen["env"]["LOADTEST_LAT"] == "28.47"
    assert seen["env"]["LOADTEST_RUN_DIR"].startswith(str(tmp_path))
    assert "--headless" in seen["argv"]
    assert "http://127.0.0.1:8005" in seen["argv"]


def test_cli_check_host_profiles_and_otp_env(monkeypatch, capsys):
    monkeypatch.setenv("LOADTEST_ALLOWED_HOSTS", "staging.example.com")
    assert cli.main(["check-host", "--host", "https://staging.example.com"]) == 0
    assert cli.main(["profiles"]) == 0
    assert cli.main(["otp-env"]) == 0
    out = capsys.readouterr().out
    assert "OK: staging.example.com:443" in out
    assert "Thresholds (09 §1)" in out
    entries = out.strip().splitlines()[-1].split(",")
    assert len(entries) == 100
    assert entries[0] == "+919000000200:123456"
