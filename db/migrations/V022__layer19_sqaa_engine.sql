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
    minimum_evidence_requirements JSONB,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 63. sqaa_indicator_definitions — What gets measured and how
CREATE TABLE sqaa_indicator_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    framework_id UUID NOT NULL REFERENCES sqaa_frameworks(id),
    indicator_code TEXT NOT NULL,
    name TEXT,
    computation_type TEXT NOT NULL
        CHECK (computation_type IN ('AUTO_COMPUTED', 'MANUAL_SUBMISSION', 'HYBRID')),
    data_source_layer INTEGER,
    performance_levels JSONB,
    weight DECIMAL NOT NULL DEFAULT 1.0,
    max_staleness_days INTEGER NOT NULL DEFAULT 30,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_indicator_per_framework UNIQUE (framework_id, indicator_code)
);

-- 64. sqaa_indicator_values — Computed or submitted indicator scores
CREATE TABLE sqaa_indicator_values (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    indicator_id UUID NOT NULL REFERENCES sqaa_indicator_definitions(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    computation_run_id UUID,
    submission_id UUID,
    indicator_value DECIMAL,
    performance_level TEXT,
    is_stale BOOLEAN NOT NULL DEFAULT FALSE,
    last_computed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_indicator_value UNIQUE (school_id, indicator_id, academic_year_id)
);

-- Trigger: reject indicator values with no provenance
CREATE OR REPLACE FUNCTION validate_sqaa_indicator_source()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.computation_run_id IS NULL AND NEW.submission_id IS NULL THEN
        RAISE EXCEPTION 'sqaa_indicator_values requires either computation_run_id or submission_id'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_sqaa_source
    BEFORE INSERT OR UPDATE ON sqaa_indicator_values
    FOR EACH ROW
    EXECUTE FUNCTION validate_sqaa_indicator_source();

-- 65. sqaa_domain_scores — Weighted domain-level aggregates
CREATE TABLE sqaa_domain_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    framework_id UUID NOT NULL REFERENCES sqaa_frameworks(id),
    domain_code TEXT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    weighted_score DECIMAL,
    indicator_count INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_domain_score UNIQUE (school_id, domain_code, academic_year_id)
);

-- 66. sqaa_composite_scores — Overall school quality tier
CREATE TABLE sqaa_composite_scores (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    framework_id UUID NOT NULL REFERENCES sqaa_frameworks(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    composite_score DECIMAL,
    tier TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_composite_score UNIQUE (school_id, framework_id, academic_year_id)
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
    priority INTEGER NOT NULL DEFAULT 5,
    retry_count INTEGER NOT NULL DEFAULT 0,
    error_message TEXT,
    queued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 68. sqaa_indicator_submissions — Manual indicator evidence submissions
CREATE TABLE sqaa_indicator_submissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    indicator_id UUID NOT NULL REFERENCES sqaa_indicator_definitions(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    submitted_by UUID NOT NULL REFERENCES users(id),
    evidence_record_ids UUID[],
    submission_value DECIMAL,
    verification_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 69. sqaa_improvement_plans — Triggered when indicators fall below threshold
CREATE TABLE sqaa_improvement_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    triggering_indicator_ids UUID[],
    title TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'ACTIVE', 'COMPLETED', 'ARCHIVED')),
    objectives JSONB,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V022', 'Layer 19 — SQAA Engine');
