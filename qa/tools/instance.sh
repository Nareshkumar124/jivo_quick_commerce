#!/usr/bin/env bash
# QA-owned backend instance on 127.0.0.1:8004 (never 8001, never Redis 6379).
#
#   qa/tools/instance.sh start [profile] [commit]   # profile: local (default) | staging | redis-down | daylimit
#   qa/tools/instance.sh stop
#   qa/tools/instance.sh status
#
# The backend under test is a clean `git archive` export of <commit> (default: HEAD) in
# /tmp/jivo-qa-<sha>/, so uncommitted work in progress in backend/ is never what gets tested.
# backend/.env (DB credentials) is symlinked, never copied or printed.
#
# Profiles (all use Redis DBs 5-7 on 6380 and the QA fixed-OTP numbers +9190000001xx):
#   local         the role-definition command (config.settings.local, DEBUG on)
#   staging       config.settings.staging (DEBUG off, docs staff-only) with a throwaway secret key,
#                 SSL redirect off, NUM_PROXIES=0. Used for DEBUG-off envelope checks only.
#   redis-down    local, but every Redis URL points at a closed port (6399): resilience checks.
#   daylimit      local with OTP_SEND_LIMIT_PER_10_MIN=50, so the 10/day cap can be reached.
#   dispatchfast / riderclock / triggerplaced / gwdown / cancelplaced / wsrecheck: local with the
#                 timers or switches of 01 §9.2 and §6 (see the case statement below).
#   shortsession  local with the staff session limits shortened (idle 90 s, absolute 180 s) so
#                 BUG-0006 can be verified black-box. The app's touch interval is 60 s.
#   clock         local with the process clock shifted (QA harness, like libfaketime): set
#                 QA_FAKE_NOW to an ISO datetime, e.g. 2026-11-03T23:30:00+05:30. Implemented by
#                 qa/tools/clock/sitecustomize.py on PYTHONPATH (shifts django.utils.timezone.now
#                 only). Read-only checks only (store open/closed); never write on this profile.
#   db-down       staging settings (DEBUG off) whose database is reached through a QA relay on
#                 127.0.0.1:6398 that is stopped right after startup (QA_DB=localdb only): a safe
#                 trigger for the 500 SERVER_ERROR envelope (P0-TC-09) without touching anything.
#
# Database: the remote dev DB from backend/.env (default). QA_DB=localdb also loads the
# temporary local PostGIS credentials from backend/.env.localdb (DL-36 fallback). Neither file
# is ever printed or copied. In a git worktree without backend/.env, the main checkout's files
# are used (resolved through git's common dir), or QA_BACKEND_ENV / QA_BACKEND_ENV_LOCALDB.
set -euo pipefail

QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$QA_DIR/.." && pwd)"
MAIN_CHECKOUT="$(cd "$(git -C "$REPO" rev-parse --path-format=absolute --git-common-dir)/.." && pwd)"
PORT=8004
HOST=127.0.0.1
LOG_DIR="$QA_DIR/private/logs"
QA_OTP_NUMBERS="+919000000101:123456,+919000000102:123456,+919000000103:123456,+919000000104:123456,+919000000105:123456,+919000000106:123456,+919000000107:123456,+919000000108:123456,+919000000109:123456,+919000000110:123456"

backend_env() {  # $1 = .env | .env.localdb
  local override="${2:-}"
  if [[ -n "$override" ]]; then echo "$override"; return; fi
  if [[ -f "$REPO/backend/$1" ]]; then echo "$REPO/backend/$1"; else echo "$MAIN_CHECKOUT/backend/$1"; fi
}
ENV_FILE="$(backend_env .env "${QA_BACKEND_ENV:-}")"
LOCALDB_FILE="$(backend_env .env.localdb "${QA_BACKEND_ENV_LOCALDB:-}")"

# Windows (Git Bash, stage 4, 2026-11-10): no `ss`, no real symlinks (`ln -s` would COPY
# backend/.env into the export) and Git Bash `kill` cannot stop a native process. There the
# instance runs in place from this checkout's backend/ (it must be clean at <commit>), the PID is
# read from `netstat -ano` and stopped with `taskkill`.
WINDOWS=0
case "$(uname -s)" in MINGW*|MSYS*|CYGWIN*) WINDOWS=1 ;; esac

pid_on_port() {  # $1 = port (default $PORT)
  local port="${1:-$PORT}"
  if [[ "$WINDOWS" == 1 ]]; then
    { netstat -ano -p tcp 2>/dev/null | awk -v a="$HOST:$port" '$2 == a && $4 == "LISTENING" {print $5; exit}'; } || true
  else
    { ss -ltnpH "sport = :$port" 2>/dev/null | grep -o "pid=[0-9]*" | head -1 | cut -d= -f2; } || true
  fi
}

kill_pid() {
  if [[ "$WINDOWS" == 1 ]]; then taskkill //PID "$1" //T //F >/dev/null 2>&1 || true; else kill "$1"; fi
}

check_8001() {  # 8001 is never touched (on the stage-4 PC it belongs to another project)
  if [[ -n "$(pid_on_port 8001)" ]]; then echo "port 8001: listening (untouched)"; else echo "port 8001: not listening (untouched)"; fi
}

cmd="${1:-status}"
case "$cmd" in
  start)
    profile="${2:-local}"
    commit="${3:-HEAD}"
    sha="$(git -C "$REPO" rev-parse --short "$commit")"
    if [[ -n "$(pid_on_port)" ]]; then echo "port $PORT busy (pid $(pid_on_port)); run stop first"; exit 1; fi
    [[ -f "$ENV_FILE" ]] || { echo "backend .env not found (set QA_BACKEND_ENV)"; exit 1; }
    if [[ "$WINDOWS" == 1 || "${QA_INPLACE:-0}" == 1 ]]; then
      head_sha="$(git -C "$REPO" rev-parse --short HEAD)"
      [[ "$sha" == "$head_sha" ]] || { echo "in-place mode tests HEAD only ($head_sha), not $sha"; exit 2; }
      if [[ -n "$(git -C "$REPO" status --porcelain -- backend)" ]]; then
        echo "backend/ has uncommitted changes: the in-place instance would not be $sha"; exit 2
      fi
      [[ -f "$REPO/backend/.env" ]] || { echo "in-place mode needs backend/.env in this checkout"; exit 1; }
      export_dir="$REPO"
    else
      export_dir="/tmp/jivo-qa-$sha"
      if [[ ! -d "$export_dir/backend" ]]; then
        mkdir -p "$export_dir"
        git -C "$REPO" archive "$sha" | tar -x -C "$export_dir"
      fi
      ln -sfn "$ENV_FILE" "$export_dir/backend/.env"
    fi
    (cd "$export_dir/backend" && uv sync --frozen --quiet)
    mkdir -p "$LOG_DIR"
    log="$LOG_DIR/instance-$profile-$(date +%Y%m%d-%H%M%S).log"

    env_vars=(
      "REDIS_URL=redis://127.0.0.1:6380/5"
      "CHANNELS_REDIS_URL=redis://127.0.0.1:6380/6"
      "CELERY_BROKER_URL=redis://127.0.0.1:6380/7"
      "OTP_TEST_NUMBERS=$QA_OTP_NUMBERS"
      "DJANGO_SETTINGS_MODULE=config.settings.local"
      "SMS_BACKEND=apps.notifications.sms.ConsoleSmsBackend"
      "PYTHONUNBUFFERED=1"
      "PYTHONIOENCODING=utf-8"
    )
    # Extra settings for this run only (same values must reach the QA worker: QA_EXTRA_ENV is
    # also read by tests/p4_support.py). Format: "KEY=value KEY2=value2".
    for kv in ${QA_EXTRA_ENV:-}; do env_vars+=("$kv"); done
    case "$profile" in
      local) ;;
      daylimit) env_vars+=("OTP_SEND_LIMIT_PER_10_MIN=50") ;;
      redis-down)
        env_vars+=(
          "REDIS_URL=redis://localhost:6399/5"
          "CHANNELS_REDIS_URL=redis://localhost:6399/6"
          "CELERY_BROKER_URL=redis://localhost:6399/7"
        ) ;;
      staging)
        secret="$(python3 -c 'import secrets; print(secrets.token_urlsafe(64))')"
        env_vars+=(
          "DJANGO_SETTINGS_MODULE=config.settings.staging"
          "DJANGO_SECRET_KEY=$secret"
          "DJANGO_ALLOWED_HOSTS=127.0.0.1,localhost"
          "NUM_PROXIES=0"
          "DJANGO_SECURE_SSL_REDIRECT=false"
        ) ;;
      shortsession)
        env_vars+=(
          "DJANGO_STAFF_SESSION_IDLE_SECONDS=90"
          "DJANGO_STAFF_SESSION_MAX_AGE_SECONDS=180"
        ) ;;
      # Timer and switch profiles from 01 §9.2 / §6 (environment only, no code):
      dispatchfast) env_vars+=("OFFER_TIMEOUT_SECONDS=10" "DISPATCH_TIMEOUT_SECONDS=60"
                               "DISPATCH_UNASSIGNED_PAUSE_SECONDS=15" "DISPATCH_RETRY_SECONDS=5") ;;
      riderclock) env_vars+=("RIDER_NOT_REACHABLE_WAIT_SECONDS=20" "RIDER_RECENT_TASK_SECONDS=60") ;;
      triggerplaced) env_vars+=("DISPATCH_TRIGGER=PLACED") ;;
      # stage 4: dispatchfast timers + a 40 s auto-accept delay and a 20 s acceptance SLA, so a
      # QA-02 order stays PLACED long enough to observe (P5-TC-38/47/57, P6-TC-33).
      s4timers) env_vars+=("OFFER_TIMEOUT_SECONDS=10" "DISPATCH_TIMEOUT_SECONDS=60"
                           "DISPATCH_UNASSIGNED_PAUSE_SECONDS=15" "DISPATCH_RETRY_SECONDS=5"
                           "AUTO_ACCEPT_DELAY_SECONDS=40" "STORE_ACCEPTANCE_SLA_SECONDS=20") ;;
      gwdown) env_vars+=("FAKE_GATEWAY_DOWN=1") ;;
      cancelplaced) env_vars+=("CUSTOMER_CANCEL_UNTIL=PLACED") ;;
      wsrecheck) env_vars+=("WS_RIDER_RECHECK_SECONDS=5" "WS_OPS_RECHECK_SECONDS=5") ;;
      clock)
        [[ -n "${QA_FAKE_NOW:-}" ]] || { echo "clock profile needs QA_FAKE_NOW"; exit 2; }
        mkdir -p "$QA_DIR/private"; rm -f "$QA_DIR/private/.instance-clock-offset"
        env_vars+=("QA_FAKE_NOW=$QA_FAKE_NOW" "PYTHONPATH=$QA_DIR/tools/clock" "QA_CLOCK_FILE=$QA_DIR/private/.instance-clock-offset") ;;
      db-down)
        [[ "${QA_DB:-remote}" == "localdb" ]] || { echo "db-down needs QA_DB=localdb (the relay never targets the shared remote DB)"; exit 2; }
        secret="$(python3 -c 'import secrets; print(secrets.token_urlsafe(64))')"
        env_vars+=(
          "POSTGRES_HOST=127.0.0.1" "POSTGRES_PORT=6398"
          "DJANGO_SETTINGS_MODULE=config.settings.staging" "DJANGO_SECRET_KEY=$secret"
          "DJANGO_ALLOWED_HOSTS=127.0.0.1,localhost" "NUM_PROXIES=0" "DJANGO_SECURE_SSL_REDIRECT=false"
        ) ;;
      *) echo "unknown profile $profile"; exit 2 ;;
    esac
    db_label="remote"
    if [[ "${QA_DB:-remote}" == "localdb" ]]; then
      [[ -f "$LOCALDB_FILE" ]] || { echo "backend .env.localdb not found"; exit 1; }
      db_label="localdb"
    fi
    (
      cd "$export_dir/backend"
      if [[ "$db_label" == "localdb" ]]; then set -a; . "$LOCALDB_FILE"; set +a; fi
      if [[ "$profile" == "db-down" ]]; then  # relay up for startup only (see tools/tcp_relay.py)
        nohup python3 "$QA_DIR/tools/tcp_relay.py" 6398 "$POSTGRES_HOST" "$POSTGRES_PORT" >/dev/null 2>&1 &
        echo $! > "$QA_DIR/private/.db-relay-pid"
        sleep 1
      fi
      env "${env_vars[@]}" nohup uv run python manage.py runserver "$HOST:$PORT" --noreload >"$log" 2>&1 &
    )
    for _ in $(seq 1 60); do
      if curl -s -o /dev/null "http://$HOST:$PORT/health/live"; then break; fi
      sleep 1
    done
    if [[ "$profile" == "db-down" && -f "$QA_DIR/private/.db-relay-pid" ]]; then
      kill "$(cat "$QA_DIR/private/.db-relay-pid")" 2>/dev/null || true
      rm -f "$QA_DIR/private/.db-relay-pid"
      echo "db-down: relay stopped after startup; database connections are now refused"
    fi
    mkdir -p "$QA_DIR/private"
    echo "$profile" > "$QA_DIR/private/.instance-profile"
    echo "$sha" > "$QA_DIR/private/.instance-commit"
    echo "$db_label" > "$QA_DIR/private/.instance-db"
    echo "started profile=$profile commit=$sha db=$db_label pid=$(pid_on_port) log=${log#$QA_DIR/}"
    ;;
  stop)
    pid="$(pid_on_port)"
    if [[ -z "$pid" ]]; then echo "nothing on $PORT"; else
      kill_pid "$pid"; for _ in $(seq 1 20); do [[ -z "$(pid_on_port)" ]] && break; sleep 0.5; done
      echo "stopped pid $pid on $PORT"
    fi
    rm -f "$QA_DIR/private/.instance-profile"
    check_8001
    ;;
  status)
    pid="$(pid_on_port)"
    echo "8004: ${pid:-not running} profile=$(cat "$QA_DIR/private/.instance-profile" 2>/dev/null || echo -) db=$(cat "$QA_DIR/private/.instance-db" 2>/dev/null || echo -)"
    check_8001
    ;;
  *) echo "usage: $0 start [profile] [commit] | stop | status"; exit 2 ;;
esac
