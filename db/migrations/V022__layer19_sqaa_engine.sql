-- ============================================================================
-- Layer 19 — SQAA Engine
-- School quality assurance, indicator computation, composite scoring,
-- improvement plans
-- ============================================================================

-- 62. sqaa_frameworks — Quality assurance framework definitions
CREATE TABLE sqaa_frameworks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    tier_thresholds JSONB NOT NULL,
    min_evidence_requirements JSONB,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 63. sqaa_indicator_definitions — What gets measured and how
CREATE TABLE sqaa_indicator_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    framework_id UUID NOT NULL REFERENCES sqaa_frameworks(id),
    indicator_code TEXT NOT NULL,
    name TEXT NOT NULL,
    computation_type TEXT NOT NULL
        CHECK (computation_type IN ('SYSTEM_COMPUTED', 'MANUAL_SUBMISSION', 'HYBRID')),
    data_source_layer TEXT,
    weight DECIMAL NOT NULL CHECK (weight > 0 AND weight <= 0.30),
    performance_levels JSONB NOT NULL,
    max_staleness_days INTEGER NOT NULL DEFAULT 30,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_indicator_per_framework UNIQUE (tenant_id, framework_id, indicator_code)
);

-- 64. sqaa_indicator_values — Computed or submitted indicator scores
CREATE TABLE sqaa_indicator_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    indicator_id UUID NOT NULL REFERENCES sqaa_indicator_definitions(id),
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    numeric_value DECIMAL,
    performance_level TEXT,
    computation_run_id UUID,
    submission_id UUID,
    is_stale BOOLEAN NOT NULL DEFAULT FALSE,
    last_computed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_indicator_value UNIQUE (tenant_id, indicator_id, school_id, academic_year_id)
);

-- Trigger: reject indicator values with no provenance (both computation_run_id and submission_id NULL)
CREATE OR REPLACE FUNCTION enforce_indicator_value_provenance()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.computation_run_id IS NULL AND NEW.submission_id IS NULL THEN
        RAISE EXCEPTION 'sqaa_indicator_values requires at least one of computation_run_id or submission_id'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_indicator_value_provenance
    BEFORE INSERT OR UPDATE ON sqaa_indicator_values
    FOR EACH ROW
    EXECUTE FUNCTION enforce_indicator_value_provenance();

-- 65. sqaa_domain_scores — Weighted domain-level aggregates
CREATE TABLE sqaa_domain_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    domain_name TEXT NOT NULL,
    weighted_score DECIMAL,
    indicator_count INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_domain_score UNIQUE (tenant_id, school_id, academic_year_id, domain_name)
);

-- 66. sqaa_composite_scores — Overall school quality tier
CREATE TABLE sqaa_composite_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    composite_score DECIMAL,
    tier TEXT
        CHECK (tier IN ('EXEMPLARY', 'EFFECTIVE', 'NEEDS_SUPPORT', 'CRITICAL')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_composite_score UNIQUE (tenant_id, school_id, academic_year_id)
);

-- 67. sqaa_computation_jobs — Idempotent job queue for SQAA recomputation
CREATE TABLE sqaa_computation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    idempotency_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'SUPERSEDED')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    queued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 68. sqaa_indicator_submissions — Manual indicator evidence submissions
CREATE TABLE sqaa_indicator_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    indicator_id UUID NOT NULL REFERENCES sqaa_indicator_definitions(id),
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    submitted_by UUID NOT NULL REFERENCES users(id),
    evidence_ref TEXT,
    submission_value DECIMAL,
    verification_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    verified_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 69. sqaa_improvement_plans — Triggered when indicators fall below threshold
CREATE TABLE sqaa_improvement_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    trigger_indicator_id UUID NOT NULL REFERENCES sqaa_indicator_definitions(id),
    title TEXT NOT NULL,
    objectives JSONB,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED')),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V022', 'Layer 19 — SQAA Engine');
