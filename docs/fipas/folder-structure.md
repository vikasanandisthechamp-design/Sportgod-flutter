# FIPAS — Folder Structure

## 1. Monorepo layout (top level)

A single pnpm + Turborepo monorepo keeps frontend, backend services, and shared packages version-locked.

```
fipas/
├── apps/
│   ├── web/                      # Next.js 14 (public + admin shell)
│   └── tv-display/               # Next.js kiosk build (optional split)
├── services/
│   ├── auth-svc/
│   ├── admin-svc/
│   ├── readings-svc/
│   ├── ingest-svc/
│   ├── alerts-svc/
│   ├── notify-svc/
│   ├── analytics-svc/
│   ├── audit-svc/
│   ├── gateway-svc/              # WebSocket fan-out
│   └── ai-predict-svc/           # placeholder for future ML
├── packages/
│   ├── shared-types/             # zod schemas + TS types (API contract)
│   ├── severity-spec/            # threshold evaluation (pure fn, shared FE/BE)
│   ├── i18n-strings/             # hi + en resource bundle
│   ├── eslint-config/
│   ├── tsconfig/
│   └── ui-kit/                   # React component library (buttons, cards, maps)
├── infra/
│   ├── docker/                   # Dockerfiles, compose stacks
│   ├── helm/                     # Helm charts per service + umbrella chart
│   ├── terraform/                # AWS / NIC Cloud IaC
│   └── k8s/                      # Kustomize overlays per env
├── ops/
│   ├── grafana/                  # dashboards as JSON
│   ├── prometheus/               # rules, alerts
│   ├── runbooks/                 # markdown runbooks
│   └── load-tests/               # k6 scripts
├── .github/
│   └── workflows/                # CI/CD pipelines
├── turbo.json
├── pnpm-workspace.yaml
├── package.json
└── README.md
```

## 2. Frontend — `apps/web` (Next.js 14 App Router)

```
apps/web/
├── app/
│   ├── [locale]/                                 # /hi or /en
│   │   ├── (public)/
│   │   │   ├── page.tsx                          # Home / state dashboard
│   │   │   ├── district/[code]/page.tsx          # District drill-down
│   │   │   ├── river/[id]/page.tsx               # River drill-down
│   │   │   ├── station/[id]/page.tsx             # Station detail + history
│   │   │   ├── alerts/page.tsx
│   │   │   ├── about/page.tsx
│   │   │   └── layout.tsx                        # public layout with header/footer
│   │   ├── display/
│   │   │   ├── page.tsx                          # TV display landing
│   │   │   ├── [rotation]/page.tsx               # rotating district groups
│   │   │   └── layout.tsx                        # fullscreen kiosk layout
│   │   ├── admin/
│   │   │   ├── (auth)/login/page.tsx
│   │   │   ├── (auth)/mfa/page.tsx
│   │   │   ├── dashboard/page.tsx
│   │   │   ├── readings/
│   │   │   │   ├── page.tsx                      # list + filter
│   │   │   │   ├── new/page.tsx                  # single entry form
│   │   │   │   └── bulk/page.tsx                 # CSV upload
│   │   │   ├── stations/page.tsx
│   │   │   ├── users/page.tsx
│   │   │   ├── audit/page.tsx
│   │   │   ├── analytics/page.tsx
│   │   │   └── layout.tsx                        # admin chrome w/ role-aware nav
│   │   └── layout.tsx                            # locale layout (fonts, providers)
│   ├── api/                                      # BFF endpoints (only if needed)
│   │   └── health/route.ts
│   ├── globals.css
│   └── not-found.tsx
├── components/
│   ├── dashboard/
│   │   ├── StateMap.tsx                          # Mapbox / MapLibre choropleth
│   │   ├── DistrictCard.tsx
│   │   ├── SeverityLegend.tsx
│   │   └── LiveTicker.tsx                        # split-flap / airport board
│   ├── display/
│   │   ├── SplitFlapRow.tsx                      # animated row
│   │   ├── RotationHeader.tsx
│   │   └── ClockBar.tsx
│   ├── admin/
│   │   ├── ReadingForm.tsx
│   │   ├── CsvDropzone.tsx
│   │   ├── RoleGuard.tsx
│   │   ├── AuditTable.tsx
│   │   └── DataTable.tsx
│   ├── ui/                                       # from @fipas/ui-kit re-exports
│   └── providers/
│       ├── QueryProvider.tsx                     # TanStack Query
│       ├── WsProvider.tsx                        # WebSocket context
│       ├── I18nProvider.tsx
│       └── AuthProvider.tsx
├── hooks/
│   ├── useLiveReadings.ts
│   ├── useDistrictSummary.ts
│   ├── useAuth.ts
│   ├── useDisplayRotation.ts
│   └── useCsrf.ts
├── lib/
│   ├── api-client.ts                             # fetch wrapper (retries, auth, trace id)
│   ├── ws-client.ts
│   ├── severity.ts                               # re-export from @fipas/severity-spec
│   ├── format.ts                                 # number/date formatting (en-IN, hi-IN)
│   └── env.ts                                    # runtime config via NEXT_PUBLIC_*
├── locales/
│   ├── en/common.json
│   └── hi/common.json
├── middleware.ts                                 # locale routing + admin auth gate
├── next.config.mjs
├── tailwind.config.ts
├── postcss.config.js
├── package.json
└── tsconfig.json
```

### Key decisions
- **App Router with RSC** for the public pages (SEO, fast TTFB).
- **Client components** for dashboards, charts, and the admin panel (interactivity + WebSocket).
- **i18n** via `next-intl`; locales come from `@fipas/i18n-strings`.
- **Maps** via MapLibre GL (OSS, no API-key lock-in) with a fallback OSM tile server hosted in NIC.
- **State** via TanStack Query for REST + a thin WebSocket adapter that surgically invalidates queries on `reading.created`.
- **Forms** via React Hook Form + Zod (reusing backend schemas from `@fipas/shared-types`).
- **Animation** via Framer Motion for split-flap rows on the TV display.

## 3. Backend service — template (`services/<name>-svc`, NestJS)

Every service follows the same structure so engineers can move between them with zero ramp-up.

```
services/readings-svc/
├── src/
│   ├── main.ts                                   # bootstrap, graceful shutdown
│   ├── app.module.ts
│   ├── config/
│   │   ├── config.module.ts                      # @nestjs/config + zod validation
│   │   └── env.schema.ts
│   ├── common/
│   │   ├── guards/                               # JwtAuthGuard, RolesGuard, CsrfGuard
│   │   ├── interceptors/                         # LoggingInterceptor, TraceInterceptor
│   │   ├── filters/                              # HttpExceptionFilter (RFC7807)
│   │   ├── pipes/                                # ZodValidationPipe
│   │   └── decorators/                           # @Roles, @CurrentUser, @AuditAction
│   ├── modules/
│   │   ├── readings/
│   │   │   ├── readings.module.ts
│   │   │   ├── readings.controller.ts            # REST
│   │   │   ├── readings.service.ts               # business logic
│   │   │   ├── readings.repository.ts            # DB access (Drizzle / Prisma)
│   │   │   ├── dto/
│   │   │   │   ├── create-reading.dto.ts
│   │   │   │   ├── query-readings.dto.ts
│   │   │   │   └── reading.response.dto.ts
│   │   │   └── __tests__/
│   │   │       ├── readings.service.spec.ts
│   │   │       └── readings.controller.spec.ts
│   │   ├── stations/
│   │   └── health/
│   ├── infrastructure/
│   │   ├── db/
│   │   │   ├── db.module.ts                      # Postgres pool (pg-pool) + Drizzle
│   │   │   ├── schema.ts                         # Drizzle schema objects
│   │   │   └── migrations/                       # timestamped SQL
│   │   ├── redis/
│   │   ├── kafka/
│   │   └── s3/
│   └── types/
├── test/
│   ├── e2e/
│   └── fixtures/
├── Dockerfile
├── nest-cli.json
├── package.json
└── tsconfig.json
```

### Service-specific variations

- `gateway-svc` replaces `readings.controller` with `ws.gateway.ts` using `@WebSocketGateway` + `socket.io` (with native WS upgrade).
- `ingest-svc` has an extra `sources/` module (`imd.adapter.ts`, `cwc.adapter.ts`, `iot-mqtt.bridge.ts`).
- `alerts-svc` has a `evaluator.ts` that imports `@fipas/severity-spec` so FE and BE produce identical verdicts.
- `audit-svc` exposes an append-only repository; all other services write via a typed client, not directly.

## 4. Shared packages

### 4.1 `packages/shared-types`

```
packages/shared-types/
├── src/
│   ├── reading.ts                # z.object({...}) + inferred TS type
│   ├── station.ts
│   ├── alert.ts
│   ├── auth.ts
│   └── index.ts
└── package.json
```

Backend services import the same Zod schemas the frontend uses for forms — a single source of truth for the API contract.

### 4.2 `packages/severity-spec`

```
packages/severity-spec/
├── src/
│   ├── severity.ts               # evaluateSeverity(level, {warn, danger, hfl})
│   └── index.ts
└── package.json
```

Pure function, ≤ 40 lines, covered by ≥ 20 unit tests including edge cases (NaN, negatives, equal-to-boundary).

### 4.3 `packages/ui-kit`

Reusable React components used by `apps/web` and the TV display: `Badge`, `SeverityPill`, `StationCard`, `FlapDigit`, `Chart` (wrapper over Visx), `DataTable`, `Button`, etc.

## 5. Naming & conventions

- **Files:** `kebab-case.ts` for modules, `PascalCase.tsx` for React components.
- **Tests:** co-located `__tests__/` inside each module; E2E in each app/service's `test/e2e/`.
- **Migrations:** `YYYYMMDDHHMMSS_description.sql`; one logical change per migration; always reversible (`.up.sql` + `.down.sql`).
- **Commits:** Conventional Commits (`feat(readings): ...`, `fix(alerts): ...`).
- **Branches:** `feat/<scope>/<ticket>`, `fix/...`, `chore/...`; protected `main`.
