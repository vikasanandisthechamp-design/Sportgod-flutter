# Module 1 — Flood Intelligence

**Inherits FIPAS** (`/docs/fipas`) as its baseline. Within DAIOS, FIPAS becomes the `flood-kernel-svc` plus its companions (`flood-ingest-svc`, `flood-forecast-svc`).

## Scope
- Real-time gauge readings (manual + IoT + API: IMD, CWC).
- Reservoir / dam monitoring, gate releases.
- Inundation extent estimation from Sentinel-1 SAR (ML segmentation).
- Basin-wide forecast (LSTM + GNN coupled).
- Historical analytics, climate re-baselining of WL/DL/HFL.

## Inputs
- Manual readings via officer console / district app.
- IMD rainfall / nowcast (15-min cadence).
- CWC station feed.
- IoT MQTT from automatic gauge stations.
- Sentinel-1 SAR scenes (ESA), MODIS (NASA), ISRO Bhuvan tiles.
- Citizen reports (photos, water-level descriptions) classified by CV.

## Outputs
- `hazard.events` (kind=`flood`)
- `flood.readings` upserts
- `twin.overlays` (`flood_extent`, `inundation_forecast`)
- `hazard.alerts` via decision-svc on threshold breach
- Basin SITREPs every 30 min during active events

## Models (see `ai-architecture.md`)
- `flood-nowcast-LSTM`, `flood-extent-UNet`, `flood-basin-GNN`, `flood-anomaly-IF`.

## Operational notes
- Threshold edits require dual approval (officer + auditor).
- Late-arriving correction events use causation_id chain to update derived state without losing history.
- Basin model is co-trained across tenants where federation agreements permit (Bihar–Nepal Kosi basin example).

## Differences from FIPAS standalone
- Tenancy: hazard kernel is multi-tenant; tenant routing at the gateway.
- Audit chain rolls up to platform `audit_events` (DAIOS-wide, hash-chained).
- Decision flow goes through DAIOS decision-svc + agent runtime, not flood-only logic.
- Dashboards composed via federated GraphQL alongside other hazards.
