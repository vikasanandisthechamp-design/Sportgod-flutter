# DAIOS — Deployment & Scaling Strategy

DAIOS is built to deploy to **multiple countries** simultaneously, each with its own data-sovereignty regime, while sharing a single global control plane for schemas, models, and learning.

## 1. Cloud strategy

| Tier | Cloud | Purpose |
|---|---|---|
| **Global control plane** | One sovereign-friendly cloud (default: AWS, Mumbai primary; Frankfurt warm DR for non-IN tenants) | Schema, model registry, drill orchestrator, telemetry lake |
| **Per-tenant sovereign plane** | Tenant-chosen cloud (AWS / NIC MeghRaj / Azure Gov / GCP Sovereign / on-prem) | All citizen data + inference |

DAIOS is **cloud-agnostic** by construction: every dependency is either open-source or has been abstracted behind an interface (`storage`, `kv`, `queue`, `gpu-inference`). A new tenant cloud onboards by writing 3–5 adapter implementations.

## 2. Topology — sovereign plane (illustrative: India)

```
Region: ap-south-1 (Mumbai) — primary
Region: ap-south-2 (Hyderabad) — active-active
Region: NIC MeghRaj DC (optional, on-prem failover)

Per region:
├── VPC 10.20.0.0/16
│   ├── Public subnets (3 AZ)   — ALB, NLB, NAT, bastion (SSM only)
│   ├── Private subnets (3 AZ)  — EKS apps, MSK
│   ├── Data subnets (3 AZ)     — RDS, ElastiCache, OpenSearch, Neo4j
│   └── GPU subnets (2 AZ)      — Inference / training
├── EKS cluster (1.30+)
│   ├── ng-apps        (m6i.xlarge, 6–60, mix on-demand+spot)
│   ├── ng-data        (r6i.2xlarge, 3, on-demand)
│   ├── ng-ws          (c6i.2xlarge, 6–40, on-demand, sticky NLB)
│   ├── ng-gpu-inf     (g6.4xlarge, 2–12, on-demand)
│   └── ng-gpu-train   (p5.48xlarge, 0–4, spot, scheduled)
├── RDS PG 16 + Timescale + PostGIS  (db.r6g.4xlarge Multi-AZ + 2 read replicas)
├── ElastiCache Redis 7  (cluster mode, 3×r6g.xlarge × 2 replicas)
├── MSK Kafka            (3 brokers, kafka.m7g.large, mTLS)
├── OpenSearch           (3 master + 6 data, gp3, encrypted)
├── Neo4j AuraDS         (or self-managed StatefulSet on EKS)
├── S3 buckets:
│    ├── fipas-uploads (citizen reports, scanned)
│    ├── fipas-tiles (COG/MVT)
│    ├── fipas-models (signed)
│    ├── fipas-traces (agent runs)
│    └── fipas-backups (Object Lock, compliance mode)
├── CloudFront + WAF + Shield Advanced (Jun–Oct enabled)
├── KMS (per-env CMK), Secrets Manager
└── CloudTrail + GuardDuty + Config + AWS Inspector
```

Active-active across two regions inside the same sovereign jurisdiction. Cross-region replication for S3 (within country), RDS read replica (within country).

## 3. Containerisation

- Multi-stage Dockerfiles, **distroless** runtime, non-root UID `10001`, read-only root FS, `tmpfs` for `/tmp`.
- Cosign-signed images, Sigstore Rekor transparency log.
- SBOM (CycloneDX) attached; Trivy scan gates merge.
- Base images rebuilt weekly; Renovate auto-PRs.
- `Dockerfile` lint via Hadolint in CI.

## 4. Kubernetes

- Helm chart per service (`infra/helm/<svc>/`), umbrella chart `infra/helm/daios/`.
- **Service mesh**: Istio with mTLS strict; SPIFFE identities; AuthorizationPolicies deny-by-default.
- **Ingress**: ALB Ingress Controller for HTTP; NLB for WebSocket (sticky session); separate NLB for partner mTLS.
- **PodSecurity** restricted (no privileged, no host network).
- **Network policies**: explicit allow for each service's egress (PG, Redis, Kafka, KMS, partner endpoints).
- **Quotas & PDBs** on every workload; HPAs use both CPU and custom metrics (Kafka lag, queue depth, WS connections).
- **Cluster autoscaler** + Karpenter for node-level efficiency.

## 5. CI/CD

### 5.1 Pipelines (GitHub Actions / Argo CD)

```
PR opened
 ├── lint, type-check, unit, coverage gate (≥ 85%)
 ├── build image (cache), Trivy scan, SBOM, Cosign sign, push to GHCR
 ├── Helm template + kubeval + Conftest (OPA) on manifests
 ├── deploy to ephemeral preview namespace (TTL 48h)
 ├── e2e (Playwright + Pact contract) against preview
 └── ZAP baseline scan

Merge to main
 ├── push :sha + :main
 ├── deploy to staging (ArgoCD)
 ├── synthetic checks + k6 smoke
 └── ML-eval gate (no model perf regression)

Tag v*.*.*
 ├── manual approvals (SRE + Security + Tenant Lead)
 ├── per-tenant promotion: argo-rollouts canary 10% → 50% → 100%
 ├── analysis template: SLO breach → auto rollback
 └── notify SEOCs & on-call
```

### 5.2 Database migrations
- Run as pre-deploy K8s Job; advisory-lock-protected for Timescale chunk safety.
- Strictly additive; destructive deferred 2 releases.
- Migration approval gate for any schema affecting `citizen.*` or `audit.*`.

### 5.3 Configuration
- Non-secret config: ConfigMaps from `infra/k8s/<env>/values.yaml`.
- Secrets: AWS Secrets Manager / HashiCorp Vault → External Secrets Operator → tmpfs `Secret`.
- Tenant feature flags: `tenant-svc` → ConfigMap reload via signed bundle (cosign-verified).

### 5.4 Progressive delivery
- **Argo Rollouts** with analysis on:
  - HTTP error rate
  - SLO freshness (alert latency, decision latency)
  - ML eval drift (for ML-touching services)
  - Synthetic alert end-to-end success
- Auto-rollback if any breaches for > 2 min.

## 6. Tenant onboarding

1. Tenant lead signs MSA; data-residency selected.
2. Region cluster created via Terraform (`infra/terraform/tenant/<code>`).
3. Tenant entry added to control plane via signed proposal (4-eyes approval).
4. Hazards & channels enabled; templates seeded.
5. Identity federation set up (tenant IdP ↔ federation-svc).
6. Drill mode runs ≥ 5 historical scenarios to certify.
7. Go-live: traffic enabled progressively (10% → 50% → 100% over 30 days).

## 7. Disaster recovery & BCP

| Scenario | Detection | Response | RTO | RPO |
|---|---|---|---|---|
| AZ outage | EKS reschedules, RDS Multi-AZ failover | automatic | ≤ 90 s | 0 |
| Region outage | Health checks fail; PagerDuty; manual go/no-go | Route 53 failover; promote replica | ≤ 5 min | ≤ 1 min |
| Cloud provider outage | Cross-cloud cold standby (per-tenant config) | manual cutover | ≤ 60 min | ≤ 15 min |
| Data corruption | checksums, anomaly alarms | PITR restore | ≤ 30 min | ≤ 5 min |
| Compromise | GuardDuty / Falco / audit-chain break | rotate KMS, redeploy from golden, restore | ≤ 4 h | ≤ 1 h |
| Submarine cable cut | telemetry gap detected | sovereign plane runs autonomous; control-plane drift acceptable 24 h | 0 user-visible | n/a |

DR drill quarterly per tenant. Result signed off by tenant CISO + DAIOS SRE Lead.

## 8. Observability

- **Metrics**: Prometheus (in-cluster) + Amazon Managed Grafana / Grafana Cloud Sovereign (EU).
- **Logs**: Loki + cold to S3 with Object Lock.
- **Traces**: Tempo, 10% baseline, 100% on error.
- **ML obs**: Arize / Phoenix; data + prediction drift; per-model SLOs.
- **Synthetic**: Grafana SM hits public + citizen endpoints from 4 in-country PoPs every 60 s.
- **War-room dashboard**: single screen for SEV-1.

## 9. Capacity plan

| Component | Baseline | Peak | Strategy |
|---|---|---|---|
| `gw-public-api` | 6 | 60 | HPA on RPS; CDN absorbs 80%+ |
| `gw-ws` | 10 | 80 | HPA on connections; sticky NLB |
| `flood-kernel-svc` | 3 | 16 | HPA on Kafka lag |
| `cyclone-track-svc` (GPU) | 2 nodes | 8 nodes | scheduled pre-monsoon scale-up |
| `decision-svc` | 4 | 24 | HPA on agent runs |
| `agent-runtime-svc` | 4 | 32 | concurrent runs |
| `model-serving-svc` | 4 GPU | 12 GPU | inference queue |
| RDS primary | r6g.4xlarge | r6g.8xlarge | vertical pre-monsoon |
| Redis | 3 shards | 6 shards | horizontal add |
| Kafka | 3 brokers | 6 brokers | broker addition |

Pre-monsoon drill (Jun 1) loads 5M concurrent WS + 5k rps public reads.

## 10. Cost management

- Per-tenant cost dashboard via OpenCost; alerts at 70/90/110% of monthly budget.
- Spot-on for stateless apps (tolerated by graceful drain).
- Inference scheduling: low-priority workloads (training, postmortems) run on spot GPU.
- COGs cached on S3 — reduces compute for tile serving.
- LLM token budgets enforced per incident in `decision-svc`.

## 11. Compliance & auditability

| Requirement | Control |
|---|---|
| Data residency (IN, IT, JP, …) | Tenant region binding; egress allow-list |
| Logs in-country (CERT-In 180 days) | S3 Object Lock, in-country bucket |
| Encryption everywhere | TLS 1.3 in flight; KMS at rest; FIPS-validated where required |
| Procurement (GeM in IN) | Catalogue listing; contract pack-up automated |
| Annual VAPT (STQC / equivalent) | Findings tracked with SLAs |
| Tenant audit reports | Per-tenant audit export, signed, time-bounded |

## 12. Tools landscape

| Concern | Tool |
|---|---|
| IaC | Terraform + Terragrunt |
| K8s manifests | Helm + Kustomize |
| GitOps | Argo CD (per env) |
| Secrets | AWS SM / Vault + ESO |
| Service mesh | Istio |
| Mesh observability | Kiali + Prometheus |
| Logs | Loki |
| Traces | Tempo |
| Metrics | Prometheus + Mimir |
| Dashboards | Grafana |
| ML pipelines | Argo Workflows / Kubeflow |
| Model registry | MLflow + Cosign |
| Feature store | Feast |
| Inference | NVIDIA Triton |
| Vector DB | pgvector + OpenSearch knn |
| Event bus | Kafka (MSK / Confluent Sovereign) |
| Map tiles | pg_tileserv / TiTiler |
| CDN | CloudFront / NIC edge |
| WAF | AWS WAF / ModSecurity CRS |
| DDoS | Shield / Cloudflare Magic |

## 13. Environments

| Env | Purpose | Data |
|---|---|---|
| `preview-pr-N` | per-PR ephemeral | seeded |
| `staging` | integration | anonymised snapshot |
| `uat` | tenant acceptance | snapshot |
| `prod-<tenant>` | live | live |
| `dr-<tenant>` | warm standby | async |
| `shadow-<tenant>` | drill / replay sandbox | replays |

## 14. Day-2 operations

- **Runbooks** in `ops/runbooks/<scenario>.md`, linked from alerts.
- **Game days** monthly: simulate kernel failure, IdP outage, GPU saturation.
- **Tenant SRE liaison**: each tenant has a named DAIOS SRE for major events.
- **Pre-monsoon hardening week**: scale tests, dependency review, comms drill, helpline rehearsal.
- **Post-event**: SEV review within 5 working days; corrective actions tracked to closure with owners.
