#!/usr/bin/env bash
# Restore a backup_db.sh dump into a NAMED target database (docs/deployment.md §7.2).
#
# Safety rules (the database server may be shared with other projects):
# - The target must match test_jivo_quick_commerce_restore* ... unless --production is given
#   together with --confirm "RESTORE INTO <target>" typed exactly.
# - A production restore always goes into a database that does not exist yet (restore beside the
#   live one, verify, then repoint the app). This script never overwrites or drops a non-test DB.
# - Only a test_jivo_quick_commerce_restore* database can be dropped (--drop-existing, --drop-only).
# - The dump's sha256 is checked before anything is created.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=infra/backup/lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: restore_db.sh --target-db NAME --dump FILE [options]
       restore_db.sh --target-db NAME --drop-only [--env-file FILE]

Create NAME, restore FILE (pg_dump -Fc) into it, then (with --verify) run verify_restore.py.

Options:
  --target-db NAME     Database to create and restore into. Must match
                       test_jivo_quick_commerce_restore* unless --production is given.
  --dump FILE          The .dump file from backup_db.sh. A sibling FILE.sha256 must exist and match
                       (skip with --skip-checksum). A sibling <base>.migrations.dump (schema-only
                       backups) is restored after it.
  --env-file FILE      Read POSTGRES_HOST/PORT/USER/PASSWORD/SSLMODE from a dotenv file
                       (e.g. backend/.env); values are never printed. POSTGRES_DB is ignored here.
  --maintenance-db DB  Database used for CREATE/DROP DATABASE (default: postgres).
  --jobs N             Parallel pg_restore jobs (default 2).
  --drop-existing      Drop the target first if it exists (test_jivo_quick_commerce_restore* only).
  --drop-only          Only drop the target (test_jivo_quick_commerce_restore* only) and exit.
  --verify             Run verify_restore.py on the target afterwards (needs uv + backend/).
  --source-db NAME     With --verify: compare tables and migrations with this DB (read-only).
  --production         Allow a target that is not a test_jivo_quick_commerce_restore* name. The
                       target must not exist yet. Requires --confirm.
  --confirm PHRASE     Must be exactly: RESTORE INTO <target-db>
  --skip-checksum      Do not require a matching .sha256 file.
  --dry-run            Print the plan, change nothing.
  -h, --help           This help.

Exit codes: 0 ok, 1 error, 2 usage or refused by a safety rule, 4 verification failed.

Example (restore drill on the shared dev server):
  infra/backup/restore_db.sh --env-file backend/.env \
    --dump ~/jqc-bk/jivo_quick_commerce_20261104T101500Z_schema.dump \
    --target-db test_jivo_quick_commerce_restore_check --drop-existing --verify \
    --source-db jivo_quick_commerce
  infra/backup/restore_db.sh --env-file backend/.env \
    --target-db test_jivo_quick_commerce_restore_check --drop-only
EOF
}

ENV_FILE="" TARGET="" DUMP="" MAINT_DB="postgres" JOBS=2
DROP_EXISTING=0 DROP_ONLY=0 VERIFY=0 SOURCE_DB="" PRODUCTION=0 CONFIRM="" SKIP_SUM=0 DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --env-file) ENV_FILE="${2:?--env-file needs a value}"; shift 2 ;;
    --target-db) TARGET="${2:?--target-db needs a value}"; shift 2 ;;
    --dump) DUMP="${2:?--dump needs a value}"; shift 2 ;;
    --maintenance-db) MAINT_DB="${2:?--maintenance-db needs a value}"; shift 2 ;;
    --jobs) JOBS="${2:?--jobs needs a value}"; shift 2 ;;
    --drop-existing) DROP_EXISTING=1; shift ;;
    --drop-only) DROP_ONLY=1; shift ;;
    --verify) VERIFY=1; shift ;;
    --source-db) SOURCE_DB="${2:?--source-db needs a value}"; shift 2 ;;
    --production) PRODUCTION=1; shift ;;
    --confirm) CONFIRM="${2-}"; shift 2 ;;
    --skip-checksum) SKIP_SUM=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; jqc_die "unknown option: $1" 2 ;;
  esac
done

# ---------------------------------------------------------------- safety rules (before any I/O)
[ -n "$TARGET" ] || { usage >&2; jqc_die "--target-db is required" 2; }
[[ "$TARGET" =~ $JQC_DB_NAME_RE ]] || jqc_die "refusing unusual database name: $TARGET" 2
[[ "$JOBS" =~ ^[1-9][0-9]?$ ]] || jqc_die "--jobs must be 1-99" 2
[ -z "$SOURCE_DB" ] || [[ "$SOURCE_DB" =~ $JQC_DB_NAME_RE ]] || jqc_die "refusing unusual database name: $SOURCE_DB" 2

is_test_target=0
[[ "$TARGET" =~ $JQC_TEST_RESTORE_RE ]] && is_test_target=1

if [ "$is_test_target" -eq 0 ]; then
  [ "$PRODUCTION" -eq 1 ] || jqc_die "target '$TARGET' is not a test_jivo_quick_commerce_restore* database; refusing (see --production)" 2
  [ "$CONFIRM" = "RESTORE INTO $TARGET" ] || jqc_die "--production needs --confirm \"RESTORE INTO $TARGET\" typed exactly" 2
  if [ "$DROP_EXISTING" -eq 1 ] || [ "$DROP_ONLY" -eq 1 ]; then
    jqc_die "--drop-existing/--drop-only are only allowed for test_jivo_quick_commerce_restore* targets" 2
  fi
fi
[ "$DROP_ONLY" -eq 1 ] || [ -n "$DUMP" ] || { usage >&2; jqc_die "--dump is required" 2; }
[ -z "$SOURCE_DB" ] || [ "$SOURCE_DB" != "$TARGET" ] || jqc_die "--source-db and --target-db are the same" 2

[ -z "$ENV_FILE" ] || jqc_load_env_file "$ENV_FILE"
unset PGDATABASE  # never fall back to the app database for any command below
jqc_env_from_postgres_vars
unset PGDATABASE
jqc_require_conn
jqc_require_tools psql pg_restore

psql_maint() { psql --no-psqlrc --no-password -X -v ON_ERROR_STOP=1 -qAt -d "$MAINT_DB" "$@"; }
db_exists() { [ "$(psql_maint -c "select 1 from pg_database where datname = '$1'")" = "1" ]; }

drop_target() {
  # Re-checked here so no code path can drop anything else.
  [[ "$TARGET" =~ $JQC_TEST_RESTORE_RE ]] || jqc_die "internal: refusing to drop $TARGET" 2
  jqc_log "dropping test database $TARGET"
  psql_maint -c "drop database if exists \"$TARGET\" with (force)"
}

if [ "$DRY_RUN" -eq 1 ]; then
  jqc_log "dry run; server $(jqc_conn_label), maintenance db $MAINT_DB"
  [ "$DROP_ONLY" -eq 0 ] || { echo "drop database if exists \"$TARGET\""; exit 0; }
  [ "$DROP_EXISTING" -eq 0 ] || echo "drop database if exists \"$TARGET\""
  echo "verify sha256 of $DUMP"
  echo "create database \"$TARGET\""
  echo "pg_restore --no-owner --no-privileges --jobs=$JOBS --dbname=$TARGET $DUMP"
  [ "$VERIFY" -eq 0 ] || echo "verify_restore.py --target-db $TARGET ${SOURCE_DB:+--source-db $SOURCE_DB}"
  exit 0
fi

if [ "$DROP_ONLY" -eq 1 ]; then
  drop_target
  exit 0
fi

# ---------------------------------------------------------------- checksum
[ -r "$DUMP" ] || jqc_die "dump not readable: $DUMP"
dump_dir="$(cd "$(dirname "$DUMP")" && pwd)"
dump_name="$(basename "$DUMP")"
mig="$dump_dir/${dump_name%.dump}.migrations.dump"
check_sum() {
  local f="$1" expected actual
  [ -r "$f.sha256" ] || jqc_die "missing checksum file $f.sha256 (or pass --skip-checksum)"
  expected="$(awk '{print $1; exit}' "$f.sha256")"
  actual="$(jqc_sha256 "$f")"
  [ "$expected" = "$actual" ] || jqc_die "checksum mismatch for $(basename "$f"): the dump is corrupt or was changed"
  jqc_log "checksum ok: $(basename "$f")"
}
if [ "$SKIP_SUM" -eq 0 ]; then
  check_sum "$DUMP"
  [ ! -e "$mig" ] || check_sum "$mig"
fi

# ---------------------------------------------------------------- create + restore
if db_exists "$TARGET"; then
  if [ "$DROP_EXISTING" -eq 1 ]; then
    drop_target
  else
    jqc_die "target $TARGET already exists (use --drop-existing for a test target; a production restore always goes into a new database)" 2
  fi
fi

jqc_log "creating $TARGET on $(jqc_conn_label)"
psql_maint -c "create database \"$TARGET\""

jqc_log "restoring $dump_name into $TARGET (jobs=$JOBS)"
t0=$(date +%s)
log="$(mktemp)"
trap 'rm -f "$log"' EXIT
set +e
pg_restore --no-password --no-owner --no-privileges --jobs="$JOBS" --dbname="$TARGET" "$DUMP" 2>"$log"
rc=$?
set -e
# pg_restore exits 1 when any statement failed but carries on. A newer client restoring into an
# older server issues SET for settings the server does not know (e.g. transaction_timeout from
# pg_restore 17+ into PostgreSQL 16); those are harmless and are the only errors tolerated.
if [ "$rc" -ne 0 ]; then
  real_errors="$(grep -E '^pg_restore: error:' "$log" \
    | grep -vE 'unrecognized configuration parameter "(transaction_timeout)"' || true)"
  if [ -n "$real_errors" ]; then
    cat "$log" >&2
    jqc_die "pg_restore failed; $TARGET is incomplete (drop it before retrying)"
  fi
  jqc_log "pg_restore reported only tolerated errors (newer-client SET parameters):"
  grep -E 'unrecognized configuration parameter' "$log" | sort -u >&2 || true
fi
if [ -e "$mig" ]; then
  jqc_log "restoring the django_migrations rows ($(basename "$mig"))"
  set +e
  pg_restore --no-password --no-owner --no-privileges --data-only --dbname="$TARGET" "$mig" 2>"$log"
  rc=$?
  set -e
  if [ "$rc" -ne 0 ] && grep -E '^pg_restore: error:' "$log" | grep -vqE 'unrecognized configuration parameter'; then
    cat "$log" >&2
    jqc_die "restoring django_migrations failed"
  fi
fi
t1=$(date +%s)
jqc_log "restore finished in $((t1 - t0))s"

# ---------------------------------------------------------------- verify
if [ "$VERIFY" -eq 1 ]; then
  repo_root="$(cd "$SCRIPT_DIR/../.." && pwd)"
  verify_args=(--target-db "$TARGET")
  [ -z "$SOURCE_DB" ] || verify_args+=(--source-db "$SOURCE_DB")
  jqc_log "running verify_restore.py"
  if ! uv run --project "$repo_root/backend" python "$SCRIPT_DIR/verify_restore.py" "${verify_args[@]}"; then
    jqc_die "verification FAILED for $TARGET" 4
  fi
fi
