# DAIOS — System Architecture

## 1. Architecture in one picture

```
                                 GLOBAL CONTROL PLANE  (one cluster)
   ┌───────────────────────────────────────────────────────────────────────────────┐
   │  Identity Federation (OIDC) │ Schema Registry │ Model Registry (MLflow)       │
   │  Tenant Catalogue           │ Config Distribution (signed) │ Telemetry Lake  │
   │  Drill / Shadow Orchestrator│ Partner Marketplace          │ Status / SLO    │
   └────────────────┬───────────────────────────────────────────────┬──────────────┘
                    │ signed config, anonymised telemetry, no PII   │
                    ▼                                               ▼
        ┌─────────────────────────┐                    ┌─────────────────────────┐
        │  SOVEREIGN PLANE — IN   │                    │  SOVEREIGN PLANE — XX   │
        │  ap-south-1 + -south-2  │                    │  in-country region(s)   │
        ├─────────────────────────┤                    ├─────────────────────────┤
        │  Edge: CDN + WAF + DDoS │                    │  Edge: CDN + WAF + DDoS │
        │  ─────────────────────  │                    │  ─────────────────────  │
        │  HAZARD KERNELS         │                    │  HAZARD KERNELS         │
        │   ├ flood   (FIPAS)     │                    │   ├ flood               │
        │   ├ earthquake          │                    │   ├ earthquake          │
        │   ├ cyclone             │                    │   ├ cyclone             │
        │   ├ heatwave            │                    │   ├ wildfire            │
        │   └ landslide           │                    │   └ tsunami             │
        │  ─────────────────────  │                    │  ─────────────────────  │
        │  CORE SERVICES          │                    │  CORE SERVICES          │
        │   identity · alerts ·   │                    │   identity · alerts ·   │
        │   citizen · response ·  │                    │   citizen · response ·  │
        │   decision · twin ·     │                    │   decision · twin ·     │
        │   analytics · audit     │                    │   analytics · audit     │
        │  ─────────────────────  │                    │  ─────────────────────  │
        │  EVENT MESH (Kafka)     │  ◀── PRIVATE ──▶   │  EVENT MESH (Kafka)     │
        │   topics: hazard.*,     │   federation       │   (only schema +        │
        │   decision.*, alert.*,  │   (no PII)         │    anon metrics cross)  │
        │   citizen.*, audit.*    │                    │                         │
        │  ─────────────────────  │                    │  ─────────────────────  │
        │  DATA: PG+Timescale,    │                    │  DATA: PG+Timescale,    │
        │  Redis, S3, OpenSearch, │                    │  Redis, S3, OpenSearch, │
        │  PostGIS, Vector DB     │                    │  PostGIS, Vector DB     │
        │  ─────────────────────  │                    │  ─────────────────────  │
        │  AI PLANE               │                    │  AI PLANE               │
        │   Triton inference,     │                    │   Triton inference,     │
        │   LLM (sovereign +      │                    │   LLM (sovereign +      │
        │   on-prem fallback),    │                    │   on-prem fallback),    │
        │   feature store, MLflow │                    │   feature store, MLflow │
        └─────────────────────────┘                    └─────────────────────────┘
                ▲          ▲                                   ▲
                │          │                                   │
   citizens ────┘          │                                   └──── citizens
   officials  ─────────────┘                                                 (per-country)
   partners   ─────────────┘
```

## 2. The two-plane model

DAIOS separates **what's global** from **what's national**:

### 2.1 Global Control Plane (one cluster, multi-AZ)
Stateless of citizen data. Owns:
- **Tenant catalogue** — every country/state on DAIOS.
- **Schema registry** — Avro/Protobuf for events; backwards-compat enforced.
- **Model registry** — MLflow with signed model artifacts; sovereign planes pull approved models.
- **Identity federation** — OIDC broker; per-tenant IdPs federate up to a global `daios.id` for partners and read-only oversight roles.
- **Config distribution** — Sigstore-signed YAML bundles, cryptographic chain of trust.
- **Telemetry lake** — anonymised SLO + ML evaluation metrics (zero PII).
- **Drill orchestrator** — coordinates global drills across countries.
- **Status & SLO portal** — public.

### 2.2 Sovereign Data Planes (one or more per country)
Owns **all** citizen data, sensor readings, decisions, audit logs. Ingress and egress are controlled:
- Inbound from control plane: signed config, model artifacts, schema updates only.
- Outbound to control plane: anonymised metrics; never raw events.
- Inter-sovereign federation is **opt-in** and allow-listed (e.g., trans-boundary river basin sharing, cyclone trajectory across two states/countries).

This satisfies the strictest data-residency regimes while still letting models trained globally improve every country's outcomes.

## 3. The hazard-kernel pattern

A **HazardKernel** is a contract every disaster type implements:

```ts
interface HazardKernel<Reading, Forecast> {
  id: HazardId;                            // 'flood' | 'earthquake' | ...
  ingest(payload: unknown): Promise<Reading[]>;
  nowcast(state: TwinState, recent: Reading[]): Promise<Severity>;
  forecast(state: TwinState, horizonH: number): Promise<Forecast>;
  threshold(reading: Reading, station: Station): Severity;
  alertPolicy(severity: Severity, hist: AlertHistory): AlertDecision;
  postmortem(eventWindow: TimeRange): Promise<PostmortemReport>;
  // Streaming hooks
  onIncident?(incident: Incident, ctx: AgentCtx): Promise<void>;
}
```

Each kernel is its own service (`flood-kernel-svc`, `eq-kernel-svc`, ...) but they all consume the same event mesh, write into the same audit substrate, and surface through the same dashboards. This is what lets DAIOS add tsunami support in 6 weeks, not 6 quarters.

## 4. Event mesh

Backbone is **Kafka** (or MSK / Confluent Cloud Sovereign).

### 4.1 Topics (partitioned by `tenant_id` + hazard-specific key)

| Namespace | Examples | Producer | Consumer |
|---|---|---|---|
| `hazard.<id>.reading` | `hazard.flood.reading`, `hazard.eq.reading` | ingest-svc, IoT bridge | hazard kernel, twin-svc |
| `hazard.<id>.forecast` | `hazard.cyclone.forecast` | hazard kernel | decision-svc, alerts-svc |
| `hazard.<id>.incident` | `hazard.heatwave.incident` | hazard kernel | response-svc, citizen-svc |
| `decision.proposal` | — | decision-svc | response-svc, audit-svc |
| `decision.authorised` | — | response-svc (on human approval) | actuators (alerts, dispatch) |
| `alert.outbound` | — | alerts-svc | channel adapters (sms, wa, rcs, cb) |
| `citizen.report` | — | citizen-svc | response-svc, twin-svc |
| `citizen.sos` | — | citizen-svc | response-svc (HIGH priority) |
| `audit.event` | — | every service | audit-svc |
| `twin.update` | — | sensors, ingestors | twin-svc |
| `train.label` | — | postmortem-svc, human reviewers | ml-training-svc (offline) |

### 4.2 Schema discipline
- Avro with Schema Registry; consumer-driven contract tests in CI.
- All events carry: `tenant_id`, `hazard_id?`, `event_id (uuidv7)`, `occurred_at`, `received_at`, `producer`, `trace_id`, `causation_id`, `correlation_id`, `schema_version`, `signature`.
- `causation_id` lets you reconstruct *why*: a citizen SOS → a decision proposal → an alert → a citizen-app push, all linked.

### 4.3 Exactly-once where it matters
- Decision authorisation, alert dispatch, and audit are written through **Kafka transactions + outbox pattern** to avoid duplicate alerts (a duplicate cyclone evacuation message at 2 AM is unacceptable).
- Sensor reads are **at-least-once** with idempotent upserts on `(station_id, observed_at, source)`.

## 5. Core services (high-level)

Detailed catalog in `microservices.md`. Logical groups:

- **Edge & gateway:** CDN, WAF, ingress, GraphQL Federation gateway, WebSocket gateway, citizen API gateway, partner API gateway.
- **Identity & access:** auth-svc, federation-svc, policy-svc (OPA), audit-svc.
- **Hazard kernels:** flood, earthquake, cyclone, heatwave, landslide, wildfire, tsunami, industrial, epidemic.
- **Ingestion:** sensor-bridge (IoT MQTT), api-puller (IMD, USGS, ECMWF), satellite-pipeline, citizen-report-svc.
- **Twin & GIS:** twin-svc, gis-tile-svc, sim-svc.
- **Decision & response:** decision-svc, agent-runtime-svc, response-svc, dispatch-svc.
- **Citizen channels:** alerts-svc, sms-adapter, wa-adapter, rcs-adapter, push-adapter, cb-adapter (cell broadcast), pa-adapter (public address), display-svc (kiosk).
- **AI plane:** model-serving (Triton), feature-store, training-svc, eval-svc, llm-router (sovereign + fallback).
- **Analytics:** rollups-svc, postmortem-svc, planner-svc, climate-rebaseline-svc.

## 6. Data flow — three canonical paths

### 6.1 Sensor → forecast → alert
```
IoT/IMD/USGS ─▶ ingest-svc ─▶ hazard.<x>.reading ─▶ flood-kernel
                                      │                    │
                                      ▼                    ▼
                                  twin-svc           hazard.<x>.forecast
                                      │                    │
                                      ▼                    ▼
                                  decision-svc ─────────────┘
                                      │
                                      ▼
                                  decision.proposal
                                      │
                                  human approval (SEOC console)
                                      │
                                      ▼
                                  decision.authorised ─▶ alerts-svc
                                                              │
                                                              ▼
                                            cb / sms / wa / rcs / push / pa
```

### 6.2 Citizen SOS → response
```
citizen-app ─▶ citizen-api ─▶ citizen.sos ─▶ response-svc
                                                 │
                                                 ▼
                                       agent-runtime (police/health agents)
                                                 │
                                                 ▼
                                       decision.proposal (auto-priority)
                                                 │
                                                 ▼
                                       SEOC dispatcher screen
                                                 │
                                                 ▼
                                       dispatch-svc ─▶ field unit + caller back
```

### 6.3 Post-event learning
```
event closed ─▶ postmortem-svc reads window from event log
              ─▶ generates draft report (LLM)
              ─▶ extracts labelled training pairs (forecast vs observed)
              ─▶ writes to train.label topic
              ─▶ ml-training-svc (offline) retrains scheduled models
              ─▶ MLflow registry → human approval → sovereign deployment
```

## 7. Layered caching & freshness

| Layer | Use | TTL | Invalidation |
|---|---|---|---|
| CDN edge | Public dashboards, kiosk | 30 s ISR + SWR 60 s | Tag-based on event publish |
| API gateway | GET endpoints | 5–15 s | Stale-while-revalidate |
| Service Redis | Latest reading per sensor, summary per district, twin tile metadata | 10 s–10 min | On `*.reading` & `twin.update` |
| Browser/app | Last good snapshot for offline read | session | Manual refresh |
| Vector store cache | Recent agent retrievals | 1 h | LRU |

## 8. Failure modes & graceful degradation

| Failure | Behaviour |
|---|---|
| Hazard kernel down | Last-known forecasts served with `staleness` header; alerts pause new escalations; citizens see "data delayed" banner |
| Decision agent down | Console offers human-only mode with templated recommendations |
| LLM sovereign endpoint down | Router falls back to on-prem distilled model (lower quality, full availability) |
| Kafka regional partition | Producers buffer to local outbox; consumer lag alarmed; replay on recovery |
| WebSocket gateway overloaded | Client falls back to 30 s long-poll |
| Submarine cable cut (cross-region) | Sovereign plane runs fully autonomously; control-plane drift up to 24 h tolerated |
| Earthquake at the data centre | Active-active across 2 in-country regions; auto-failover ≤ 90 s |

## 9. Observability

- **Metrics** — Prometheus + Grafana; SLO objects per module (alert latency, agent decision latency, twin tile freshness, model drift).
- **Tracing** — OpenTelemetry; `causation_id` carried in baggage; full chain queryable.
- **Logging** — JSON to Loki + cold to S3 with Object Lock.
- **ML observability** — Arize / Evidently AI; data drift, prediction drift, lift over baseline per hazard.
- **War-room dashboard** — single screen for the duty SRE during a SEV-1, with cross-module health.

## 10. Time, language, units

- All times in UTC at rest; rendered in tenant TZ.
- Languages: per-tenant active set; UI bundles distributed via control plane; right-to-left support for Arabic/Hebrew tenants.
- Units: SI canonical, locale-aware rendering (mm vs in, °C vs °F).
- Calendars: Gregorian primary; localized secondary (Saka, Hijri, Bikram Sambat) on citizen-facing surfaces.
