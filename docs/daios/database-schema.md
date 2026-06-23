# DAIOS — Database Schema

Three datastores carry distinct workloads:

| Store | Purpose |
|---|---|
| **PostgreSQL 16 + TimescaleDB + PostGIS** | Authoritative state, time-series readings, geo |
| **Redis 7** | Hot path cache + pubsub + rate-limit + ephemeral session state |
| **OpenSearch** | Full-text on incidents, audit, citizen reports |
| **Neo4j** | Infrastructure graph (roads, power, telecom topology) |
| **S3 / Object** | Satellite tiles, model artefacts, signed reports, raw payloads |
| **Vector store (pgvector / OpenSearch knn)** | RAG corpus for agents (SOPs, past incidents, policy docs) |

Schema below is **per sovereign plane**. Multi-tenancy is enforced via `tenant_id` on every table + RLS.

## 1. Schemas (logical partitioning)

```sql
CREATE SCHEMA platform;     -- tenants, users, roles, audit, consent
CREATE SCHEMA geo;          -- regions, districts, wards, cadastral, hospitals, dams
CREATE SCHEMA hazard;       -- hazard-agnostic core: events, incidents, alerts, decisions
CREATE SCHEMA flood;        -- per-hazard extensions
CREATE SCHEMA earthquake;
CREATE SCHEMA cyclone;
CREATE SCHEMA heatwave;
CREATE SCHEMA landslide;
CREATE SCHEMA twin;         -- live geo-temporal state
CREATE SCHEMA response;     -- incidents (operational), tasks, dispatch, resources
CREATE SCHEMA citizen;      -- registered citizens, reports, SOS, consents
CREATE SCHEMA ai;           -- model registry mirror, evaluations, agent runs
CREATE SCHEMA analytics;    -- continuous aggregates, materialised views
```

## 2. Platform — tenants, users, roles, audit

```sql
-- A tenant is typically a country, but can be a state inside a federation
CREATE TABLE platform.tenants (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT UNIQUE NOT NULL,            -- 'IN-BR', 'IN-OD', 'NP'
  name            TEXT NOT NULL,
  region          TEXT NOT NULL,                   -- ap-south-1, ap-southeast-3
  data_residency  TEXT NOT NULL,                   -- 'IN','NP','BD'
  hazards_enabled TEXT[] NOT NULL,                 -- ['flood','cyclone','heatwave']
  channels_enabled TEXT[] NOT NULL,                -- ['sms','wa','cb']
  feature_flags   JSONB NOT NULL DEFAULT '{}'::jsonb,
  status          TEXT NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE platform.users (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL REFERENCES platform.tenants(id),
  email           CITEXT NOT NULL,
  phone_e164      TEXT,
  full_name_enc   BYTEA NOT NULL,                  -- AES-GCM
  password_hash   TEXT NOT NULL,
  webauthn_creds  JSONB NOT NULL DEFAULT '[]'::jsonb,
  mfa_enrolled    BOOLEAN NOT NULL DEFAULT false,
  status          TEXT NOT NULL DEFAULT 'active',
  last_login_at   TIMESTAMPTZ,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (tenant_id, email)
);

CREATE TABLE platform.roles (
  id              SERIAL PRIMARY KEY,
  code            TEXT UNIQUE NOT NULL,
  -- 'global_admin','tenant_admin','seoc_commander','district_officer',
  -- 'data_entry','department_lead','citizen_responder','auditor','readonly'
  scope           TEXT NOT NULL                    -- 'global','tenant','region','district','department'
);

CREATE TABLE platform.user_roles (
  user_id         UUID NOT NULL REFERENCES platform.users(id),
  role_id         INT  NOT NULL REFERENCES platform.roles(id),
  region_code     TEXT REFERENCES geo.regions(code),
  district_code   TEXT REFERENCES geo.districts(code),
  department      TEXT,                            -- 'police','health','water','power','transport'
  assigned_by     UUID REFERENCES platform.users(id),
  assigned_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id, COALESCE(region_code,''), COALESCE(district_code,''), COALESCE(department,''))
);

-- ABAC attributes for OPA
CREATE TABLE platform.user_attributes (
  user_id         UUID PRIMARY KEY REFERENCES platform.users(id),
  attrs           JSONB NOT NULL DEFAULT '{}'::jsonb
);

-- Append-only signed audit (Timescale hypertable)
CREATE TABLE platform.audit_events (
  id              BIGSERIAL,
  tenant_id       UUID NOT NULL,
  occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id        UUID,
  actor_type      TEXT NOT NULL,                   -- 'user','agent','system'
  agent_run_id    UUID,                            -- if AI agent
  action          TEXT NOT NULL,
  entity_type     TEXT NOT NULL,
  entity_id       TEXT NOT NULL,
  before          JSONB,
  after           JSONB,
  request_id      UUID,
  causation_id    UUID,
  trace_id        TEXT,
  prev_signature  BYTEA,
  signature       BYTEA NOT NULL,
  PRIMARY KEY (occurred_at, id)
);
SELECT create_hypertable('platform.audit_events','occurred_at',chunk_time_interval=>INTERVAL '7 days');
REVOKE UPDATE, DELETE ON platform.audit_events FROM PUBLIC;
SELECT add_retention_policy('platform.audit_events', INTERVAL '10 years');
```

## 3. Geo — physical world reference

```sql
CREATE EXTENSION IF NOT EXISTS postgis;

CREATE TABLE geo.regions (
  code        TEXT PRIMARY KEY,                    -- 'BR' (Bihar), 'OD'
  tenant_id   UUID NOT NULL REFERENCES platform.tenants(id),
  name_en     TEXT NOT NULL,
  names_i18n  JSONB NOT NULL DEFAULT '{}'::jsonb,  -- {"hi":"बिहार","mr":"महाराष्ट्र"}
  polygon     GEOGRAPHY(MULTIPOLYGON, 4326),
  population  BIGINT
);

CREATE TABLE geo.districts (
  code        TEXT PRIMARY KEY,
  region_code TEXT NOT NULL REFERENCES geo.regions(code),
  name_en     TEXT NOT NULL,
  names_i18n  JSONB NOT NULL DEFAULT '{}'::jsonb,
  centroid    GEOGRAPHY(POINT, 4326) NOT NULL,
  polygon     GEOGRAPHY(MULTIPOLYGON, 4326),
  population  BIGINT
);

CREATE TABLE geo.wards (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  district_code TEXT NOT NULL REFERENCES geo.districts(code),
  code        TEXT NOT NULL,
  name        TEXT NOT NULL,
  polygon     GEOGRAPHY(MULTIPOLYGON, 4326) NOT NULL,
  population  BIGINT,
  UNIQUE (district_code, code)
);

-- Critical infrastructure used in impact estimation & dispatch
CREATE TABLE geo.facilities (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL REFERENCES platform.tenants(id),
  type        TEXT NOT NULL                        -- 'hospital','school','dam','shelter','power_substation','pumping_station','fire_station','police_station'
              CHECK (type IN ('hospital','school','dam','shelter','power_substation','pumping_station','fire_station','police_station','telecom_tower','airport','bridge','railway_station','water_treatment')),
  name        TEXT NOT NULL,
  district_code TEXT REFERENCES geo.districts(code),
  location    GEOGRAPHY(POINT, 4326) NOT NULL,
  capacity    JSONB,                               -- {"beds":120,"icu":18}
  attrs       JSONB NOT NULL DEFAULT '{}'::jsonb,
  status      TEXT NOT NULL DEFAULT 'operational'
);
CREATE INDEX ix_facilities_geo ON geo.facilities USING GIST (location);
CREATE INDEX ix_facilities_type ON geo.facilities (tenant_id, type);
```

## 4. Hazard core — events, incidents, alerts, decisions

These are **hazard-agnostic** tables that every kernel writes into. Hazard-specific extensions live in their own schemas (§5).

```sql
-- A canonical "thing happened" record. Append-only.
CREATE TABLE hazard.events (
  id            UUID PRIMARY KEY DEFAULT uuidv7(),
  tenant_id     UUID NOT NULL,
  hazard        TEXT NOT NULL,                     -- 'flood','earthquake','cyclone',...
  occurred_at   TIMESTAMPTZ NOT NULL,
  received_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  source        TEXT NOT NULL,                     -- 'sensor','imd_api','citizen','ml_forecast','satellite'
  severity      TEXT NOT NULL CHECK (severity IN ('info','watch','warning','severe','extreme')),
  location      GEOGRAPHY(POINT, 4326),
  payload       JSONB NOT NULL,
  schema_ver    SMALLINT NOT NULL,
  causation_id  UUID,
  correlation_id UUID,
  signature     BYTEA NOT NULL
);
SELECT create_hypertable('hazard.events','occurred_at',chunk_time_interval=>INTERVAL '1 day');
CREATE INDEX ix_events_tenant_hazard_time ON hazard.events (tenant_id, hazard, occurred_at DESC);
CREATE INDEX ix_events_geo ON hazard.events USING GIST (location);

-- An incident is a coordinated, named situation officials are tracking
CREATE TABLE hazard.incidents (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL,
  hazard        TEXT NOT NULL,
  title         TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'monitoring' -- monitoring|active|escalated|resolved|post-event
                CHECK (status IN ('monitoring','active','escalated','resolved','post-event')),
  severity      TEXT NOT NULL,
  opened_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  opened_by     UUID,
  closed_at     TIMESTAMPTZ,
  area          GEOGRAPHY(MULTIPOLYGON, 4326),
  affected_districts TEXT[] NOT NULL DEFAULT '{}',
  est_affected_population BIGINT,
  attrs         JSONB NOT NULL DEFAULT '{}'::jsonb
);

CREATE TABLE hazard.alerts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL,
  incident_id   UUID REFERENCES hazard.incidents(id),
  hazard        TEXT NOT NULL,
  severity      TEXT NOT NULL,
  raised_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  cleared_at    TIMESTAMPTZ,
  area          GEOGRAPHY(MULTIPOLYGON, 4326) NOT NULL,
  message_i18n  JSONB NOT NULL,                    -- {"en":"...", "hi":"..."}
  channels_dispatched JSONB NOT NULL DEFAULT '[]'::jsonb,
                                                   -- [{channel,sent_at,recipients,status}]
  authorising_user_id UUID,
  authorisation_chain JSONB NOT NULL DEFAULT '[]'::jsonb,
  status        TEXT NOT NULL DEFAULT 'active'
);

-- A proposal made by the decision engine awaiting / having authorisation
CREATE TABLE hazard.decisions (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id     UUID NOT NULL,
  incident_id   UUID REFERENCES hazard.incidents(id),
  proposed_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  proposer      TEXT NOT NULL,                     -- 'agent:police','agent:health','human:user-uuid'
  agent_run_id  UUID,
  rank          INT NOT NULL,
  action_type   TEXT NOT NULL,                     -- 'evacuate','open_shelter','dispatch_team','issue_alert','close_road'
  action_payload JSONB NOT NULL,
  rationale     TEXT NOT NULL,
  reasoning_trace_url TEXT,                        -- S3 URL to full chain-of-thought (admin-only)
  confidence    NUMERIC(4,3) NOT NULL,
  expected_impact JSONB,                           -- estimated lives, property, time saved
  status        TEXT NOT NULL DEFAULT 'pending'
                CHECK (status IN ('pending','authorised','rejected','executed','expired')),
  authorised_by UUID,
  authorised_at TIMESTAMPTZ,
  executed_at   TIMESTAMPTZ,
  outcome       JSONB
);
CREATE INDEX ix_decisions_incident ON hazard.decisions (incident_id, rank);
```

## 5. Hazard-specific extensions

Each kernel adds its own time-series tables that link back to `hazard.events` via foreign key.

### 5.1 Flood
```sql
CREATE TABLE flood.stations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  code TEXT NOT NULL UNIQUE,
  river_id UUID, district_code TEXT REFERENCES geo.districts(code),
  location GEOGRAPHY(POINT,4326) NOT NULL,
  warning_level NUMERIC(8,3), danger_level NUMERIC(8,3), hfl NUMERIC(8,3),
  zero_gauge NUMERIC(8,3), source TEXT, status TEXT
);
CREATE TABLE flood.readings (
  station_id UUID NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  level_m NUMERIC(8,3) NOT NULL,
  trend TEXT, severity TEXT NOT NULL,
  source TEXT NOT NULL, ingested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  event_id UUID REFERENCES hazard.events(id),
  PRIMARY KEY (station_id, observed_at, source)
);
SELECT create_hypertable('flood.readings','observed_at',chunk_time_interval=>INTERVAL '1 day');
```

### 5.2 Earthquake
```sql
CREATE TABLE earthquake.events (
  event_id UUID PRIMARY KEY REFERENCES hazard.events(id),
  origin_at TIMESTAMPTZ NOT NULL,
  epicenter GEOGRAPHY(POINT,4326) NOT NULL,
  depth_km NUMERIC(6,2),
  magnitude NUMERIC(3,2) NOT NULL,
  magnitude_type TEXT NOT NULL,                    -- 'Mw','Mb','Ml'
  shakemap_url TEXT,
  felt_intensity_mmi SMALLINT
);
CREATE INDEX ix_eq_geo ON earthquake.events USING GIST (epicenter);

CREATE TABLE earthquake.shake_observations (
  station_id UUID NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  pga NUMERIC(8,4),         -- peak ground acceleration (g)
  pgv NUMERIC(8,4),
  intensity_mmi SMALLINT,
  PRIMARY KEY (station_id, observed_at)
);
SELECT create_hypertable('earthquake.shake_observations','observed_at',chunk_time_interval=>INTERVAL '1 day');
```

### 5.3 Cyclone
```sql
CREATE TABLE cyclone.systems (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id UUID NOT NULL,
  basin TEXT NOT NULL,                              -- 'NIO','SIO'
  name TEXT NOT NULL,                               -- 'Biparjoy'
  classification TEXT NOT NULL,                     -- 'D','DD','CS','SCS','VSCS','ESCS','SuCS'
  formed_at TIMESTAMPTZ NOT NULL,
  dissipated_at TIMESTAMPTZ
);
CREATE TABLE cyclone.track_points (
  cyclone_id UUID NOT NULL REFERENCES cyclone.systems(id),
  observed_at TIMESTAMPTZ NOT NULL,
  position GEOGRAPHY(POINT,4326) NOT NULL,
  pressure_mb NUMERIC(6,1),
  wind_max_kt NUMERIC(5,1),
  source TEXT NOT NULL,                             -- 'imd','jtwc','ecmwf'
  PRIMARY KEY (cyclone_id, observed_at, source)
);
SELECT create_hypertable('cyclone.track_points','observed_at',chunk_time_interval=>INTERVAL '6 hours');

CREATE TABLE cyclone.forecast_tracks (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cyclone_id UUID NOT NULL REFERENCES cyclone.systems(id),
  issued_at TIMESTAMPTZ NOT NULL,
  model TEXT NOT NULL,                              -- 'IMD-GFS','ECMWF-IFS','DAIOS-Ensemble'
  horizon_hours INT NOT NULL,
  geometry GEOGRAPHY(LINESTRING,4326) NOT NULL,
  cone GEOGRAPHY(POLYGON,4326),                     -- uncertainty cone
  attrs JSONB NOT NULL
);
```

### 5.4 Heatwave
```sql
CREATE TABLE heatwave.observations (
  station_id UUID NOT NULL,
  observed_at TIMESTAMPTZ NOT NULL,
  temp_c NUMERIC(4,1) NOT NULL,
  rh_pct NUMERIC(4,1),
  heat_index_c NUMERIC(4,1),
  wbgt_c NUMERIC(4,1),
  PRIMARY KEY (station_id, observed_at)
);
SELECT create_hypertable('heatwave.observations','observed_at',chunk_time_interval=>INTERVAL '1 day');
```

### 5.5 Landslide
```sql
CREATE TABLE landslide.risk_grid (
  cell_id BIGINT NOT NULL,                          -- H3 r=8 cell
  evaluated_at TIMESTAMPTZ NOT NULL,
  rainfall_24h NUMERIC(6,1),
  soil_moisture NUMERIC(4,3),
  slope_deg NUMERIC(4,1),
  risk_score NUMERIC(4,3) NOT NULL,
  risk_class TEXT NOT NULL,
  PRIMARY KEY (cell_id, evaluated_at)
);
SELECT create_hypertable('landslide.risk_grid','evaluated_at',chunk_time_interval=>INTERVAL '1 day');
```

## 6. Twin — live geo-temporal state

```sql
CREATE TABLE twin.snapshots (
  tenant_id    UUID NOT NULL,
  taken_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  scope        TEXT NOT NULL,                        -- 'tenant','region:BR','district:PAT'
  state        JSONB NOT NULL,                       -- compact JSON snapshot of overlays
  PRIMARY KEY (tenant_id, scope, taken_at)
);
SELECT create_hypertable('twin.snapshots','taken_at',chunk_time_interval=>INTERVAL '1 hour');
SELECT add_retention_policy('twin.snapshots', INTERVAL '30 days');

CREATE TABLE twin.overlays (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL,
  layer        TEXT NOT NULL,                        -- 'flood_extent','wind_field','heat_grid'
  generated_at TIMESTAMPTZ NOT NULL,
  geometry     GEOGRAPHY(MULTIPOLYGON,4326),
  raster_url   TEXT,
  attrs        JSONB
);
```

## 7. Response — operational data

```sql
CREATE TABLE response.tasks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  incident_id   UUID NOT NULL REFERENCES hazard.incidents(id),
  decision_id   UUID REFERENCES hazard.decisions(id),
  type          TEXT NOT NULL,                       -- 'dispatch','evacuate','open_shelter','road_close'
  assigned_dept TEXT NOT NULL,
  assigned_unit_id UUID,
  status        TEXT NOT NULL DEFAULT 'queued',
  priority      SMALLINT NOT NULL DEFAULT 5,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  due_by        TIMESTAMPTZ,
  completed_at  TIMESTAMPTZ,
  payload       JSONB NOT NULL
);
CREATE INDEX ix_tasks_incident_status ON response.tasks (incident_id, status);

CREATE TABLE response.units (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL,
  department  TEXT NOT NULL,
  callsign    TEXT NOT NULL,
  type        TEXT NOT NULL,                        -- 'NDRF-team','ambulance','fire-tender','police-patrol'
  capacity    JSONB,
  base_location GEOGRAPHY(POINT,4326),
  status      TEXT NOT NULL DEFAULT 'available'
);

CREATE TABLE response.unit_telemetry (
  unit_id     UUID NOT NULL REFERENCES response.units(id),
  observed_at TIMESTAMPTZ NOT NULL,
  location    GEOGRAPHY(POINT,4326) NOT NULL,
  speed_kmh   NUMERIC(5,2),
  status      TEXT,
  PRIMARY KEY (unit_id, observed_at)
);
SELECT create_hypertable('response.unit_telemetry','observed_at',chunk_time_interval=>INTERVAL '1 hour');
SELECT add_retention_policy('response.unit_telemetry', INTERVAL '90 days');
```

## 8. Citizen data

Privacy-by-design. PII fields are encrypted at the application layer (AES-GCM, per-tenant DEK, KMS-wrapped). Searchable PII uses blind indexes (HMAC-SHA256 with per-tenant secret).

```sql
CREATE TABLE citizen.profiles (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id       UUID NOT NULL,
  phone_blind_idx BYTEA,                             -- searchable
  phone_enc       BYTEA,
  name_enc        BYTEA,
  preferred_lang  TEXT NOT NULL DEFAULT 'en',
  preferred_channels TEXT[] NOT NULL DEFAULT '{push}',
  registered_via  TEXT NOT NULL,                     -- 'app','sms','web'
  consent         JSONB NOT NULL,                    -- versioned consent record
  home_location_geohash CHAR(8),                     -- coarse only at rest
  status          TEXT NOT NULL DEFAULT 'active',
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE citizen.devices (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  citizen_id      UUID NOT NULL REFERENCES citizen.profiles(id),
  push_token_enc  BYTEA,
  platform        TEXT NOT NULL,
  last_seen_at    TIMESTAMPTZ,
  device_attestation JSONB                           -- Play Integrity / DeviceCheck
);

CREATE TABLE citizen.reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL,
  citizen_id  UUID,
  hazard      TEXT,
  reported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  location    GEOGRAPHY(POINT,4326),
  text_redacted TEXT,
  media_urls  TEXT[],
  cv_labels   JSONB,                                 -- ML classifier output
  trust_score NUMERIC(3,2),
  triage_status TEXT NOT NULL DEFAULT 'pending'
);
CREATE INDEX ix_reports_geo ON citizen.reports USING GIST (location);

-- High-priority — always denormalised, zero indirection
CREATE TABLE citizen.sos (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id   UUID NOT NULL,
  citizen_id  UUID,
  initiated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  location    GEOGRAPHY(POINT,4326) NOT NULL,
  callback_phone_enc BYTEA NOT NULL,
  details     JSONB,
  status      TEXT NOT NULL DEFAULT 'open',
  assigned_unit_id UUID,
  closed_at   TIMESTAMPTZ
);
CREATE INDEX ix_sos_open ON citizen.sos (tenant_id, status) WHERE status = 'open';
```

## 9. AI

```sql
CREATE TABLE ai.models (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  hazard       TEXT,
  task         TEXT NOT NULL,                        -- 'forecast','classify','detect','sum'
  framework    TEXT NOT NULL,                        -- 'pytorch','xgboost','llm'
  artifact_uri TEXT NOT NULL,                        -- s3://...
  version      TEXT NOT NULL,
  registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  approved_for_prod BOOLEAN NOT NULL DEFAULT false,
  signature    BYTEA NOT NULL                        -- cosign attestation
);

CREATE TABLE ai.evaluations (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  model_id     UUID NOT NULL REFERENCES ai.models(id),
  evaluated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  dataset      TEXT NOT NULL,
  metrics      JSONB NOT NULL,                       -- {"mae":0.18,"crps":0.42,...}
  drift        JSONB
);

CREATE TABLE ai.agent_runs (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  tenant_id    UUID NOT NULL,
  incident_id  UUID,
  agent_id     TEXT NOT NULL,                        -- 'orchestrator','police','health',...
  started_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at     TIMESTAMPTZ,
  status       TEXT NOT NULL DEFAULT 'running',
  prompt_hash  BYTEA,
  tools_used   JSONB,
  trace_uri    TEXT,                                 -- s3://traces/...
  output       JSONB,
  cost_tokens  INT,
  guardrails_triggered JSONB
);
```

## 10. Continuous aggregates

```sql
CREATE MATERIALIZED VIEW analytics.events_hourly
WITH (timescaledb.continuous) AS
SELECT tenant_id, hazard,
       time_bucket('1 hour', occurred_at) AS bucket,
       severity,
       COUNT(*) AS n
FROM hazard.events
GROUP BY tenant_id, hazard, bucket, severity
WITH NO DATA;
SELECT add_continuous_aggregate_policy('analytics.events_hourly',
  start_offset=>INTERVAL '30 days', end_offset=>INTERVAL '5 minutes',
  schedule_interval=>INTERVAL '5 minutes');

CREATE MATERIALIZED VIEW analytics.alerts_daily
WITH (timescaledb.continuous) AS
SELECT tenant_id, hazard,
       time_bucket('1 day', raised_at) AS bucket,
       severity, COUNT(*) AS n
FROM hazard.alerts
GROUP BY tenant_id, hazard, bucket, severity
WITH NO DATA;
```

## 11. Row-level security & multi-tenancy

```sql
ALTER TABLE hazard.events ENABLE ROW LEVEL SECURITY;
CREATE POLICY tenant_isolation ON hazard.events
  USING (tenant_id::text = current_setting('app.tenant_id', true));

-- Officer scoping (district)
CREATE POLICY officer_scope ON response.tasks
  FOR ALL TO app_role
  USING (
    current_setting('app.role',true) IN ('seoc_commander','tenant_admin')
    OR EXISTS (
      SELECT 1 FROM hazard.incidents i
      WHERE i.id = response.tasks.incident_id
        AND current_setting('app.district',true) = ANY(i.affected_districts)
    )
  );
```

The connection-pooler injects `SET LOCAL app.tenant_id`, `app.role`, `app.user_id`, `app.district` on every transaction.

## 12. Retention summary

| Data | Hot (PG) | Warm (compressed) | Cold (S3 Glacier) |
|---|---|---|---|
| `hazard.events` | 90 days | 2 years | 10 years |
| `flood.readings` etc. | 90 days | 2 years | 10 years |
| `response.unit_telemetry` | 90 days | — | 1 year |
| `citizen.sos` | 1 year | 5 years | 10 years |
| `citizen.reports` | 1 year | 3 years | 5 years (anonymised) |
| `platform.audit_events` | 1 year | 9 years | indefinite, immutable |
| `ai.agent_runs` | 30 days | 1 year | — |
| `twin.snapshots` | 30 days | — | — |

## 13. Backup & recovery

- pgBackRest daily full + 6-hourly incrementals; WAL archived continuously.
- PITR window 30 days.
- Cross-AZ sync, cross-region async (within sovereign boundary only).
- Quarterly restore drills measure RTO; gate is ≤ 5 min for hot DB.
- Backups are encrypted (KMS), bucket has Object Lock (compliance mode).
