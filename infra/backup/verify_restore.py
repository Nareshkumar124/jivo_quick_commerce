#!/usr/bin/env python3
"""Verify a restored Jivo Quick Commerce database (docs/deployment.md §7.3).

Run it through the backend's uv environment (it needs psycopg 3, already a backend dependency):

    uv run --project backend python infra/backup/verify_restore.py \\
        --target-db test_jivo_quick_commerce_restore_check [--source-db jivo_quick_commerce]

Connection settings come from the libpq variables (PGHOST, PGPORT, PGUSER, PGPASSWORD, PGSSLMODE),
filled from POSTGRES_* or from ``--env-file backend/.env`` (only those keys are read; nothing is
printed). ``restore_db.sh --verify`` exports them for you.

Everything runs in READ ONLY transactions, on the target and on the optional source: the script
never writes to any database.

Checks (each is PASS, WARN or FAIL; any FAIL gives exit code 1):

1. ``postgis`` extension installed in the target.
2. Exact row count of every table in ``public`` (printed; with ``--source-db``, a full restore must
   match the source; skipped for schema-only restores, where every table but django_migrations is
   empty by design).
3. Migration state: ``django_migrations`` exists and is not empty; with ``--source-db`` the set of
   applied (app, name) pairs and the set of tables, columns, constraints and indexes must equal the
   source's.
4. Key constraints that protect money and stock exist (``storeinventory_reserved_within_on_hand``,
   ``payment_amount_positive``, ...).
5. Business invariants on the restored data (08 §6, the same read-only checks QA uses):
   stock ledger sums, reservations vs ``reserved``, the bill formula, refunds within payments.
   Tables that do not exist yet in this phase are skipped, not failed.

Exit codes: 0 all passed (warnings allowed), 1 a check failed, 2 usage / connection error.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from dataclasses import asdict, dataclass, field
from pathlib import Path

try:
    import psycopg
    from psycopg import sql
except ImportError:  # pragma: no cover - environment problem, not a check failure
    sys.stderr.write(
        "psycopg is not installed. Run through the backend env: "
        "uv run --project backend python infra/backup/verify_restore.py ...\n"
    )
    sys.exit(2)

ENV_KEYS = {
    "POSTGRES_HOST": "PGHOST",
    "POSTGRES_PORT": "PGPORT",
    "POSTGRES_USER": "PGUSER",
    "POSTGRES_PASSWORD": "PGPASSWORD",
    "POSTGRES_SSLMODE": "PGSSLMODE",
}

# Tables filled by CREATE EXTENSION itself, not by the app: not counted as restored data.
EXTENSION_TABLES = {"spatial_ref_sys"}

# Constraints whose loss would silently allow bad money or stock data (07 §3, 08 §6).
REQUIRED_CONSTRAINTS = {
    "inventory_storeinventory": [
        "storeinventory_on_hand_not_negative",
        "storeinventory_reserved_not_negative",
        "storeinventory_reserved_within_on_hand",
    ],
    "inventory_stockmovement": ["stockmovement_delta_not_zero", "stockmovement_on_hand_after_ok"],
    "inventory_stockreservation": ["stockreservation_order_variant_unique"],
    "payments_payment": [
        "payment_amount_positive",
        "payment_gateway_payment_id_unique",
        "payment_gateway_order_id_unique",
    ],
    "payments_refund": ["refund_amount_positive", "refund_gateway_refund_id_unique"],
}

# (name, severity, tables needed, SQL returning one integer: the number of violating rows)
INVARIANTS: list[tuple[str, str, tuple[str, ...], str]] = [
    (
        "stock: reserved within 0..on_hand",
        "FAIL",
        ("inventory_storeinventory",),
        "select count(*) from inventory_storeinventory "
        "where on_hand < 0 or reserved < 0 or reserved > on_hand",
    ),
    (
        "stock: on_hand equals the sum of its StockMovement deltas",
        "FAIL",
        ("inventory_storeinventory", "inventory_stockmovement"),
        "select count(*) from inventory_storeinventory si left join ("
        " select store_id, variant_id, sum(delta) as s from inventory_stockmovement"
        " group by store_id, variant_id) m"
        " on m.store_id = si.store_id and m.variant_id = si.variant_id "
        "where si.on_hand <> coalesce(m.s, 0)",
    ),
    (
        "stock: latest StockMovement.on_hand_after equals on_hand",
        "FAIL",
        ("inventory_storeinventory", "inventory_stockmovement"),
        "select count(*) from inventory_storeinventory si join lateral ("
        " select on_hand_after from inventory_stockmovement sm"
        " where sm.store_id = si.store_id and sm.variant_id = si.variant_id"
        " order by sm.created_at desc, sm.id desc limit 1) last on true "
        "where last.on_hand_after <> si.on_hand",
    ),
    (
        "stock: reserved equals the sum of ACTIVE reservations",
        "FAIL",
        ("inventory_storeinventory", "inventory_stockreservation"),
        "select count(*) from inventory_storeinventory si left join ("
        " select store_id, variant_id, sum(quantity) as q from inventory_stockreservation"
        " where status = 'ACTIVE' group by store_id, variant_id) r"
        " on r.store_id = si.store_id and r.variant_id = si.variant_id "
        "where si.reserved <> coalesce(r.q, 0)",
    ),
    (
        "stock: no ACTIVE reservation on a terminal order",
        "WARN",
        ("inventory_stockreservation", "orders_order"),
        "select count(*) from inventory_stockreservation r join orders_order o on o.id = r.order_id"
        " where r.status = 'ACTIVE'"
        " and o.status in ('DELIVERED', 'CANCELLED', 'PAYMENT_FAILED', 'RETURNED')",
    ),
    (
        "money: grand_total = item_total - coupon + fees + tip (08 6.2)",
        "FAIL",
        ("orders_order",),
        "select count(*) from orders_order where grand_total <> item_total - coupon_discount"
        " + delivery_fee + small_cart_fee + handling_fee + tip",
    ),
    (
        "money: product_discount = mrp_total - item_total",
        "FAIL",
        ("orders_order",),
        "select count(*) from orders_order where product_discount <> mrp_total - item_total",
    ),
    (
        "money: no negative amounts on orders",
        "FAIL",
        ("orders_order",),
        "select count(*) from orders_order where least(mrp_total, item_total, product_discount,"
        " coupon_discount, delivery_fee, small_cart_fee, handling_fee, tip, grand_total,"
        " amount_refunded, amount_paid) < 0",
    ),
    (
        "money: amount_refunded never exceeds amount_paid (ONLINE)",
        "FAIL",
        ("orders_order",),
        "select count(*) from orders_order where payment_method = 'ONLINE'"
        " and amount_paid > 0 and amount_refunded > amount_paid",
    ),
    (
        "money: refunds on a payment never exceed the payment",
        "FAIL",
        ("payments_payment", "payments_refund"),
        "select count(*) from payments_payment p join ("
        " select payment_id, sum(amount) as s from payments_refund"
        " where status in ('PENDING', 'PROCESSED') group by payment_id) r"
        " on r.payment_id = p.id where r.s > p.amount",
    ),
    (
        "payments: duplicate CAPTURED payments without a refund",
        "WARN",
        ("payments_payment", "payments_refund"),
        "select count(*) from (select p.order_id from payments_payment p"
        " where p.status = 'CAPTURED' and not exists (select 1 from payments_refund r"
        " where r.payment_id = p.id and r.status in ('PENDING', 'PROCESSED'))"
        " group by p.order_id having count(*) > 1) d",
    ),
    (
        "orders: every order has status history",
        "WARN",
        ("orders_order", "orders_orderstatushistory"),
        "select count(*) from orders_order o where not exists ("
        " select 1 from orders_orderstatushistory h where h.order_id = o.id)",
    ),
]


@dataclass
class Result:
    name: str
    status: str  # PASS / WARN / FAIL / SKIP
    detail: str = ""


@dataclass
class Report:
    target: str
    source: str | None
    results: list[Result] = field(default_factory=list)
    row_counts: dict[str, int] = field(default_factory=dict)

    def add(self, name: str, status: str, detail: str = "") -> None:
        self.results.append(Result(name, status, detail))

    @property
    def failed(self) -> bool:
        return any(r.status == "FAIL" for r in self.results)


def load_env_file(path: Path) -> None:
    """Copy the POSTGRES_* connection keys from a dotenv file into PG* variables. POSTGRES_DB is
    deliberately ignored: the database is always named on the command line."""
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip().removeprefix("export ")
        key, sep, value = line.partition("=")
        if not sep or key not in ENV_KEYS:
            continue
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        os.environ[ENV_KEYS[key]] = value


def fill_pg_env() -> None:
    for pg_key, pg_var in ENV_KEYS.items():
        if not os.environ.get(pg_var) and os.environ.get(pg_key):
            os.environ[pg_var] = os.environ[pg_key]
    os.environ.setdefault("PGCONNECT_TIMEOUT", "10")
    os.environ.setdefault("PGAPPNAME", "jqc-verify-restore")


def connect(dbname: str) -> psycopg.Connection:
    conn = psycopg.connect(dbname=dbname, autocommit=False)
    conn.read_only = True  # every transaction on this connection is READ ONLY
    return conn


def scalar(conn: psycopg.Connection, query: sql.Composable | str, params=None):
    with conn.cursor() as cur:
        cur.execute(query, params)
        row = cur.fetchone()
        return row[0] if row else None


def tables(conn: psycopg.Connection) -> list[str]:
    with conn.cursor() as cur:
        cur.execute(
            "select tablename from pg_tables where schemaname = 'public' order by tablename"
        )
        return [r[0] for r in cur.fetchall()]


def schema_fingerprint(conn: psycopg.Connection) -> dict[str, set]:
    """Columns, constraints and indexes of the public schema, for a source/target comparison."""
    out: dict[str, set] = {}
    with conn.cursor() as cur:
        cur.execute(
            "select table_name, column_name, data_type, is_nullable from information_schema.columns"
            " where table_schema = 'public'"
        )
        out["columns"] = {tuple(r) for r in cur.fetchall()}
        cur.execute(
            "select c.conrelid::regclass::text, c.conname, c.contype from pg_constraint c"
            " join pg_namespace n on n.oid = c.connamespace where n.nspname = 'public'"
        )
        out["constraints"] = {tuple(r) for r in cur.fetchall()}
        cur.execute("select tablename, indexname from pg_indexes where schemaname = 'public'")
        out["indexes"] = {tuple(r) for r in cur.fetchall()}
    return out


def migrations(conn: psycopg.Connection) -> set[tuple[str, str]]:
    with conn.cursor() as cur:
        cur.execute("select app, name from django_migrations")
        return {(a, n) for a, n in cur.fetchall()}


def verify(target_db: str, source_db: str | None, schema_only: bool | None) -> Report:
    report = Report(target=target_db, source=source_db)
    tgt = connect(target_db)
    src = connect(source_db) if source_db else None
    try:
        # 1. PostGIS
        postgis = scalar(tgt, "select extversion from pg_extension where extname = 'postgis'")
        report.add(
            "postgis extension present",
            "PASS" if postgis else "FAIL",
            f"version {postgis}" if postgis else "missing: geo queries would fail",
        )

        # 2. Row counts (exact)
        tgt_tables = tables(tgt)
        for t in tgt_tables:
            report.row_counts[t] = scalar(
                tgt, sql.SQL("select count(*) from {}").format(sql.Identifier("public", t))
            )
        data_rows = sum(
            n
            for t, n in report.row_counts.items()
            if t != "django_migrations" and t not in EXTENSION_TABLES
        )
        if schema_only is None:
            schema_only = data_rows == 0
        report.add(
            "tables restored",
            "PASS" if tgt_tables else "FAIL",
            f"{len(tgt_tables)} tables, {data_rows} data rows"
            + (" (schema-only restore)" if schema_only else ""),
        )

        # 3. Migration state
        if "django_migrations" not in tgt_tables:
            report.add("django_migrations present", "FAIL", "table missing")
            tgt_migs: set[tuple[str, str]] = set()
        else:
            tgt_migs = migrations(tgt)
            report.add(
                "django_migrations present",
                "PASS" if tgt_migs else "FAIL",
                f"{len(tgt_migs)} applied migrations across {len({a for a, _ in tgt_migs})} apps",
            )
        if src is not None:
            src_migs = migrations(src)
            missing, extra = src_migs - tgt_migs, tgt_migs - src_migs
            report.add(
                "migration state equals source",
                "PASS" if not missing and not extra else "FAIL",
                f"missing {sorted(missing)[:5]} extra {sorted(extra)[:5]}"
                if missing or extra
                else f"{len(src_migs)} migrations match",
            )
            src_tables = tables(src)
            only_src = sorted(set(src_tables) - set(tgt_tables))
            only_tgt = sorted(set(tgt_tables) - set(src_tables))
            report.add(
                "table set equals source",
                "PASS" if not only_src and not only_tgt else "FAIL",
                f"missing {only_src[:10]} extra {only_tgt[:10]}"
                if only_src or only_tgt
                else f"{len(src_tables)} tables match",
            )
            sf, tf = schema_fingerprint(src), schema_fingerprint(tgt)
            for part in ("columns", "constraints", "indexes"):
                diff = sf[part] ^ tf[part]
                report.add(
                    f"{part} equal source",
                    "PASS" if not diff else "FAIL",
                    f"{len(diff)} differences, e.g. {sorted(diff)[:3]}"
                    if diff
                    else f"{len(sf[part])} match",
                )
            if not schema_only:
                mismatched = []
                for t in src_tables:
                    if t not in report.row_counts:
                        continue
                    n = scalar(
                        src, sql.SQL("select count(*) from {}").format(sql.Identifier("public", t))
                    )
                    if n != report.row_counts[t]:
                        mismatched.append(f"{t}: source {n} target {report.row_counts[t]}")
                # A live source keeps changing after the dump, so differences are a warning; a
                # restore of a quiesced or snapshot source must match exactly.
                report.add(
                    "row counts equal source",
                    "PASS" if not mismatched else "WARN",
                    "; ".join(mismatched[:10]) if mismatched else "all tables match",
                )

        # 4. Key constraints
        for table, names in REQUIRED_CONSTRAINTS.items():
            if table not in tgt_tables:
                report.add(f"constraints on {table}", "SKIP", "table not in this schema")
                continue
            with tgt.cursor() as cur:
                cur.execute(
                    "select conname from pg_constraint where conrelid = %s::regclass",
                    (f"public.{table}",),
                )
                present = {r[0] for r in cur.fetchall()}
            # unique constraints may be implemented as unique indexes
            with tgt.cursor() as cur:
                cur.execute(
                    "select indexname from pg_indexes where schemaname = 'public'"
                    " and tablename = %s",
                    (table,),
                )
                present |= {r[0] for r in cur.fetchall()}
            missing = [n for n in names if n not in present]
            report.add(
                f"constraints on {table}",
                "FAIL" if missing else "PASS",
                f"missing {missing}" if missing else f"{len(names)} present",
            )

        # 5. Business invariants
        for name, severity, needed, query in INVARIANTS:
            absent = [t for t in needed if t not in tgt_tables]
            if absent:
                report.add(name, "SKIP", f"no table {absent[0]} yet")
                continue
            bad = scalar(tgt, query)
            report.add(name, "PASS" if bad == 0 else severity, f"{bad} violating rows")
    finally:
        tgt.rollback()
        tgt.close()
        if src is not None:
            src.rollback()
            src.close()
    return report


def render(report: Report, show_counts: bool) -> str:
    lines = [f"verify_restore: target={report.target} source={report.source or '-'}", ""]
    width = max(len(r.name) for r in report.results)
    for r in report.results:
        lines.append(f"  [{r.status:4}] {r.name.ljust(width)}  {r.detail}")
    if show_counts:
        lines += ["", "  row counts:"]
        lines += [f"    {t}: {n}" for t, n in sorted(report.row_counts.items())]
    counts = {
        s: sum(r.status == s for r in report.results) for s in ("PASS", "WARN", "FAIL", "SKIP")
    }
    lines += ["", "  " + "  ".join(f"{k} {v}" for k, v in counts.items())]
    lines.append("  RESULT: " + ("FAILED" if report.failed else "OK"))
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description="Verify a restored Jivo Quick Commerce database (read-only).",
        epilog="Exit codes: 0 ok (warnings allowed), 1 a check failed, 2 usage/connection error.",
    )
    parser.add_argument("--target-db", required=True, help="the restored database to check")
    parser.add_argument(
        "--source-db", help="optional database to compare with (read-only), e.g. the dump source"
    )
    parser.add_argument("--env-file", type=Path, help="dotenv file with POSTGRES_* (backend/.env)")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--schema-only", dest="schema_only", action="store_true", default=None)
    mode.add_argument("--full", dest="schema_only", action="store_false")
    parser.add_argument("--counts", action="store_true", help="print the row count of every table")
    parser.add_argument("--json", action="store_true", help="print the report as JSON")
    args = parser.parse_args(argv)

    if args.env_file:
        load_env_file(args.env_file)
    fill_pg_env()
    try:
        report = verify(args.target_db, args.source_db, args.schema_only)
    except psycopg.OperationalError as exc:
        # libpq messages name host/db/user, never the password.
        sys.stderr.write(f"connection failed: {str(exc).strip().splitlines()[0]}\n")
        return 2
    if args.json:
        sys.stdout.write(json.dumps(asdict(report), indent=2) + "\n")
    else:
        sys.stdout.write(render(report, args.counts))
    return 1 if report.failed else 0


if __name__ == "__main__":
    sys.exit(main())
