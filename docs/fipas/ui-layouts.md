# FIPAS — UI Layouts

This document describes every major screen: purpose, layout, data bindings, interactions, i18n and accessibility notes. Dimensions assume a 12-column grid and the Tailwind breakpoints `sm 640`, `md 768`, `lg 1024`, `xl 1280`, `2xl 1536`.

Design tokens:
- Font: **Noto Sans Devanagari** (Hindi) + **Inter** (Latin).
- Base scale: 16 px body, 14 px meta, 28/40/56/72 px display.
- Severity palette: `safe #16A34A`, `warning #EAB308`, `danger #F97316`, `critical #DC2626`.
- Surface: `#FFFFFF` light, `#0B1220` dark, `#111827` TV mode.
- Motion: Framer Motion with `reduce-motion` respected.

## 1. Public Dashboard — `/` (state view)

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  [Gov of Bihar crest]  FIPAS — Flood Intelligence               हि | EN     │
│  बाढ़ सूचना व जन जागरूकता प्रणाली     Last updated: 11:42 IST    [ TV Mode ] │
├─────────────────────────────────────────────────────────────────────────────┤
│  Status ribbon:                                                             │
│  ■ Safe 124   ■ Warning 18   ■ Danger 7   ■ Critical 2   Total stations 151 │
├─────────────────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────┐  ┌──────────────────────────────────┐    │
│  │  BIHAR CHOROPLETH MAP         │  │  ACTIVE ALERTS (live)            │    │
│  │  (38 districts coloured by    │  │  ─────────────────────────────── │    │
│  │   worst severity)             │  │  ● CRITICAL  Kosi @ Kursela      │    │
│  │                               │  │    52.1 m  ↑ 0.18 m/h            │    │
│  │  [hover: district name, tally]│  │  ● DANGER    Bagmati @ Sonakhan  │    │
│  │                               │  │    49.8 m  ↑ 0.14 m/h            │    │
│  │                               │  │  ● DANGER    Burhi Gandak ...    │    │
│  └───────────────────────────────┘  └──────────────────────────────────┘    │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────┐    │
│  │  DISTRICT CARDS (responsive grid, 4 → 2 → 1 cols)                  │     │
│  │  [Patna 3/8 danger]  [Muzaffarpur 1/7 crit] [Bhagalpur 0/6]  ...   │     │
│  └─────────────────────────────────────────────────────────────────────┘    │
├─────────────────────────────────────────────────────────────────────────────┤
│  Footer: Data sources IMD · CWC · WRD Bihar   Accessibility   Privacy       │
└─────────────────────────────────────────────────────────────────────────────┘
```

- **Data bindings:** `GET /api/v1/public/districts` (SSR) + WebSocket `alerts.state`, `readings.district.*` (CSR).
- **Interactions:** Click district → drill to `/district/[code]`; click active alert row → station detail.
- **Accessibility:** WCAG 2.2 AA. Map has a textual list equivalent (`<ol>`), alerts ticker is ARIA live region (`polite`, `critical` becomes `assertive`).
- **i18n:** All labels from `@fipas/i18n-strings`; numbers localised via `Intl.NumberFormat('en-IN' | 'hi-IN')`.

## 2. District Drill-down — `/district/[code]`

Two-column layout on `lg+`, single column on mobile.

- Left column: District header (name, population, division), severity donut, trend sparkline (last 24 h aggregate).
- Right column: Station table (code, river, latest level, delta-1h, trend arrow, severity pill, last updated).
- Top-right: "View on TV display" and "Export CSV" (public, last 7 days).
- Live updates highlight row for 3 s on WebSocket event.

## 3. Station Detail — `/station/[id]`

- Header: station name (hi + en), river, coordinates, levels (WL/DL/HFL) pill.
- **Hero gauge:** animated vertical meter showing current level vs WL, DL, HFL bands.
- **Time-series chart** (Visx/D3): selectable windows 6h, 24h, 7d, 30d, custom. Overlay horizontal lines at WL/DL/HFL.
- Metadata: data source, operator, last corrected-at.
- Shareable deep link, QR code for field teams.

## 4. Smart-TV Display Mode — `/display` (kiosk)

Target: 1920×1080 and 3840×2160 LED TVs in SEOC, district control rooms, bus stops, railway stations.

```
┌────────────────────────────────────────────────────────────────────────────┐
│  FIPAS LIVE  |  बिहार जल संसाधन विभाग             ◉ LIVE  24 Apr 11:42 IST │
│                                                    Next refresh in 04:37   │
├────────────────────────────────────────────────────────────────────────────┤
│ SEVERITY SUMMARY (state)                                                   │
│   ■■■■■■■■■■■■■■■■■■  SAFE 124    ■■■ WARN 18    ■ DANGER 7    ■ CRIT 2   │
├────────────────────────────────────────────────────────────────────────────┤
│  DISTRICT                RIVER            STATION           LEVEL   STATUS │
│  ─────────────────────────────────────────────────────────────────────────  │
│  KATIHAR                 KOSI             KURSELA           52.1 m  ■ CRIT │
│  MUZAFFARPUR             BURHI GANDAK     AHIRWALIA         49.8 m  ■ DNGR │
│  SITAMARHI               BAGMATI          SONAKHAN          49.4 m  ■ DNGR │
│  DARBHANGA               KAMLA            JHANJHARPUR       47.1 m  ■ WARN │
│  SUPAUL                  KOSI             BASUA             46.9 m  ■ WARN │
│  ...                                                                        │
│  ─────────────────────────────────────────────────────────────────────────  │
│    (rows flip in split-flap animation; auto-rotates 18 rows every 10s)      │
├────────────────────────────────────────────────────────────────────────────┤
│  MARQUEE: CRITICAL — Kosi at Kursela crossed HFL by 0.3 m at 11:30 IST ... │
└────────────────────────────────────────────────────────────────────────────┘
```

### Display-mode specifics

- **Fullscreen API:** on load, requests `document.documentElement.requestFullscreen()`; no chrome, no scrollbars, cursor hidden after 3 s of inactivity.
- **Auto-refresh:** page soft-reloads every 5 min (`router.refresh()` to re-SSR); WebSocket overlays between reloads.
- **Split-flap animation:** each digit/letter is a `FlapDigit` that cycles to the new value in 600 ms, staggered per column.
- **Rotation:** 18 rows visible; when district list > 18 rows, rotates groups every 10 s with a slide-up transition; `display.rotation` WS topic synchronises multiple TVs in the same SEOC wall.
- **Color coding:** background of the row tinted 8% of severity colour; status pill is the full colour.
- **Kiosk compatibility:** tested on Samsung Tizen, LG webOS, generic Android TV via Chromium, Raspberry Pi + Chromium `--kiosk`.
- **Resilience:** service-worker caches last good render; if API is down > 90 s, a "Last good data — 11:38 IST" banner appears and content remains readable.
- **Hindi/English rotation:** the header toggles hi/en every 30 s; data labels stay in local language of the TV (configurable via `?lang=hi|en|bi` where `bi` alternates).

## 5. Admin Panel shell — `/admin/*`

Two-pane layout: left sidebar (240 px, collapsible), right content. Top bar shows user avatar, role chips, active district scope, locale switch, and logout.

Sidebar items depend on role:
- **State Admin:** Dashboard · Readings · Stations · Rivers · Users · Audit · Analytics · Ingestion jobs · Settings
- **District Officer:** Dashboard · Readings · Stations (read) · Audit (district) · Analytics (district)
- **Data Entry:** Dashboard · Readings (their stations) · Bulk upload
- **Auditor:** Audit (read-only across state) · Reports

### 5.1 Login — `/admin/login`

Minimal, centered card. Fields: email, password, "Show password", "Remember me". Submit → if MFA enrolled, redirects to `/admin/mfa`. After 5 failed attempts the account locks and SEOC is alerted (internal email).

### 5.2 Admin Dashboard — `/admin/dashboard`

- Top cards: "Active alerts", "Stations reporting today", "Readings last 24 h", "Ingestion errors last 24 h".
- Middle: Live feed of readings (scoped to role) with source badges.
- Right: To-do panel — stations with no reading in last 12 h (call to action for data entry operators).

### 5.3 Reading entry — `/admin/readings/new`

```
┌─────────────────────────────────────────────────────────────────┐
│  New Reading                                                    │
│                                                                 │
│  Station *       [ Searchable combobox: code + name ]           │
│  Observed at *   [ Datetime picker, default now()    ]          │
│  Level (m) *     [ __ . ___ ]  WL 47.5 / DL 49.6 / HFL 51.8     │
│  Trend           ( ) Rising  (•) Steady  ( ) Falling            │
│  Remarks         [ textarea                                     ]│
│                                                                 │
│  Severity preview: ■ DANGER (49.82 ≥ 49.60)                     │
│                                                                 │
│  [ Save & add another ]   [ Save ]       [ Cancel ]             │
└─────────────────────────────────────────────────────────────────┘
```

- Live severity preview from `@fipas/severity-spec`.
- Station combobox scoped by RBAC (no stations outside officer's district listed).
- On save: optimistic UI, toast "Saved — alert sent to X subscribers" if severity rose.
- Duplicate guard: if a reading within ±1 minute exists for same station, confirm-replace dialog.

### 5.4 Bulk CSV upload — `/admin/readings/bulk`

- Dropzone, client-side CSV parse preview (PapaParse), column mapping UI, dry-run toggle.
- After upload: progress stream via WebSocket `admin.ingest.live`; per-row pass/fail table; errors exportable as CSV.

### 5.5 Station management — `/admin/stations`

- Data table with server-side search, filter by district/river/status.
- Row click → drawer with edit form (state_admin only). Thresholds require dual-approval: edit puts change into "pending", auditor or 2nd state_admin confirms.

### 5.6 Users & roles — `/admin/users`

- Table: name, email, roles (chips), status, last login.
- Create user: email, phone, full name, role assignment with scope (state / district / station); temp password emailed; MFA enrolment forced at first login.
- Role changes are audited with before/after JSON.

### 5.7 Audit — `/admin/audit`

- Filterable table: actor, action, entity, timestamp, ip, result.
- Row expand shows signed JSON diff (before/after) with cryptographic signature check indicator.
- Export CSV (signed manifest).

### 5.8 Analytics — `/admin/analytics`

- Trend charts per district/river/station.
- Flood-days heatmap (calendar view, darker = more severe).
- Correlation overlay with rainfall (IMD) when available.
- Export: CSV, PDF report (server-rendered via Puppeteer in a sandboxed job).

## 6. Responsive behaviour

| Breakpoint | Public dashboard | TV display | Admin |
|---|---|---|---|
| `< sm` | Single column, map collapses to list | Single row at a time, larger type | Sidebar becomes hamburger drawer |
| `sm–md` | Map above, cards below | Two columns | Drawer, condensed tables |
| `lg+` | Side-by-side map + alerts | Full 18-row table | Full sidebar + content |
| `2xl (TV)` | — | Oversized typography, high contrast | — |

## 7. Animation & motion

- Split-flap row flip: 600 ms, `ease-out`, staggered 40 ms per column.
- Marquee: 20 s linear, pauses on hover (not TV).
- Alert ribbon pulse: 2 s, `2px` glow for `critical` only.
- `prefers-reduced-motion`: replaces flips with fades, disables marquee.

## 8. Accessibility

- WCAG 2.2 AA; severity never communicated by colour alone — always paired with label and icon.
- Keyboard nav: skip-to-content link, focus rings (`2px #2563EB`), all interactive controls reachable.
- Screen-reader labels bilingual (`aria-label` picks language from `<html lang>`).
- Contrast ≥ 4.5:1 for text, ≥ 3:1 for UI chrome; TV mode ≥ 7:1 (AAA).
- Language metadata `<html lang="hi">` / `en` correctly set so speech synthesis works.

## 9. Offline / low-bandwidth

- Service worker caches shell + last API response per district.
- Progressive enhancement: the core table is readable without JS (SSR HTML + CSS only).
- Optional "Lite mode" toggle disables map and animations for 2G connections.
