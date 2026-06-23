# DAIOS — Security Architecture

DAIOS is a **government-grade, citizen-trust-critical platform** whose decisions move people, vehicles, and authority. Security is not a sidecar; it is the substrate.

This document covers Zero-Trust posture, identity, encryption, supply chain, AI-specific threats, audit, and compliance.

## 1. Threat model (top-level)

| Threat | Surface | Top mitigations |
|---|---|---|
| Falsified hazard data | Ingestion APIs, sensor feeds, admin entry | mTLS partner ingest, anomaly detector, dual approval on threshold edits, signed audit |
| Manipulated AI output | LLM injection, RAG poisoning, model substitution | Prompt hardening, retrieval source allow-list, signed model artefacts, post-call safety checks |
| Compromised admin/officer account | Phishing, credential reuse, device theft | MFA + WebAuthn, device binding, step-up MFA, impossible-travel alerts |
| Ransomware / destructive actor | K8s, DB, S3 | Object-Lock backups, immutable audit, KMS rotation, isolated DR |
| Denial of service during disaster | Public + WS endpoints | CDN + WAF + Shield, autoscaling, static fallback, cell-broadcast as out-of-band |
| Insider abuse | Privileged operators | Least-privilege RBAC/ABAC, dual approval, append-only signed audit, segregation of duties |
| Supply-chain compromise | Dependencies, container images, models | SBOM, Trivy, Cosign, Kyverno admission, SLSA L3 build provenance |
| Cross-tenant data leak | Multi-tenant DB, control plane | RLS, tenant-scoped keys, control plane carries no PII, tenant-bound JWTs |
| AI misalignment in production | Decision agents | Tool gateway, scoped permissions, no auto-execute, reasoning trace, safety-svc post-call |

## 2. Zero-Trust architecture

DAIOS treats no network as trusted. Every request is authenticated, authorised, encrypted.

### 2.1 Identity is the perimeter
- **Workloads**: SPIFFE/SPIRE identities issued by Istio; mTLS east-west; policy by SVID.
- **Humans**: OIDC + MFA + WebAuthn; **device-bound** sessions; risk scored at every authentication.
- **Services-to-partner**: mTLS + OAuth2 client credentials; cert pinning; CRL/OCSP enforced.
- **Citizens**: device-bound JWT (Play Integrity / DeviceCheck attestation), OTP-anchored.

### 2.2 Continuous verification
- Tokens are short-lived (15 min access for officials) and rotating.
- Session re-evaluated on each request (policy-svc / OPA).
- Risk signals fed in: device posture, IP reputation, behavioural anomalies → **adaptive auth**.
- Step-up MFA required for sensitive mutations (authorise decision, raise broadcast, edit thresholds, manage users).

### 2.3 Microsegmentation
- Default-deny network policies in K8s.
- Egress allow-list per namespace; metadata service IMDSv2-only.
- Database access only via the service account that owns the schema; cross-schema access is mediated by service APIs.

## 3. Authentication & sessions

### 3.1 Citizens
- Phone-OTP first; passkey upgrade promoted on subsequent logins.
- Device JWT bound to attested device id + push-token.
- Lifetimes: access 1 h, refresh 30 d, rotating.
- Suspicious indicators (root/jailbreak, no attestation, fraud-signal IP) → SOS still works; non-SOS features degrade gracefully.

### 3.2 Officials
- OIDC SSO (tenant IdP) + MFA (TOTP min, WebAuthn preferred for `seoc_commander`, `tenant_admin`).
- Session cookies SameSite=Strict, Secure, HttpOnly; `__Host-` prefix.
- CSRF: double-submit cookie + `X-CSRF-Token`.
- Step-up MFA prompts (every 5 min during a Severe incident; every 4 h normally) for high-impact mutations.
- Concurrent-session cap configurable per tenant.

### 3.3 Partners
- mTLS with cert pinning + OAuth2 client credentials.
- Per-partner contracted scopes; signed contract artefact lives in tenant catalogue.
- Tokens 10 min; renewed by client cert + secret.

### 3.4 JWT specifics
- RS256, JWKS rotated every 90 d; signing keys in HSM (AWS CloudHSM / equivalent).
- Claims minimal; roles resolved server-side per request.
- JTI revocation list in Redis; "Sign out everywhere" bumps user version.

## 4. Authorisation — RBAC + ABAC via OPA

Centralised in `policy-svc` (OPA + Rego). Every privileged decision (API mutation, agent tool call, DB query under RLS) hits OPA.

### 4.1 Roles (illustrative)
- `global_admin` (DAIOS team) — ops, no tenant data
- `tenant_admin` — tenant-wide
- `seoc_commander` — authorise decisions, raise broadcasts
- `district_officer` — scoped to district(s)
- `department_lead` (police/health/water/...) — scoped per dept + region
- `data_entry` — scoped per station/sensor
- `auditor` — read-only across tenant
- `readonly` — partner observers

### 4.2 ABAC attributes
- `tenant_id`, `region_code`, `district_code`, `department`, `clearance`, `device_posture`, `time_of_day`, `incident_role`.
- Used in policies like:
  ```rego
  allow {
    input.action == "authoriseDecision"
    input.user.roles[_].code == "seoc_commander"
    input.user.tenant_id == input.resource.tenant_id
    input.user.mfa_age_seconds < 300
  }
  ```
- Policies versioned, tested (`opa test`), deployed signed.

### 4.3 Defence in depth (4 layers)
1. **API gateway**: path ACLs.
2. **Service guards**: NestJS/FastAPI per-route checks.
3. **OPA central decision**: business rules.
4. **DB RLS**: last-line guard against bug-induced cross-tenant queries.

### 4.4 Dual approval
Sensitive actions (threshold edit, user role change, broadcast template change, model promotion to prod) follow a **propose → second approver → commit** flow. Both actors audited.

## 5. Encryption

### 5.1 At rest
- RDS, S3, EBS, OpenSearch, ElastiCache, MSK — all KMS-encrypted with **per-tenant CMK**.
- **Citizen PII** further encrypted at the application layer via AES-256-GCM with per-tenant DEK (envelope + KMS-wrapped).
- **Search on encrypted PII** via blind index (HMAC-SHA256 + per-tenant secret).
- Backups in S3 with **Object Lock (compliance mode)**, 30 d minimum.
- KMS rotation: 90 d for service keys, 180 d for tenant CMKs (or per tenant policy).

### 5.2 In flight
- TLS 1.3; legacy 1.2 only behind explicit allow-list.
- HSTS preload-ready, OCSP stapling, CT monitoring.
- mTLS east-west via Istio; SPIFFE rotates every 24 h.
- Message-layer encryption optional for ultra-sensitive incidents (Signal-style sealed sender between department leads).

### 5.3 End-to-end (E2EE)
- **Family-circle** sharing in citizen app uses E2EE (libsignal). Server stores only sealed payloads.
- **Officer voice notes** between department leads can use E2EE; transcripts stay device-local unless explicitly shared.
- **SOS callbacks** between citizen and dispatcher use SRTP-encrypted media via the dispatch SBC; recording opt-in per tenant.

### 5.4 Key management
- Keys live in KMS / CloudHSM (FIPS 140-2 L3 where required by tenant).
- Keys never leave the HSM; envelope encryption everywhere.
- Per-tenant separation; cryptographic shredding (drop DEK) supports right-to-erasure.
- Audit of every key use; alarms on anomaly.

## 6. Web & app hardening

### 6.1 OWASP Top-10 mappings
| OWASP | Control |
|---|---|
| A01 Broken Access Control | RBAC+ABAC+OPA+RLS |
| A02 Cryptographic Failures | TLS 1.3, KMS, Argon2id, no JWT in localStorage |
| A03 Injection | Zod validators, Drizzle/Prisma parameterised queries, no `eval` |
| A04 Insecure Design | Threat model per feature, security review gate |
| A05 Misconfiguration | PodSecurity restricted, CIS-EKS benchmark, strict headers |
| A06 Vulnerable Components | Renovate, Trivy, SBOM gate, allow-listed registries |
| A07 Auth Failures | MFA, lockout, breach check, rotating tokens |
| A08 Integrity Failures | Cosign-signed images & models, Kyverno admission, signed audit chain |
| A09 Logging & Monitoring | Structured logs, Falco runtime, audit-chain integrity check, SIEM |
| A10 SSRF | Egress allow-list, IMDSv2 only, partner endpoints pinned |

### 6.2 HTTP headers (public + officer)
```
Strict-Transport-Security: max-age=63072000; includeSubDomains; preload
Content-Security-Policy: default-src 'self'; script-src 'self' 'nonce-{N}'; style-src 'self' 'nonce-{N}'; img-src 'self' data: <tile-host>; connect-src 'self' wss://<tenant>; frame-ancestors 'none'; base-uri 'self'; form-action 'self'
X-Content-Type-Options: nosniff
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(self), camera=(), microphone=(self)
Cross-Origin-Opener-Policy: same-origin
Cross-Origin-Embedder-Policy: require-corp
```

### 6.3 Mobile (citizen app)
- Cert pinning to tenant gateway.
- Code obfuscation; root/jailbreak detection (Play Integrity / DeviceCheck).
- Secure storage (Keystore / Keychain).
- Anti-screenshot on SOS PIN screen.

## 7. Supply-chain security

- **SBOM** (CycloneDX) per service; failed risk score blocks merge.
- **Image signing** with Cosign (Sigstore); Kyverno admission **rejects unsigned images**.
- **Build provenance** (SLSA Level 3): builds in hardened workers, attested via Sigstore Rekor.
- **Dependency policy**: only allow-listed registries (npm, PyPI mirrors curated); GitHub provenance required for actions.
- **Model artefacts** signed; loader verifies signature before serving.
- **Secret scanning** in pre-commit + CI; gitleaks + custom detectors; merge blocked on hits.

## 8. AI-specific security (`safety-svc`)

### 8.1 Prompt-injection defence
- Inputs from citizens/partners are **untrusted** by definition.
- Tagged context windows: agents receive untrusted input enclosed in canonical markers; ignore-instructions trained-in.
- Tool gateway never accepts agent-generated SQL or shell — only structured calls.

### 8.2 RAG hardening
- Sources signed; vector store entries carry provenance.
- Per-source trust score; agents cite or refuse on policy-bound topics.
- Retrieval results sanitised by `nlp-redactor` before reaching LLM.

### 8.3 Model integrity
- Models loaded only if Cosign signature valid and SHA matches MLflow registry.
- Promotion pipeline requires human approval.
- Inference container is read-only; model weights mounted from a verified volume.

### 8.4 Output safety
- `safety-svc` runs post-generation: hallucination grounding, jurisdictional language compliance, action-actionability.
- Below confidence threshold or above risk threshold → block with rationale + queue for human.

### 8.5 Adversarial testing
- Red-team drills quarterly with internal + external partners.
- Findings become regression tests; safety-svc rules updated.

## 9. WAF / DDoS readiness

- **WAF**: AWS WAF managed groups (Core, Bad Inputs, SQLi, XSS, Bot Control); custom rules for geo allow + rate-based.
- **Shield Advanced** during disaster seasons; pre-approved limit increases.
- **Origin protection**: SG accepts traffic only from CloudFront managed prefix list.
- **Rate limiting**: per-IP, per-user, per-API-key, per-route; 429 with `Retry-After`.
- **Circuit breakers** in service mesh for noisy partner endpoints.

## 10. Audit & forensics

- Append-only `platform.audit_events` hypertable per tenant.
- Each record HMAC-signed with per-tenant audit key; **hash-chained** by including `prev_signature` in HMAC input.
- Hourly verification job; chain break = SEV-1 + auto-freeze of mutations.
- Logs replicated to a separate AWS account `daios-logs-archive-<tenant>` with deny-delete SCP.
- Glacier Deep Archive after 1 year; immutable for 10 years.
- Officer / citizen access to one's own audit available via portal (DPDP / GDPR-style).

## 11. Privacy & data protection

### 11.1 Classification & handling
| Class | Examples | Storage |
|---|---|---|
| Public | Sensor readings, district summaries, public alerts | Open, NDSAP-publishable |
| Internal | Officer name/email, tasks | Application-layer encrypted, RLS |
| Sensitive | MFA secrets, password hashes | KMS+app-layer; never logged |
| Restricted | Citizen PII, SOS phone numbers, devices | Per-tenant DEK; field-level encryption; access audited |
| Crypto | Keys, audit signing keys | KMS/HSM only |

### 11.2 Data minimisation
- Citizen onboarding asks only what's needed (phone, language, channel preference).
- No Aadhaar / national-ID full numbers stored.
- Coarse home location (geohash 8 chars) only at rest; precise location used only at SOS/report time and aged out.
- IPs salt-hashed before persistence on public APIs.

### 11.3 Citizen rights (DPDP / GDPR-style)
- Self-service data download, deletion, consent management in citizen app.
- Erasure via cryptographic shredding (drop DEK) — verifiable to user.
- Consent versioned; new templates require fresh consent.
- Tenant-specific DPO contact published in privacy notice.

### 11.4 Cross-tenant isolation
- Tenant ID on every row; RLS enforced.
- Tenant-bound encryption keys.
- Control plane never holds citizen PII; exchange is via signed config + anon metrics only.

## 12. Compliance mapping

| Requirement | Control |
|---|---|
| **CERT-In Apr 2022** (180-day logs in IN) | S3 Object Lock + region binding |
| **DPDP Act (India)** | Consent mgmt, data principal rights, breach notification SLA |
| **MeitY Empanelled Cloud / NIC MeghRaj** | Tenant-level deployment options |
| **GDPR (EU tenants)** | Lawful basis, DPO, DPIAs, SCCs (when applicable) |
| **ISO 27001** | Controls matrix `ops/compliance/iso27001-matrix.xlsx` |
| **ISO 22301 (BCP)** | DR plan, drill cadence, RTO/RPO |
| **NIST 800-53 / 800-171** | Mapped for US gov / partner tenants |
| **WCAG 2.2 AA / AAA** | UI gate in CI |
| **SOC 2 Type II** | Annual audit (DAIOS-as-a-service tenants) |

## 13. Incident response

- **Detection**: GuardDuty, CloudTrail Lake, Falco runtime, audit-chain integrity, WAF anomalies, ML-drift alarms.
- **Severity**: SEV-1 (citizen-impacting OR data integrity OR privacy breach) → duty SRE + tenant CISO + DAIOS CISO.
- **Playbooks**: in `ops/runbooks/security/*.md`.
- **Comms**: status page (separate AWS account), tenant SEOC notifications, regulator notification within mandated window.
- **Post-mortem**: blameless review in 5 working days; CAPAs tracked to closure with owners.

## 14. Vulnerability management

- Daily image + dep scans; HIGH+ 24 h SLA, CRITICAL same-day.
- Monthly patch cycle; emergency patches out-of-band.
- Annual external VAPT (STQC empanelled in IN; equivalent abroad).
- **Bug bounty / responsible disclosure**: `security@daios.global`; PGP key at `/.well-known/security.txt`.
- "Hall of fame" + monetary rewards (per tenant policy).

## 15. Hard policy commitments

These are encoded as guardrails in code (not just policy docs):

1. **AI never auto-executes citizen-facing actions.** All public broadcasts require human authorisation with MFA.
2. **Citizen PII never leaves the sovereign plane** without explicit, audited, per-record consent.
3. **No model is trained on raw citizen content** without explicit consent and PII redaction.
4. **No AI is used to triage individual citizens for help.** Routing/classification only.
5. **Audit chain integrity is a non-negotiable invariant.** A break is SEV-1 and freezes mutations.
6. **No backdoor accounts.** Break-glass accounts are time-limited, dual-controlled, audited.
7. **Drill mode is impossible to confuse with live mode** at the UI layer (persistent banner) and the alert layer (tagged channels).

## 16. Security in SDLC

- PR template: threat considered, validators, audit, tests, docs.
- `CODEOWNERS`: security team gates `/auth`, `/iam`, `/policy`, `/safety`, `.github/workflows/`, `infra/`.
- Mandatory checks: unit, e2e, ZAP, Trivy, gitleaks, license, ML eval, OPA conftest.
- Annual secure-coding training; phishing sims quarterly for tenant operators.
- Threat-model walkthroughs each major release.
