# FIPAS — Deployment Strategy

## 1. Target platform

Primary: **AWS (Mumbai `ap-south-1`, DR in Hyderabad `ap-south-2`)**, procured through AWS EdTech/GovTech agreement with data-residency attestation.
Alternate: **NIC Cloud (MeghRaj)** — same topology, OpenStack/K8s-flavoured managed services, which the manifests support with minor tweaks. The deployment artifacts are cloud-agnostic (Helm + Terraform + Kustomize).

## 2. Topology (prod)

```
Region: ap-south-1 (Mumbai)
├── VPC 10.20.0.0/16
│   ├── Public subnets (3 AZs)     — ALB, NAT, bastion
│   ├── Private subnets (3 AZs)    — EKS nodes, MSK brokers
│   └── Data subnets (3 AZs)       — RDS, ElastiCache (no IGW route)
├── EKS cluster: fipas-prod (1.30)
│   ├── Node group: apps (m6i.xlarge, 3–30, spot+on-demand mix)
│   ├── Node group: data (r6i.2xlarge, 3, on-demand)
│   └── Node group: gateway-ws (c6i.2xlarge, 3–20, on-demand, sticky LB)
├── RDS PostgreSQL 16 (db.r6g.2xlarge, Multi-AZ, TimescaleDB)
│   └── 2x read replicas (1x sync, 1x async)
├── ElastiCache Redis 7 (cluster mode, 3 shards × 2 replicas)
├── MSK Kafka (3 brokers, kafka.m7g.large, in-cluster mTLS)
├── S3 buckets: fipas-backups, fipas-uploads, fipas-static
├── CloudFront + WAF + Shield
├── Secrets Manager + KMS (CMK per env)
├── Route53 zone: fipas.bihar.gov.in
└── CloudTrail + Config + GuardDuty

DR Region: ap-south-2 (Hyderabad)
├── Warm standby EKS (scaled to 0 for apps, 1 for data plane)
├── RDS cross-region read replica (async)
└── S3 cross-region replication for backups
```

## 3. Containerisation

Every service has a multi-stage `Dockerfile`:

```dockerfile
# services/readings-svc/Dockerfile
FROM node:20-alpine AS deps
WORKDIR /app
COPY pnpm-lock.yaml package.json ./
RUN corepack enable && pnpm install --frozen-lockfile --prod=false

FROM node:20-alpine AS build
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN pnpm build && pnpm prune --prod

FROM gcr.io/distroless/nodejs20-debian12 AS runtime
WORKDIR /app
USER 10001:10001
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./package.json
EXPOSE 3000
CMD ["dist/main.js"]
```

- **Distroless** runtime minimises CVE surface.
- **Non-root** UID; read-only root FS; `tmpfs` for `/tmp`.
- **Image signing:** cosign (sigstore) in CI, verified at admission via Kyverno.
- **SBOM:** CycloneDX generated and attached to the image; scanned by Trivy in CI.

Next.js `apps/web` uses `output: 'standalone'`:

```dockerfile
FROM node:20-alpine AS build
WORKDIR /app
COPY . .
RUN corepack enable && pnpm install --frozen-lockfile && pnpm --filter web build

FROM gcr.io/distroless/nodejs20-debian12
WORKDIR /app
USER 10001:10001
COPY --from=build /app/apps/web/.next/standalone ./
COPY --from=build /app/apps/web/.next/static ./apps/web/.next/static
COPY --from=build /app/apps/web/public ./apps/web/public
EXPOSE 3000
CMD ["apps/web/server.js"]
```

## 4. Kubernetes (EKS)

Helm chart template (`infra/helm/readings-svc/`):

```
deployment.yaml     — replicas, probes, resources, PodSecurity
service.yaml        — ClusterIP
hpa.yaml            — CPU + custom metric (p95 latency)
pdb.yaml            — minAvailable: 2
networkpolicy.yaml  — egress: pg, redis, kafka only
configmap.yaml      — non-secret config
externalsecret.yaml — pulls from AWS Secrets Manager via ESO
serviceaccount.yaml — IRSA for S3/Secrets Manager access
```

Sample Deployment excerpt:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata: { name: readings-svc }
spec:
  replicas: 5
  strategy:
    type: RollingUpdate
    rollingUpdate: { maxSurge: 25%, maxUnavailable: 0 }
  template:
    spec:
      automountServiceAccountToken: true
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        fsGroup: 10001
        seccompProfile: { type: RuntimeDefault }
      containers:
      - name: app
        image: ghcr.io/wrd-bihar/readings-svc:{{ .Values.image.tag }}
        resources:
          requests: { cpu: 250m, memory: 256Mi }
          limits:   { cpu: 1,    memory: 512Mi }
        readinessProbe: { httpGet: { path: /health/ready, port: 3000 } }
        livenessProbe:  { httpGet: { path: /health/live,  port: 3000 } }
        securityContext:
          readOnlyRootFilesystem: true
          allowPrivilegeEscalation: false
          capabilities: { drop: [ALL] }
```

### WebSocket gateway specifics
- Session affinity: `sessionAffinity: ClientIP` on the Service, and NLB with `proxy_protocol_v2`.
- Idle timeout on ALB: 3600 s; ping/pong 25 s.
- HPA on custom metric `websocket_connections_active`.

### Service mesh
- Istio (or Linkerd) for mTLS between pods, retries, circuit breakers, outlier detection.
- AuthorizationPolicies allow only declared service-to-service calls (zero-trust east-west).

### Ingress
- AWS ALB Ingress Controller for HTTP; separate NLB for WebSockets.
- TLS: ACM certificate for `*.fipas.bihar.gov.in`; TLS 1.3 only, HSTS 2 y preload-ready.

## 5. CI/CD

### 5.1 Pipeline stages (GitHub Actions)

```
PR opened
 └── lint, typecheck, unit tests, coverage gate (>= 85%)
 └── build docker image (cache)
 └── Trivy scan (fail on HIGH)
 └── SBOM, cosign sign, push to ghcr (PR tag)
 └── deploy preview env (ephemeral K8s namespace, TTL 48h)
 └── e2e (Playwright) + API contract (Pact) tests against preview

Merge to main
 └── same build
 └── push :main and :<sha> images
 └── deploy to staging
 └── run synthetic checks + k6 smoke

Tag v*.*.*
 └── manual approval (2 reviewers: SRE + Security)
 └── blue/green to prod (argo rollouts analysis)
 └── auto-rollback on SLO breach
 └── notify #fipas-ops + SEOC duty officer
```

### 5.2 Database migrations
- Run via a pre-deploy Kubernetes Job that uses a migration image.
- Strictly additive; destructive changes gated behind a 2-release deprecation window.
- Timescale hypertable DDL wrapped in advisory locks to avoid concurrent chunk creation conflicts.

### 5.3 Progressive delivery
- **Argo Rollouts** with canary (10% → 50% → 100%) driven by SLO analysis (P95 latency, error rate, freshness SLO).
- Automatic rollback if any metric breaches for > 2 min.
- **Feature flags** via Unleash for risky features (IoT ingestion, AI prediction).

## 6. Environments & promotion

| Env | Cluster | Data | Purpose |
|---|---|---|---|
| `preview-<pr>` | shared EKS, namespace | seeded | PR review |
| `staging` | shared EKS | anonymised prod snapshot (weekly) | integration |
| `uat` | dedicated namespace | prod snapshot (weekly) | WRD acceptance |
| `prod` | dedicated EKS | live | live |
| `dr` | standby EKS in ap-south-2 | async replica | failover |

Promotion is forward-only via tags; rollback is by redeploying the previous tag.

## 7. Configuration & secrets

- Non-secret config → ConfigMaps, sourced from `infra/k8s/<env>/values.yaml`.
- Secrets → AWS Secrets Manager + External Secrets Operator → K8s `Secret` objects.
- KMS CMK per environment; rotation every 180 days; envelope encryption for DB-stored sensitive fields (AES-256-GCM).
- No secret ever lives in git; pre-commit hook runs `gitleaks`.

## 8. Observability stack

- **Prometheus** (in-cluster) + **Amazon Managed Grafana**.
- **Loki** for logs (S3 backing).
- **Tempo** for traces; 10% sampling baseline, 100% on error.
- **Synthetic monitoring** (Grafana Synthetic Monitoring) hits `/`, `/display`, `/api/v1/public/districts` from 4 Indian PoPs every 60 s.
- **SLOs** modelled in Sloth; error budget dashboards visible to WRD leadership.
- **On-call:** PagerDuty → duty SRE → SEOC duty officer (SMS via Gupshup) for SEV-1.

## 9. Disaster recovery & BCP

| Scenario | Detection | Response | RTO | RPO |
|---|---|---|---|---|
| AZ outage | Multi-AZ auto-failover | automatic | ≤ 2 min | 0 |
| Region outage | PagerDuty + manual decision | Route53 failover to DR, promote replica | 15 min | ≤ 5 min |
| Data corruption | Checksums, anomaly alerts | PITR restore from pgBackRest | ≤ 60 min | ≤ 5 min |
| Ransomware / compromised K8s | GuardDuty, runtime alerts | Rotate secrets, re-deploy from golden AMIs, restore DB from immutable S3 backup | ≤ 4 h | ≤ 1 h |
| Flood at control room | N/A | Static CDN fallback HTML continues to serve read-only | 0 | last-good state |

DR drill every quarter with go/no-go signed off by WRD CIO.

## 10. Compliance & audits

- **MeitY e-Gov policy** — audit checklist tracked in `ops/compliance/meity.md`.
- **CERT-In directives (Apr 2022)** — 180-day log retention in India; achieved via S3 with Object Lock in `ap-south-1`.
- **NDSAP / data publishing** — public datasets published monthly to data.gov.in via automated job.
- **STQC / third-party audit** — annual VAPT; remediation SLAs coded into `CODEOWNERS` + security issue template.

## 11. Capacity plan

| Component | Baseline | Peak (flood season) | Scaling |
|---|---|---|---|
| `readings-svc` | 3 pods | 20 pods | HPA CPU/RPS |
| `gateway-svc` | 3 pods | 30 pods | HPA active WS connections |
| `ingest-svc` | 2 pods | 10 pods | HPA queue depth |
| CDN | N/A | 5 Tbps global | CloudFront |
| PG primary | r6g.2xlarge | r6g.8xlarge | vertical, pre-scheduled before monsoon |
| Redis | 3×r6g.large | 6×r6g.large | horizontal shard add |
| MSK | 3 brokers | 6 brokers | broker addition |

Annual pre-monsoon drill (June 1): full load test @ 5M concurrent WS + 10k rps public API using k6.

## 12. Example Helm values diff (prod vs staging)

```yaml
# infra/helm/readings-svc/values.prod.yaml
replicaCount: 5
autoscaling: { enabled: true, minReplicas: 5, maxReplicas: 20, targetCPUUtilizationPercentage: 60 }
resources:
  requests: { cpu: 500m, memory: 512Mi }
  limits:   { cpu: 2,    memory: 1Gi }
env:
  LOG_LEVEL: info
  REDIS_HOSTS: "fipas-redis-0001.xxxx.ng.0001.aps1.cache.amazonaws.com:6379,..."
```

```yaml
# infra/helm/readings-svc/values.staging.yaml
replicaCount: 2
autoscaling: { enabled: false }
resources:
  requests: { cpu: 200m, memory: 256Mi }
  limits:   { cpu: 1,    memory: 512Mi }
env:
  LOG_LEVEL: debug
```
