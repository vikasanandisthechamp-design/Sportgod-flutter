# FIPAS — Database Schema

**Engine:** PostgreSQL 16 with TimescaleDB 2.14 extension.
**Char set:** UTF-8, locale `en_IN`.
**Timezone:** all timestamps stored as `TIMESTAMPTZ` in UTC; presentation layer renders in `Asia/Kolkata`.

## 1. Schemas (logical partitioning)

```sql
CREATE SCHEMA core;       -- reference data: rivers, stations, districts
CREATE SCHEMA ops;        -- operational: readings, alerts, ingestions
CREATE SCHEMA iam;        -- identity & access: users, roles, sessions
CREATE SCHEMA audit;      -- append-only audit trail
CREATE SCHEMA analytics;  -- continuous aggregates / materialised views
```

## 2. Reference data (`core`)

```sql
-- Bihar administrative divisions
CREATE TABLE core.districts (
  code            CHAR(4) PRIMARY KEY,                 -- e.g. 'PAT', 'MZP'
  name_en         TEXT NOT NULL,
  name_hi         TEXT NOT NULL,
  division        TEXT NOT NULL,
  centroid        GEOGRAPHY(POINT, 4326) NOT NULL,
  polygon         GEOGRAPHY(MULTIPOLYGON, 4326),
  population      INTEGER,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE core.rivers (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name_en         TEXT NOT NULL UNIQUE,
  name_hi         TEXT NOT NULL,
  basin           TEXT NOT NULL,                       -- 'Ganga', 'Kosi', 'Bagmati', ...
  origin          TEXT,
  length_km       NUMERIC(6,1),
  tributary_of    UUID REFERENCES core.rivers(id),
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- A gauge station measures one river at one location
CREATE TABLE core.stations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  code            TEXT NOT NULL UNIQUE,                -- CWC/WRD station code
  name_en         TEXT NOT NULL,
  name_hi         TEXT NOT NULL,
  river_id        UUID NOT NULL REFERENCES core.rivers(id) ON DELETE RESTRICT,
  district_code   CHAR(4) NOT NULL REFERENCES core.districts(code),
  location        GEOGRAPHY(POINT, 4326) NOT NULL,
  elevation_m     NUMERIC(8,3),
  -- Calibrated reference levels (meters)
  warning_level   NUMERIC(8,3) NOT NULL,
  danger_level    NUMERIC(8,3) NOT NULL,
  hfl             NUMERIC(8,3) NOT NULL,               -- Highest Flood Level ever recorded
  hfl_recorded_on DATE,
  zero_gauge      NUMERIC(8,3) NOT NULL,               -- datum offset
  status          TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','inactive','under_maintenance','decommissioned')),
  source          TEXT NOT NULL DEFAULT 'WRD'
                  CHECK (source IN ('WRD','CWC','IMD','IoT')),
  metadata        JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK (warning_level < danger_level AND danger_level <= hfl)
);

CREATE INDEX ix_stations_district ON core.stations (district_code) WHERE status = 'active';
CREATE INDEX ix_stations_river    ON core.stations (river_id)      WHERE status = 'active';
CREATE INDEX ix_stations_geo      ON core.stations USING GIST (location);
```

## 3. Time-series data (`ops`)

### 3.1 Readings hypertable

```sql
CREATE TABLE ops.readings (
  station_id     UUID        NOT NULL REFERENCES core.stations(id),
  observed_at    TIMESTAMPTZ NOT NULL,
  level_m        NUMERIC(8,3) NOT NULL,
  trend          TEXT        NOT NULL
                 CHECK (trend IN ('rising','steady','falling','unknown')),
  severity       TEXT        NOT NULL
                 CHECK (severity IN ('safe','warning','danger','critical')),
  source         TEXT        NOT NULL
                 CHECK (source IN ('manual','api_imd','api_cwc','iot','import_csv')),
  ingested_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  ingestion_id   UUID        NOT NULL REFERENCES ops.ingestions(id),
  operator_id    UUID        REFERENCES iam.users(id),            -- NULL for automated
  raw_payload    JSONB,                                           -- upstream original
  is_corrected   BOOLEAN     NOT NULL DEFAULT false,
  correction_of  BIGINT,                                          -- self-reference (see below)
  id             BIGSERIAL   NOT NULL,
  PRIMARY KEY (station_id, observed_at, source)
);

SELECT create_hypertable('ops.readings', 'observed_at',
                         chunk_time_interval => INTERVAL '1 day',
                         if_not_exists       => TRUE);

-- Fast "latest per station" lookups
CREATE INDEX ix_readings_station_time_desc
  ON ops.readings (station_id, observed_at DESC);

-- Severity scan for alert dashboards
CREATE INDEX ix_readings_severity_time
  ON ops.readings (severity, observed_at DESC)
  WHERE severity IN ('danger','critical');

-- Compression on older chunks
ALTER TABLE ops.readings SET (
  timescaledb.compress,
  timescaledb.compress_orderby   = 'observed_at DESC',
  timescaledb.compress_segmentby = 'station_id'
);
SELECT add_compression_policy('ops.readings', INTERVAL '7 days');
SELECT add_retention_policy  ('ops.readings', INTERVAL '2 years');
```

### 3.2 Latest-reading cache table (for sub-ms lookups)

```sql
CREATE TABLE ops.readings_latest (
  station_id     UUID PRIMARY KEY REFERENCES core.stations(id),
  observed_at    TIMESTAMPTZ NOT NULL,
  level_m        NUMERIC(8,3) NOT NULL,
  severity       TEXT NOT NULL,
  trend          TEXT NOT NULL,
  updated_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Upsert on every readings insert via trigger
CREATE OR REPLACE FUNCTION ops.tg_upsert_latest() RETURNS trigger AS $$
BEGIN
  INSERT INTO ops.readings_latest (station_id, observed_at, level_m, severity, trend)
  VALUES (NEW.station_id, NEW.observed_at, NEW.level_m, NEW.severity, NEW.trend)
  ON CONFLICT (station_id) DO UPDATE
    SET observed_at = EXCLUDED.observed_at,
        level_m     = EXCLUDED.level_m,
        severity    = EXCLUDED.severity,
        trend       = EXCLUDED.trend,
        updated_at  = now()
    WHERE ops.readings_latest.observed_at < EXCLUDED.observed_at;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER tg_readings_latest
AFTER INSERT ON ops.readings
FOR EACH ROW EXECUTE FUNCTION ops.tg_upsert_latest();
```

### 3.3 Ingestions

```sql
CREATE TABLE ops.ingestions (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  source         TEXT NOT NULL,              -- 'manual','csv','api_imd','api_cwc','iot'
  started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at    TIMESTAMPTZ,
  initiated_by   UUID REFERENCES iam.users(id),
  row_count      INTEGER NOT NULL DEFAULT 0,
  ok_count       INTEGER NOT NULL DEFAULT 0,
  error_count    INTEGER NOT NULL DEFAULT 0,
  status         TEXT NOT NULL DEFAULT 'running'
                 CHECK (status IN ('running','succeeded','partial','failed')),
  artifact_url   TEXT,                       -- S3 URL for CSV
  error_summary  JSONB
);
CREATE INDEX ix_ingestions_started ON ops.ingestions (started_at DESC);
```

### 3.4 Alerts

```sql
CREATE TABLE ops.alerts (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  station_id     UUID NOT NULL REFERENCES core.stations(id),
  severity       TEXT NOT NULL CHECK (severity IN ('warning','danger','critical')),
  raised_at      TIMESTAMPTZ NOT NULL,
  raised_reading_id BIGINT,
  cleared_at     TIMESTAMPTZ,
  cleared_reading_id BIGINT,
  peak_level_m   NUMERIC(8,3) NOT NULL,
  peak_at        TIMESTAMPTZ NOT NULL,
  status         TEXT NOT NULL DEFAULT 'active'
                 CHECK (status IN ('active','cleared','expired')),
  notified_channels JSONB NOT NULL DEFAULT '[]'::jsonb,   -- [{channel:"sms",sent_at,recipients}]
  created_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX ix_alerts_active ON ops.alerts (station_id, status) WHERE status = 'active';
CREATE INDEX ix_alerts_raised ON ops.alerts (raised_at DESC);
```

## 4. Identity & Access (`iam`)

```sql
CREATE TABLE iam.roles (
  id        SERIAL PRIMARY KEY,
  code      TEXT UNIQUE NOT NULL
            CHECK (code IN ('state_admin','district_officer','data_entry','auditor','readonly')),
  name_en   TEXT NOT NULL,
  name_hi   TEXT NOT NULL,
  scope     TEXT NOT NULL CHECK (scope IN ('state','district','station'))
);

CREATE TABLE iam.users (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email             CITEXT UNIQUE NOT NULL,
  phone_e164        TEXT,
  -- sensitive fields AES-256 encrypted at application layer
  full_name_enc     BYTEA NOT NULL,
  aadhaar_last4_enc BYTEA,
  password_hash     TEXT NOT NULL,                    -- argon2id
  mfa_secret_enc    BYTEA,                            -- TOTP, AES-GCM
  status            TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','disabled','locked')),
  failed_attempts   INTEGER NOT NULL DEFAULT 0,
  last_login_at     TIMESTAMPTZ,
  password_changed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE iam.user_roles (
  user_id         UUID NOT NULL REFERENCES iam.users(id) ON DELETE CASCADE,
  role_id         INTEGER NOT NULL REFERENCES iam.roles(id),
  district_code   CHAR(4) REFERENCES core.districts(code),   -- nullable for state scope
  station_id      UUID REFERENCES core.stations(id),
  assigned_by     UUID REFERENCES iam.users(id),
  assigned_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, role_id, COALESCE(district_code, '----'),
               COALESCE(station_id, '00000000-0000-0000-0000-000000000000'::uuid))
);

-- Refresh tokens stored hashed; JTIs tracked for rotation & revocation
CREATE TABLE iam.refresh_tokens (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id        UUID NOT NULL REFERENCES iam.users(id) ON DELETE CASCADE,
  token_hash     BYTEA NOT NULL,
  user_agent     TEXT,
  ip_inet        INET,
  issued_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at     TIMESTAMPTZ NOT NULL,
  revoked_at     TIMESTAMPTZ,
  replaced_by    UUID REFERENCES iam.refresh_tokens(id)
);
CREATE INDEX ix_refresh_user_active ON iam.refresh_tokens (user_id) WHERE revoked_at IS NULL;
```

## 5. Audit trail (`audit`) — append-only

```sql
CREATE TABLE audit.events (
  id             BIGSERIAL PRIMARY KEY,
  occurred_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  actor_id       UUID,                       -- NULL for system
  actor_role     TEXT,
  actor_ip       INET,
  action         TEXT NOT NULL,              -- 'reading.create','user.login','station.update',...
  entity_type    TEXT NOT NULL,
  entity_id      TEXT NOT NULL,
  before         JSONB,
  after          JSONB,
  request_id     UUID,                       -- correlates to API call
  signature      BYTEA NOT NULL              -- HMAC-SHA256 over canonical record
);
SELECT create_hypertable('audit.events', 'occurred_at',
                         chunk_time_interval => INTERVAL '7 days',
                         if_not_exists       => TRUE);
CREATE INDEX ix_audit_actor  ON audit.events (actor_id, occurred_at DESC);
CREATE INDEX ix_audit_entity ON audit.events (entity_type, entity_id, occurred_at DESC);

-- Hard guarantee of append-only
REVOKE UPDATE, DELETE ON audit.events FROM PUBLIC;
CREATE RULE no_update AS ON UPDATE TO audit.events DO INSTEAD NOTHING;
CREATE RULE no_delete AS ON DELETE TO audit.events DO INSTEAD NOTHING;

SELECT add_retention_policy('audit.events', INTERVAL '7 years');
```

## 6. Continuous aggregates (`analytics`)

```sql
CREATE MATERIALIZED VIEW analytics.readings_hourly
WITH (timescaledb.continuous) AS
SELECT station_id,
       time_bucket('1 hour', observed_at) AS bucket,
       AVG(level_m)  AS avg_level,
       MIN(level_m)  AS min_level,
       MAX(level_m)  AS max_level,
       COUNT(*)      AS sample_count,
       MAX(severity) AS peak_severity
FROM ops.readings
GROUP BY station_id, bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('analytics.readings_hourly',
  start_offset      => INTERVAL '30 days',
  end_offset        => INTERVAL '1 hour',
  schedule_interval => INTERVAL '15 minutes');

CREATE MATERIALIZED VIEW analytics.readings_daily
WITH (timescaledb.continuous) AS
SELECT station_id,
       time_bucket('1 day', observed_at) AS bucket,
       AVG(level_m)  AS avg_level,
       MIN(level_m)  AS min_level,
       MAX(level_m)  AS max_level,
       COUNT(*)      AS sample_count,
       BOOL_OR(severity IN ('danger','critical')) AS had_danger
FROM ops.readings
GROUP BY station_id, bucket
WITH NO DATA;

SELECT add_continuous_aggregate_policy('analytics.readings_daily',
  start_offset      => INTERVAL '2 years',
  end_offset        => INTERVAL '1 day',
  schedule_interval => INTERVAL '1 hour');
```

District-level rollup for dashboard heatmap:

```sql
CREATE MATERIALIZED VIEW analytics.district_summary AS
SELECT d.code,
       d.name_en,
       COUNT(s.id)                                         AS station_count,
       SUM((rl.severity = 'critical')::int)                AS critical_count,
       SUM((rl.severity = 'danger')::int)                  AS danger_count,
       SUM((rl.severity = 'warning')::int)                 AS warning_count,
       SUM((rl.severity = 'safe')::int)                    AS safe_count,
       MAX(rl.updated_at)                                  AS last_updated_at
FROM core.districts d
LEFT JOIN core.stations s       ON s.district_code = d.code AND s.status = 'active'
LEFT JOIN ops.readings_latest rl ON rl.station_id  = s.id
GROUP BY d.code, d.name_en;

CREATE UNIQUE INDEX ix_district_summary_code ON analytics.district_summary (code);
```

Refresh every 30 s (background job) or on-demand when `readings.created` lands.

## 7. Seed taxonomy (illustrative)

```sql
INSERT INTO core.districts (code, name_en, name_hi, division, centroid) VALUES
 ('PAT','Patna','पटना','Patna',      ST_Point(85.1376, 25.5941)::geography),
 ('MZP','Muzaffarpur','मुजफ्फरपुर','Tirhut', ST_Point(85.3910, 26.1197)::geography),
 ('BGP','Bhagalpur','भागलपुर','Bhagalpur', ST_Point(86.9842, 25.2425)::geography),
 ('DBG','Darbhanga','दरभंगा','Darbhanga', ST_Point(85.8918, 26.1542)::geography),
 ('KTR','Katihar','कटिहार','Purnea',  ST_Point(87.5750, 25.5378)::geography);
 -- ... all 38 districts

INSERT INTO core.rivers (name_en, name_hi, basin) VALUES
 ('Ganga','गंगा','Ganga'),
 ('Kosi','कोसी','Kosi'),
 ('Bagmati','बागमती','Bagmati'),
 ('Gandak','गंडक','Gandak'),
 ('Burhi Gandak','बूढ़ी गंडक','Gandak'),
 ('Kamla Balan','कमला बलान','Kosi'),
 ('Mahananda','महानंदा','Mahananda'),
 ('Son','सोन','Ganga'),
 ('Punpun','पुनपुन','Ganga');
```

## 8. Security & row-level policy

Row-level security enforces that a `district_officer` can only read/write readings for stations in their assigned districts:

```sql
ALTER TABLE ops.readings ENABLE ROW LEVEL SECURITY;

CREATE POLICY readings_read_public
  ON ops.readings FOR SELECT
  USING (true);                                -- public read via API (app enforces)

CREATE POLICY readings_write_scope
  ON ops.readings FOR INSERT WITH CHECK (
    current_setting('app.role', true) = 'state_admin'
    OR EXISTS (
      SELECT 1
      FROM core.stations s
      JOIN iam.user_roles ur ON ur.district_code = s.district_code
      WHERE s.id = NEW.station_id
        AND ur.user_id::text = current_setting('app.user_id', true)
    )
  );
```

App sets `SET LOCAL app.user_id = '...'; SET LOCAL app.role = '...';` per transaction.

## 9. Backup & recovery

- **Base backup:** pgBackRest daily full, incremental every 6 h → encrypted S3 bucket, cross-region replicated.
- **WAL archiving:** continuous, 5-min granularity → RPO ≤ 5 min.
- **PITR:** 30-day window.
- **Logical dumps:** weekly `pg_dump` of `core` + `iam` for rapid restore tests.
- **Restore drill:** quarterly, measured RTO must be ≤ 15 min.
