# FIPAS — Security Architecture

FIPAS is a **government-of-record** platform whose data feeds real-world evacuation decisions. Security objectives are: integrity of readings (no tampering), authenticity (provable source), availability during floods, and confidentiality of operator PII.

This document maps every requirement in the brief to a concrete control and reflects MeitY, CERT-In (Apr 2022), and NIC hardening guidance.

## 1. Threat model (summary)

| Threat | Attack surface | Mitigation |
|---|---|---|
| Falsified water levels | Admin login, ingestion API | MFA, RBAC, dual approval on thresholds, signed audit log, anomaly detector on outlier readings |
| Denial of service during flood | Public URLs, WS | CloudFront + WAF + Shield, autoscaling, static CDN fallback |
| SQL injection / XSS / CSRF | All inputs | Parameterised queries (Drizzle/pg), Zod validation, CSP, SameSite cookies + CSRF token |
| Credential theft | Admin UI, phishing | Short-lived JWT + rotating refresh, MFA (TOTP + optional FIDO2), device fingerprinting, SEOC alert on impossible-travel |
| Insider abuse | District officers | RBAC scoping, least privilege, append-only signed audit, segregation of duties for threshold edits |
| Data exfiltration | DB, backups | Encryption at rest (KMS), private subnets, VPC endpoints, S3 Object Lock, DLP on admin exports |
| Supply-chain compromise | Dependencies, images | SBOM, Trivy, cosign signing, Kyverno admission, Renovate bot, Dependabot |
| Network interception | Edge, east-west | TLS 1.3, HSTS, mTLS between services |
| Abuse of public API | Public endpoints | Rate limit, WAF bot control, anonymity preserved (no PII logged) |

## 2. Transport security

- **TLS 1.3 only**, 1.2 allowed for legacy partner APIs with explicit allow-listing.
- Ciphers: `TLS_AES_128_GCM_SHA256`, `TLS_AES_256_GCM_SHA384`, `TLS_CHACHA20_POLY1305_SHA256`.
- **HSTS** `max-age=63072000; includeSubDomains; preload`; domain submitted to preload list.
- **OCSP stapling** enabled; cert transparency monitored.
- **mTLS** for service-to-service (Istio auto-rotated every 24 h) and for IMD/CWC ingestion (client cert CN allow-list).
- Key material stored in **AWS KMS / CloudHSM** (FIPS 140-2 L3).

## 3. Authentication & session

- **Admin users**
  - Password: Argon2id (`t=3, m=64MB, p=4`), min 12 chars + policy (NIST 800-63B), breached-password check against HIBP k-anon.
  - **MFA mandatory** — TOTP (RFC 6238) for all, hardware FIDO2 for `state_admin`.
  - Account lock after 5 failed attempts, 15 min cooldown; SEOC notification after 3 lockouts/hour/account.
  - Password reset via signed URL (15 min TTL), step-up MFA required.
- **JWT**
  - RS256, 15 min access token, 7 day rotating refresh.
  - Claims minimal; roles resolved server-side per request against cached role table.
  - JWKS with 90 day key rotation; overlap window allows zero-downtime rotation.
- **CSRF**
  - Admin uses **double-submit cookie** (`fipas_csrf`) + `X-CSRF-Token` header on mutating requests.
  - SameSite=`Strict` on auth cookies; `Secure`, `HttpOnly`.
- **Session revocation** — JTI block-list in Redis (TTL = token exp); admin "Sign out everywhere" flips versioning bump in user record.
- **Public users** — anonymous, no cookies set on public pages (consent-free analytics only).

## 4. Authorization (RBAC)

Roles:

| Role | Scope | Capabilities |
|---|---|---|
| `state_admin` | state | Full master-data CRUD, user mgmt, threshold changes (with dual approval), DR drills |
| `district_officer` | district | View/edit readings for their district(s); cannot modify station thresholds |
| `data_entry` | station(s) | Insert readings, view own; no edit of past readings beyond ±5 min |
| `auditor` | state | Read-only audit log and analytics, no data mutation |
| `readonly` | state | Internal dashboards for partners (IMD, NDRF liaison) |

Enforcement layers (defence in depth):
1. **API gateway**: path ACLs by role claim.
2. **NestJS `RolesGuard`** per route, backed by `@Roles()` + `@Scope()` decorators.
3. **PostgreSQL RLS** — policies gate writes by `app.user_id` and `app.role` settings (see database-schema §8).
4. **Frontend** — `RoleGuard` hides UI; never relied on for security, only UX.

Sensitive operations (threshold change, user role assignment, deletion) require **dual approval**: initiator creates a pending change, a second approver with equal or higher role commits it. Both parties are audited.

## 5. Encryption at rest

- **RDS storage** — encrypted with KMS CMK (`aws:kms`), automatic snapshot encryption.
- **S3** — SSE-KMS with per-bucket CMK; `fipas-backups` has **S3 Object Lock** (compliance mode, 30-day min retention) for ransomware resilience.
- **EBS** volumes — encrypted.
- **Sensitive fields in DB** (full name, Aadhaar last 4, MFA secret, phone for alerts) use **application-layer AES-256-GCM** envelope encryption: DEK wrapped by KMS CMK, DEK rotated per tenant quarterly. Columns stored as `bytea` with a small header `{kid, iv, aad-ref}`.
- **Field-level search** on encrypted fields uses blind index (HMAC-SHA256 of normalised value + per-tenant secret).

## 6. Input validation & web-app hardening (OWASP Top-10)

| OWASP | Control |
|---|---|
| A01 Broken Access Control | RolesGuard, RLS, server-authoritative checks |
| A02 Cryptographic Failures | TLS 1.3 only, KMS, Argon2id, no JWT in localStorage |
| A03 Injection | Zod validators on every DTO; Drizzle/pg parameterised queries; no `eval`; ESLint `no-unsafe-*` |
| A04 Insecure Design | Threat model per feature, security design review gate in PR template |
| A05 Security Misconfiguration | PodSecurity restricted, CIS-EKS benchmark, `nosniff`, `X-Frame-Options: DENY`, strict CSP |
| A06 Vulnerable Components | Renovate + Dependabot + Trivy gate on HIGH |
| A07 Auth Failures | MFA, lockout, breach check, rotating tokens |
| A08 Software & Data Integrity | cosign-signed images, Kyverno admission, signed audit log |
| A09 Logging & Monitoring | Structured logs, immutable audit hypertable, alerting runbooks |
| A10 SSRF | Outbound allow-list (IMD/CWC/S3/KMS); metadata service `IMDSv2` only |

**Content Security Policy** (public pages):

```
default-src 'self';
script-src 'self' 'nonce-{{nonce}}';
style-src  'self' 'nonce-{{nonce}}';
img-src    'self' data: https://tiles.fipas.bihar.gov.in;
font-src   'self';
connect-src 'self' wss://fipas.bihar.gov.in;
frame-ancestors 'none';
base-uri 'self';
form-action 'self';
report-uri /csp-report;
```

Additional headers: `Referrer-Policy: strict-origin-when-cross-origin`, `Permissions-Policy: geolocation=(), camera=(), microphone=()`, `Cross-Origin-Opener-Policy: same-origin`, `Cross-Origin-Embedder-Policy: require-corp` (admin only).

## 7. WAF & DDoS readiness

- **AWS WAF managed rule groups:** Core Rule Set, Known Bad Inputs, SQLi, XSS, Linux, Bot Control (flood season).
- **Custom rules:** geo allow (India + SAARC neighbours for OCI diaspora); rate-based 2000 req / 5 min / IP; challenge on anomalous user agents.
- **AWS Shield Standard** always on; **Shield Advanced** enabled June–October annually.
- **Origin protection:** origin ALB accepts traffic only from CloudFront managed prefix list; direct access blocked by SG.
- **Quotas:** pre-approved service limit increases before monsoon (CloudFront requests, WAF WCU, RDS connections).

## 8. Audit & forensics

- Every mutating API action, login, role change, config read of sensitive values, and data export is written to `audit.events`.
- Records are **HMAC-SHA256 signed** with a per-service key (rotated monthly) covering a canonicalised JSON of the record — chain-signed by including the previous record's signature in the HMAC input to form a **tamper-evident hash chain**.
- Verification job runs hourly; break detected → SEV-1 page + immediate freeze of mutations.
- Logs shipped to a separate AWS account (`fipas-logs-archive`) with deny-delete SCP and 7-year lifecycle to Glacier Deep Archive.

## 9. Privacy & data classification

| Class | Examples | Handling |
|---|---|---|
| Public | Station readings, district summaries | Published freely, NDSAP open |
| Internal | Operator full name, email | AES-GCM encrypted at app layer, access audited |
| Confidential | MFA secret, password hash, Aadhaar last 4 | AES-GCM + access-only-via-service, never logged |
| Restricted | Cryptographic keys, DB creds | KMS/HSM, never in env files |

- **PII minimisation:** only name, phone, email captured; no Aadhaar full numbers, no citizen PII (platform is consumer-anonymous on public side).
- **Right to access/erasure:** admin UI allows auditor to export or delete an operator on verified request; DB uses cryptographic shredding (rotate & drop DEK) for erasure.
- **Analytics:** server-side only, no third-party trackers; IP addresses salt-hashed before storage.

## 10. Secret management

- **AWS Secrets Manager** per-env; rotation lambdas for DB creds (30 d), API keys (90 d).
- **External Secrets Operator** syncs to K8s `Secret` objects mounted as tmpfs, never projected to env of init containers.
- **Pre-commit:** `gitleaks`, `detect-secrets`; CI blocks on any match.
- **Dev**: `.env.example` only in repo; real values pulled from `aws secretsmanager get-secret-value` via Makefile target.

## 11. Network security

- **Private subnets** for all compute and data; public only for ALB/NLB/NAT.
- **Security groups** default-deny; least privilege; reviewed by IaC lint (tfsec / checkov).
- **VPC endpoints** (gateway + interface) for S3, DynamoDB, Secrets Manager, KMS, STS — no NAT traffic for AWS API calls.
- **Egress** via NAT with domain allow-list (IMD/CWC URLs, Gupshup, cosign/sigstore for image verification).
- **Bastion:** SSM Session Manager only (no inbound SSH), session recording enabled.

## 12. Vulnerability management

- Daily image scan (Trivy) against the registry; critical vulns page on-call within 24 h.
- Monthly patch Tuesday: base images, K8s node AMIs, Helm charts.
- **Annual VAPT** by STQC / CERT-In empanelled firm; findings tracked in dedicated Jira project with SLAs (Critical 7 d, High 30 d).
- **Bug bounty / responsible disclosure** — `security@wrd.bihar.gov.in`, PGP key published at `/.well-known/security.txt`.

## 13. Incident response

- **Detection:** GuardDuty, CloudTrail Lake queries, CSP report endpoint, WAF anomaly alarms, Falco for runtime, audit-chain break detector.
- **Playbooks** in `ops/runbooks/`: `auth-compromise.md`, `ddos.md`, `data-tamper.md`, `ransomware.md`, `key-rotation.md`, `region-failover.md`.
- **Severity matrix:** SEV-1 (public dashboard down OR data integrity at risk) pages duty SRE + WRD CISO + SEOC officer.
- **Communication:** status page at `status.fipas.bihar.gov.in` (static, hosted in separate AWS account).
- **Post-incident:** blameless review within 5 working days; action items tracked to closure.

## 14. Compliance mapping

| Requirement | Control |
|---|---|
| MeitY Gazette 2018 — data residency | All data & backups in India (ap-south-1 / ap-south-2) |
| CERT-In Apr 2022 — 180 d logs | S3 Object Lock retention policy |
| NDSAP 2012 — open data | Monthly automated publish to data.gov.in |
| ISO 27001 controls | Mapped in `ops/compliance/iso27001-matrix.xlsx` |
| WCAG 2.2 AA | Enforced in CI via axe-core; quarterly manual audit by NIC |

## 15. Security in SDLC

- Mandatory PR checklist: threat considered, validators added, audit written, tests updated, docs updated.
- `CODEOWNERS`: security team reviews any change touching `/auth`, `/iam`, `/audit`, `/security`, `.github/workflows/`.
- Pre-merge checks: unit tests, e2e, ZAP baseline against preview, trivy, secret scan, license check.
- Training: annual secure-coding refresher; phishing simulations quarterly for WRD staff with admin access.

---

### Appendix A — Sample NestJS guards wiring

```ts
// common/decorators/roles.decorator.ts
export const Roles = (...roles: RoleCode[]) => SetMetadata('roles', roles);
export const Scope = (scope: 'state'|'district'|'station') => SetMetadata('scope', scope);

// readings.controller.ts
@Post()
@UseGuards(JwtAuthGuard, RolesGuard, CsrfGuard, AuditInterceptor)
@Roles('state_admin','district_officer','data_entry')
@Scope('station')
@AuditAction('reading.create')
createReading(@Body() dto: CreateReadingDto, @CurrentUser() user: UserCtx) { ... }
```

### Appendix B — Sample audit signing (pseudocode)

```ts
const canonical = canonicalJson({
  occurred_at, actor_id, actor_role, action, entity_type, entity_id,
  before, after, request_id, prev_sig,
});
const signature = hmacSha256(auditKey, canonical);
await db.insert(audit.events).values({ ...record, signature });
```
