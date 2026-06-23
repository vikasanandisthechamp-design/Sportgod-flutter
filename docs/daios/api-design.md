# DAIOS — API Design

DAIOS exposes four classes of API, each optimised for a different consumer:

| API | Consumer | Style | Auth |
|---|---|---|---|
| **Public Read API** | Citizens, websites, kiosks, third-party apps | REST + GraphQL, heavily cached | None / API key |
| **Citizen API** | Citizen mobile/web app | REST + WebSocket | Device-bound JWT |
| **Officer / Console API** | SEOC, district officers, agency leads | GraphQL Federation + WebSocket | OIDC + MFA + WebAuthn |
| **Partner / Agency API** | IMD, USGS, telcos, NDRF, hospitals | REST + Webhooks + gRPC | mTLS + OAuth2 client-credentials |

All under `https://<tenant>.daios.gov` (e.g. `bihar.daios.gov`) and the global `https://api.daios.global` (control-plane only).

## 1. Conventions

- **Versioning:** URI for REST (`/api/v1/...`), schema directives for GraphQL (`@since`, `@deprecated`).
- **Time:** ISO 8601, server normalises to UTC; clients render in local TZ.
- **IDs:** UUIDv7 for events (sortable by time); UUIDv4 elsewhere.
- **Pagination:** cursor-based (opaque token); `limit` ≤ 200.
- **Idempotency:** `Idempotency-Key` header on writes.
- **Correlation:** every response carries `X-Request-ID` and `X-Trace-ID` (W3C traceparent).
- **Errors:** RFC 7807 Problem+JSON for REST; typed errors in GraphQL `extensions.code`.
- **Rate limits:** documented per route, returned in `RateLimit-*` headers (RFC 9239).
- **OpenAPI 3.1 + GraphQL SDL** generated from server code; published at `/api/openapi.json` and `/graphql/schema`.

## 2. Public Read API (REST highlights)

```
GET /api/v1/public/hazards                                # which hazards are tracked here
GET /api/v1/public/regions
GET /api/v1/public/regions/{code}
GET /api/v1/public/regions/{code}/summary                 # all-hazard severity rollup
GET /api/v1/public/incidents/active
GET /api/v1/public/incidents/{id}
GET /api/v1/public/alerts/active?bbox=&hazard=
GET /api/v1/public/alerts/{id}
GET /api/v1/public/twin/overlays?layer=flood_extent&z=&x=&y=  # tile endpoint
GET /api/v1/public/sensors/{type}/{id}/latest
GET /api/v1/public/sensors/{type}/{id}/history?from=&to=&bucket=
GET /api/v1/public/post-event/{incident_id}/report.pdf    # signed report
```

Cached aggressively at CDN (`Cache-Control: public, s-maxage=15, stale-while-revalidate=60`).

## 3. Public GraphQL (federated)

A federated GraphQL endpoint stitches readings, twin overlays, alerts, and incidents so dashboards can fetch one shape, no waterfalls.

```graphql
type Query {
  region(code: ID!): Region
  incident(id: ID!): Incident
  activeAlerts(bbox: BBox, hazards: [Hazard!]): [Alert!]!
}

type Region {
  code: ID!
  name: I18n!
  population: Int!
  districts: [District!]!
  summary(hazards: [Hazard!]): SeveritySummary!
}

type Incident {
  id: ID!
  hazard: Hazard!
  status: IncidentStatus!
  severity: Severity!
  area: GeoJSON!
  estAffectedPopulation: Int
  alerts: [Alert!]!
  decisions(authorisedOnly: Boolean = true): [Decision!]!
  timeline(limit: Int = 100): [TimelineEntry!]!
  postEventReportUrl: URL
}

type Decision {
  id: ID!
  proposer: String!
  rank: Int!
  actionType: ActionType!
  rationale: String!
  confidence: Float!
  status: DecisionStatus!
  expectedImpact: ExpectedImpact
  reasoningTraceUrl: URL @auth(roles: [auditor, seoc_commander])
}

scalar GeoJSON
scalar URL
scalar I18n
```

Subscriptions are GraphQL over WS:

```graphql
type Subscription {
  incidentUpdated(id: ID!): Incident!
  alertsInRegion(code: ID!): Alert!
  twinOverlayUpdated(layer: String!): OverlayPatch!
}
```

## 4. Citizen API (REST + WS)

```
POST /api/v1/citizen/auth/register             { phone, lang, channel_consent }
POST /api/v1/citizen/auth/otp/verify           { phone, code }
POST /api/v1/citizen/sos                       { lat, lng, details? }
                                              ★ no body for "panic" (just headers + last known loc)
POST /api/v1/citizen/reports                   multipart: photo, video, text, geo
GET  /api/v1/citizen/me/alerts                 (their subscribed hazards/area)
GET  /api/v1/citizen/me/preferences
PATCH /api/v1/citizen/me/preferences
GET  /api/v1/citizen/nearby                    (open shelters, hospitals, road status)
```

WebSocket topics:
- `citizen.alerts.me` — alerts targeted at the device's last-known cell or geohash
- `citizen.incidents.nearby`
- `citizen.sos.{id}` — status updates on their own SOS

### 4.1 SOS contract (must work even on low signal)
- Request body is optional; everything inferred from headers + cached profile.
- Server acks within 1 s with `sos_id`.
- Response includes a one-time **SOS PIN** for callbacks.
- Even if WS is down, citizens get SMS confirmation.
- Idempotent: same device repeating SOS within 5 min → same `sos_id`.

```http
POST /api/v1/citizen/sos
Authorization: Bearer <device-jwt>
X-Last-Loc: 25.5941,85.1376
X-Battery: 7
Idempotency-Key: 0195f10f-...

201 Created
{
  "sos_id": "0195f...",
  "pin": "4-731-902",
  "ack_sms_sent": true,
  "estimated_response_min": 12,
  "checklist": ["..."]
}
```

## 5. Officer / Console API

Officer console runs on **GraphQL Federation** so SEOC dashboards compose data across hazards in one query. Mutations are typed; permissions enforced via OPA (`policy-svc`).

```graphql
type Mutation {
  acknowledgeAlert(id: ID!, note: String): Alert!
  authoriseDecision(id: ID!, justification: String!): Decision!
                  @requires(role: "seoc_commander")
  rejectDecision(id: ID!, reason: String!): Decision!
  raiseManualAlert(input: ManualAlertInput!): Alert!
                  @requires(role: ["seoc_commander","district_officer"])
  openIncident(input: IncidentInput!): Incident!
  closeIncident(id: ID!, summary: String!): Incident!
  createTask(input: TaskInput!): Task!
  reassignTask(id: ID!, unitId: ID!): Task!
  invokeAgent(input: AgentInvokeInput!): AgentRun!
                  @requires(role: ["seoc_commander","department_lead"])
  pushPostEventReport(id: ID!): Url!
}
```

Every mutation requires a fresh **step-up MFA token** (≤ 5 min old) and produces an audit entry with `before/after` JSON and the user's reasoning.

### 5.1 Voice-command interface

A WS topic `officer.voice` accepts streamed audio frames; voice-svc transcribes (Whisper-class, sovereign) and emits a structured intent. Intents are routed to the same GraphQL mutations through `agent-tool-gateway-svc`, with the human pressing PTT acting as authorisation evidence.

```
ws://officer.daios.gov/voice
→ frames (PCM 16k)
← {"transcript":"...","intent":"OPEN_INCIDENT","args":{...},"confidence":0.94}
← {"intent_authorised":true,"mutation":"openIncident","result":{...}}
```

A spoken **command word** (configurable; default "DAIOS confirm") is required before high-impact actions execute. Without it, the agent only proposes; the officer taps to authorise.

## 6. Partner API (machine-to-machine)

mTLS + OAuth2 client-credentials. Each partner has a contract describing allowed endpoints, scopes, and SLAs.

```
POST /api/v1/ingest/imd/observations
POST /api/v1/ingest/usgs/eq
POST /api/v1/ingest/jtwc/cyclone-track
POST /api/v1/ingest/iot/batch
POST /api/v1/ingest/hospital/capacity
POST /api/v1/ingest/citizen-report-bulk
```

Webhooks for partners (push from DAIOS):

```
POST /webhook  body=alert.raised | incident.opened | sos.assigned | postmortem.published
                Signature: sha256=...
```

gRPC service for ultra-low-latency partners (telcos for cell broadcast):

```protobuf
service AlertChannel {
  rpc Dispatch (stream AlertBatch) returns (stream DispatchAck);
  rpc Health (Empty) returns (HealthStatus);
}
```

## 7. Standard error model

```json
{
  "type":   "https://daios.global/errors/forbidden-cross-tenant",
  "title":  "Cross-tenant access denied",
  "status": 403,
  "detail": "Tenant IN-BR cannot access incident in IN-OD",
  "request_id": "0195f10f-...",
  "trace_id":   "00-...-01",
  "remediation":"Use the correct tenant gateway"
}
```

Common types:

| Type | HTTP | Meaning |
|---|---|---|
| `validation` | 422 | Schema or business-rule violation |
| `idempotent-replay` | 200 | Replay; cached result returned |
| `rate-limited` | 429 | Retry-After header set |
| `auth-required` | 401 | No / invalid token |
| `forbidden-rbac` | 403 | Authenticated but not authorised |
| `forbidden-cross-tenant` | 403 | Tenant boundary violation |
| `causality-conflict` | 409 | Optimistic concurrency lost |
| `dependency-down` | 503 | Upstream (e.g. IMD) unavailable; degraded |
| `safety-blocked` | 451 | AI output blocked by safety-svc |

## 8. Authentication & sessions

| Audience | Method | Lifetime |
|---|---|---|
| Citizen | OTP → device-bound JWT (binding to `device_id` + attestation) | Access 1 h, refresh 30 d, rotating |
| Officer | OIDC SSO + MFA + WebAuthn step-up for sensitive | Access 15 m, refresh 8 h |
| Partner (server) | OAuth2 client-credentials + mTLS | Access 10 m |
| Inter-service | Istio mTLS + SPIFFE identity | per-call |

JWT uses RS256, JWKS rotated every 90 days; verifying services cache keys 24 h.

## 9. Rate limits (illustrative)

| Endpoint class | Anonymous | Citizen JWT | Officer | Partner |
|---|---|---|---|---|
| `GET /public/*` | 200 rps/IP | n/a | n/a | per-contract |
| `POST /citizen/sos` | n/a | 3 / 5 min / device | n/a | n/a |
| `POST /citizen/reports` | n/a | 30 / hour | n/a | n/a |
| `mutation authoriseDecision` | n/a | n/a | 60 / min / user | n/a |
| `POST /ingest/*` | n/a | n/a | n/a | per-contract; default 1k rps |

Rate-limit excess returns `429` with `Retry-After`.

## 10. WebSocket protocol

Native WS, fallback to HTTP long-poll. STOMP-like envelopes:

```json
{ "v":1, "type":"subscribe|unsubscribe|event|ack|err|ping|pong",
  "topic":"...", "id":"...", "payload":{...} }
```

Heartbeats every 25 s. Server enforces:
- ≤ 25 topic subscriptions per connection
- Per-connection outbound buffer 256 messages; overflow → disconnect with code `4002 slow_consumer`
- Per-IP concurrent: 5 anonymous, unlimited authenticated
- Officer connections require step-up MFA every 4 h

Back-pressure pattern: server uses `payload.cursor` so clients can resume after network blips without missing events.

## 11. Idempotency, retries, exactly-once

- POST writes accept `Idempotency-Key` (UUID). Server stores hash of (key, route, body) for 24 h; replay returns the original 2xx response.
- The internal **outbox pattern** guarantees that a successful HTTP write has the corresponding Kafka event committed exactly once (transactional outbox).
- Citizen-side retries are recommended only for SOS (idempotent by design); other writes have user-visible status that prevents accidental duplicates.

## 12. Cell broadcast & PA integration (special)

Cell broadcast is a one-shot, one-shot-only channel — duplicate or conflicting messages cause public confusion. The flow:

1. Operator authorises a `decision.broadcast` decision.
2. `cb-adapter-svc` checks tower-list against jurisdiction overlay.
3. Telco gRPC `Dispatch` is called within a Kafka transaction.
4. Telco ack is recorded against the alert.
5. `safety-svc` post-publication audit verifies content was within authorised template.

A "kill switch" mutation `mutation cancelBroadcast(id: ID!, reason: String!)` is available to Tenant Admins and is itself audited.

## 13. Documentation & developer experience

- **Public API portal**: `https://developers.daios.global/<tenant>` — OpenAPI, GraphQL Voyager, code samples (`curl`, JS, Python, Go).
- **Sandbox tenant**: `sandbox.daios.global` with synthetic data for partner testing; never connected to live channels.
- **CLI**: `daios` CLI for officials (audit query, agent run inspection, drill triggers) — uses the same APIs.
- **SDKs**: TypeScript, Python, Go (auto-generated from OpenAPI/GraphQL).
- **Contract tests**: every service ships **Pact** consumer tests; partner integrations verified in CI before merge.
