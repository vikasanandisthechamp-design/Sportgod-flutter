# FIPAS — System Architecture

## 1. Architecture at a glance

```
                                    ┌─────────────────────────────────────────┐
                                    │           PUBLIC CITIZENS (5M+)         │
                                    │  Browsers · Smart TVs · Mobile · Kiosks │
                                    └──────────────────┬──────────────────────┘
                                                       │ HTTPS (TLS 1.3)
                                                       ▼
                              ┌────────────────────────────────────────────────┐
                              │   CDN (CloudFront / NIC edge) + AWS WAF        │
                              │   Rules: OWASP top-10, geo allow IN, rate-lim  │
                              └───────────────┬──────────────────┬─────────────┘
                                              │ static + HTML    │ /api, /ws
                                              ▼                  ▼
                          ┌────────────────────────┐   ┌──────────────────────┐
                          │  Next.js (SSR + ISR)   │   │  Ingress / API GW    │
                          │  Public dashboard      │   │  (NGINX + Kong)      │
                          │  TV display mode       │   │  mTLS to services    │
                          │  Admin panel shell     │   └──────┬───────────────┘
                          └───────────┬────────────┘          │
                                      │ SSR fetch             │
                                      ▼                       ▼
                              ┌───────────────────────────────────────────┐
                              │              SERVICE MESH (Istio)         │
                              ├───────────────────────────────────────────┤
                              │  auth-svc     readings-svc    alerts-svc  │
                              │  admin-svc    analytics-svc   ingest-svc  │
                              │  notify-svc   audit-svc       ai-predict  │
                              └──────┬────────────┬───────────┬───────────┘
                                     │            │           │
                        ┌────────────▼───┐  ┌─────▼─────┐  ┌──▼────────────┐
                        │ PostgreSQL 16  │  │  Redis 7  │  │  Kafka / MSK  │
                        │ + TimescaleDB  │  │ Cluster   │  │  (event bus)  │
                        │ (primary + 2x  │  │ (cache +  │  │  topics:      │
                        │  read replica) │  │ pubsub)   │  │   readings.*  │
                        └────────┬───────┘  └───────────┘  │   alerts.*    │
                                 │                          │   audit.*     │
                                 ▼                          └──┬────────────┘
                        ┌────────────────┐                     │
                        │ S3 / NIC Object│                     │ consumed by
                        │ - CSV uploads  │                     ▼
                        │ - report PDFs  │          ┌──────────────────────┐
                        │ - DB backups   │          │  Consumers:          │
                        └────────────────┘          │  - alerts-svc        │
                                                    │  - analytics-svc     │
                                                    │  - ai-predict-svc    │
                                                    │  - notify-svc        │
                                                    └──────────────────────┘

   Write plane (admin + ingestion)                      Read plane (public)
   ───────────────────────────────                      ────────────────────
   Admin UI / CSV / IMD / CWC / IoT   ──▶ ingest-svc    CDN → Next.js SSR/ISR
           │                                                      │
           ▼                                                      │
   readings-svc → PG(write) → Kafka(readings.created)             │
                                      │                           │
                                      ▼                           │
                            alerts-svc, analytics                 │
                                      │                           │
                           Redis pub/sub (rooms: district/river)  │
                                      │                           │
                                      ▼                           │
                             gateway-svc (WS fan-out) ────────────┘
```

## 2. Layer-by-layer explanation

### 2.1 Edge & Delivery
- **CDN:** CloudFront (if AWS) or NIC edge cache. Caches `/`, `/display`, `/district/[id]` HTML (ISR 60 s) and all `/_next/static/*` (1 year immutable). Public API GET responses are cached at the edge with `Cache-Control: public, s-maxage=15, stale-while-revalidate=60`.
- **WAF:** AWS WAF or ModSecurity with OWASP CRS. Geo allow-list: India + SAARC. Rate-limit 100 rps per IP on `/api/*`, 10 rps on `/auth/*`.
- **DDoS:** AWS Shield Standard (free) + Shield Advanced for disaster-season enablement. Anycast IPs. Autoscaling up to 10× baseline.

### 2.2 Frontend (Next.js 14 App Router)
- **Public dashboard** — SSR + ISR for SEO and cold-start speed; hydrated client subscribes to WebSocket for live updates.
- **Display mode** (`/display`) — fullscreen, kiosk-friendly, auto-rotates district groups, auto-refresh every 5 min, WebSocket overlay.
- **Admin panel** (`/admin/*`) — CSR only, behind auth cookie; no SSR of protected data.
- **i18n** via `next-intl` — Hindi (`hi`) and English (`en`); URL-prefixed locales; device/browser auto-detect with manual switch.

### 2.3 API Gateway
- NGINX Ingress + Kong plugins (JWT, rate-limit, CORS, request-transform, prometheus).
- Terminates TLS 1.3 (ingress cert from ACM / NIC CA).
- Routes by path:
  - `/api/v1/public/*` → readings-svc (read-only, aggressively cached)
  - `/api/v1/admin/*` → admin-svc (JWT required)
  - `/api/v1/ingest/*` → ingest-svc (mTLS or API key)
  - `/ws` → gateway-svc (WebSocket, sticky session)

### 2.4 Microservices (NestJS)
| Service | Responsibility | Scaling |
|---|---|---|
| `auth-svc` | Login, refresh, password, MFA, session revocation | 3 replicas, HA |
| `admin-svc` | CRUD for rivers/stations/readings, CSV upload, user mgmt | 2–5 replicas |
| `readings-svc` | Public read API (latest, history, aggregates) | 5–20 replicas (HPA) |
| `ingest-svc` | API pulls from IMD/CWC, IoT MQTT bridge, schema validation, dedup | 2–10 replicas |
| `alerts-svc` | Threshold evaluation, state-transition detection, alert emission | 2 replicas |
| `notify-svc` | Dispatch SMS, WhatsApp, email, push (future) | 2 replicas + queue |
| `analytics-svc` | Rollups, heatmaps, trends, exports | 2 replicas |
| `audit-svc` | Append-only audit log, signed, searchable | 2 replicas |
| `ai-predict-svc` | ML prediction (12/24/48h forecast) — future | GPU pool |
| `gateway-svc` | WebSocket fan-out, Redis pub/sub bridge | 5–30 replicas, sticky |

All services are NestJS (TypeScript), packaged as Docker images, deployed via Helm. Internal traffic is mTLS via Istio.

### 2.5 Data layer

**PostgreSQL 16 + TimescaleDB**
- Single logical primary with streaming replication to 2 read replicas (sync to 1, async to 1).
- Time-series tables are hypertables chunked by day.
- Continuous aggregates for hourly and daily roll-ups materialised automatically.
- Compression policy on chunks > 7 days (≈10× compression).
- Retention: raw 2 y, hourly 10 y, daily indefinite.

**Redis 7 (cluster mode)**
- **Cache:** latest reading per station (`station:{id}:latest`), district summary (`district:{code}:summary`), thresholds (`station:{id}:levels`).
- **Pub/Sub:** `readings.new`, `alerts.new`, `alerts.cleared` channels consumed by gateway-svc for WebSocket fan-out.
- **Session/refresh-token store:** hashed refresh tokens, JTI revocation list.
- **Rate-limit counters.**

**Object storage (S3 / NIC)**
- CSV uploads (quarantined → validated → archived).
- Generated reports (PDF).
- DB backups (daily full + WAL).
- Static flood-map tiles for heatmap layer.

### 2.6 Event bus (Kafka / MSK)
Topics (partitioned by `station_id`):
- `readings.created` — every new validated reading.
- `readings.corrected` — late-arriving corrections.
- `alerts.raised`, `alerts.cleared` — state transitions.
- `audit.events` — append-only audit trail, 7-year retention.
- `ingest.dlq` — dead-letter queue for malformed external payloads.

Kafka is optional for MVP (can use Redis Streams) but recommended at state scale.

### 2.7 Data flow — happy path

**Manual reading**
1. District Officer enters water level in admin panel → `POST /api/v1/admin/readings` (JWT, CSRF-token).
2. `admin-svc` validates (range check, deduplication by `station_id + observed_at`), writes to PG.
3. PG trigger + service emits `readings.created` to Kafka.
4. `alerts-svc` evaluates thresholds; if state changes → emits `alerts.raised`.
5. `analytics-svc` bumps hourly aggregate; `audit-svc` writes signed log.
6. `gateway-svc` consumes `readings.created` from Redis pub/sub → pushes WS message to rooms `district:{code}` and `river:{id}`.
7. Public browsers receive the update within < 5 s end-to-end.
8. CDN ISR revalidates page on next request (≤ 60 s).

**API ingestion (IMD/CWC)**
1. `ingest-svc` cron every 15 min calls IMD/CWC APIs with signed client cert.
2. Payload validated against JSON Schema; bad rows → `ingest.dlq`.
3. Valid rows written idempotently using `(station_id, observed_at, source)` natural key.
4. Same downstream flow as manual.

**IoT (future)**
1. Devices publish MQTT to AWS IoT Core with X.509 device cert.
2. Rules engine forwards to `ingest-svc` HTTP endpoint (or directly to Kafka).
3. Same validation and downstream flow.

### 2.8 Caching strategy

| Layer | Key | TTL | Invalidation |
|---|---|---|---|
| CDN edge | `/`, `/district/*`, `/display` | 60 s ISR | On-demand via `revalidateTag('readings')` when state changes |
| CDN edge | `/api/v1/public/*` GETs | 15 s + SWR 60 s | Stale-while-revalidate |
| Redis | `station:{id}:latest` | 10 min | Invalidated on `readings.created` |
| Redis | `district:{code}:summary` | 30 s | Invalidated on `readings.created` for any member station |
| Browser | `localStorage` language, layout | — | User action |

### 2.9 Failure modes & degradation

| Failure | Behaviour |
|---|---|
| WebSocket down | Client falls back to 30 s polling of `/api/v1/public/readings/latest` |
| Redis down | Services bypass cache and hit read replicas; stale banner shown after 60 s |
| Primary DB down | Read replica promotion (PgBouncer + Patroni), writes blocked, public read continues, admin shown maintenance |
| CDN outage | Origin is autoscaled and can serve direct, degraded performance only |
| Kafka down | Services buffer to local disk; `readings.created` emitted on recovery; alerts evaluated inline as fallback |
| Ingest external API down | Last successful timestamp exposed; banner "IMD data delayed" |

### 2.10 Observability

- **Metrics:** Prometheus + Grafana; RED per service, USE per node, domain SLOs (freshness, WS connected, threshold-breach count).
- **Logs:** structured JSON → Fluent Bit → Loki / OpenSearch; PII-scrubbed.
- **Traces:** OpenTelemetry → Tempo / Jaeger; w3c trace-context propagated through Kafka headers.
- **Alerting:** Alertmanager → PagerDuty / Gupshup SMS for on-call + SEOC duty officer.
- **Dashboards:** state overview, per-district, ingestion health, alert storm, DB health, WS fan-out.

## 3. Environments

| Env | Purpose | Data |
|---|---|---|
| `dev` | Developer sandbox | Synthetic seed |
| `staging` | Pre-prod, mirror of prod topology | Anonymised snapshot |
| `uat` | Acceptance by WRD officers | Last week prod snapshot |
| `prod` | Live | Real |
| `dr` | Warm standby in Hyderabad region | Async replica |
