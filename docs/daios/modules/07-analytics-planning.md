# Module 7 — Analytics & Planning

The "post-event" brain that closes the loop and the "pre-event" brain that prepares the next one.

## Post-event
- **Auto-generated post-mortem reports** by `postmortem-svc`:
  - Executive summary
  - Timeline (key decisions, alerts, resource movements)
  - Comparison: forecast vs observed
  - What went well / what didn't (qualitative + quantitative)
  - Recommendations for the next cycle
- Officers edit; tenant CISO signs; published to tenant + control-plane (anonymised) for shared learning.
- Outcomes feed `train.label` topic for model retraining.

## Capacity planning
- `planner-svc` runs hundreds of simulated scenarios overnight on the twin.
- Identifies resource gaps (shelter capacity vs flood-prone population, ambulance gaps in heat-wave-prone districts).
- Outputs ranked investment recommendations (e.g., "+200 shelter capacity in Saharsa reduces expected un-sheltered population by 35%").

## Drill scheduling
- `drill-svc` schedules drills using historical events (e.g., "replay 2008 Kosi this Tuesday").
- Routes through shadow stack — no real channels, no real units, but operators see realistic dashboards and respond.
- Outcomes scored against expected behaviour; gaps identified.

## Climate re-baselining
- `climate-rebaseline-svc` recomputes return periods annually using latest observation.
- Flags stations whose Warning/Danger levels need recalibration.
- Hydrologists approve via dual-approval flow.

## Open data publication
- `data-publisher-svc` pushes anonymised public datasets monthly to NDSAP / data.gov / equivalent.
- Schemas versioned; signed manifests; checksums published.

## Dashboards
- **Tenant dashboard**: events, alerts, decisions, response times, citizen-reach metrics.
- **Inter-tenant comparison** (anonymised): "tenants of similar size + hazard profile achieve X; you achieve Y".
- **Climate trend dashboard**: 10-year trends, flood-day counts, heat-day counts, return-period shifts.

## Exports
- CSV / Parquet bulk exports (officer + auditor scope).
- PDF reports server-rendered (sandboxed Puppeteer); signed.
- API endpoints for partners (researchers, academics) under contract.
