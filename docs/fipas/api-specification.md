# FIPAS — API Specification

All endpoints are served under `https://fipas.bihar.gov.in`.
Versioning is URI-based: `/api/v1/...`. Breaking changes bump the major version; additive changes do not.

## 1. Conventions

- **Content type:** `application/json; charset=utf-8`. CSV upload: `multipart/form-data`.
- **Timestamps:** ISO 8601 with timezone (`2026-04-24T11:42:05+05:30`).
- **Units:** water level in meters (`level_m`), always 3-decimal precision.
- **Pagination:** cursor-based (`?cursor=...&limit=50`). `limit` max 200.
- **Idempotency:** `POST` endpoints that mutate accept `Idempotency-Key: <uuid>` header; repeat calls within 24 h return the original result.
- **Correlation:** every response carries `X-Request-ID` that matches the access log and audit entry.
- **Rate limits:** per IP for public, per user+IP for admin. Exceeded → `429` with `Retry-After`.
- **Error model:** RFC 7807 Problem+JSON.

```json
{
  "type":    "https://fipas.bihar.gov.in/errors/invalid-range",
  "title":   "Invalid water level",
  "status":  422,
  "detail":  "level_m must be between 0 and 150",
  "instance":"/api/v1/admin/readings",
  "request_id":"0195f10f-..."
}
```

## 2. Authentication

- **Admin users** → JWT access token (15 min) + refresh token (7 days, rotating).
- **Ingestion clients** → mTLS client certificate (IMD, CWC) **or** signed API key (IoT gateway).
- **Public API** → anonymous, rate-limited by IP.
- Access tokens are `Authorization: Bearer <jwt>`; admin UI also sends `X-CSRF-Token` on mutating calls.

### 2.1 Auth endpoints

```
POST   /api/v1/auth/login                     {email, password, mfa_code?}
POST   /api/v1/auth/refresh                   {refresh_token}           → rotates
POST   /api/v1/auth/logout                    Authorization: Bearer
POST   /api/v1/auth/mfa/enroll                Authorization: Bearer
POST   /api/v1/auth/mfa/verify                {code}
POST   /api/v1/auth/password/change           {old_password, new_password}
POST   /api/v1/auth/password/forgot           {email}                   → email link
POST   /api/v1/auth/password/reset            {token, new_password}
```

### 2.2 JWT claims

```json
{
  "sub": "8c7f...-user-uuid",
  "iss": "fipas-auth",
  "aud": "fipas-api",
  "iat": 1714041000,
  "exp": 1714041900,
  "jti": "0195f10f-...",
  "roles": [
    {"role":"district_officer","scope":"district","district_code":"MZP"},
    {"role":"data_entry","scope":"station","station_id":"..."}
  ]
}
```

Signed with RS256, keys rotated every 90 days. Public keys served at `/.well-known/jwks.json`.

## 3. Public REST API (read-only, cached)

All `GET`s are safe to cache at CDN (`Cache-Control: public, s-maxage=15, stale-while-revalidate=60`).

### 3.1 Districts

```
GET /api/v1/public/districts
```
List all 38 districts with latest summary.

```json
{
  "data": [
    {
      "code": "MZP",
      "name": {"en":"Muzaffarpur","hi":"मुजफ्फरपुर"},
      "division": "Tirhut",
      "station_count": 7,
      "severity_breakdown": {"safe":4,"warning":2,"danger":1,"critical":0},
      "worst_severity": "danger",
      "last_updated_at": "2026-04-24T11:40:00+05:30"
    }
  ]
}
```

```
GET /api/v1/public/districts/{code}
GET /api/v1/public/districts/{code}/stations
```

### 3.2 Rivers

```
GET /api/v1/public/rivers
GET /api/v1/public/rivers/{id}
GET /api/v1/public/rivers/{id}/stations
```

### 3.3 Stations

```
GET /api/v1/public/stations?district=MZP&river=<uuid>&severity=danger&cursor=&limit=50
GET /api/v1/public/stations/{id}
GET /api/v1/public/stations/{id}/latest
GET /api/v1/public/stations/{id}/history?from=&to=&bucket=1h
```

`/latest`:

```json
{
  "data": {
    "station_id": "...",
    "code": "CWC-MZP-01",
    "name": {"en":"Burhi Gandak at Ahirwalia","hi":"बूढ़ी गंडक, अहिरवालिया"},
    "river": {"id":"...","name":{"en":"Burhi Gandak","hi":"बूढ़ी गंडक"}},
    "district_code": "MZP",
    "location": {"lat":26.12,"lng":85.39},
    "levels": {"warning_level":47.5,"danger_level":49.6,"hfl":51.8},
    "reading": {
      "level_m": 49.82,
      "observed_at": "2026-04-24T11:30:00+05:30",
      "severity": "danger",
      "trend": "rising",
      "delta_1h": 0.14,
      "delta_6h": 0.72
    }
  }
}
```

`/history`:

```json
{
  "bucket": "1h",
  "from": "2026-04-17T00:00:00+05:30",
  "to":   "2026-04-24T12:00:00+05:30",
  "series": [
    {"t":"2026-04-24T11:00:00+05:30","avg":49.68,"min":49.60,"max":49.82}
  ]
}
```

### 3.4 Alerts (public)

```
GET /api/v1/public/alerts/active
GET /api/v1/public/alerts/recent?since=&limit=100
```

### 3.5 Map tiles / heatmap

```
GET /api/v1/public/heatmap.geojson               # per-district severity choropleth
GET /api/v1/public/stations.geojson?severity=    # station markers
```

Served with strong ETags, 60 s CDN cache.

## 4. Admin REST API

All routes require `Authorization: Bearer` and `X-CSRF-Token`. RBAC is enforced server-side per endpoint.

### 4.1 Readings

```
POST   /api/v1/admin/readings
```
Body:
```json
{
  "station_id": "...",
  "observed_at": "2026-04-24T11:30:00+05:30",
  "level_m": 49.82,
  "trend": "rising",
  "remarks": "Gauge read manually, board clear"
}
```
- **Who:** `data_entry` with station scope, `district_officer` within their district, `state_admin` globally.
- **Behaviour:** server computes `severity` from station thresholds; server stamps `operator_id`, `ingested_at`; rejects if duplicate within 1 min.
- **Response:** `201 Created` with full reading + triggered alerts (if any).

```
PATCH  /api/v1/admin/readings/{id}         # correction (records both rows, is_corrected=true)
GET    /api/v1/admin/readings?station_id=&from=&to=&cursor=&limit=
DELETE /api/v1/admin/readings/{id}         # state_admin only; soft-delete via correction
```

### 4.2 Bulk CSV upload

```
POST /api/v1/admin/readings/bulk            Content-Type: multipart/form-data
```
Fields: `file` (CSV, ≤ 20 MB), `strict=true|false`, `dry_run=true|false`.

CSV columns: `station_code,observed_at,level_m,trend,remarks`.

Flow:
1. Upload to S3 quarantine prefix.
2. Virus scan (ClamAV sidecar).
3. Schema + range validation.
4. If `dry_run`: returns per-row verdict, no writes.
5. Otherwise commits within a single `ingestions` batch; partial success allowed unless `strict=true`.

Response includes a `job_id` and a poll endpoint:

```
GET /api/v1/admin/ingestions/{job_id}
```

### 4.3 Master data

```
GET    /api/v1/admin/rivers
POST   /api/v1/admin/rivers                        # state_admin
PATCH  /api/v1/admin/rivers/{id}
GET    /api/v1/admin/stations
POST   /api/v1/admin/stations                      # state_admin
PATCH  /api/v1/admin/stations/{id}                 # state_admin / district_officer (limited fields)
```

### 4.4 Users & roles (state_admin only)

```
GET    /api/v1/admin/users
POST   /api/v1/admin/users
PATCH  /api/v1/admin/users/{id}
POST   /api/v1/admin/users/{id}/roles
DELETE /api/v1/admin/users/{id}/roles/{assignment_id}
POST   /api/v1/admin/users/{id}/disable
POST   /api/v1/admin/users/{id}/reset-password
```

### 4.5 Audit log

```
GET /api/v1/admin/audit?actor_id=&action=&entity_type=&from=&to=&cursor=
```
Auditor role gets read-only, all entities. District officer sees only their district entities.

### 4.6 Analytics

```
GET /api/v1/admin/analytics/trends?station_id=&from=&to=&bucket=1d
GET /api/v1/admin/analytics/flood-days?district=&year=
GET /api/v1/admin/analytics/export?format=csv|pdf&report=...
```

## 5. Ingestion API (machine-to-machine)

mTLS required; caller identity is the certificate CN.

```
POST /api/v1/ingest/readings                       # batch, idempotent
POST /api/v1/ingest/heartbeat                      # IoT device ping
POST /api/v1/ingest/imd/push                       # IMD webhook (signed)
POST /api/v1/ingest/cwc/push                       # CWC webhook (signed)
```

Request:

```json
{
  "source": "api_cwc",
  "batch_id": "cwc-2026-04-24T11:30Z",
  "readings": [
    {"station_code":"CWC-MZP-01","observed_at":"...","level_m":49.82},
    ...
  ]
}
```

Response:

```json
{
  "accepted": 124,
  "rejected": 2,
  "rejections": [
    {"station_code":"CWC-XYZ","reason":"unknown_station"},
    {"station_code":"CWC-MZP-01","observed_at":"...","reason":"duplicate"}
  ],
  "ingestion_id": "..."
}
```

## 6. WebSocket API

Endpoint: `wss://fipas.bihar.gov.in/ws`.
Transport: native WebSocket with STOMP-like topic subscription, fallback to Socket.IO long-polling.

### 6.1 Handshake

```
GET /ws
Sec-WebSocket-Protocol: fipas.v1
# anonymous for public rooms; Authorization: Bearer for admin rooms
```

On connect the server responds with:

```json
{"type":"welcome","server_time":"...","heartbeat_ms":25000,"client_id":"..."}
```

Client must respond to `ping` every 25 s or be disconnected.

### 6.2 Message envelope

```json
{
  "type":    "subscribe|unsubscribe|event|error|ping|pong",
  "topic":   "readings.district.MZP",
  "id":      "client-generated-correlation",
  "payload": { ... }
}
```

### 6.3 Topics

| Topic | Auth | Payload |
|---|---|---|
| `readings.district.{code}` | public | new reading within district |
| `readings.river.{id}` | public | new reading on river |
| `readings.station.{id}` | public | single station stream |
| `alerts.state` | public | alerts raised/cleared anywhere in Bihar |
| `alerts.district.{code}` | public | district alerts |
| `display.rotation` | public | TV-mode rotation tick (every 10 s) |
| `admin.audit.live` | auditor/state_admin | real-time audit events |
| `admin.ingest.live` | state_admin | ingestion progress |

### 6.4 Events

**`reading.created`**
```json
{
  "type":"event","topic":"readings.district.MZP",
  "payload":{
    "station_id":"...","code":"CWC-MZP-01",
    "level_m":49.82,"severity":"danger","trend":"rising",
    "observed_at":"...","delta_1h":0.14
  }
}
```

**`alert.raised`** / **`alert.cleared`**
```json
{
  "type":"event","topic":"alerts.state",
  "payload":{
    "alert_id":"...","station_id":"...","severity":"critical",
    "raised_at":"...","peak_level_m":52.1
  }
}
```

### 6.5 Backpressure & limits

- Server buffers per connection up to 256 messages; overflow → disconnect with `slow_consumer`.
- Max 20 topic subscriptions per client.
- Per-IP concurrent connections: 5 anonymous, unlimited authenticated.

## 7. Rate limits (summary)

| Scope | Endpoint | Limit |
|---|---|---|
| Anonymous | `GET /api/v1/public/*` | 100 rps / IP, 5k rph / IP |
| Anonymous | WebSocket connect | 5 concurrent / IP |
| Auth | `POST /auth/login` | 5 / min / IP, 20 / min / email |
| Auth user | `POST /api/v1/admin/readings` | 120 / min |
| Ingest mTLS | `POST /api/v1/ingest/*` | 1000 rps / client cert |

## 8. Health & ops

```
GET /health/live         # liveness
GET /health/ready        # readiness (checks PG, Redis, Kafka)
GET /metrics             # Prometheus, internal only
GET /version             # build sha, git tag
```

## 9. OpenAPI

The full OpenAPI 3.1 spec is generated from NestJS decorators and served at:

```
GET /api/v1/openapi.json
GET /api/v1/docs                   # Redoc (internal only)
```

Admin Redoc is behind auth; public subset is published for partner integrators.
