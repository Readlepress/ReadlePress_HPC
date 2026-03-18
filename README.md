# ReadlePress

NEP 2020 compliant Holistic Progress Card (HPC) platform for India's government school system.

## Architecture

23-layer architecture — this repository implements **Phase 1 (Layers 1–5)** and **Phase 2 (Layers 6–12)**.

| Phase | Layers | Purpose |
|-------|--------|---------|
| Phase 1 | 1–5 | Foundation: multi-tenant isolation, identity, academic year lifecycle, taxonomy, localization |
| Phase 2 | 6–12 | Classroom Operations: evidence ledger, offline capture, rubric engine, mastery aggregation, 360° feedback, interventions, inclusion |

## Tech Stack

- **Database**: PostgreSQL 16 (RLS, triggers, JSONB, hash chains)
- **API Server**: Node.js / TypeScript / Fastify
- **Cache**: Redis 7
- **Migrations**: Flyway-style ordered SQL migrations

## Quick Start

```bash
# Install dependencies
npm install

# Start PostgreSQL and Redis (Docker)
docker compose up -d

# Or use a local PostgreSQL instance and configure .env

# Run migrations
npm run migrate

# Seed development data
npm run seed

# Start the API server
npm run dev

# Run integration tests
npm run test:integration
```

## Project Structure

```
db/
  migrations/          # Versioned SQL migrations (V001–V012)
  repeatable/          # Re-runnable migrations (RLS, functions, indexes)
  init/                # Database role setup
  seeds/               # Seed data
src/
  config/              # Database and Redis configuration
  middleware/          # Auth, tenant context
  routes/              # API route handlers
  services/            # Business logic layer
  types/               # TypeScript type definitions
  server.ts            # Fastify server entry point
  migrate.ts           # Migration runner
  seed.ts              # Database seeder
tests/
  integration/         # Integration tests against real PostgreSQL
```

## Key Architectural Decisions

- **Row Level Security (RLS)** on every tenant-scoped table — enforced at the database level
- **Hash-chained audit log** — append-only, tamper-evident event log
- **Academic year state machine** — one-way transitions: PLANNING → ACTIVE → REVIEW → LOCKED
- **Competency UID immutability** — UIDs can never be changed once assigned
- **Mastery event immutability** — ACTIVE events cannot be modified; amendments require dual approval
- **No-naked-scoring constraint** — every mastery event requires evidence or observation notes
- **Intervention sensitivity levels** — WELFARE/SAFEGUARDING cases enforced by RLS, not application code
- **k-anonymity** for peer assessment aggregates
- **Merkle tree** year-lock snapshots for long-term integrity verification

## API Endpoints

### Phase 1
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/auth/login` | Authenticate user |
| POST | `/api/v1/consent/initiate` | Send OTP for consent |
| POST | `/api/v1/consent/verify` | Verify OTP, create consent records |
| GET | `/api/v1/ui-schema` | Stage-aware UI configuration |
| GET | `/api/v1/academic-years` | List academic years |
| POST | `/api/v1/academic-years/:id/close` | Year-close workflow |
| GET | `/api/v1/competencies` | List active competencies |
| GET | `/api/v1/localization/strings` | Batch-fetch localized strings |
| GET | `/api/v1/students` | List students |
| POST | `/api/v1/students/:id/enrolments` | Enrol student |

### Phase 2
| Method | Path | Purpose |
|--------|------|---------|
| POST | `/api/v1/evidence` | Upload evidence |
| POST | `/api/v1/capture/sync` | Sync offline captures |
| GET | `/api/v1/students/:id/assessment-context` | Overlay-aware rubric context |
| POST | `/api/v1/rubric-completions` | Submit rubric assessment |
| GET | `/api/v1/students/:id/mastery-summary` | Current mastery aggregates |
| POST | `/api/v1/mastery-events/:id/verify` | Verify mastery event draft |
| POST | `/api/v1/feedback-requests/batch` | Dispatch 360° feedback |
| POST | `/api/v1/feedback-requests/:id/response` | Submit feedback response |
| GET | `/api/v1/moderation-queue` | Teacher moderation queue |
| GET | `/api/v1/intervention-alerts` | Open alerts for a class |
| POST | `/api/v1/intervention-alerts/:id/convert` | Create intervention plan |
| POST | `/api/v1/students/:id/overlays` | Create accommodation overlay |
| POST | `/api/v1/overlays/:id/approve` | Approve/reject overlay |
| GET | `/api/v1/students/:id/overlays/active` | Active overlays for student |

## Compliance

- **NEP 2020**: Full NCF 2023 competency framework support
- **DPDP Act 2023**: Purpose-specific consent, data localisation, erasure workflow
- **NCF 2023**: Stage-specific assessment descriptors
- **TRAI DLT**: SMS template registration for OTP delivery
