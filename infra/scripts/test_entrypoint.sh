#!/usr/bin/env bash
# Tests for the production image's jqc-entrypoint (backend/Dockerfile heredoc; P8 OWASP M8).
#
# Usage: bash infra/scripts/test_entrypoint.sh      (from anywhere; needs only bash + sh + awk)
#        bash infra/scripts/test_entrypoint.sh --help
#
# Extracts the entrypoint from the Dockerfile and runs it with a stub `python` on PATH, so no image
# build, Django or database is needed. Checks:
#   1. a failing deploy check blocks the start (the command never runs, non-zero exit)
#   2. a passing check starts the command
#   3. JQC_SKIP_STARTUP_CHECK=1 is refused under production/staging/deployed settings, for
#      gunicorn, uvicorn, celery and jqc-release alike (exit 64, command never runs)
#   4. under local settings the skip is allowed and prints a WARNING
# Exit 0 when all pass, 1 otherwise. Writes only to a temp dir it removes.

set -euo pipefail
export LC_ALL=C

if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
  sed -n '2,14p' "$0"; exit 0
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

awk "/^COPY --chmod=0755 <<'SHEOF' \/usr\/local\/bin\/jqc-entrypoint/{f=1;next} /^SHEOF/{f=0} f" \
  "$ROOT/backend/Dockerfile" > "$tmp/jqc-entrypoint"
[ -s "$tmp/jqc-entrypoint" ] || { echo "FAIL: entrypoint not found in backend/Dockerfile"; exit 1; }
chmod +x "$tmp/jqc-entrypoint"

# Stub python: exit code from STUB_CHECK_RC (the deploy check result).
mkdir -p "$tmp/bin"
printf '#!/bin/sh\necho "stub python $*" >&2\nexit "${STUB_CHECK_RC:-0}"\n' > "$tmp/bin/python"
# Stub commands record that they ran.
for c in gunicorn uvicorn celery jqc-release; do
  printf '#!/bin/sh\necho ran > "%s/ran"\n' "$tmp" > "$tmp/bin/$c"
done
chmod +x "$tmp/bin/"*

failures=0
run() {  # run <expected rc> <expect command ran: yes|no> <description> -- env... -- cmd
  local want_rc="$1" want_ran="$2" desc="$3"; shift 3
  rm -f "$tmp/ran"
  local rc=0
  env PATH="$tmp/bin:$PATH" "$@" "$tmp/jqc-entrypoint" "${CMD[@]}" >"$tmp/out" 2>&1 || rc=$?
  local ran=no; [ -e "$tmp/ran" ] && ran=yes
  if [ "$rc" = "$want_rc" ] && [ "$ran" = "$want_ran" ]; then
    echo "PASS: $desc"
  else
    echo "FAIL: $desc (rc=$rc want $want_rc, ran=$ran want $want_ran)"; sed 's/^/    /' "$tmp/out"
    failures=$((failures + 1))
  fi
}

CMD=(gunicorn config.asgi:application)
run 1 no "failing deploy check blocks start (production)" \
  DJANGO_SETTINGS_MODULE=config.settings.production STUB_CHECK_RC=1
run 0 yes "passing deploy check starts the command" \
  DJANGO_SETTINGS_MODULE=config.settings.production STUB_CHECK_RC=0

for settings in config.settings.production config.settings.staging config.settings.deployed; do
  for c in gunicorn uvicorn celery jqc-release; do
    CMD=("$c")
    run 64 no "skip refused: $settings / $c" \
      DJANGO_SETTINGS_MODULE="$settings" JQC_SKIP_STARTUP_CHECK=1 STUB_CHECK_RC=0
  done
done

CMD=(gunicorn)
run 0 yes "skip allowed under local settings" \
  DJANGO_SETTINGS_MODULE=config.settings.local JQC_SKIP_STARTUP_CHECK=1 STUB_CHECK_RC=1
if grep -q "WARNING: JQC_SKIP_STARTUP_CHECK=1" "$tmp/out"; then
  echo "PASS: local skip prints a WARNING"
else
  echo "FAIL: local skip printed no WARNING"; failures=$((failures + 1))
fi

if [ "$failures" -ne 0 ]; then
  echo "test_entrypoint: $failures failed"
  exit 1
fi
echo "test_entrypoint: all passed"
