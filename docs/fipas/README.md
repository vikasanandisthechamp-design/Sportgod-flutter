# FIPAS — Flood Intelligence & Public Awareness System

**Owner:** Water Resources Department, Government of Bihar
**Classification:** State-level critical public infrastructure (Disaster Management)
**Audience:** Public citizens, District Officers, State Emergency Operations Centre (SEOC), IMD, CWC

FIPAS is a state-wide flood early-warning and public awareness platform. It ingests real-time river water-level data from manual readings, API feeds (IMD, CWC), and future IoT sensors; serves a public dashboard and airport-style Smart-TV display across all 38 districts of Bihar; and provides a hardened admin panel for field operators, district officers, and state administrators.

This design targets a peak concurrency of several million users during flood events (Kosi, Bagmati, Gandak, Ganga surges), sub-5-second data freshness, and NIC-compliant hosting.

## Deliverables in this folder

| # | Document | Contents |
|---|---|---|
| 1 | [architecture.md](./architecture.md) | End-to-end system architecture (textual diagram + explanation), service boundaries, data flow, event bus, caching tiers |
| 2 | [database-schema.md](./database-schema.md) | PostgreSQL + TimescaleDB schema, hypertables, continuous aggregates, retention, indexes, seed taxonomy |
| 3 | [api-specification.md](./api-specification.md) | REST + WebSocket contracts, auth, versioning, rate limits, error model, idempotency |
| 4 | [folder-structure.md](./folder-structure.md) | Frontend (Next.js) and backend (NestJS microservices) directory layouts |
| 5 | [ui-layouts.md](./ui-layouts.md) | Public dashboard, Smart-TV display mode, admin panel — screen-by-screen descriptions |
| 6 | [deployment.md](./deployment.md) | Docker, Kubernetes, CI/CD, environments, blue-green, observability, DR |
| 7 | [security.md](./security.md) | Threat model, TLS, JWT, RBAC, encryption-at-rest, WAF/DDoS, audit, OWASP mitigations |

## Design principles

1. **Public-first, always-on.** The public dashboard and TV display must remain readable even if write paths, admin, or ingestion are degraded. Read plane and write plane are isolated.
2. **Data freshness SLO ≤ 30 s** from admin save to public render (P95). TV mode auto-refresh on a 5-minute cadence with live WebSocket overlay.
3. **Defence in depth.** Public read path is fully cache-served; admin path is mTLS + JWT + RBAC + audit.
4. **Graceful degradation.** WebSocket down → poll fallback. Redis down → DB fallback. Primary DB down → read replica + static CDN snapshot of last good state.
5. **Government compliance.** MeitY/CERT-In guidelines, data residency in India (NIC Cloud / AWS Mumbai + Hyderabad), signed audit trail, data classification per NDSAP.
6. **Future-ready.** IoT ingestion and AI prediction plug in behind the same event bus without touching the public read plane.

## Top-level data & alert thresholds

Each river-gauge station has two calibrated reference levels published by CWC/WRD:

| Level | Meaning | Dashboard color |
|---|---|---|
| Below Warning Level (WL) | Normal flow | **Safe** — green `#16A34A` |
| ≥ Warning Level, < Danger Level | Rising concern | **Warning** — yellow `#EAB308` |
| ≥ Danger Level (DL), < Highest Flood Level (HFL) | Active flood risk | **Danger** — orange `#F97316` |
| ≥ Highest Flood Level | Extreme / historic | **Critical** — red `#DC2626` |

The threshold evaluation is a pure function of `(reading, station.warning_level, station.danger_level, station.hfl)` and runs on both backend (for alerts) and frontend (for colouring) from the same shared spec.

## Non-functional targets

| Metric | Target |
|---|---|
| Public-dashboard P95 TTFB | ≤ 200 ms from CDN edge |
| Public API P95 latency | ≤ 150 ms cached, ≤ 400 ms uncached |
| Data freshness (admin save → public) | ≤ 30 s P95 |
| WebSocket fan-out | 5M concurrent subscribers |
| Ingestion throughput | 10k readings/minute peak |
| Availability | 99.95% public read plane, 99.9% admin |
| RPO / RTO | 5 min / 15 min |
| Retention | Raw 2 years, hourly aggregates 10 years, daily forever |
