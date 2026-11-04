---
name: local-stack
description: "Start, stop, restart and health-check the local Jivo dev stack on this Windows machine (native Redis 6380, MinIO and Mailpit, Django :8001, Celery worker and beat). Use whenever the user asks to start/restart the server, the app can't reach the backend, :8001 is down, Celery tasks aren't running, or after a merge or migration that needs a restart."
---

# Local stack (no Docker)

Everything runs natively from the **main tree on `develop`** (`/c/jivo_projects/jivo_quick_commerce`). The :8001 server only ever runs merged code. Never use port 6379 or the `redis-chai` / `mongo-chai` containers (another project). 5432 and 8000 are taken.

| Service | Port | Start |
|---|---|---|
| Redis | 6380 | `redis-server --port 6380 --bind 127.0.0.1` |
| MinIO | 9000/9001 | `dev-services.ps1 -Action start` |
| Mailpit | 1025/8025 | same script |
| Django (ASGI dev) | 8001 | `uv run python manage.py runserver 127.0.0.1:8001` |
| Celery worker | – | `uv run celery -A config worker --pool threads -l info` |
| Celery beat | – | `uv run celery -A config beat -l info` (DatabaseScheduler from settings) |

## Status
```bash
redis-cli -p 6380 ping                                   # PONG
powershell -NoProfile -ExecutionPolicy Bypass -File "C:/jivo_projects/jivo_quick_commerce/infra/scripts/windows/dev-services.ps1" -Action status
curl -s http://127.0.0.1:8001/health/ready               # DB + Redis checks; /health/live = process only
netstat -ano | grep -E ':(6380|8001|9000|9001|1025|8025) .*LISTEN'
```
Workers: check the background task list (or `tasklist | grep -i celery` / `ps -W | grep -i celery`).

## Start (order matters)
Use the Bash tool with `run_in_background: true` for every long-running process (no `&`, no `nohup`). Remember each task ID; you'll need it to stop the process.
1. Redis: `redis-server --port 6380 --bind 127.0.0.1` (background). Skip if `ping` already answers.
2. MinIO + Mailpit: `powershell -NoProfile -ExecutionPolicy Bypass -File "C:/jivo_projects/jivo_quick_commerce/infra/scripts/windows/dev-services.ps1" -Action start` (first time on a machine: `-Action init` creates the buckets). Optional `-Service minio|mailpit`.
3. Django, Celery worker, Celery beat: **three separate background tasks**, each:
   ```bash
   cd /c/jivo_projects/jivo_quick_commerce/backend && unset POSTGRES_HOST POSTGRES_PORT POSTGRES_DB POSTGRES_USER POSTGRES_PASSWORD && uv run <command from the table>
   ```
   **Never `celery worker -B`**: embedded beat is refused on Windows. The worker must use `--pool threads` (prefork doesn't work on Windows).
4. Verify with `curl -s http://127.0.0.1:8001/health/ready`. If the DB check fails, the remote DB may be unreachable (see DL-36: temporary local PostGIS `jivoqc-pg-local` on 5433 via `set -a; . backend/.env.localdb; set +a`). Ask before switching DBs.

The unset line matters: stale `POSTGRES_*` in the shell would override `backend/.env`. Never print `backend/.env`.

## Stop / restart
- Background processes you started: stop them with **TaskStop** (load it via ToolSearch `select:TaskStop`) using the task ID. That kills the process tree.
- If the task ID is lost (new session), find the PID and kill it:
  ```bash
  netstat -ano | grep ':8001 .*LISTEN'          # last column = PID
  taskkill //PID <pid> //T //F                  # Git Bash needs // for switches
  ```
  For Celery, `tasklist //V | grep -i celery` or `wmic process where "commandline like '%celery%'" get processid,commandline`. Kill only this project's processes (command line contains `jivo_quick_commerce`).
- `runserver` autoreloads Python changes, but **restart Django + worker + beat** after: a merge into develop, new migrations applied, `.env` changes, new Celery tasks or beat schedules, installed packages (`uv sync`).
- MinIO/Mailpit: `dev-services.ps1 -Action stop` (or `-Service minio`).
- Redis: TaskStop its task, or `redis-cli -p 6380 shutdown nosave` (6380 only, never 6379).

## Other instances (don't disturb)
- QA runs its own backend on 127.0.0.1:8004 with Redis DBs 5–7; admin agent smoke-tests on 8003. Don't kill those unless their owner is idle and the user agrees.
- Tests don't need MinIO, Mailpit or :8001; they use their own `POSTGRES_TEST_DB` / `TEST_REDIS_DB`.

## Phone access
The USB phone reaches :8001 and MinIO only through `adb reverse` (see `phone-build-install`). After a restart the reverse rules survive, but they're lost when the phone reconnects.
