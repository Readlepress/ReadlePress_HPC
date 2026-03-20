# ReadlePress — Production Readiness Matrix

Brutally honest status of each layer against the Master Blueprint.

**Status definitions:**
- **PRODUCTION-READY**: Schema complete, triggers enforced, RLS verified, endpoints tested, failure traps covered
- **SUBSTANTIALLY IMPLEMENTED**: Schema exists with correct structure, key constraints present, endpoints working, needs hardening
- **SCAFFOLD**: Tables and routes exist, business logic is thin or stub-level, not tested end-to-end
- **CONCEPT**: Route registered, service returns placeholder data, needs real implementation

---

## Core Production Spine (must be hardened first)

| Layer | Name | Status | What's Done | What's Missing |
|-------|------|--------|-------------|----------------|
| L1 | Platform Foundation | **SUBSTANTIALLY IMPLEMENTED** | 12+ tables, RLS on all, audit hash chain, append-only rules, role assignments, consent records, sessions, token invalidation queue, soft-delete log | Parameterized session context (FIXED), JWT secret enforcement (FIXED), request_log 90-day purge, cross-tenant CI test suite |
| L2 | Government Identity | **SUBSTANTIALLY IMPLEMENTED** | Schools, students, teachers, parents, enrolments, dedup fields, APAAR tracking, transfer records | Identity change log not populated by triggers, dedup workflow endpoints thin, HPC Part-A identity endpoint needs field coverage audit |
| L3 | Academic Year | **SUBSTANTIALLY IMPLEMENTED** | State machine trigger (one-way), year snapshots, Merkle tree, completeness checks, terms | Rollover jobs execute endpoint is stub, student promotion decisions not wired to enrolment lifecycle |
| L4 | Taxonomy Spine | **SUBSTANTIALLY IMPLEMENTED** | Competencies with UID immutability trigger, lineage, activations, descriptor levels, bridge mappings, frameworks table | Change proposal workflow is scaffold, taxonomy versioning exclusion constraint not implemented |
| L5 | Localization | **SUBSTANTIALLY IMPLEMENTED** | 23 languages seeded, OFFICIAL_LOCKED immutability, locale format rules, SMS templates | Fallback chain logging not active, namespace-based key organization not enforced, bulk-resolve endpoint thin |
| L6 | Evidence Ledger | **SUBSTANTIALLY IMPLEMENTED** | Evidence records with EXIF fields, custody chain (append-only, hash-chained), access log, redaction requests, trust hierarchy | EXIF pipeline runs via pg-boss but not battle-tested, evidence tagging tables exist but not populated by upload flow |
| L7 | Capture UX | **SUBSTANTIALLY IMPLEMENTED** | Mastery event drafts, sync with idempotency, conflict detection, bi-temporal timestamps, GPS confidence | Draft promotion endpoint exists but thin, offline queue entries table exists but not integrated with Flutter sync service |
| L8 | Rubric Engine | **SUBSTANTIALLY IMPLEMENTED** | Templates, dimensions, completion records, inter-rater divergence, amendment log (append-only), no-naked-scoring constraint | Group assessment fan-out logic is thin, descriptor sets not fully wired to templates |
| L9 | Mastery Aggregation | **SUBSTANTIALLY IMPLEMENTED** | Partitioned mastery_events, EWM computation function, idempotent job queue, aggregates, growth curves, stage readiness | Domain aggregates and class aggregates tables exist but not computed by jobs, outlier flags not generated |
| L10 | 360 Feedback | **SUBSTANTIALLY IMPLEMENTED** | Prompt sets, requests, responses, peer aggregates with k-anonymity, moderation queue, self-assessment links | Moderation SLA job runs but not E2E tested, response rate computation thin |
| L11 | Interventions | **SUBSTANTIALLY IMPLEMENTED** | Trigger rules, alerts, plans with sensitivity RLS (WELFARE/SAFEGUARDING blocked for CLASS_TEACHER), outcome evidence, welfare access log | Trigger rule engine evaluates basic rules but not battle-tested, plan lifecycle management thin |
| L12 | Inclusion/UDID | **SUBSTANTIALLY IMPLEMENTED** | Disability profiles with AES-256-GCM encryption, overlays with self-approval prevention, credit overlay links, expiry notifications | IEP fields exist but workflow not implemented, overlay renewal flow is stub |

## Phase C — Credentialing (needs deepening)

| Layer | Name | Status | What's Done | What's Missing |
|-------|------|--------|-------------|----------------|
| L13 | Credit Engine | **SCAFFOLD** | 11 tables with correct structure, policy version pinning trigger, computation jobs, external claims | Evidence triangle enforcement is schema-only (no API-level gate), domain cap computation not implemented in job worker, overlay-aware threshold lookup not wired |
| L14 | Export Engine | **SCAFFOLD** | Templates, jobs, document records, signing keys, authorizations, bulk archives | Snapshot integrity gate not implemented in export flow, stage-specific template rendering delegated to PDF service, bulk concurrency control not implemented |

## Governance & Scale (scaffolded, not hardened)

| Layer | Name | Status | What's Done | What's Missing |
|-------|------|--------|-------------|----------------|
| L15 | Audit & Override | **SCAFFOLD** | Override requests with dual approval, application log, permission snapshots, governance alerts with 100-char resolution | entity_version_hash staleness check not implemented, permission snapshot auto-capture triggers not created, nightly chain verification wired via pg_cron but not tested against real data |
| L16 | AI Layer | **SCAFFOLD** | Provider registry, prompt templates, generation log (hash-chained, append-only), draft contents with ai_assisted immutability, bias monitoring, consent checks | Six-step generation pipeline not fully implemented (PII scrubbing, injection defense are stubs), provider adapter interface not formalized, bias monitoring runs on synthetic data only |
| L17 | District/State | **SCAFFOLD** | Governance nodes, policy packs, effective cache, oversight assignments, compliance dashboard cache, transfer records, directives | Policy pack inheritance merge logic not implemented, staggered deployment not implemented, district admin RLS verified for intervention_plans but not for all specified tables |
| L18 | Business/Procurement | **SCAFFOLD** | SLA definitions, monitoring, onboarding, training, support tickets, exit procedures | SLA automated monitoring job not created, training staleness job not created, exit state machine thin |
| L19 | SQAA Engine | **SCAFFOLD** | Frameworks, indicator definitions, values with source validation trigger, domain/composite scores, computation jobs, submissions, improvement plans | Auto-SQAA service computes 9 indicators but not integrated into the job queue, district drilldown privacy filtering thin |
| L20 | Policy/Compliance | **SCAFFOLD** | Directives, conflicts, checklists, risk radar, outbound submissions, distribution log | Conflict detection logic not implemented (tables exist, auto-detection not wired), auto-compliance staleness check is stub, outbound portal integration is placeholder |

## Connective Tissue (scaffolded)

| Layer | Name | Status | What's Done | What's Missing |
|-------|------|--------|-------------|----------------|
| L21 | CPD/NPST | **SCAFFOLD** | Professional profiles with immutable data_use_restrictions, hours ledger (append-only), peer observations with self-pairing constraint, NPST assessments, growth interventions | CPD 20% self-directed cap not enforced in computation, peer observation cycle pairing algorithm not implemented, district admin RLS verified |
| L22 | Portability/VC | **SCAFFOLD** | Standards, packages, sections, import requests, CRL (append-only, public), taxonomy bridge mappings, consent records | Package generation logic is stub (doesn't build actual JSON-LD), section exclusion rules not enforced, CRL endpoint exists but returns empty, duplicate import prevention not wired |
| L23 | Community Partners | **SCAFFOLD** | Partners with vetting gate trigger, CRITICAL auto-suspension trigger, hash-chained vetting/safeguarding logs, sessions, alumni, engagement aggregates | Alumni self-registration flow not implemented, engagement verification flow thin, aggregates not computed by job worker |

## Advanced Features (concept/prototype)

| Feature | Status | What's Done | Production Path |
|---------|--------|-------------|-----------------|
| Adaptive Recommendations | **CONCEPT** | Priority scoring algorithm with graph traversal, endpoint exists | Needs real usage data to validate scoring weights |
| Predictive Intervention | **CONCEPT** | scikit-learn pipeline trains on synthetic data | Needs one academic term of real data to train meaningful model |
| On-Device AI | **CONCEPT** | Template-based observation suggestions, TFLite service layer | Needs actual TFLite model trained on teacher observations |
| NLP Parent Feedback | **CONCEPT** | Keyword-based Hindi/English sentiment, theme extraction | Needs IndicBERT integration for real multilingual NLP |
| Computer Vision | **CONCEPT** | EXIF-based classification placeholder | Needs actual CV model (CLIP/Florence-2) |
| Policy Simulation | **CONCEPT** | Impact analysis queries against live data | Functional but untested at scale |
| Automated SQAA | **CONCEPT** | 9 indicators computed from SQL queries | Needs integration into SQAA job queue |
| Blockchain Anchoring | **CONCEPT** | Mock mode works, ethers.js ready for Polygon | Needs real Polygon deployment |
| Federated Bias Detection | **CONCEPT** | Local metric computation, aggregation logic | Needs Flower framework integration at scale |
| Real-Time Collaboration | **CONCEPT** | WebSocket session management, divergence detection | Needs frontend integration and load testing |

---

## Security Hardening Status

| Item | Status |
|------|--------|
| SQL injection in session context | **FIXED** — now uses `set_config($1, $2, true)` with UUID/role format validation |
| JWT secret enforcement | **FIXED** — throws in non-development environments if JWT_SECRET not set |
| DB connection string fallbacks | **FIXED** — `requireEnv()` only allows dev fallbacks when `NODE_ENV=development` |
| RLS on all tenant-scoped tables | Done (176 tables) |
| Append-only enforcement | Done (48 rules on 24 tables) |
| UDID encryption | Done (AES-256-GCM) |
| Soft-delete audit trail | Done (V030 triggers) |
| Cross-tenant CI test | Written (integration tests), needs CI pipeline |
| OWASP Top 10 review | Not started |
| VAPT audit | Requires external engagement |

---

## Recommended Build Order Going Forward

1. **Harden L1-L3** — cross-tenant CI tests, session invalidation E2E test, year-close full flow test
2. **Complete L6-L9 core flow** — evidence upload → rubric completion → mastery event → aggregation (one E2E path)
3. **Complete L11 intervention flow** — trigger → alert → plan → action → evidence → close
4. **Complete L13 credit computation** — evidence triangle gate, domain cap, overlay-aware threshold
5. **Complete L14 export** — snapshot integrity gate, stage-specific template, signing
6. **Harden L15 governance** — entity_version_hash, permission snapshot triggers
7. **Then and only then**: deepen L16-L23 and advanced features
