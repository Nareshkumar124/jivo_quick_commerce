# Speed and scaling strategy

How to keep Jivo Quick Commerce fast as the user base grows, and what to change at each stage. This guide is written for the project owner and the development agents. It covers strategy only. Each item becomes a task in `docs/task-tracker.md` when we schedule it.

Status as of 2026-11-20. Sources:
- the performance analysis of 2026-11-20 (read-only review of the code)
- `docs/09-nfr-security-compliance.md` §1 (targets)
- `infra/deploy/compose.prod.yml`
- `docs/deployment.md` §12 (light load test)

**Legend**
- ✅ done
- 🔄 in progress (T-817 backend, T-818 customer app, T-819 DevOps)
- ⬜ not started
- ⚠ needs the owner's decision (money, cost, data, or a new database extension)

---

## 1. Where we are today

| Layer | Current setup | Notes |
|---|---|---|
| Server | One shared Linux server, Docker Compose project `jqc`. Other company sites also run on it. | Fine for staging. Not for a public launch at scale. |
| Web/API | `gunicorn` with uvicorn ASGI, **3 workers** | Handles HTTP and WebSockets in the same processes |
| Background jobs | Celery, **1 worker × 4 processes**, plus beat | One queue for everything. 🔄 a `slow` queue is being added (T-817/T-819). |
| Database | PostgreSQL 16 + PostGIS in the same compose project: `shared_buffers=256MB`, `max_connections=100` | Same machine as the app. No replica. |
| Redis | One instance, 384 MB, **no persistence** | Serves as cache, Celery broker, channel layer and latest rider location |
| Files | MinIO (S3-compatible) behind nginx. **No CDN.** | WebP 256/512/1024 px variants are created at upload ✅ |
| Measured | Light load test (about 20 users): read endpoints p95 23–46 ms | The full test (500 sessions, 50 orders/min) has not been run (DL-75) |

**Targets (doc 09 §1)**

| Metric | Target |
|---|---|
| Read endpoints p95 | < 300 ms |
| Order placement p95 | < 800 ms |
| Serviceability p95 | < 150 ms |
| Rider offer delivery | < 3 s |
| Customer app cold start | < 3 s |
| Launch capacity | 50 orders/min and 500 concurrent sessions |

**Already done**
- Per-store Redis cache for the home feed, catalog, search, serviceability and app config, cleared when the data changes.
- Query-count tests on the hot endpoints.
- Indexes on the hot tables.
- WebP image variants.
- WebSockets with a polling fallback.
- Skeleton loaders.
- A database connection pool on staging (T-218).
- Retention purges for rider locations and notifications.
- Obfuscated release AABs.

---

## 2. Growth stages

Rough sizes to plan against. The real limits come from load tests (§12), not from this table.

| Stage | Users / load | What must be true | Main moves |
|---|---|---|---|
| **A. Launch** (1 city, a few dark stores) | Up to about 5k daily users, 50 orders/min peak, 500 concurrent sessions | Targets met in a full load test, monitoring on, backups tested | Everything in §3 "Before launch" |
| **B. Growth** (several cities) | About 50k daily users, 200–500 orders/min, 5k concurrent sessions | No single machine is critical; the DB is the only stateful core | Dedicated or managed servers, CDN, PgBouncer, 2+ web nodes, split Redis, separate WebSocket service |
| **C. Scale** (national) | 500k+ daily users, 1–3k orders/min, 50k+ concurrent sessions | Every tier scales out horizontally; the DB is protected from read traffic | Read replicas, autoscaling, table partitioning, edge-cached catalog, per-region thinking |

The architecture (Django services, Celery, Redis, PostGIS) does not need a rewrite for stage C. It needs more machines, better separation and a protected database.

---

## 3. Before launch (stage A checklist)

Ordered by value. "Owner" is the project agent that does the work.

| # | Strategy | Why | Owner | Status |
|---|---|---|---|---|
| A1 | **Move production off the shared server** to its own server or managed services, in an Indian region (e.g. Mumbai) | Other sites can't slow us down. Low latency for Indian users. Needed for the full load test. | devops-engineer | ⬜ ⚠ cost |
| A2 | **Run the full load test** (500 sessions, 50 orders/min, rider dispatch) on that server | Today order placement and dispatch under load are unmeasured | devops-engineer + qa-engineer | ⬜ (DL-75) |
| A3 | **Monitoring:** Sentry tracing on (e.g. 5–10% sample), a `/metrics` endpoint, Prometheus/Grafana or a hosted APM, alerts on p95, error rate and queue depth | You can't fix what you can't see. The alert rules already wait on these metrics. | django-backend-dev + devops-engineer | ⬜ |
| A4 | **Rate limits per user, not per IP**, and a separate nginx limit zone for images | Indian mobile carriers put thousands of users behind one IP (CGNAT). Per-IP limits would block real customers at peak. | backend + devops | ✅ in code (T-817/T-819), not deployed |
| A5 | **Split background jobs:** `celery` (urgent: dispatch, push, SMS, realtime, payments) and `slow` (exports, invoice PDFs, imports, purges), each with its own worker | One big export must never delay a rider offer (3 s target) | backend + devops | ✅ in code (T-817/T-819), not deployed |
| A6 | **CDN for product images**, e.g. CloudFront or Cloudflare in front of the bucket. Long cache headers; the WebP variants are already there. | Images are most of the bytes. A CDN takes this load off our server and is faster for users. | devops-engineer | ⬜ ⚠ cost |
| A7 | **Compress JSON** (gzip/brotli) for public catalog responses only (BREACH-safe) | 3–5× smaller payloads on slow 4G | devops-engineer | ✅ in code (T-819), not deployed |
| A8 | **App speed:** image disk cache, parallel cold start, saved home feed shown instantly, cart tap coalescing, one silent retry for GETs | The biggest change in how fast the app *feels* | flutter-customer-dev | 🔄 T-818 |
| A9 | **Versioned static files** (manifest storage) | Staff browsers never run stale Ops Console JS after a deploy | django-backend-dev | ✅ in code (T-817/T-819), not deployed |
| A10 | **Redis persistence for the broker:** at least use a separate Redis (or DB) with AOF for Celery, so a restart doesn't lose queued jobs | Today Redis has no persistence. A restart loses queued pushes, dispatch jobs and invoice jobs. | devops-engineer | ⬜ |
| A11 | **Backups and restore drill on the production DB**, with point-in-time recovery if managed | Losing orders is worse than being slow | devops-engineer | partly (staging drill, DL-75) |
| A12 | **Store capacity guard:** auto-pause a store, or extend the ETA, when its open-order backlog or free riders cross a threshold | At peak, the real bottleneck is pickers and riders, not servers. Promising "10 min" and failing loses customers. | backend + admin | ⬜ ⚠ product rule |

---

## 4. Customer and rider apps

The fastest request is the one the app doesn't make.

| Strategy | Detail | Status |
|---|---|---|
| Disk image cache | `cached_network_image` for all product, category and banner images | 🔄 T-818 |
| Stale-while-revalidate home | Show the last home feed and store at once, then refresh in the background. Never show saved prices at checkout: the bill always comes from the server. | 🔄 T-818 |
| Parallel startup | Fetch config and profile together; check serviceability during the splash | 🔄 T-818 |
| Fewer calls per action | Coalesce cart taps. Have the backend return the address-aware bill on item changes (one call instead of two). | 🔄 T-818 (backend part via `docs/api-requests.md`) |
| Smart retries | One silent retry for GETs on network errors, with jitter. Never retry POSTs without an `Idempotency-Key`. | 🔄 T-818 |
| Reconnect with jitter | After a server deploy or blip, thousands of apps reconnect WebSockets at once. Random back-off (e.g. 1–10 s) avoids a "thundering herd". | ⬜ check both apps |
| Push instead of polling | Use FCM for important events; poll only when the socket is down, and slower in the background | ✅ mostly (customer polling every 10 s, rider every 5 s, only while the socket is down) |
| Lists | Lazy builders for long lists (order history) | 🔄 T-818 |
| App size | Per-ABI APKs for testing; AAB for Play (already) | ⬜ PM skill |
| Rider battery and data | Balanced GPS accuracy while idle, high accuracy only on an active task. Send location every N seconds or M metres, whichever comes first. | ⬜ flutter-rider-dev |
| Forced update | `426 APP_UPDATE_REQUIRED` lets us retire old app versions that call slow or old endpoints | ✅ |

---

## 5. Edge and network

| Strategy | Detail | Status |
|---|---|---|
| CDN for images | See A6. Cache-busting through the variant file names. | ⬜ |
| Edge-cache public catalog JSON | Catalog, home and search are already the same for every user in a store. With `Cache-Control: public, max-age=30–60` and a per-store cache key, a CDN or nginx `proxy_cache` can answer most reads without reaching Django. The "Previously bought" rail must stay out of the shared response, or come from a separate per-user call. | ⬜ stage B |
| nginx `proxy_cache` for `/media/` | A stop-gap until the CDN exists | 🔄 T-819 |
| HTTP/2 and keep-alive | Fewer TLS handshakes on mobile | ⬜ check the nginx site |
| Separate limit zones | API, images, WebSocket and auth (OTP) each get their own limit, so one can't starve another | 🔄 T-819 |

---

## 6. API tier

| Strategy | Detail | Stage |
|---|---|---|
| Stateless web nodes | No local state (sessions and cache in Redis, files in S3), so we can add nodes behind a load balancer at any time | A ✅ design, B to use |
| Worker sizing | Size gunicorn workers per node to the CPU (about 2× cores for ASGI) and measure. Raise the DB pool size with them. | A |
| Separate WebSocket service | Run `/ws/` on its own ASGI containers, so long-lived sockets don't take workers from HTTP requests | B |
| Timeouts everywhere | Request timeout, DB statement timeout (e.g. 5 s for API requests) and outbound HTTP timeouts (Razorpay, SMS and FCM already have some) | A |
| Keep requests thin | Anything over about 100 ms that the user doesn't need to wait for (PDFs, emails, pushes, webhooks) goes to Celery through `transaction.on_commit` | ✅ rule, keep enforcing |
| Autoscaling | Scale web nodes on CPU and p95, and workers on queue depth | C |

---

## 7. Caching

| Strategy | Detail | Status |
|---|---|---|
| Per-store catalog/home/search cache | Versioned keys, cleared on change | ✅ |
| Fewer Redis round trips | `get_many` for version keys | 🔄 T-817 |
| Separate stock from catalog | Stock changes on every order. Keep "in stock / quantity left" in a small, short-TTL cache or a separate endpoint, so a sale doesn't invalidate the whole catalog cache for the store. | ⬜ B (measure the invalidation rate first) |
| Stampede protection | When a hot key expires, let one request rebuild it while others get the old value (lock or early refresh) | ⬜ B |
| Serviceability cache by area | Cache point-in-polygon results by rounded coordinates or geohash. Store polygons rarely change. | ⬜ check what exists, B |
| Client cache headers | `ETag` / `Last-Modified` on catalog responses, so the app gets `304 Not Modified` | ⬜ B |

---

## 8. Database (the part that is hardest to scale later)

| Strategy | Detail | Stage |
|---|---|---|
| Connection pooling | The psycopg pool exists (T-218). At stage B add **PgBouncer** (transaction mode) in front of Postgres, so many web and worker processes share a few DB connections. | A ✅ / B |
| Managed Postgres | Automated backups, point-in-time recovery, failover and easy resizing (e.g. AWS RDS or Azure Flexible Server with PostGIS) | B ⚠ cost |
| Read replica | Send reports, Ops Console analytics and exports to a replica, so they never slow down order placement | B/C |
| Keep the stock lock short | Stock reservation uses `select_for_update` in variant-id order ✅. Keep that transaction tiny: no network calls, no PDFs, no pushes inside it. That matters most for best-sellers at one store during a sale. | A (review in the load test) |
| Query discipline | Query-count tests ✅. Add `pg_stat_statements` to find slow queries in production. | A ⚠ new extension (doc rule: only `postgis` today) |
| Indexes | Re-check with real query plans after the load test (orders by store and status, delivery tasks by rider, notifications by user) | A |
| Big tables | Purge or partition by month: rider locations ✅ 30 days, notifications ✅ 90 days. Plan this for `StockMovement`, `OrderStatusHistory` and audit logs at stage C. Archive old orders to cold storage only if needed. | C |
| Search | Today's search is plain "contains" matching. Typo-tolerant search with `pg_trgm` (a GIN index) is cheap for a small catalog. A separate search engine (Meilisearch or OpenSearch) only if the catalog grows a lot, which is unlikely for a single-brand catalog. | A/B ⚠ new extension |

---

## 9. Background jobs (Celery)

| Strategy | Detail | Stage |
|---|---|---|
| Queues by urgency | `celery` (urgent) and `slow`, each with its own worker | 🔄 A |
| More queues as we grow | e.g. `realtime` (location fan-out), `notifications` (push and SMS), `payments`, `slow` | B |
| Durable broker | Redis with AOF, or RabbitMQ / managed Redis. Late acks (`acks_late`) for jobs that must not be lost. | A/B |
| Idempotent tasks | Every task safe to run twice (already the rule) | ✅ rule |
| Rate-limit outbound calls | FCM, SMS (MSG91) and Razorpay have limits. Use per-task rate limits and back-off, so a burst doesn't get us throttled. | A |
| One beat only | Exactly one `beat` process, even with many workers | ✅ |
| Monitor queue depth | Alert when the urgent queue waits longer than a few seconds | A (part of A3) |

---

## 10. Real-time (WebSockets and rider location)

| Strategy | Detail | Stage |
|---|---|---|
| Latest location in Redis only | The live map reads Redis. Write history to the DB in batches or samples, not on every ping. | ⬜ check the current write path |
| Throttle the fan-out | Send the customer at most one rider update every 2–3 s, even if the rider sends more | ⬜ check |
| Dedicated channel-layer Redis | Keep real-time traffic off the cache and broker Redis | B |
| Separate WebSocket nodes | See §6 | B |
| Reconnect jitter | See §4 | A |

---

## 11. Third-party services and degradation

| Strategy | Detail |
|---|---|
| Timeouts and circuit breakers | If Razorpay, MSG91 or FCM is slow, fail fast and retry later. Never hold a web worker waiting on them. |
| Graceful degradation | If the DB is slow, still serve the cached home and catalog. If SMS is down, show a clear OTP error. If push fails, polling still updates the order. |
| Kill switches | Admin flags to turn off heavy features at peak (e.g. "Previously bought", search suggestions, exports during business hours) |
| Payment webhooks | Already idempotent on `event_id` ✅. Keep them on the urgent queue. |

---

## 12. Proving it: load and reliability testing

1. **The full load test** on the production-like server (A2): 500 sessions, 50 orders/min, rider dispatch, a 30-minute soak.
2. **Step tests:** 2×, 5× and 10× launch load, to find the first bottleneck. It is usually DB connections, a hot lock or Redis memory.
3. **Spike test:** a sale at 8 pm. Ten times the traffic within one minute.
4. **Failure drills:** restart Redis, restart a worker, make the DB slow. The apps must recover and no orders may be lost.
5. **Re-run the load tests before each major release**, and record the results in `docs/deployment.md` §12.

The harness exists (`loadtest/`, Locust, T-812).

---

## 13. Operations at scale (not code, but they decide the speed customers feel)

- **Dark stores per area:** delivery time depends on distance. More, smaller stores beat faster servers.
- **Capacity per store:** pickers and riders per time slot. Show an honest ETA, or pause taking orders when overloaded (A12).
- **Dynamic ETA:** include the current queue and free riders. Today the ETA is a fixed formula (`apps/stores/services.py`). ⚠ product decision.
- **Rider pool at peak:** incentives and shift planning. Dispatch is only as fast as the free riders.

---

## 14. Suggested order of work

1. **Now (in progress):** T-817 backend, T-818 customer app, T-819 DevOps speed fixes.
2. **Before launch:**
   - A1 dedicated server ⚠
   - A3 monitoring
   - A6 CDN ⚠
   - A10 durable broker
   - A2 full load test, then fix what it finds
   - A12 store capacity guard ⚠
3. **After launch, as traffic grows (stage B):**
   - managed Postgres and PgBouncer
   - separate WebSocket service
   - split Redis
   - edge-cached catalog
   - read replica for reports
4. **Stage C:** autoscaling, table partitioning, more queues, multi-city capacity planning.

**Decisions needed from the owner (⚠)**
- Server and CDN budget, and the hosting provider.
- Adding the Postgres extensions `pg_trgm` and `pg_stat_statements`.
- Store capacity rules and a dynamic ETA.
