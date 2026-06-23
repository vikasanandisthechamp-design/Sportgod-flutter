# DAIOS — AI Architecture

DAIOS is **AI-native, not AI-decorated**. AI is on the critical path for prediction, decision support, and post-event learning, with three hard rules:

1. **AI proposes, humans dispose.** No public-facing action executes without a human authorising chain.
2. **Every output is traceable.** Reasoning traces, prompts, tool calls, and confidence scores are stored and auditable.
3. **Sovereignty first.** Models, weights, and inference run inside the sovereign plane unless the tenant explicitly opts in to a hosted external model.

## 1. Three layers of AI

| Layer | What it does | Latency target |
|---|---|---|
| **Predictive ML** | Hazard-specific forecasts, nowcasts, classifiers, detection from images/satellite | ms–seconds |
| **Decision Intelligence (LLM agents)** | Multi-agent reasoning, action proposals, voice assistance, post-event reports | seconds–tens of seconds |
| **Continuous Learning** | Offline retraining, evaluation, drift detection, model promotion | hours–days |

## 2. Predictive ML — the model zoo

Each hazard kernel owns one or more models, registered in MLflow with **signed artefacts** and versioned datasets.

### 2.1 Flood
| Model | Type | Inputs | Output | Cadence |
|---|---|---|---|---|
| `flood-nowcast-LSTM` | Sequence-to-sequence LSTM | Past 72 h gauge readings + IMD rainfall | 6 h ahead level forecast per station | Inference 5 min, retrain weekly |
| `flood-extent-UNet` | Image segmentation | Sentinel-1 SAR + DEM | Inundation polygon (per ward) | After each S1 pass |
| `flood-basin-GNN` | Graph NN over basin topology | All station readings + tributary graph | Coupled per-station forecast | 15 min |
| `flood-anomaly-IF` | Isolation Forest | Single station last 24 h | Outlier score for tampering / sensor fault | Per reading |

### 2.2 Earthquake
| Model | Notes |
|---|---|
| `eq-pwave-detector` | CNN on accelerometer streams; emits early-warning candidate within 1–2 s of P-wave arrival |
| `eq-shakemap-rapid` | Bayesian regression over reported intensity + station PGA → spatial shake map within 90 s |
| `eq-aftershock-ETAS` | Statistical Epidemic-Type Aftershock Sequence model for short-term aftershock probability |

### 2.3 Cyclone
| Model | Notes |
|---|---|
| `cyclone-track-ensemble` | Ensemble blender over IMD-GFS, ECMWF-IFS, JTWC tracks; produces consensus track + uncertainty cone |
| `cyclone-intensity-LightGBM` | Gradient boosting on SST + shear + organisation features for 24/48/72 h intensity |
| `cyclone-storm-surge-SCHISM` | Numerical hydrodynamic surge model triggered when track approaches coast |

### 2.4 Heatwave
- `heat-mortality-poisson` — relates heat-index to historical mortality per district to project burden.
- `heat-grid-downscale` — physics-informed ML downscales IMD coarse grid to ward-level temperature.

### 2.5 Landslide
- `landslide-risk-XGBoost` — slope, lithology, soil moisture, antecedent rainfall; risk per H3 cell.
- `landslide-insar-CNN` — Sentinel-1 InSAR coherence-loss detection for post-event mapping.

### 2.6 Wildfire
- `fire-spotting-VIIRS-classifier` — false-positive filtering on satellite hot-spots.
- `fire-spread-CA` — cellular-automaton spread simulation conditioned on weather + fuel load.

### 2.7 Cross-cutting
- `citizen-report-classifier` — multimodal CV+text on uploaded photos/video; tags `flood`, `building_collapse`, `road_block`, `injured`, `false_positive`.
- `nlp-redactor` — strips PII from free-text fields before they enter open analytics.

## 3. Inference plane

```
   client / kernel
        │
        ▼
   model-serving-svc  (NVIDIA Triton, gRPC + REST, multi-model)
        │ ┌─ ONNX runtime, TensorRT, PyTorch, XGBoost ─┐
        └─┤ A/B routing │ batching │ shadow models    │
          └────┬───────────────────────────────────────┘
               ▼
        feature-store-svc (Feast online + offline)
               │
               ▼
        observability + eval-svc
```

- **Triton** serves all hazard models with model-ensemble graphs (e.g., feature transform → model → calibrator pipeline).
- **GPU pool** for vision/SAR; **CPU pool** for tabular/sequence.
- **Champion / challenger:** every prod model has a shadow challenger receiving 100% of inference inputs but no outputs to consumers; eval-svc tracks divergence and lift.
- **Online features** in Feast (Redis); **offline** in S3 + BigQuery / Athena.

## 4. Decision Intelligence — the agent layer

The decision engine is a **multi-agent graph**, not a single chatbot.

### 4.1 Agent roster

| Agent | Knows | Tools (read) | Tools (write — pre-auth) |
|---|---|---|---|
| `orchestrator` | Whole picture | All `read.*` | `propose.*` only |
| `police` | Police SOPs, station rosters, traffic | `read.unit`, `read.traffic`, `read.incident` | `propose.dispatch`, `propose.road_close` |
| `health` | Hospitals, ICU, ambulances, blood banks | `read.facility`, `read.capacity`, `read.unit` | `propose.deploy_ambulance`, `propose.surge_hospital` |
| `water` | Rivers, dams, gates, pumping stations | `read.flood`, `read.dam`, `read.pump` | `propose.gate_release`, `propose.evacuate_zone` |
| `power` | Grid topology, substations, load | `read.grid`, `read.outage` | `propose.load_shed`, `propose.island` |
| `transport` | Roads, bridges, rail, airports | `read.transport`, `read.weather` | `propose.divert`, `propose.suspend_rail` |
| `civil-defence` | Shelters, supplies, volunteers | `read.shelter`, `read.supply`, `read.volunteer` | `propose.open_shelter`, `propose.activate_volunteer` |
| `comms` | Citizen channels, languages, templates | `read.channel`, `read.consent` | `propose.broadcast` |

All `propose.*` write to `hazard.decisions` with `status='pending'`. **No agent can commit an authorised decision.** Authorisation requires a human with the appropriate role in policy-svc.

### 4.2 Orchestration pattern

A directed graph with a coordinator (LangGraph-style):

```
                      orchestrator
                     /     |       \
              police   water    health
                  \   |    \   /
                   transport   civil-defence
                       \      /
                        comms
                          │
                          ▼
                    consolidator
                          │
                          ▼
              ranked decision proposals
```

Each agent answers a **scoped question** the orchestrator dispatches: e.g., "given a 3 m flood in district X within 12 h, what is your top-3 actions?" Consolidator removes duplicates, clusters by action type, and returns a ranked list with rationale and impact estimates.

### 4.3 LLM routing (`llm-router-svc`)

- **Default**: a fine-tuned, sovereign-deployed open-weights model (e.g., a Llama / Mistral-class model fine-tuned on disaster SOPs and prior incidents) running on in-country GPUs.
- **Heavyweight**: optional, tenant-opted in, for the orchestrator role only — a frontier model accessed via a private VPC endpoint with **PII redaction at the egress hop**.
- **Fallback**: a smaller distilled model on CPU pool guarantees availability even if GPU pool degrades.
- **Router policy**: model choice is a function of (task, latency budget, sensitivity, tenant config). Logged per call.

### 4.4 Tool gateway (the only path agents take)

Agents never call services directly. Every tool call goes through `agent-tool-gateway-svc`:

- Validates the **intent** against the agent's allow-list.
- Resolves arguments (e.g., resource IDs) against the **tenant scope**.
- Enforces **policy-svc** authorisation per call.
- Logs full request + response in `ai.agent_runs` and `audit.events`.
- Applies **rate limits** per agent / per tenant / per session.
- Strips secrets and PII from data before returning to the agent (privacy-preserving retrieval).

This is what makes the agents safe to operate in production: they have no native side-effects.

### 4.5 Retrieval-augmented context (RAG)

A vector store holds:
- Standard Operating Procedures per agency (versioned, signed)
- Past incident reports and lessons learned
- Cultural/linguistic templates for citizen communication
- Map gazetteer (place-names, dialects)

Agents retrieve via `gateway.read.kb` with cite-or-die instruction: every claim in the agent's reasoning must reference a source. `safety-svc` rejects outputs without citations on policy-bound topics.

### 4.6 Reasoning trace

Every agent run produces a trace stored in S3 (encrypted, signed):
- Prompt and context ingredients
- Tool calls and results
- Intermediate thoughts (when applicable)
- Final output and confidence
- Guardrail decisions

Auditors and SEOC commanders can replay traces in the console. Citizens never see traces; the public-facing rationale is a sanitised one-paragraph summary.

## 5. Safety, alignment & guardrails (`safety-svc`)

**Pre-call** checks:
- Prompt-injection scrubbing on inputs that came from citizens or partners.
- PII detection on retrieval results before passing to LLMs.

**Post-call** checks before output reaches a human:
- Hallucination detection (citation grounding score).
- Toxicity, bias, jurisdictional language compliance.
- Actionability check (does the proposal name a valid resource that exists?).
- Confidence threshold per `action_type`.

Failures route to `decision.proposal` with `status='blocked'` and a flag for human review; they do not reach citizens.

**Red-team drills** quarterly: an internal team and contracted external partners try to provoke unsafe outputs; failures become regression tests.

## 6. Continuous learning

### 6.1 Pipeline

```
postmortem-svc ─▶ extracts (forecast, observed) pairs
                  + officer feedback (was the recommendation good?)
                  + outcome data (did the action work?)
                  ─▶ writes train.label topic
                          │
                          ▼
                  ml-training-svc (offline)
                          │
                          ▼
                  evaluate vs frozen test set
                          │
                          ▼
                  challenger pushed to MLflow
                          │
                          ▼
                  shadow-deploy → eval-svc compares
                          │
                          ▼
                  human approval (model owner + tenant admin)
                          │
                          ▼
                  promote → signed artefact → sovereign deploy
```

### 6.2 Datasets

- **Real**: every event captured in `hazard.events` is a labelled sample.
- **Drill**: shadow-mode replays produce additional labelled sequences with known answers.
- **Synthetic**: physics simulators (HEC-RAS for floods, SCHISM for surge) generate corner cases (1-in-200-year events, dam breach).
- **Federated**: countries opt to share **gradient updates** — never raw data — across the control plane. Implemented via secure aggregation; differential privacy budget tracked per tenant.

### 6.3 Evaluation

- Hazard-specific metrics: CRPS for flood/cyclone forecasts, MAE for level, ROC-AUC for landslide, F1 for citizen-report classifier.
- **Operational metrics:** false-alarm rate, missed-alarm rate, mean lead time at alert generation, decision approval rate by humans, time-to-action.
- **Counterfactual analysis** post-event: what would the model have said had it run earlier? Stored alongside the report.

### 6.4 Climate re-baselining

A scheduled job runs annually:
- Recomputes return-period statistics with the latest decade.
- Surfaces stations whose Warning/Danger levels need re-calibration.
- Produces a draft change list for hydrologists to approve.

## 7. MLOps

| Concern | Tool | Notes |
|---|---|---|
| Tracking | MLflow | Per-tenant project, lineage links to dataset & code |
| Feature store | Feast | Online (Redis) + offline (S3 + Athena) |
| Orchestration | Argo Workflows / Kubeflow | DAGs per hazard |
| Pipelines | DVC + Pachyderm-style | Data lineage, reproducible training |
| Eval | Evidently AI + custom probes | Drift, calibration, fairness |
| Registry | MLflow + Sigstore | Cosign-signed artefacts |
| Promotion | Argo Rollouts on Triton | Canary → 10% → 50% → 100% |
| Observability | Arize / Phoenix | Prediction logs, drift alerts |
| Cost | OpenCost | Inference $ per hazard, budget alerts |

## 8. Voice & multimodal

- **Speech-to-text**: in-country deployed Whisper-class encoder; supports 12+ Indian languages and dialects; sub-second per sentence on GPU.
- **Text-to-speech**: open-weights TTS deployed sovereign; per-language voice persona for alerts.
- **Vision**: citizen-report classifier and satellite segmentation share a Triton ensemble (encoder shared, heads specialised).
- **Translation**: per-tenant language pairs; alerts always rendered in all configured languages and verified by a `translation-quality` model before dispatch.

## 9. Cost & latency budgets

- **Per-incident agent budget**: token cap per tenant per incident; orchestrator enforces hard stop and falls back to templates.
- **Latency budget**: orchestrator must return ranked proposals within 30 s; per-agent sub-budget 10 s; tool calls ≤ 1 s p95.
- **Caching**: identical queries within an incident hit a per-incident agent cache (TTL 60 s) — common during a fast-moving event.

## 10. Failure & degradation modes

| Failure | Behaviour |
|---|---|
| GPU pool down | Fallback to distilled CPU model; flag "AI degraded" in console |
| LLM router can't reach any model | Decision-svc switches to **template-only** mode: rule-based proposals with disclaimers |
| Drift alarm fires on a model | Shadow becomes champion *only* after human approval; otherwise champion frozen, alerts include "model under review" notice |
| Safety-svc blocks too many outputs | Auto-rollback to previous prompt template; SRE paged |
| Federated update poisoned | Aggregation rejects outliers; affected tenant re-evaluated; secure-aggregation logs reviewed |

## 11. What we are explicitly **not** building

- We do **not** auto-execute alerts on the public from AI alone.
- We do **not** train models on raw citizen content without explicit consent.
- We do **not** use AI to make eligibility / triage decisions on individual citizens (e.g., "this person gets help, this one doesn't"). Citizen-side ML is limited to routing, classification, and language tasks; humans triage individuals.

These are policy commitments, encoded as service-level guardrails in `safety-svc`.
