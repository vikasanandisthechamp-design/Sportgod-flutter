# DAIOS — Microservices Catalog

A microservice in DAIOS is the unit of independent deploy, scale, and on-call. Boundaries are drawn so that **a single team can own one or two services end-to-end**, and so that hazard-specific blast radius stays contained.

## 1. Naming & conventions

- Service name pattern: `<domain>-svc` (`flood-kernel-svc`, `alerts-svc`).
- One repo per service, NestJS or FastAPI; common scaffolding from `@daios/service-template`.
- Health: `/health/live`, `/health/ready`, `/metrics`, `/version`.
- Auth: mTLS east-west, JWT north-south.
- Topics owned by a service prefix the service name; topics consumed are documented in the service README.
- SLOs declared as code (`slos.yaml`) — checked in CI, exported to Prometheus.

## 2. The catalogue

### 2.1 Edge & Gateway tier

| Service | Owns | Stack | Scaling | Notes |
|---|---|---|---|---|
| `cdn-edge` | Static assets, ISR cache, image optimisation | CloudFront + Lambda@Edge | global PoPs | WAF + Shield in front |
| `gw-public-api` | Public REST + GraphQL federation | Apollo Router + NestJS | HPA on RPS | Read-only |
| `gw-citizen-api` | Citizen mobile/web → core | NestJS | HPA on RPS | JWT, device-bound refresh |
| `gw-partner-api` | Partner agencies (IMD, NDRF, telcos) | NestJS + OAuth2 m2m | HPA | Strict rate-limit + contract |
| `gw-ws` | WebSocket fan-out (citizens, dashboards) | Node + uWS | HPA on active conns; sticky | Pub-sub bridge to Redis Streams |
| `gw-officer` | Internal admin/officer console | NestJS + WebAuthn | HPA | mTLS + step-up MFA |

### 2.2 Identity, Access & Audit

| Service | Owns | Notes |
|---|---|---|
| `auth-svc` | Login, refresh, MFA (TOTP + WebAuthn), session revocation | RS256 JWT, 90-day key rotation |
| `federation-svc` | OIDC broker between tenant IdPs and DAIOS | SAML/OIDC, state-IdP per country |
| `policy-svc` | OPA/Rego central policy decision point | RBAC + ABAC, deny-by-default |
| `audit-svc` | Append-only signed audit log, hash-chained | Per-tenant key, immutable storage |
| `consent-svc` | Citizen consent (location, push, channel preferences) | DPDP Act / GDPR-style |

### 2.3 Hazard Kernels (one per hazard)

All implement the same `HazardKernel` contract. Each runs as `*-kernel-svc` plus optional companion services for ingestion/inference.

| Kernel | Inputs | Companion services |
|---|---|---|
| `flood-kernel-svc` | gauge readings, IMD/CWC API, satellite SAR | `flood-ingest-svc`, `flood-forecast-svc` |
| `eq-kernel-svc` | seismic feeds (USGS, IMD seismo), accelerometer IoT | `eq-ingest-svc`, `eq-shakemap-svc` |
| `cyclone-kernel-svc` | IMD, JTWC, ECMWF ensembles, satellite | `cyclone-ingest-svc`, `cyclone-track-svc` |
| `heatwave-kernel-svc` | IMD weather, satellite LST, AQI feeds | `heat-ingest-svc` |
| `landslide-kernel-svc` | rainfall, slope DEM, soil moisture, InSAR | `slide-ingest-svc`, `slide-risk-svc` |
| `wildfire-kernel-svc` | VIIRS/MODIS hot-spots, weather, fuel-load | `fire-ingest-svc`, `fire-spread-svc` |
| `tsunami-kernel-svc` | NTWC, DART buoys, EQ kernel cross-feed | `tsunami-ingest-svc` |
| `industrial-kernel-svc` | air-quality sensors, plant SCADA | `industrial-ingest-svc` |
| `epidemic-kernel-svc` | hospital feeds, syndromic surveillance | `epidemic-ingest-svc` |

### 2.4 Ingestion

| Service | Owns |
|---|---|
| `sensor-bridge-svc` | MQTT broker bridge for IoT (gauges, accelerometers, weather stations) |
| `api-puller-svc` | Cron-based pulls from gov APIs (IMD, CWC, USGS, ECMWF) with adapters |
| `satellite-pipeline-svc` | Periodic ingestion of Sentinel-1/2, MODIS, VIIRS, ISRO Bhuvan tiles |
| `citizen-report-svc` | Crowdsourced reports (photo/video/text + location), CV-classified |
| `webhook-receiver-svc` | Push from partners (telco network, hospital ERP) |

### 2.5 Twin & GIS

| Service | Owns |
|---|---|
| `twin-svc` | Live geo-temporal state (sensors, hospitals, schools, dams, population) |
| `gis-tile-svc` | Vector + raster map tile serving (MapLibre + PostGIS) |
| `sim-svc` | What-if simulation engine; scenario forking from live state |
| `population-svc` | Census + WorldPop integration; ward-level populations |
| `infra-graph-svc` | Roads, power, telecom topology graph (Neo4j) |

### 2.6 Decision & Response

| Service | Owns |
|---|---|
| `decision-svc` | Orchestrates multi-agent reasoning; produces ranked, traced recommendations |
| `agent-runtime-svc` | LangGraph/Bedrock-Agents-style runtime; tool gateway, sandboxing |
| `response-svc` | Incident command, tasking, SITREPs, resource allocation |
| `dispatch-svc` | Field-unit dispatch (NDRF, police, ambulance), real-time vehicle tracking |
| `resource-svc` | Inventory of supplies, equipment, shelters, with location & SLA |
| `volunteer-svc` | Vetted volunteer roster, surge activation |

### 2.7 Citizen Channels

| Service | Owns |
|---|---|
| `alerts-svc` | Composes hazard alerts, multilingual templating, severity gating |
| `sms-adapter-svc` | Telco SMS APIs (TRAI/DoT compliant); DLT templates |
| `wa-adapter-svc` | WhatsApp Business API; opt-in tracking |
| `rcs-adapter-svc` | RCS Business Messaging |
| `push-adapter-svc` | FCM, APNs, in-house Web Push |
| `cb-adapter-svc` | Cell-broadcast (CMAS/EU-Alert); per-cell-tower targeting |
| `pa-adapter-svc` | Public-address speakers (sirens, mosques, temples opt-in) |
| `display-svc` | Kiosk/TV signage rendering & rotation orchestration |
| `voice-svc` | TTS + voice-call alerts (low-literacy regions); IVR for SOS |

### 2.8 AI Plane

| Service | Owns |
|---|---|
| `model-serving-svc` | Triton inference; gRPC + REST; GPU & CPU pools |
| `feature-store-svc` | Online + offline features; backed by Feast |
| `training-svc` | Scheduled offline training; reads `train.label` topic |
| `eval-svc` | Continuous model evaluation; data/prediction drift; champion-challenger |
| `llm-router-svc` | Routes to sovereign LLM, on-prem fallback, or external model with redaction guard |
| `agent-tool-gateway-svc` | The only path agents take to read/write DAIOS state; enforces scoped permissions |
| `safety-svc` | Pre-publication safety checks on AI output: hallucination, toxicity, jurisdictional compliance |

### 2.9 Analytics & Planning

| Service | Owns |
|---|---|
| `rollups-svc` | Continuous aggregates, dashboards, exports |
| `postmortem-svc` | After-action AI report generation; humans edit, audit-trail kept |
| `planner-svc` | Capacity planning, drill scheduling, scenario library |
| `climate-rebaseline-svc` | Re-baselines flood return periods etc. as climate shifts |
| `data-publisher-svc` | NDSAP / open-data publication; anonymised, scheduled |

### 2.10 Platform / Cross-cutting

| Service | Owns |
|---|---|
| `tenant-svc` | Tenant lifecycle, region binding, feature flags per tenant |
| `config-svc` | Signed config distribution from control plane |
| `secrets-broker-svc` | Pulls from KMS/HSM, leases short-lived creds to services |
| `obs-aggregator-svc` | Anonymised SLO/ML metrics → control plane telemetry lake |
| `drill-svc` | Shadow-mode runner; replays historical events into a sandbox |

## 3. Service-level dependency table (essential edges)

```
gw-public-api      → readings (read-only via cache), twin, alerts (read), gis-tile
gw-citizen-api     → auth, citizen-report, alerts, twin, response (SOS)
gw-officer         → auth, every kernel (read), decision, response, agent-runtime
flood-kernel       → flood-ingest, twin, model-serving, alerts, audit
decision-svc       → agent-runtime, every kernel (read), twin, sim, llm-router, safety, audit
agent-runtime      → agent-tool-gateway → policy → kernels/twin/response/feature-store
alerts-svc         → consent, sms/wa/rcs/push/cb/pa adapters, audit
postmortem-svc     → audit (read-only), every kernel (read), llm-router, safety
```

## 4. Scaling profiles

| Service | Baseline | Peak | Scaler |
|---|---|---|---|
| `gw-ws` | 10 pods | 80 pods | active connections |
| `gw-public-api` | 6 | 40 | RPS |
| `flood-kernel-svc` | 3 | 12 | Kafka lag |
| `cyclone-track-svc` | 2 | 20 | GPU utilisation |
| `decision-svc` | 4 | 16 | request queue |
| `agent-runtime-svc` | 4 | 32 | concurrent agent runs |
| `model-serving-svc` (GPU) | 2 nodes | 12 nodes | inference queue |
| `alerts-svc` | 4 | 30 | outbox depth |
| `cb-adapter-svc` | 1 | 4 | cell-broadcast queue |
| `twin-svc` | 4 | 12 | tile request rate |

## 5. Service ownership template

Every service ships with a `SERVICE.md`:

```yaml
name: flood-kernel-svc
owner: team-flood
oncall: pagerduty:team-flood
slos:
  - name: "kernel.forecast.p95"
    target: "p95 < 4s"
  - name: "kernel.availability"
    target: "99.95%"
data_classes_handled: [public, internal]
external_dependencies: [imd-api, cwc-api]
disaster_role: "predictive"
runbooks:
  - "../../ops/runbooks/flood-kernel-stale.md"
  - "../../ops/runbooks/imd-feed-down.md"
```

This file is the source of truth for the service registry, on-call rotations, and the duty SRE's "who do I page" flow.

## 6. Why this many services?

Each is small (200–2,000 LoC of business logic). The split is not theoretical — it maps to:

- **Failure isolation** — a bad cyclone model deploy cannot bring down flood alerts.
- **Vendor swap-ability** — `wa-adapter-svc` can be replaced without touching `alerts-svc`.
- **Clearance compartmentalisation** — countries with stricter clearance can run a subset (e.g., no LLM, only on-prem inference) by toggling services in their tenant config.
- **Team autonomy** — a 3-person squad owns a kernel end-to-end, including deployment, on-call and SLOs.
