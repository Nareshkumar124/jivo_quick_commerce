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
#   local       the role-definition command (config.settings.local, DEBUG on)
#   staging     config.settings.staging (DEBUG off, docs staff-only) with a throwaway secret key,
#               SSL redirect off, NUM_PROXIES=0. Used for DEBUG-off envelope checks only.
#   redis-down  local, but every Redis URL points at a closed port (6399): resilience checks.
#   daylimit    local with OTP_SEND_LIMIT_PER_10_MIN=50, so the 10/day cap can be reached.
set -euo pipefail

QA_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO="$(cd "$QA_DIR/.." && pwd)"
PORT=8004
HOST=127.0.0.1
LOG_DIR="$QA_DIR/private/logs"
QA_OTP_NUMBERS="+919000000101:123456,+919000000102:123456,+919000000103:123456,+919000000104:123456,+919000000105:123456"

pid_on_port() {
  { ss -ltnpH "sport = :$PORT" 2>/dev/null | grep -o "pid=[0-9]*" | head -1 | cut -d= -f2; } || true
}

check_8001() {
  if ss -ltnH "sport = :8001" | grep -q LISTEN; then echo "dev server 8001: still listening (untouched)"; else echo "WARNING: nothing listening on 8001"; fi
}

cmd="${1:-status}"
case "$cmd" in
  start)
    profile="${2:-local}"
    commit="${3:-HEAD}"
    sha="$(git -C "$REPO" rev-parse --short "$commit")"
    export_dir="/tmp/jivo-qa-$sha"
    if [[ -n "$(pid_on_port)" ]]; then echo "port $PORT busy (pid $(pid_on_port)); run stop first"; exit 1; fi
    if [[ ! -d "$export_dir/backend" ]]; then
      mkdir -p "$export_dir"
      git -C "$REPO" archive "$sha" | tar -x -C "$export_dir"
    fi
    ln -sfn "$REPO/backend/.env" "$export_dir/backend/.env"
    (cd "$export_dir/backend" && uv sync --frozen --quiet)
    mkdir -p "$LOG_DIR"
    log="$LOG_DIR/instance-$profile-$(date +%Y%m%d-%H%M%S).log"

    env_vars=(
      "REDIS_URL=redis://localhost:6380/5"
      "CHANNELS_REDIS_URL=redis://localhost:6380/6"
      "CELERY_BROKER_URL=redis://localhost:6380/7"
      "OTP_TEST_NUMBERS=$QA_OTP_NUMBERS"
      "DJANGO_SETTINGS_MODULE=config.settings.local"
      "PYTHONUNBUFFERED=1"
    )
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
      *) echo "unknown profile $profile"; exit 2 ;;
    esac
    (cd "$export_dir/backend" && env "${env_vars[@]}" nohup uv run python manage.py runserver "$HOST:$PORT" --noreload >"$log" 2>&1 &)
    for _ in $(seq 1 60); do
      if curl -s -o /dev/null "http://$HOST:$PORT/health/live"; then break; fi
      sleep 1
    done
    echo "$profile" > "$QA_DIR/private/.instance-profile"
    echo "$sha" > "$QA_DIR/private/.instance-commit"
    echo "started profile=$profile commit=$sha pid=$(pid_on_port) log=${log#$QA_DIR/}"
    ;;
  stop)
    pid="$(pid_on_port)"
    if [[ -z "$pid" ]]; then echo "nothing on $PORT"; else
      kill "$pid"; for _ in $(seq 1 20); do [[ -z "$(pid_on_port)" ]] && break; sleep 0.5; done
      echo "stopped pid $pid on $PORT"
    fi
    rm -f "$QA_DIR/private/.instance-profile"
    check_8001
    ;;
  status)
    pid="$(pid_on_port)"
    echo "8004: ${pid:-not running} profile=$(cat "$QA_DIR/private/.instance-profile" 2>/dev/null || echo -)"
    check_8001
    ;;
  *) echo "usage: $0 start [profile] [commit] | stop | status"; exit 2 ;;
esac
