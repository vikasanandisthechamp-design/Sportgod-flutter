# DAIOS — UI / UX Structure

DAIOS has **five distinct interfaces**, each with a different user, posture, and design language.

| Surface | Primary user | Posture | Tech |
|---|---|---|---|
| 1. Public Web Dashboard | Citizens, journalists, partners | Read-only, low-bandwidth-friendly | Next.js SSR/ISR, MapLibre |
| 2. Citizen Mobile/Web App | Affected/at-risk citizens | Fast, calm, multilingual | React Native + PWA |
| 3. SEOC Command Console | State Emergency Operations Centre | Wall-screen + multi-monitor | Next.js + Electron variant |
| 4. District / Field Console | District officers, agency leads | Tablet/laptop, sometimes offline | PWA |
| 5. Public Display Network | Bus stops, railway stations, kiosks, TV walls | Glanceable, highest contrast | Next.js kiosk build |

A shared design system (`@daios/ui-kit`) ensures visual consistency across surfaces while letting each one specialise.

## 1. Design system fundamentals

- **Severity palette** (locked, used everywhere): Safe `#16A34A`, Watch `#3B82F6`, Warning `#EAB308`, Severe `#F97316`, Extreme `#DC2626`.
- **Hazard glyphs**: a single icon set (Lucide-derived); each hazard has a stable mark.
- **Typography**: Inter (Latin), Noto Sans Devanagari (Hindi), Noto Naskh Arabic (Arabic), Noto Sans Bengali, etc. Per-tenant font bundle.
- **Voice & tone**: terse, unambiguous, action-oriented. No marketing language. Ever.
- **A11y**: WCAG 2.2 AA on public + citizen surfaces, **AAA on the SEOC wall** because operators are colour-tested and screen-tested under stress.
- **Reduced motion** respected on every surface.
- **Dark mode default** on operator surfaces; auto on public.

## 2. Public Web Dashboard

### 2.1 Information architecture
```
/                              → state-level overview (map + active alerts)
/region/[code]                 → regional drill-down
/district/[code]               → district detail
/hazard/[id]                   → all-region rollup for a hazard
/incident/[id]                 → incident page (alerts, timeline, public report)
/sensors/[type]/[id]           → station/sensor detail
/post-event/[incident_id]      → archived incident page
/help                          → what to do for each hazard
/about
```

### 2.2 Home layout (state)
```
┌──────────────────────────────────────────────────────────────┐
│ DAIOS · <Tenant>           हिं | EN | …          [TV mode]   │
│ Active hazards: ● Flood · ○ Heatwave · ○ Earthquake          │
├──────────────────────────────────────────────────────────────┤
│ Severity ribbon: ■ Safe ■ Watch ■ Warning ■ Severe ■ Extreme │
├──────────────────────────────────────────────────────────────┤
│  ┌────────────────────────┐ ┌────────────────────────────┐   │
│  │  STATE MAP (choropleth)│ │ ACTIVE INCIDENTS (live)    │   │
│  │  layers togglable      │ │ ─ Kosi flood, Katihar      │   │
│  │  (flood ext, wind, eq) │ │ ─ Heatwave, Gaya           │   │
│  │                        │ │ ─ Cyclone watch, coast     │   │
│  └────────────────────────┘ └────────────────────────────┘   │
│  ┌────────────────────────────────────────────────────────┐  │
│  │  DISTRICT GRID (responsive)                            │  │
│  └────────────────────────────────────────────────────────┘  │
└──────────────────────────────────────────────────────────────┘
```

### 2.3 Incident page
- Hero: hazard, severity, area polygon on map, est. affected population.
- Tabs: **Live status** · **Alerts** · **What to do** · **Timeline** · **Post-event report (when closed)**.
- Each alert shows: severity, area, recommended action, channels dispatched, time, in current language + EN.
- **Citizen action panel**: prominent "Report from this area" CTA → goes to citizen app or SMS short-code.

### 2.4 Low-bandwidth mode
- Toggle (auto-detected on 2G/Save-Data header).
- Disables map, animations, large images.
- Text-first table view; ≤ 30 KB per page.

## 3. Citizen Mobile/Web App

### 3.1 Design intent
- **Calm in a crisis.** Never red-alert by default — only when there's an active alert near the user.
- **Three taps to safety.** Open → see status near me → know what to do.
- **Works on a 5-year-old phone over 2G.**
- **Voice-first option.** A button reads the alert aloud in the user's language.

### 3.2 Screens

```
1. Home
   - Header: location, current severity (color), language
   - Big card: "All clear in <ward>" or active alert
   - Quick actions: SOS · Report · Nearby (shelters, hospitals)
   - Hazard chips (toggle subscriptions)

2. Active alert (interrupts only when severity ≥ Severe)
   - Hazard, area, recommended action (max 3 bullets)
   - Map snippet
   - "Mark me safe" / "I need help"
   - Share alert

3. Report
   - Camera/gallery + text + auto-location
   - Hazard tag (optional)
   - Submit even offline (queued)

4. SOS
   - Single big red button; long-press to confirm
   - Sends location + last-known + battery + nearest cell
   - Confirmation screen with PIN, ETA, callback number

5. My area
   - Subscribed wards/districts
   - Sensor history
   - Past alerts

6. Family circle (opt-in)
   - Share location with up to 5 trusted contacts during a Severe event
   - Auto-disables 24 h after event resolved

7. Profile / Settings / Consent / Language
```

### 3.3 Accessibility & inclusion
- **Voice mode**: reads any screen aloud; voice-trigger words for SOS in 12 languages.
- **Pictogram fallback** for low-literacy users: alerts shown with universal pictograms ("evacuate", "stay indoors", "boil water").
- **High-contrast mode** built-in.
- **Family-share PIN** so a literate relative can administer the app for an elderly user.

## 4. SEOC Command Console

The "war-room". Built for a multi-monitor wall (2 × 4 K) in front of a duty commander, with overflow operators on workstations.

### 4.1 Monitor layout (typical)

```
Monitor 1 (left half of wall) — STATE OVERVIEW MAP
  ├─ choropleth + hazard layers (toggle)
  ├─ unit positions (NDRF, ambulance, fire)
  └─ alert footprints (translucent)

Monitor 2 (right half of wall) — INCIDENT FOCUS
  ├─ selected incident details
  ├─ decision queue (pending vs authorised)
  └─ live agent reasoning side panel

Operator workstation 1 — HAZARD MONITORING
  └─ per-hazard kernel views (flood gauges, eq feeds, cyclone tracks)

Operator workstation 2 — RESPONSE / DISPATCH
  └─ tasks board, unit map, comms log

Operator workstation 3 — CITIZEN CHANNEL
  └─ SOS queue, citizen reports triage, broadcast composer

Operator workstation 4 — INTER-AGENCY COORDINATION
  └─ tasks per dept, SITREP composer, video huddle
```

### 4.2 Top-level views

#### 4.2.1 Decision Queue
The **defining screen** of DAIOS for officials.

```
PENDING DECISIONS                                    [Filter: severe+]
┌────────────────────────────────────────────────────────────────────┐
│ #1  EVACUATE  Sonpur block ✦ Police+CivilDefence                   │
│     Confidence 0.86  · est. saved 2,400  · ETA 45 min              │
│     Why: flood ETA 4h, road network reliable, shelters available   │
│     [▶ Show reasoning]   [✓ Authorise]   [✗ Reject]   [Modify]     │
├────────────────────────────────────────────────────────────────────┤
│ #2  OPEN_SHELTER  Hajipur GHS school ✦ Civil Defence               │
│     Confidence 0.92  · capacity 800                                │
│     Why: ...  [▶]  [✓ Authorise]                                    │
├────────────────────────────────────────────────────────────────────┤
│ #3  BROADCAST  Cell broadcast warning, 14 cells ✦ Comms            │
│     Confidence 0.78 · template "flood-evac-hi-en-bho"              │
│     [▶]  [✓ Authorise]                                              │
└────────────────────────────────────────────────────────────────────┘

AUTHORISED · IN PROGRESS                            [last 30 min]
┌────────────────────────────────────────────────────────────────────┐
│ ✓ DISPATCH  NDRF Team-7 to Saharsa  · 11:14 · ETA 11:55            │
│ ✓ ROAD_CLOSE  NH-31 km 142  · 11:09  · barricades placed           │
└────────────────────────────────────────────────────────────────────┘
```

Authorising requires a fresh MFA stamp (re-prompted every 5 min during a Severe incident).

#### 4.2.2 Reasoning panel (right side)
Selecting a proposal opens a panel showing:
- One-paragraph rationale (sanitised)
- Citations (SOPs, prior incidents)
- Tools the agent invoked (read.* calls)
- Alternative proposals it considered and why they were ranked lower
- Confidence calibration history

#### 4.2.3 Dispatch board
- Map with units (icons), tasks (pins).
- Drag-drop assignment.
- Unit cards: callsign, ETA, capacity, current task.
- Comms tab: voice/video bridge to unit lead.

#### 4.2.4 SITREP composer
- AI drafts a SITREP every 30 min during active incident.
- Officer edits, signs, publishes to partner agencies and the public incident page.

### 4.3 Voice interface
- PTT button on every screen.
- "DAIOS, status of Saharsa" → reads summary.
- "DAIOS confirm authorise decision 1" → executes (with audit).
- Voice transcripts shown side-by-side with their executed mutations for verification.

## 5. District / Field Console

### 5.1 Posture
- Tablet-first; works offline (PWA + service worker).
- Limited to the user's scope.
- Field-friendly: large tap targets, glove-compatible.

### 5.2 Screens
- **My district overview** (mirrors state console, scoped).
- **Reading entry** (manual gauge readings, photo + level).
- **Citizen reports triage**.
- **Tasks assigned to me / my dept**.
- **SITREP composer (district)**.
- **Quick comms** (push talk to SEOC, fellow officers).

### 5.3 Offline-first
- All today's data cached on device.
- Submitted reports/readings queued; sync on reconnect with conflict resolution.
- "Last sync" timestamp prominent.

## 6. Public Display Network

### 6.1 Forms
- 16:9 TVs at SEOC, district control rooms, bus stops, railway stations.
- 9:16 portrait kiosks in panchayat offices, shelters, hospitals.
- Multi-screen video walls in SEOC.

### 6.2 Modes
| Mode | Trigger |
|---|---|
| **Normal** | No active severe events: shows state map + tips |
| **Alert** | Active warning/severe in district: full alert with action steps |
| **Critical** | Extreme event: emergency layout, sirens recommended |
| **Drill** | Banner clearly says "DRILL", same content |

### 6.3 Critical layout (TV)
```
┌─────────────────────────────────────────────────────────────────┐
│ ⚠ CRITICAL ALERT — KOSI FLOOD                  11:42 IST · LIVE │
├─────────────────────────────────────────────────────────────────┤
│  AREA: SAHARSA · MADHEPURA · KATIHAR (12 wards)                 │
│                                                                 │
│  ACT NOW:                                                       │
│   1. Move to higher ground / nearest shelter immediately        │
│   2. Take essentials: ID, water, medicines, phone               │
│   3. Avoid crossing flooded roads                               │
│                                                                 │
│  NEAREST SHELTERS                                               │
│   • Saharsa GHS School    (1.2 km)  capacity: 600               │
│   • Madhepura Stadium     (2.4 km)  capacity: 1,500             │
│                                                                 │
│  HELPLINE 1078  ·  SOS via DAIOS app  ·  SMS DAIOS to 56767     │
└─────────────────────────────────────────────────────────────────┘
```
- Languages rotate every 12 s.
- Multi-screen walls show alert + map + shelters + helplines split across panels.

### 6.4 Operational
- Devices register with `display-svc`, identified by JWT-attested device ID.
- Content driven by WS topic `display.<region>.<id>`.
- Auto-recovers from network drops (last good content stays).
- Hardware-watchdog reboot on freeze.

## 7. Cross-cutting UX patterns

### 7.1 Time
- Every timestamp shows **absolute** + **relative** ("11:42 IST · 7 min ago").
- Clocks visible everywhere on operator surfaces.

### 7.2 Provenance
- Every fact cards **shows source**: which feed, which agent, last updated.
- Click → trace.

### 7.3 Confidence
- AI outputs always show a confidence ring/bar.
- Below threshold → marked "AI advisory, low confidence — operator decides".

### 7.4 Drill safety
- A persistent "DRILL MODE" banner across the entire UI when shadow events are routed to that surface; impossible to mistake.

## 8. Performance budgets

| Surface | First Contentful Paint | Interaction |
|---|---|---|
| Public dashboard | ≤ 1.5 s on 3G mid-range Android | INP ≤ 200 ms |
| Citizen app | ≤ 2 s cold start | INP ≤ 100 ms |
| SEOC console | ≤ 1 s on LAN | INP ≤ 50 ms |
| Public display | ≤ 3 s boot, 30 fps animation | n/a |

## 9. Accessibility (top of mind)

- **Colour-only never sufficient**: severity always paired with label + glyph.
- **Captions and transcripts** on all video content (drills, briefings).
- **Sign-language video** track for top-3 priority alerts (per tenant policy).
- **Screen-reader audited** on every release; axe-core gate in CI.
- **Plain-language** alternative content for citizen surfaces, written by a comms editor (not by ML alone).

## 10. Internationalisation

- Languages configured per tenant; UI strings, dates, numbers, units localise automatically.
- Right-to-left layouts supported (Arabic, Urdu).
- Tenant comms team can edit alert templates in their CMS; translations auto-suggested + human-approved.
- Pictogram fallback for unsupported languages.
