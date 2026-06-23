# Module 4 — Citizen Engagement Platform

Two-way channel between DAIOS and the public. Outbound: alerts, advisories, broadcasts. Inbound: SOS, reports, status, family-safety.

## Surfaces
- **Mobile app** (Android-first, iOS, PWA fallback)
- **SMS short-code** (lowest common denominator)
- **WhatsApp Business / RCS Business Messaging**
- **Voice IVR** (low-literacy regions)
- **Cell broadcast** (no opt-in, geo-targeted, one-shot)
- **Public address** (mosques, temples, sirens — opt-in network)
- **Web (citizen.daios.gov)**

## Outbound — alerts
- Composed by `alerts-svc`; templated; multilingual.
- Channels chosen per recipient profile + alert severity.
- Cell broadcast for Severe/Extreme, no opt-out (where law permits).
- Voice TTS auto-generated for accessibility / low-literacy.
- Action verbs from the canonical 8–10 vocabulary (evacuate, shelter-in-place, …).

## Inbound — SOS
- Single-button design; works on low signal; idempotent.
- Captures location + last-known + battery + cell-id.
- Returns SOS PIN for callbacks.
- Routed to `response-svc` priority queue; dispatcher screen highlights within seconds.
- Health-priority: integrates with 108/911-equivalent dispatch.

## Inbound — citizen reports
- Photo/video/text + auto-location.
- Classified by `citizen-report-classifier` (multimodal).
- Trust score + cross-reference to existing incidents.
- High-trust reports promoted into `hazard.events` automatically; low-trust queued for human triage.
- Photos PII-redacted (face/plate blur) before storage.

## Family circle (opt-in, E2EE)
- Up to 5 trusted contacts share location during a Severe event.
- Auto-disable 24 h after event resolved.
- E2EE via libsignal; server stores sealed payloads only.
- "I am safe" check-in propagates to circle.

## Inclusion
- Pictograms for low-literacy.
- Voice mode for visually impaired or illiterate.
- Sign-language video for top alerts.
- Shareable PIN for elderly users administered by literate relative.
- Languages: per tenant set; right-to-left where applicable.

## Privacy
- Phone numbers + names application-layer encrypted; blind-indexed for search.
- Location precision aged out post-incident.
- Consent versioned and visible; revocation honoured immediately.
- Right to access / erasure self-service in app.
- DPO contact in privacy notice per tenant.

## Anti-abuse
- Rate limits per device/phone.
- Device attestation (Play Integrity / DeviceCheck) for SOS-relevant flows.
- Spammy reports flagged; repeat offenders soft-throttled.
- Verified-volunteer track for trusted reporters.

## SLOs
- SOS ack ≤ 1 s; response ETA shown to citizen ≤ 5 s after assignment.
- Alert delivery to opted-in citizens: P95 ≤ 30 s from authorisation.
- Cell broadcast dispatch: P95 ≤ 60 s.
