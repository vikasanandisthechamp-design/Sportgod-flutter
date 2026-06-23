# DAIOS — Disaster AI Operating System

> A planet-scale, AI-native disaster operating system that **predicts, coordinates, informs, and learns** — designed to run across multiple countries while respecting each one's data sovereignty.

DAIOS is not a dashboard. It is an **operating system for disasters**: hazards are pluggable kernels, response agencies are first-class processes, citizens are an authenticated channel, and every event becomes training data that makes the next response measurably better.

## 0. Why this exists

Today's disaster response is built from fragmented systems: one tool for floods, another for earthquakes, a third for SMS alerts, a WhatsApp group for coordination, and a spreadsheet for after-action reports. By the time information reaches a District Magistrate, it is filtered, hours old, and lossy.

DAIOS collapses that stack. One substrate, one event bus, one identity plane, one decision engine. Pluggable hazards, pluggable agencies, pluggable citizen channels.

## 1. Modules

| # | Module | What it owns |
|---|---|---|
| 1 | **Flood Intelligence** | River gauges, IMD/CWC ingestion, basin models. (Inherits FIPAS — see `/docs/fipas`.) |
| 2 | **Multi-Hazard Monitoring** | Earthquake (USGS, IMD seismo), Cyclone (IMD, JTWC, ECMWF), Heatwave (IMD, satellite LST), Landslide (rainfall + slope + soil moisture), Wildfire (VIIRS, MODIS), Industrial / Epidemic plug-ins |
| 3 | **Emergency Response Coordination** | Incident command, resource allocation, inter-agency tasking, SITREPs |
| 4 | **Citizen Engagement** | SOS, hyperlocal alerts (SMS / WhatsApp / RCS / push / Cell Broadcast), citizen reports, missing-persons |
| 5 | **Decision Intelligence** | Multi-agent LLM "war room", scenario simulation, action recommendations with reasoning traces |
| 6 | **Public Display Network** | TV / kiosk / digital signage / public-address auto-generation |
| 7 | **Analytics & Planning** | Post-event AI reports, drills, capacity planning, climate-change re-baselining |

Each module is documented in `docs/daios/modules/`.

## 2. Design principles

1. **Hazards are plug-ins.** A new disaster type (volcano, tsunami, tech-pandemic) is added by implementing the `HazardKernel` contract, not by patching the core.
2. **Sovereign by default.** Data residency is configured per tenant (country/state). Personally identifying data **never** leaves jurisdiction. The control plane synchronises only schemas, model definitions, and anonymised telemetry.
3. **AI proposes, humans dispose.** Every AI action has a reasoning trace, a confidence score, an authorising human, and an audit entry. No AI agent acts on the public without an approved human authorisation chain.
4. **Read plane is unkillable.** Citizen-facing reads survive any internal failure — last-good state served from CDN + edge cache.
5. **Event-sourced.** State is derived from an append-only event log; every dashboard, every alert, every report can be reconstructed from `(t0, t1)`.
6. **Open at the edges, closed at the core.** Open APIs and webhooks for partners; sealed, mTLS-only, mutually authenticated core.
7. **Self-learning by construction.** Every event, decision, and outcome is captured for offline training and online fine-tuning. After-action reports write themselves; humans edit, not write.
8. **Accessible.** Multilingual, multi-script, voice-first for officials, low-bandwidth for citizens. WCAG 2.2 AA on every screen.
9. **Drill-able.** A dedicated "shadow" mode runs the entire stack in simulation against historical or synthetic events without touching real channels.

## 3. Non-functional targets

| Metric | Target |
|---|---|
| Citizen alert P95 (event detected → alert in pocket) | ≤ 60 s |
| SEOC dashboard P95 freshness | ≤ 5 s |
| Decision-agent recommendation P95 | ≤ 8 s for one-shot, ≤ 30 s for multi-step plan |
| Public read availability | 99.99% (4 nines) |
| Control-plane availability | 99.95% |
| Concurrent citizen WS sessions | 25M global, 5M per region |
| Ingestion throughput | 500k events/min sustained, 5M/min burst |
| RPO / RTO (regional) | 1 min / 5 min |
| RPO / RTO (cross-country failover, opt-in) | 5 min / 15 min |
| Event-log retention | 10 years hot, indefinite cold |
| Model retrain cadence | hazard-specific (flood weekly, EQ never auto, cyclone seasonal) |

## 4. Document map

| File | Topic |
|---|---|
| `architecture.md` | Global control plane + regional data planes, hazard kernels, event mesh |
| `microservices.md` | Catalog of every service with responsibility, scaling profile, dependencies |
| `database-schema.md` | Multi-tenant, hazard-agnostic event log + hazard-specific extensions |
| `api-design.md` | REST + GraphQL federation + WebSocket + gRPC; partner & citizen APIs |
| `ai-architecture.md` | Model zoo per hazard, agent orchestration, MLOps, evaluation, safety |
| `digital-twin.md` | GIS substrate, live overlays, simulation engine, what-if API |
| `ui-ux.md` | SEOC command room, district dashboards, citizen app, kiosk, voice |
| `deployment.md` | Multi-region & multi-country topology, sovereign clouds, CI/CD, DR |
| `security.md` | Zero-trust, RBAC/ABAC, MFA, E2EE, audit chain, CERT-In/ISO27001 mapping |
| `modules/*.md` | Per-module specifications |

## 5. Glossary

- **Hazard Kernel** — pluggable module implementing `ingest()`, `nowcast()`, `forecast()`, `threshold()`, `alert()`, `postmortem()`.
- **Department Agent** — an LLM-backed agent encapsulating one agency's SOPs (police, health, water, power, transport, civil-defence). Has scoped tool access.
- **Decision Engine** — multi-agent orchestrator that produces ranked action plans with reasoning traces.
- **Digital Twin** — geo-temporal model of a region (population, infra, hospitals, roads, schools, dams) used as the substrate for simulation and impact estimation.
- **SEOC** — State Emergency Operations Centre; analogous unit per country.
- **NDMA / NDRF** — India: National Disaster Management Authority / Response Force; abstracted to `NationalAuthority` in tenancy model.
- **Sovereign Plane** — a per-country cluster running data + ML inference; never replicates citizen PII outward.
- **Control Plane** — global cluster running schema registry, model registry, federated identity, telemetry aggregation.
- **Shadow Mode** — non-production replay of live stack against historical/synthetic events; used for drills and pre-deployment evaluation.
