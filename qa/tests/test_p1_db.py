"""Phase 1 database checks (07 §2.1/§3/§4). READ-ONLY SQL on the shared database: aggregates
only, never other users' phone numbers or emails."""

from __future__ import annotations

import pytest

from qa_support import db_query, describe

pytestmark = pytest.mark.db


def _one(sql: str, params: tuple = ()):
    return db_query(sql, params)[0][0]


def test_p1_tc69_identity_uniqueness_and_format():
    """P1-TC-69 phone, email and auth_id are unique (DB constraints present; no duplicates incl.
    case-insensitive email); emails stored lowercase; blank stored as NULL; phones E.164."""
    uniques = {
        row[0]
        for row in db_query(
            "select a.attname from pg_index i join pg_class t on t.oid=i.indrelid "
            "join pg_attribute a on a.attrelid=t.oid and a.attnum = any(i.indkey) "
            "where t.relname='accounts_user' and i.indisunique and i.indnatts=1"
        )
    }
    assert {"phone", "email", "auth_id"} <= uniques, uniques
    assert _one("select count(*) from (select lower(email) from accounts_user where email is not null group by 1 having count(*)>1) d") == 0
    assert _one("select count(*) from accounts_user where email <> lower(email)") == 0
    assert _one("select count(*) from accounts_user where email = '' or phone = '' or auth_id = ''") == 0
    bad_phone = _one("select count(*) from accounts_user where phone is not null and phone !~ '^\\+[1-9][0-9]{6,13}$'")
    assert bad_phone == 0, f"{bad_phone} users with a non-E.164 phone"


def test_p1_tc70_one_default_address_per_user():
    """P1-TC-70 At most one live default address per user (partial unique constraint present),
    and every user with live addresses has exactly one default."""
    ((indexdef,),) = db_query(
        "select indexdef from pg_indexes where indexname='address_one_default_per_user'"
    )
    assert "is_default" in indexdef and "is_deleted" in indexdef
    assert _one(
        "select count(*) from (select user_id from accounts_address where is_default and not is_deleted "
        "group by user_id having count(*)>1) d"
    ) == 0
    no_default = _one(
        "select count(*) from (select user_id from accounts_address where not is_deleted group by user_id "
        "having bool_or(is_default) is false) d"
    )
    assert no_default == 0, f"{no_default} user(s) with live addresses but no default"
    assert _one("select count(*) from accounts_address where is_deleted and is_default") == 0


def test_p1_tc71b_otp_stored_hashed():
    """P1-TC-71b OTPs are stored only as a 64-hex keyed hash; no plaintext code column exists;
    attempts never exceed 5."""
    cols = {r[0] for r in db_query(
        "select column_name from information_schema.columns where table_name='accounts_otprequest'"
    )}
    assert "code_hash" in cols and not ({"code", "otp", "otp_code", "plain_code"} & cols), cols
    assert _one("select count(*) from accounts_otprequest where code_hash !~ '^[0-9a-f]{64}$'") == 0
    # The fixed test code must not appear as plain SHA-256 either (it is an HMAC keyed by SECRET_KEY).
    assert _one(
        "select count(*) from accounts_otprequest where code_hash = encode(sha256('123456'::bytea),'hex')"
    ) == 0
    assert _one("select coalesce(max(attempts),0) from accounts_otprequest") <= 5


def test_p1_tc72_no_orphans_and_foreign_keys():
    """P1-TC-72 No orphan rows: every address/device belongs to an existing user, outstanding
    tokens point at users, blacklist rows at outstanding tokens; FK constraints exist."""
    fks = {r[0] for r in db_query(
        "select conrelid::regclass::text from pg_constraint where contype='f' "
        "and conrelid::regclass::text in ('accounts_address','accounts_device',"
        "'token_blacklist_outstandingtoken','token_blacklist_blacklistedtoken','cms_appversionpolicy')"
    )}
    assert len(fks) == 5, fks
    checks = {
        "address": "select count(*) from accounts_address a left join accounts_user u on u.id=a.user_id where u.id is null",
        "device": "select count(*) from accounts_device d left join accounts_user u on u.id=d.user_id where u.id is null",
        "outstanding": "select count(*) from token_blacklist_outstandingtoken o left join accounts_user u on u.id=o.user_id where o.user_id is not null and u.id is null",
        "outstanding_null_user": "select count(*) from token_blacklist_outstandingtoken where user_id is null",
        "blacklist": "select count(*) from token_blacklist_blacklistedtoken b left join token_blacklist_outstandingtoken o on o.id=b.token_id where o.id is null",
        "user_groups": "select count(*) from accounts_user_groups ug left join auth_group g on g.id=ug.group_id where g.id is null",
        "policy": "select count(*) from cms_appversionpolicy p left join cms_appconfig c on c.id=p.config_id where c.id is null",
    }
    found = {name: _one(sql) for name, sql in checks.items()}
    assert all(v == 0 for v in found.values()), found


def test_p1_tc73_soft_deleted_addresses_hidden(api, user_a, make_address):
    """P1-TC-73 The API list equals the DB's live (not deleted) rows for the caller; soft-deleted
    rows still exist in the DB (soft delete) but never appear in the API."""
    a = make_address(user_a, house="QA soft-delete probe")
    assert api.delete(f"/api/v1/addresses/{a['id']}/", headers=user_a.headers).status_code == 204
    live_db = {r[0] for r in db_query(
        "select id from accounts_address where user_id=%s and not is_deleted", (user_a.user["id"],)
    )}
    r = api.get("/api/v1/addresses/?page_size=100", headers=user_a.headers)
    live_api = {x["id"] for x in r.json()["results"]}
    assert live_api == live_db, describe(r)
    assert db_query("select is_deleted from accounts_address where id=%s", (a["id"],)) == [(True,)]


def test_p1_tc74_column_types_and_constraints():
    """P1-TC-74 lat/lng are numeric(9,6) (decimals, never floats); the lat/lng range check
    constraint and the AppConfig singleton constraint exist; char lengths match 07 §2.1."""
    cols = {
        (r[0], r[1]): (r[2], r[3], r[4], r[5])
        for r in db_query(
            "select table_name, column_name, data_type, numeric_precision, numeric_scale, "
            "character_maximum_length from information_schema.columns "
            "where table_name in ('accounts_address','accounts_user','accounts_device')"
        )
    }
    assert cols[("accounts_address", "lat")][:3] == ("numeric", 9, 6)
    assert cols[("accounts_address", "lng")][:3] == ("numeric", 9, 6)
    assert cols[("accounts_user", "phone")][3] == 15
    assert cols[("accounts_user", "auth_id")][3] == 64
    assert cols[("accounts_device", "fcm_token")][3] == 512
    float_cols = [k for k, v in cols.items() if v[0] in ("real", "double precision")]
    assert not float_cols, float_cols
    names = {r[0] for r in db_query("select conname from pg_constraint where contype='c'")}
    assert {"address_lat_lng_range", "cms_appconfig_singleton"} <= names


def test_p1_tc75_retention_state():
    """P1-TC-75 Retention (07 §4) state: no OTP rows older than 30 days and no account past the
    30-day grace period left un-anonymised (both jobs run daily via beat)."""
    assert _one("select count(*) from accounts_otprequest where created_at < now() - interval '30 days'") == 0
    assert _one(
        "select count(*) from accounts_user where deleted_at < now() - interval '30 days' and anonymised_at is null"
    ) == 0


def test_p1_tc75b_non_ascii_phones_stored():
    """P1-TC-75b Evidence for BUG-0002: OTP rows whose phone contains non-ASCII digits (count
    only). Informational: passes either way, the count is printed in -rA output."""
    n = _one("select count(*) from accounts_otprequest where phone !~ '^\\+[0-9]+$'")
    print(f"OTP rows with non-ASCII phone digits: {n}")


def test_p1_tc72b_migration_state():
    """Environment record: accounts/cms migrations applied in the shared DB (names only)."""
    rows = db_query("select app, name from django_migrations where app in ('accounts','cms') order by app, id")
    print("applied:", rows)
    assert ("accounts", "0002_phase1_auth_devices_addresses") in rows
