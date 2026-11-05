#!/usr/bin/env bash
# Logical backup of the Jivo Quick Commerce PostgreSQL + PostGIS database (docs/deployment.md §7).
#
# pg_dump is read-only on the source database. Each run writes a new, timestamped set of files
# and never overwrites an existing one:
#   <db>_<UTC stamp>[_schema].dump           pg_dump custom format (-Fc), restore with restore_db.sh
#   <db>_<UTC stamp>[_schema].migrations.dump  --schema-only only: the django_migrations rows, so
#                                            verify_restore.py can check the migration state
#   <file>.sha256                            checksum of each dump (sha256sum format)
#   <db>_<UTC stamp>[_schema].manifest.json  what was dumped, with which tool versions, checksums
#
# A full dump holds customer PII and KYC data: keep it out of the repo, store it encrypted, and
# restrict who can read it (docs/deployment.md §7.4). Files are created with umask 077.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=infra/backup/lib.sh
. "$SCRIPT_DIR/lib.sh"

usage() {
  cat <<'EOF'
Usage: backup_db.sh [options]

Dump one database with pg_dump -Fc, write a sha256 checksum and a manifest, and optionally upload.

Options:
  --env-file FILE   Read POSTGRES_HOST/PORT/DB/USER/PASSWORD/SSLMODE from a dotenv file
                    (e.g. backend/.env). Values are never printed. Without it the libpq PG*
                    variables are used, falling back to POSTGRES_*.
  --db NAME         Database to dump (default: PGDATABASE / POSTGRES_DB).
  --out-dir DIR     Output directory (default: $BACKUP_DIR, else
                    ~/.local/share/jivoqc-backups). Must be outside the git repo.
  --schema-only     Dump the schema only (no table data), plus the django_migrations rows in a
                    second file. Holds no PII; used for restore dry runs.
  --upload          After a successful dump, copy the files to $BACKUP_UPLOAD_URI.
                    Supported: s3://bucket/prefix (AWS CLI, SSE-KMS). Placeholder until D-05:
                    without BACKUP_UPLOAD_URI the upload step refuses and exits 3.
  --dry-run         Print what would run (no credentials), change nothing.
  -h, --help        This help.

Exit codes: 0 ok, 1 error, 2 usage, 3 upload not configured.

Examples:
  infra/backup/backup_db.sh --env-file backend/.env --schema-only --out-dir /tmp/jqc-bk
  BACKUP_UPLOAD_URI=s3://jivoqc-backups-prod/db infra/backup/backup_db.sh --upload
EOF
}

ENV_FILE="" DB="" OUT_DIR="${BACKUP_DIR:-$HOME/.local/share/jivoqc-backups}"
SCHEMA_ONLY=0 UPLOAD=0 DRY_RUN=0

while [ $# -gt 0 ]; do
  case "$1" in
    --env-file) ENV_FILE="${2:?--env-file needs a value}"; shift 2 ;;
    --db) DB="${2:?--db needs a value}"; shift 2 ;;
    --out-dir) OUT_DIR="${2:?--out-dir needs a value}"; shift 2 ;;
    --schema-only) SCHEMA_ONLY=1; shift ;;
    --upload) UPLOAD=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; jqc_die "unknown option: $1" 2 ;;
  esac
done

[ -z "$ENV_FILE" ] || jqc_load_env_file "$ENV_FILE"
jqc_env_from_postgres_vars
DB="${DB:-${PGDATABASE:-}}"
[ -n "$DB" ] || jqc_die "no database: pass --db or set PGDATABASE/POSTGRES_DB" 2
[[ "$DB" =~ $JQC_DB_NAME_RE ]] || jqc_die "refusing unusual database name: $DB" 2
jqc_require_conn
jqc_require_tools pg_dump

# Never write dumps inside the git work tree (the repo is public).
if git_top="$(git -C "$SCRIPT_DIR" rev-parse --show-toplevel 2>/dev/null)"; then
  out_abs="$(jqc_abspath "$OUT_DIR")"
  top_abs="$(cd "$git_top" && pwd -P)"
  case "$out_abs/" in
    "$top_abs"/*) jqc_die "--out-dir is inside the git repo ($out_abs); choose a directory outside it" 2 ;;
  esac
fi

stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mode_label="full"; [ "$SCHEMA_ONLY" -eq 0 ] || mode_label="schema-only"
suffix=""; [ "$SCHEMA_ONLY" -eq 0 ] || suffix="_schema"
base="${DB}_${stamp}${suffix}"
dump="$OUT_DIR/$base.dump"
mig="$OUT_DIR/$base.migrations.dump"
manifest="$OUT_DIR/$base.manifest.json"

mode_args=()
[ "$SCHEMA_ONLY" -eq 0 ] || mode_args=(--schema-only)

if [ "$DRY_RUN" -eq 1 ]; then
  jqc_log "dry run; target $(jqc_conn_label)/$DB"
  echo "pg_dump -Fc ${mode_args[*]:-} --dbname=$DB --file=$dump"
  [ "$SCHEMA_ONLY" -eq 0 ] || echo "pg_dump -Fc --data-only --table=public.django_migrations --dbname=$DB --file=$mig"
  [ "$UPLOAD" -eq 0 ] || echo "upload to \${BACKUP_UPLOAD_URI:-<not set>}"
  exit 0
fi

umask 077
mkdir -p "$OUT_DIR"
[ ! -e "$dump" ] || jqc_die "refusing to overwrite $dump"

jqc_log "dumping $DB from $(jqc_conn_label) ($mode_label)"
t0=$(date +%s)
pg_dump --format=custom --compress=6 --no-password ${mode_args[@]+"${mode_args[@]}"} --dbname="$DB" --file="$dump"
files=("$dump")
if [ "$SCHEMA_ONLY" -eq 1 ]; then
  pg_dump --format=custom --no-password --data-only --table=public.django_migrations \
    --dbname="$DB" --file="$mig"
  files+=("$mig")
fi
t1=$(date +%s)

server_version="$(psql --no-psqlrc --no-password -XAtq -d "$DB" -c 'show server_version' 2>/dev/null || echo unknown)"
postgis_version="$(psql --no-psqlrc --no-password -XAtq -d "$DB" \
  -c "select extversion from pg_extension where extname='postgis'" 2>/dev/null || echo unknown)"

entries=""
for f in "${files[@]}"; do
  sum="$(jqc_sha256 "$f")"
  (cd "$(dirname "$f")" && printf '%s  %s\n' "$sum" "$(basename "$f")" > "$(basename "$f").sha256")
  entries="${entries}${entries:+,}
    {\"file\": \"$(basename "$f")\", \"bytes\": $(jqc_file_size "$f"), \"sha256\": \"$sum\"}"
done

git_sha="$(git -C "$SCRIPT_DIR" rev-parse --short HEAD 2>/dev/null || echo unknown)"
cat > "$manifest" <<EOF
{
  "database": "$DB",
  "mode": "$mode_label",
  "created_at_utc": "$stamp",
  "duration_seconds": $((t1 - t0)),
  "server_version": "$server_version",
  "postgis_version": "${postgis_version:-none}",
  "pg_dump_version": "$(pg_dump --version | awk '{print $NF}')",
  "repo_commit": "$git_sha",
  "files": [$entries
  ]
}
EOF
jqc_log "wrote $dump ($(jqc_file_size "$dump") bytes) in $((t1 - t0))s; manifest $manifest"

if [ "$UPLOAD" -eq 1 ]; then
  uri="${BACKUP_UPLOAD_URI:-}"
  if [ -z "$uri" ]; then
    jqc_log "upload requested but BACKUP_UPLOAD_URI is not set (no backup bucket until D-05)"
    exit 3
  fi
  case "$uri" in
    s3://*)
      jqc_require_tools aws
      for f in "${files[@]}" "${files[@]/%/.sha256}" "$manifest"; do
        aws s3 cp --only-show-errors --sse aws:kms "$f" "${uri%/}/$(basename "$f")"
      done
      jqc_log "uploaded ${#files[@]} dump file(s) + checksums + manifest to ${uri%/}/"
      ;;
    *) jqc_die "unsupported BACKUP_UPLOAD_URI scheme (only s3:// is implemented)" 3 ;;
  esac
fi
