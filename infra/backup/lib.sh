# Shared helpers for infra/backup/*.sh. Sourced, never executed directly.
#
# Connection settings come from the standard libpq variables (PGHOST, PGPORT, PGUSER, PGPASSWORD,
# PGDATABASE, PGSSLMODE). As a convenience they are filled from POSTGRES_* (the backend's names),
# or from a dotenv file given with --env-file. Values are exported to child processes only and are
# never printed: do not add `set -x` to these scripts.

# shellcheck shell=bash

export LC_ALL=C  # also set by each script before sourcing; [a-z] must mean ASCII a-z

# Restore targets that need no production flag (CLAUDE.md: tests may only create or drop
# databases named test_jivo_quick_commerce*). Nothing else is ever dropped by these scripts.
# shellcheck disable=SC2034  # used by the scripts that source this file
JQC_TEST_RESTORE_RE='^test_jivo_quick_commerce_restore[a-z0-9_]*$'
# Any database name these scripts accept at all (keeps identifiers safe to quote in SQL).
# shellcheck disable=SC2034
JQC_DB_NAME_RE='^[a-z_][a-z0-9_]{0,62}$'

jqc_log() { printf '[%s] %s\n' "$(date -u +%H:%M:%SZ)" "$*" >&2; }
jqc_die() { jqc_log "ERROR: $1"; exit "${2:-1}"; }

# Absolute physical path of PATH, which need not exist yet (nothing is created).
jqc_abspath() {
  local p="$1" tail=""
  while [ ! -d "$p" ]; do
    tail="/$(basename "$p")$tail"
    p="$(dirname "$p")"
  done
  printf '%s%s' "$(cd "$p" && pwd -P)" "$tail"
}

# Read POSTGRES_HOST/PORT/DB/USER/PASSWORD/SSLMODE from a dotenv file into PG* variables.
# Only those six keys are read; every other line (and every other secret) is ignored.
jqc_load_env_file() {
  local file="$1" line key val
  [ -r "$file" ] || jqc_die "env file not readable: $file"
  while IFS= read -r line || [ -n "$line" ]; do
    line="${line%$'\r'}"
    line="${line#export }"
    case "$line" in
      POSTGRES_HOST=*|POSTGRES_PORT=*|POSTGRES_DB=*|POSTGRES_USER=*|POSTGRES_PASSWORD=*|POSTGRES_SSLMODE=*) ;;
      *) continue ;;
    esac
    key="${line%%=*}"
    val="${line#*=}"
    # strip one level of matching quotes
    if [ "${#val}" -ge 2 ]; then
      case "$val" in
        \"*\") val="${val:1:${#val}-2}" ;;
        \'*\') val="${val:1:${#val}-2}" ;;
      esac
    fi
    case "$key" in
      POSTGRES_HOST) export PGHOST="$val" ;;
      POSTGRES_PORT) export PGPORT="$val" ;;
      POSTGRES_DB) export PGDATABASE="$val" ;;
      POSTGRES_USER) export PGUSER="$val" ;;
      POSTGRES_PASSWORD) export PGPASSWORD="$val" ;;
      POSTGRES_SSLMODE) export PGSSLMODE="$val" ;;
    esac
  done < "$file"
}

# Fill PG* from POSTGRES_* where PG* is unset (the backend's variable names).
jqc_env_from_postgres_vars() {
  [ -n "${PGHOST:-}" ] || [ -z "${POSTGRES_HOST:-}" ] || export PGHOST="$POSTGRES_HOST"
  [ -n "${PGPORT:-}" ] || [ -z "${POSTGRES_PORT:-}" ] || export PGPORT="$POSTGRES_PORT"
  [ -n "${PGDATABASE:-}" ] || [ -z "${POSTGRES_DB:-}" ] || export PGDATABASE="$POSTGRES_DB"
  [ -n "${PGUSER:-}" ] || [ -z "${POSTGRES_USER:-}" ] || export PGUSER="$POSTGRES_USER"
  [ -n "${PGPASSWORD:-}" ] || [ -z "${POSTGRES_PASSWORD:-}" ] || export PGPASSWORD="$POSTGRES_PASSWORD"
  [ -n "${PGSSLMODE:-}" ] || [ -z "${POSTGRES_SSLMODE:-}" ] || export PGSSLMODE="$POSTGRES_SSLMODE"
  export PGCONNECT_TIMEOUT="${PGCONNECT_TIMEOUT:-10}"
  export PGAPPNAME="${PGAPPNAME:-jqc-backup}"
}

jqc_require_conn() {
  [ -n "${PGHOST:-}" ] || jqc_die "no database host: set PGHOST/POSTGRES_HOST or pass --env-file"
  [ -n "${PGUSER:-}" ] || jqc_die "no database user: set PGUSER/POSTGRES_USER or pass --env-file"
}

jqc_require_tools() {
  local t
  for t in "$@"; do
    command -v "$t" >/dev/null 2>&1 || jqc_die "'$t' not found on PATH (PostgreSQL client tools, same major version as the server or newer)"
  done
}

jqc_sha256() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    jqc_die "neither sha256sum nor shasum is available"
  fi
}

jqc_file_size() { wc -c < "$1" | tr -d ' '; }

# Connection target for logs. The host and role are not printed unless JQC_SHOW_HOST=1: logs of
# these scripts end up in CI output and reports, and the repo is public.
jqc_conn_label() {
  if [ "${JQC_SHOW_HOST:-0}" = "1" ]; then
    printf '%s@%s:%s' "${PGUSER:-?}" "${PGHOST:-?}" "${PGPORT:-5432}"
  else
    printf 'the configured server (port %s)' "${PGPORT:-5432}"
  fi
}
