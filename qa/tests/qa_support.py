"""Shared helpers for the black-box suites: HTTP client with redacted logging, OpenAPI response
validation, read-only DB access and QA-owned Redis cleanup.

Safety rules enforced here (qa-engineer role definition):
- The target must be the QA instance (127.0.0.1:8004 by default). Port 8001 (shared dev server)
  is refused.
- Redis cleanup only touches `jqc:rl:*` keys in DBs 5-7 on port 6380, never port 6379.
- The DB connection is read-only, credentials come from backend/.env and are never printed;
  connection errors are re-raised without the host.
- Tokens are redacted to first/last 4 characters and phones masked in anything we print.
"""

from __future__ import annotations

import base64
import copy
import functools
import json
import os
import re
import subprocess
from pathlib import Path
from typing import Any
from urllib.parse import urlsplit

import httpx
import jsonschema
import yaml

QA_DIR = Path(__file__).resolve().parent.parent
REPO = QA_DIR.parent
PRIVATE = QA_DIR / "private"


def _main_checkout() -> Path:
    """The main checkout when QA runs from a git worktree (.worktrees/qa has no backend/.env)."""
    try:
        common = subprocess.run(
            ["git", "-C", str(REPO), "rev-parse", "--path-format=absolute", "--git-common-dir"],
            capture_output=True,
            text=True,
            check=True,
        ).stdout.strip()
        return Path(common).parent
    except (OSError, subprocess.CalledProcessError):
        return REPO


def backend_env_file(name: str = ".env") -> Path:
    """backend/.env (or .env.localdb): QA_BACKEND_ENV override, this checkout, else the main
    checkout. The file is only ever read, never printed or copied."""
    override = os.environ.get("QA_BACKEND_ENV") if name == ".env" else None
    if override:
        return Path(override)
    local = REPO / "backend" / name
    return local if local.exists() else _main_checkout() / "backend" / name


def instance_db() -> str:
    """Which database the running QA instance uses: remote (backend/.env) or localdb."""
    marker = PRIVATE / ".instance-db"
    return marker.read_text().strip() if marker.exists() else "remote"

BASE_URL = os.environ.get("QA_BASE_URL", "http://127.0.0.1:8004")
if urlsplit(BASE_URL).port == 8001:
    raise SystemExit("Refusing to run against 8001 (the shared dev server). Use the QA instance.")

QA_REDIS_URL = os.environ.get("QA_REDIS_URL", "redis://localhost:6380/5")

# QA fixed-OTP numbers (role definition). Never +919000000001..003 (user / other agents).
TEST_OTP = "123456"
QA_PHONES = {
    "a": "+919000000101",  # IDOR user A, token tests
    "b": "+919000000102",  # IDOR user B
    "c": "+919000000103",  # rider-app login, profile tests
    "d": "+919000000104",  # devices / misc
    "e": "+919000000105",  # account deletion
    # PM-approved P5 stage 2 (2026-11-09), QA instance env only:
    "f": "+919000000106",  # third rider (ranking with three candidates)
    "g": "+919000000107",  # PENDING_KYC / REJECTED rider
    "h": "+919000000108",  # rider to anonymise
    "i": "+919000000109",  # COD-refusal customer (COD block)
    "j": "+919000000110",  # spare (P6/P7 inbox and support)
}
# Non-test numbers for limit tests: the console SMS backend sends nothing and no Celery worker
# consumes the QA broker DB, so no SMS ever leaves the machine.
NONTEST_PREFIX = "+9199999000"

APP_HEADERS = {
    "X-App-Name": "customer",
    "X-App-Version": "1.0.0",
    "X-Platform": "android",
}
RIDER_HEADERS = {**APP_HEADERS, "X-App-Name": "rider"}


def profile() -> str:
    env = os.environ.get("QA_PROFILE")
    if env:
        return env
    marker = PRIVATE / ".instance-profile"
    return marker.read_text().strip() if marker.exists() else "local"


def instance_commit() -> str:
    marker = PRIVATE / ".instance-commit"
    if marker.exists():
        return marker.read_text().strip()
    return subprocess.run(
        ["git", "-C", str(REPO), "rev-parse", "--short", "HEAD"],
        capture_output=True,
        text=True,
        check=True,
    ).stdout.strip()


# --------------------------------------------------------------------------- redaction

_JWT_RE = re.compile(r"eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+")
_PHONE_RE = re.compile(r"\+91[6-9]\d{9}")


def redact_token(token: str | None) -> str:
    if not token:
        return str(token)
    return f"{token[:4]}…{token[-4:]}" if len(token) > 8 else "****"


def mask_phone(phone: str) -> str:
    return f"{phone[:3]}******{phone[-4:]}" if len(phone) > 7 else "*" * len(phone)


def redact(text: str) -> str:
    text = _JWT_RE.sub(lambda m: redact_token(m.group(0)), text)
    return _PHONE_RE.sub(lambda m: mask_phone(m.group(0)), text)


def jwt_claims(token: str) -> dict:
    """Decode a JWT payload without verifying (inspection only)."""
    payload = token.split(".")[1]
    payload += "=" * (-len(payload) % 4)
    return json.loads(base64.urlsafe_b64decode(payload))


# --------------------------------------------------------------------------- HTTP


def client(headers: dict | None = None, **kwargs) -> httpx.Client:
    return httpx.Client(
        base_url=BASE_URL,
        headers={**APP_HEADERS, **(headers or {})},
        timeout=httpx.Timeout(30.0),
        follow_redirects=False,
        **kwargs,
    )


def bearer(access: str) -> dict:
    return {"Authorization": f"Bearer {access}"}


def describe(resp: httpx.Response) -> str:
    """One-line, redacted summary for assertion messages and evidence."""
    body = resp.text[:600]
    return redact(f"{resp.request.method} {resp.request.url.path} -> {resp.status_code} {body}")


def assert_error(resp: httpx.Response, status: int, code: str) -> dict:
    assert resp.status_code == status, describe(resp)
    assert resp.headers.get("content-type", "").startswith("application/json"), describe(resp)
    body = resp.json()
    assert set(body) == {"error"}, describe(resp)
    err = body["error"]
    assert set(err) == {"code", "message", "details"}, describe(resp)
    assert err["code"] == code, describe(resp)
    assert isinstance(err["message"], str) and err["message"], describe(resp)
    assert isinstance(err["details"], dict), describe(resp)
    return err


# --------------------------------------------------------------------------- OpenAPI


def schema_path() -> Path:
    override = os.environ.get("QA_SCHEMA")
    if override:
        return Path(override)
    exported = Path(f"/tmp/jivo-qa-{instance_commit()}/backend/openapi/schema.yaml")
    return exported if exported.exists() else REPO / "backend/openapi/schema.yaml"


@functools.cache
def openapi() -> dict:
    return yaml.safe_load(schema_path().read_text())


def _convert(node: Any, strict: bool) -> Any:
    """OpenAPI 3.0 schema object -> JSON Schema (2020-12). `nullable` becomes a null branch;
    in strict mode objects with `properties` get `additionalProperties: false` so undocumented
    response fields (possible PII leaks) fail validation."""
    if isinstance(node, list):
        return [_convert(item, strict) for item in node]
    if not isinstance(node, dict):
        return node
    out = {}
    for key, value in node.items():
        if key == "$ref":
            out["$ref"] = value.replace("#/components/schemas/", "#/$defs/")
        elif key in ("example", "examples", "discriminator", "xml", "externalDocs"):
            continue
        else:
            out[key] = _convert(value, strict)
    if strict and out.get("type") == "object" and "properties" in out:
        out.setdefault("additionalProperties", False)
    if out.pop("nullable", False):
        return {"anyOf": [out, {"type": "null"}]}
    return out


@functools.cache
def _defs(strict: bool) -> dict:
    return {
        name: _convert(schema, strict)
        for name, schema in openapi()["components"]["schemas"].items()
    }


def operation(operation_id: str) -> tuple[str, str, dict]:
    for path, ops in openapi()["paths"].items():
        for method, op in ops.items():
            if isinstance(op, dict) and op.get("operationId") == operation_id:
                return method.upper(), path, op
    raise KeyError(operation_id)


def all_operations() -> list[tuple[str, str, str, dict]]:
    out = []
    for path, ops in openapi()["paths"].items():
        for method, op in ops.items():
            if method in ("get", "post", "put", "patch", "delete"):
                out.append((op["operationId"], method.upper(), path, op))
    return out


def validate_response(resp: httpx.Response, operation_id: str, strict: bool = True) -> None:
    """Assert the status is documented for the operation and the body matches its schema."""
    _, _, op = operation(operation_id)
    status = str(resp.status_code)
    assert status in op["responses"], (
        f"{operation_id}: status {status} not documented "
        f"(documented {sorted(op['responses'])}). {describe(resp)}"
    )
    content = op["responses"][status].get("content")
    if not content:
        assert not resp.content, f"{operation_id}: expected empty body. {describe(resp)}"
        return
    media = content.get("application/json")
    assert media, f"{operation_id} {status}: no JSON content documented"
    schema = copy.deepcopy(_convert(media["schema"], strict))
    schema["$defs"] = _defs(strict)
    schema["$schema"] = "https://json-schema.org/draft/2020-12/schema"
    try:
        jsonschema.validate(
            resp.json(), schema, format_checker=jsonschema.Draft202012Validator.FORMAT_CHECKER
        )
    except jsonschema.ValidationError as exc:
        raise AssertionError(
            f"{operation_id} {status} does not match the schema: {redact(exc.message)} "
            f"at {list(exc.absolute_path)}"
        ) from None


# --------------------------------------------------------------------------- Redis (own DB only)


def qa_redis():
    import redis

    parts = urlsplit(QA_REDIS_URL)
    db = int((parts.path or "/0").lstrip("/") or 0)
    if parts.port == 6379 or db not in (5, 6, 7):
        raise SystemExit("QA Redis must be port 6380 DB 5-7 (never 6379, never dev DBs 0-2).")
    return redis.Redis.from_url(QA_REDIS_URL, socket_connect_timeout=2, socket_timeout=2)


def clear_rate_limits() -> int:
    """Delete only the QA instance's rate-limit counters (`jqc:rl:*`) in the QA Redis DB."""
    return _delete_matching("jqc:rl:*")


def _delete_matching(*patterns: str) -> int:
    r = qa_redis()
    keys = [k for p in patterns for k in r.scan_iter(match=p, count=500)]
    if keys:
        r.delete(*keys)
    return len(keys)


def clear_catalog_cache() -> int:
    """Drop the QA instance's catalog bodies and store snapshot (QA Redis DB 5 only), so API
    output can be compared with SQL without the 300 s cache lag (changes made through :8001 do
    not invalidate the QA instance's cache)."""
    return _delete_matching("jqc:1:catalog:*", "jqc:1:stores:areas:*")


def clear_throttle(scope: str) -> int:
    """Drop the QA instance's DRF throttle history for one scope (e.g. notify_me)."""
    return _delete_matching(f"jqc:1:throttle_{scope}_*")


def redis_keys(pattern: str) -> list[str]:
    return [k.decode() for k in qa_redis().scan_iter(match=pattern, count=500)]


STORE_ID = 1  # the seeded GGN-01 store (the only store in the shared dev DB)
STORE_HEADERS = {**APP_HEADERS, "X-Store-Id": str(STORE_ID)}
STORE_POINT = (28.471, 77.044)  # GGN-01 location (lat, lng)
MUMBAI = (19.076, 72.8777)


# --------------------------------------------------------------------------- DB (read-only)


def db_connect():
    """Read-only connection to the shared DB. Credentials from backend/.env, never printed."""
    import psycopg
    from dotenv import dotenv_values

    env = dict(dotenv_values(backend_env_file(".env")))
    if instance_db() == "localdb":  # read the same database the instance under test uses
        env.update(dotenv_values(backend_env_file(".env.localdb")))
    env.update(os.environ)
    try:
        conn = psycopg.connect(
            host=env["POSTGRES_HOST"],
            port=env.get("POSTGRES_PORT") or "5432",
            dbname=env["POSTGRES_DB"],
            user=env["POSTGRES_USER"],
            password=env["POSTGRES_PASSWORD"],
            connect_timeout=10,
            autocommit=False,
        )
    except Exception as exc:  # never echo the host or user
        raise RuntimeError(f"DB connection failed ({type(exc).__name__})") from None
    conn.read_only = True
    return conn


def db_query(sql: str, params: tuple = ()) -> list[tuple]:
    with db_connect() as conn, conn.cursor() as cur:
        cur.execute("SET TRANSACTION READ ONLY")
        cur.execute(sql, params)
        rows = cur.fetchall() if cur.description else []
        conn.rollback()
        return rows
