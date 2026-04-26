# Module 5 — Decision Intelligence

The "brain" of DAIOS. Multi-agent LLM orchestration that turns hazard predictions and live state into ranked, traced action proposals.

See `ai-architecture.md` §4 for full agent architecture. This file scopes the **product surface** of the module.

## What officials see
- A **Decision Queue** in the SEOC console with pending proposals.
- Each proposal: action, scope, rationale, confidence, expected impact.
- One-click actions: **Authorise**, **Reject**, **Modify**, **Show reasoning**.
- Reasoning panel: citations, alternatives considered, agents involved, tools used.

## What's automated vs. human
- **Automated**: detection, prediction, proposal generation, simulation, post-event reports, language localisation.
- **Human**: every action that touches citizens, deploys resources, or commits funds.

## Hard guardrails (encoded, not promised)
1. No proposal becomes an action without a human + MFA + audit entry.
2. Below confidence thresholds (per action type), proposals are flagged and require dual approval.
3. `safety-svc` post-call check rejects proposals that fail grounding/actionability/jurisdiction.
4. Reasoning trace is mandatory and stored signed.

## Scenarios the engine handles well
- Prioritising N proposals across departments under finite resources.
- Comparing two evacuation strategies on the digital twin.
- Updating proposals as conditions evolve (causation chain from new readings).
- Producing comms templates in tenant languages with cultural nuance.

## Scenarios it explicitly defers to humans
- Judgement calls under high uncertainty / political sensitivity.
- Anything involving individual identification or eligibility.
- Cross-tenant coordination (humans negotiate; agent only summarises).

## Continuous improvement
- Officer Authorise/Reject feedback is a labelled signal.
- Outcomes (did the action work? what happened on the ground?) close the loop.
- Models retrain offline, promote with human approval, deploy via canary.
