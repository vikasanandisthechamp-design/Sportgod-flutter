# DAIOS — Digital Twin

The Digital Twin is the **single geo-temporal substrate** every other DAIOS module reads from and writes into. Maps, dashboards, decision agents, and simulation all see the same world.

It is **not** a 3-D rendered city for show. It is a queryable, time-versioned model of physical reality that supports impact estimation and what-if simulation at speed.

## 1. Layers (stacked)

```
┌──────────────────────────────────────────────────────┐
│  L7  AGENT REASONING LAYER                           │
│      RAG over twin metadata + map gazetteer          │
├──────────────────────────────────────────────────────┤
│  L6  SIMULATION LAYER                                │
│      sim-svc: scenario fork, run, score, compare     │
├──────────────────────────────────────────────────────┤
│  L5  IMPACT LAYER                                    │
│      population × hazard footprint = est. affected   │
├──────────────────────────────────────────────────────┤
│  L4  LIVE OVERLAYS                                   │
│      flood extent · wind field · heat grid · plumes  │
│      shake map · fire perimeter · road closures      │
├──────────────────────────────────────────────────────┤
│  L3  DYNAMIC STATE                                   │
│      sensor latest, hospital capacity, unit pos,     │
│      power outages, traffic, telecom outage          │
├──────────────────────────────────────────────────────┤
│  L2  STATIC INFRASTRUCTURE                           │
│      hospitals, schools, dams, shelters, towers,     │
│      power substations, bridges, water mains         │
├──────────────────────────────────────────────────────┤
│  L1  TOPOLOGY GRAPH                                  │
│      roads, rail, power grid, telecom (Neo4j)        │
├──────────────────────────────────────────────────────┤
│  L0  GEO BASE                                        │
│      regions, districts, wards, cadastre, DEM,       │
│      land cover, river network                       │
└──────────────────────────────────────────────────────┘
```

## 2. Data sources

| Layer | Sources |
|---|---|
| L0 base | OpenStreetMap, ISRO Bhuvan / Survey of India, Census polygons, SRTM/AW3D DEM, ESA WorldCover, HydroSHEDS rivers |
| L1 topology | OSM road graph, government cadastre, utility-supplied grid + telecom topology |
| L2 static | Health Ministry HMIS, education ministry, dam authority, custom WRD/SDMA datasets |
| L3 dynamic | DAIOS sensors, partner ERPs (hospitals, telcos), traffic feeds, partner logistics |
| L4 overlays | Hazard kernels (`twin.update` events) |
| L5 impact | population-svc + hazard footprint joined per ward |
| L6 sim | physics simulators triggered on demand |
| L7 RAG | vector index over L0–L5 metadata + gazetteer |

## 3. Storage choices

| Concern | Store |
|---|---|
| Vector geometry, queries | PostGIS (in the same Postgres) |
| Raster (DEM, satellite) | Cloud-Optimised GeoTIFF (COG) on S3 + STAC catalogue |
| Topology graph | Neo4j (`infra-graph-svc`) |
| Live state cache | Redis (per-tenant keyspace) |
| Tile serving | `gis-tile-svc` — vector tiles via `pg_tileserv`, raster via TiTiler |
| Time-versioned snapshots | TimescaleDB hypertable `twin.snapshots` |
| Vector index | pgvector / OpenSearch knn |

## 4. Tile strategy

- Vector tiles: MVT (Mapbox Vector Tile) at zooms 5–16, generated lazily and cached at CDN.
- Raster overlays: pre-tiled COGs; clients fetch only the bbox/zoom they need.
- **Live overlays** use a special protocol: client subscribes to `twin.overlays.{layer}` WS topic; server pushes minimal **patches** (added/removed/changed feature IDs) so the map updates without re-downloading whole tiles.

## 5. Population & impact estimation

`population-svc` exposes:

```
GET /api/v1/twin/population?wkt=POLYGON(...)&age_band=&time=now
```

Returns total + breakdown (age, vulnerability index, schools-in-session, hospitals-occupied), computed by clipping the requested polygon against pre-built ward-level rasterised population grids (200 m).

Impact estimation is the join:

```
Affected = ⋃(hazard footprints) ⋂ population grid
        weighted by vulnerability × time-of-day × infra-criticality
```

Used by:
- `decision-svc` to rank proposals by expected lives saved.
- `comms` agent to choose channels (e.g., elderly-heavy ward → voice + PA, not just push).
- Postmortem reports.

## 6. The simulation engine (`sim-svc`)

`sim-svc` clones the live twin into a sandbox at `t0`, evolves it under a scenario, and returns a scored outcome. Scenarios:

| Hazard | Engine |
|---|---|
| Flood | HEC-RAS / open-source HEC-RAS-Compute coupled with basin model |
| Cyclone storm surge | SCHISM / ADCIRC |
| Earthquake shake | OpenQuake hazard + GEM exposure |
| Wildfire spread | FARSITE / cellular automata |
| Heatwave mortality | Statistical model + climate projection |
| Cascading (e.g. dam breach + flood) | Ad-hoc orchestrator chaining engines |

### 6.1 Scenario API

```
POST /api/v1/twin/sim/scenarios
{
  "name": "Kosi 2008 + 20%",
  "base_state_at": "now",
  "perturbations": [
    { "type":"rainfall","region":"BR-NE","amount_mm":300,"duration_h":48 },
    { "type":"dam","id":"...","action":"breach","time_offset_h":12 }
  ],
  "horizon_h": 72,
  "metrics": ["affected_population","inundation_area","critical_infra_loss"]
}
→ 202 Accepted, sim_id

GET /api/v1/twin/sim/scenarios/{sim_id}
→ progress + intermediate frames

GET /api/v1/twin/sim/scenarios/{sim_id}/result
```

### 6.2 Use cases

- **Pre-monsoon drills**: replay 2008 Kosi, 1998 Brahmaputra, 1999 Odisha; verify alerts, response, comms work.
- **Live decision support**: orchestrator may invoke `sim-svc` on a developing event ("if cyclone deviates 30 km north, what's affected?") with a 30-s budget.
- **Capacity planning**: planner-svc runs hundreds of simulated scenarios overnight to identify resource gaps.
- **Climate change projection**: re-run historical events under +1.5 °C, +2 °C, +3 °C scenarios.

### 6.3 Safety

Sim runs in a separate Kubernetes namespace with no write access to live datastores. All `twin.snapshots` accessed are read-only. Result polygons and statistics are stored under a `sim:*` namespace and never leak into `hazard.events` unless explicitly promoted by an analyst.

## 7. Time travel

Snapshots are taken every 1 minute at the tenant level for the last 24 h, every hour for the last 30 days. Officials can rewind:

```
GET /api/v1/twin/state?at=2026-04-24T11:30:00Z
```

Used for forensic review, training, drill.

## 8. Map gazetteer & dialect-aware naming

A village can be spelled four different ways across systems. The gazetteer:

- Canonical place ID per region/district/ward/village.
- Multi-script, multi-script-spelling, dialectal variants.
- Lat/lng centroid, polygon if available.
- Aliases used by partner systems (so an "IMD code" maps to a DAIOS place ID).

Used by:
- Voice intent extraction ("Send NDRF to **Singhwara**" — ambiguous? gazetteer disambiguates).
- Citizen-report parsing.
- Alert rendering in the right language and script.

## 9. Federated topology

Some infra (rivers, roads, power lines, weather systems) doesn't respect borders. The twin supports **trans-tenant linking**:

- A river basin spanning Bihar and Nepal (Kosi) has nodes with `linked_tenant`s.
- A cyclone in the Bay of Bengal can have its track shared between IN-OD, IN-AP, IN-WB tenants in real time.
- Federation is **read-only by default** and **opt-in**, governed by signed agreements stored in tenant metadata.
- No PII crosses borders; only physical-world data does.

## 10. Privacy & ethics

- Population grids are coarse (200 m) and aggregated; individual-level data is never stored in the twin.
- Vehicle telemetry (response units) is the only fine-grained tracking — bound to operational accounts, retained 90 days.
- Citizen-shared photos/videos are processed in the twin only after PII redaction (face blur, plate blur).
- Display features (kiosks, partner portals) cannot drill below ward level.

## 11. Performance targets

| Operation | Target |
|---|---|
| Tile fetch (vector) | P95 ≤ 50 ms cached, ≤ 200 ms cold |
| Live overlay patch | P95 ≤ 1 s end-to-end |
| Population query (10 km² polygon) | P95 ≤ 250 ms |
| Impact estimation | P95 ≤ 500 ms |
| Sim scenario (typical 12 h flood, 1 km grid) | ≤ 60 s elapsed |
| Time-travel snapshot read | P95 ≤ 200 ms |

## 12. Why a twin and not a "map"

A map answers "what is at this place?" The twin answers four questions:

1. **What** is here, **right now**, including its dynamic state?
2. **Who** is exposed if a hazard footprint lands here, and how vulnerable are they?
3. **What if** we change one variable — what does the future look like?
4. **What was** the state at time T — for forensic review and learning?

These four questions are what differentiate a 1990s GIS dashboard from a 2050-grade disaster operating system.
