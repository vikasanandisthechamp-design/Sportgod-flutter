# Module 2 — Multi-Hazard Monitoring

Adds **earthquake, cyclone, heatwave, landslide, wildfire, tsunami, industrial, epidemic** as plug-in hazard kernels. Each implements the same `HazardKernel` contract (`architecture.md` §3) and lights up specific overlays, alerts, and decision proposals.

## Earthquake
- **Sources**: USGS, IMD seismo, in-network MEMS accelerometers.
- **Detect**: P-wave detector emits early-warning candidate within 1–2 s of arrival.
- **Predict**: rapid shake map (≤ 90 s), aftershock probability (ETAS).
- **Alert**: cell broadcast + PA sirens; "Drop, Cover, Hold" content auto-localised.
- **Twin overlays**: shakemap, building-fragility, hospitals-affected.

## Cyclone
- **Sources**: IMD, JTWC, ECMWF ensembles, satellite imagery.
- **Predict**: ensemble track + intensity + storm-surge (SCHISM/ADCIRC).
- **Alert**: 96/72/48/24/12-hour pre-landfall alerts; evacuation zones tied to surge predictions.
- **Twin overlays**: track, cone, wind field, surge inundation.
- **Decision proposals**: shelter activation, fishermen recall, NDRF pre-positioning.

## Heatwave
- **Sources**: IMD weather, satellite LST, AQI feeds.
- **Predict**: heat index per ward; mortality projection per district.
- **Alert**: graded — Yellow/Orange/Red per IMD criteria; vulnerable-population targeted (elderly, outdoor workers).
- **Decision proposals**: cooling shelters, work-hour advisories, water-distribution.

## Landslide
- **Sources**: rainfall, slope/DEM, soil moisture, InSAR coherence loss.
- **Predict**: H3-cell risk score using `landslide-risk-XGBoost`.
- **Alert**: village-level when threshold + topographic exposure met.
- **Decision proposals**: road closure, pre-emptive evacuation of cliff-side hamlets.

## Wildfire
- **Sources**: VIIRS/MODIS hot-spots, weather, fuel-load grid.
- **Predict**: spread simulation (`fire-spread-CA`).
- **Alert**: evacuation polygons computed from spread; air-quality co-alerts.
- **Decision proposals**: fire-line resources, road closures, smoke-mask distribution.

## Tsunami
- **Sources**: NTWC, DART buoys, EQ-kernel cross-feed (mag ≥ 6.5 marine).
- **Predict**: travel-time + run-up estimation.
- **Alert**: coastal cell broadcast within 5 min of detection.
- **Decision proposals**: vertical evacuation, port shut-down, fishermen recall.

## Industrial / chemical
- **Sources**: AQ sensors, plant SCADA, citizen reports.
- **Predict**: dispersion modelling (Gaussian plume baseline; CFD on demand).
- **Alert**: shelter-in-place vs evacuate based on plume + wind.
- **Decision proposals**: PPE deployment, hospital-prep, traffic diversion.

## Epidemic / health
- **Sources**: hospital ERPs (syndromic), labs, citizen reports.
- **Predict**: outbreak detection (anomaly), short-horizon SEIR variants.
- **Alert**: targeted public-health advisories; PII never on public surfaces.
- **Decision proposals**: contact-tracing posture, testing surge, comms templates.

## Cross-hazard considerations
- **Cascading events** (EQ → tsunami, EQ → dam breach → flood, cyclone → flood + landslide) are first-class: kernels publish `correlation_id` so `decision-svc` reasons across them.
- **Common alert templates** with hazard slot, language slot, action slot.
- **Common citizen action vocabulary**: 8–10 verbs (evacuate, shelter-in-place, move higher, boil water, mask up, conserve, …) with localised pictograms.
- **Shared SITREP** when multiple hazards coexist in the same region.

## Adding a new hazard kernel (recipe)
1. Implement `HazardKernel` interface in a NestJS service.
2. Define schema extension in `<hazard>.<schema>.sql`.
3. Register Kafka topics (`hazard.<id>.*`) + Avro schemas.
4. Add severity threshold + alert templates to tenant config.
5. Provide minimum two ML models (nowcast + forecast) or rule-based stubs.
6. Add decision-agent SOP knowledge to RAG corpus.
7. Run shadow drills against historical events; verify alert + decision quality.
8. Tenant admin enables the hazard via feature flag.
