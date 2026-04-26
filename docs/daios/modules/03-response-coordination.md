# Module 3 — Emergency Response Coordination

The operational backbone: turning **decisions** (authorised by humans on AI proposals) into **tasks** that real units execute, tracked in real time.

## Concepts
- **Incident**: a coordinated, named situation (`hazard.incidents`).
- **Decision**: a proposed action with rationale, ranked, awaiting authorisation (`hazard.decisions`).
- **Task**: an authorised, assigned unit of work (`response.tasks`).
- **Unit**: a deployable resource (NDRF team, ambulance, fire tender, police patrol, drone) with telemetry.

## Lifecycle

```
event → incident.opened → decision.proposed (multi-agent)
                          → decision.authorised (human)
                          → task.created → task.assigned → task.in_progress → task.completed
                                                        ↘ task.failed (re-route)
                          → SITREP.published (every 30 min)
                          → incident.closed → postmortem
```

## Key features
- **Incident command** with role-based seats (commander, ops chief, planning chief, logistics, comms).
- **Tasking board** with drag-drop and auto-assignment proposals (closest-feasible-unit + capability match).
- **Live unit telemetry** (position, status, fuel, capacity).
- **Inter-agency tasking**: cross-department tasks route through `agent-runtime` to the right department lead with notifications + SLA.
- **Resource ledger**: shelters, ambulances, supplies; reservations and allocations tracked with audit.
- **SITREP** auto-drafted by LLM; officer edits + signs; published to public incident page and partner agencies.
- **Comms**: voice/video bridges to units; transcripts logged; PTT supported.

## Integration points
- `decision-svc` writes proposals; `response-svc` consumes after authorisation.
- `dispatch-svc` issues tasking to unit devices (Android tablets, APIs to partner ERPs).
- `volunteer-svc` activates vetted volunteers when official capacity insufficient.
- `resource-svc` is queried by department agents for proposal feasibility.

## Specialised flows
- **Mass evacuation**: target population → shelter capacity match → bus dispatch + traffic diversion → comms broadcast → check-in at shelter.
- **Cell broadcast**: gated through `cb-adapter-svc` with strict authorisation chain.
- **Cross-tenant** (e.g., trans-state/trans-country basin): incident scope can include linked tenants for read-only coordination.

## SLOs
- Decision authorisation → task created: ≤ 5 s
- Task dispatched → unit acks on device: ≤ 60 s (network permitting)
- SITREP cadence: 30 min during active; 5 min during severe
