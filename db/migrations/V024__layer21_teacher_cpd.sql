-- ============================================================================
-- Layer 21 — Teacher CPD (Continuous Professional Development)
-- NPST alignment, CPD tracking, peer observation, professional growth
-- ============================================================================

-- 80. teacher_professional_profiles — CPD profile per teacher
CREATE TABLE teacher_professional_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    npst_version_id UUID,
    current_npst_level TEXT,
    annual_cpd_target_hours DECIMAL NOT NULL DEFAULT 50,
    data_use_restrictions TEXT[] NOT NULL DEFAULT ARRAY['NO_PUNITIVE_USE', 'NO_SALARY_DETERMINATION', 'NO_DISTRICT_RANKING'],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_teacher_professional_profile UNIQUE (tenant_id, teacher_id)
);

-- Trigger: data_use_restrictions column is immutable after creation
CREATE OR REPLACE FUNCTION protect_data_use_restrictions()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.data_use_restrictions IS DISTINCT FROM NEW.data_use_restrictions THEN
        RAISE EXCEPTION 'data_use_restrictions is immutable and cannot be modified'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_data_use_restrictions
    BEFORE UPDATE ON teacher_professional_profiles
    FOR EACH ROW
    EXECUTE FUNCTION protect_data_use_restrictions();

-- 81. npst_framework_versions — NPST standard versions
CREATE TABLE npst_framework_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    version_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
    standards JSONB NOT NULL,
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 82. cpd_provider_registry — Approved CPD activity providers
CREATE TABLE cpd_provider_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    trust_level TEXT NOT NULL DEFAULT 'STANDARD'
        CHECK (trust_level IN ('HIGH', 'STANDARD', 'UNVERIFIED')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 83. cpd_activity_records — Individual CPD activity entries
CREATE TABLE cpd_activity_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    activity_type TEXT NOT NULL
        CHECK (activity_type IN (
            'ONLINE_COURSE', 'FORMAL_TRAINING', 'PEER_OBSERVATION',
            'ACTION_RESEARCH', 'SELF_DIRECTED'
        )),
    provider_id UUID REFERENCES cpd_provider_registry(id),
    hours_claimed DECIMAL NOT NULL,
    hours_verified DECIMAL,
    evidence_record_ids UUID[],
    peer_observation_record_id UUID,
    verification_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    verified_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 84. cpd_hours_ledger — Append-only verified hours ledger
CREATE TABLE cpd_hours_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    activity_record_id UUID NOT NULL REFERENCES cpd_activity_records(id),
    hours_credited DECIMAL NOT NULL,
    policy_version_id UUID,
    verified_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for cpd_hours_ledger
CREATE RULE no_cpd_ledger_update AS ON UPDATE TO cpd_hours_ledger DO INSTEAD NOTHING;
CREATE RULE no_cpd_ledger_delete AS ON DELETE TO cpd_hours_ledger DO INSTEAD NOTHING;

-- 85. peer_observation_records — Individual observation entries
CREATE TABLE peer_observation_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    cycle_id UUID,
    observer_teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    observed_teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    npst_standard_ratings JSONB,
    observation_notes TEXT,
    status TEXT NOT NULL DEFAULT 'SCHEDULED'
        CHECK (status IN ('SCHEDULED', 'COMPLETED', 'CANCELLED')),
    observed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT observer_not_observed CHECK (observer_teacher_id != observed_teacher_id)
);

-- 86. peer_observation_cycles — School-level observation cycle management
CREATE TABLE peer_observation_cycles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    school_id UUID NOT NULL REFERENCES schools(id),
    managed_pairings JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'PLANNING'
        CHECK (status IN ('PLANNING', 'ACTIVE', 'COMPLETED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 87. npst_competency_assessments — Formal competency assessment against NPST
CREATE TABLE npst_competency_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    npst_version_id UUID NOT NULL REFERENCES npst_framework_versions(id),
    assessor_id UUID NOT NULL REFERENCES users(id),
    standard_code TEXT,
    rating TEXT,
    evidence_ref TEXT,
    assessed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 88. professional_growth_interventions — Growth plans for teachers
CREATE TABLE professional_growth_interventions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    title TEXT NOT NULL,
    objectives JSONB,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'ACTIVE', 'COMPLETED', 'CANCELLED')),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 89. cpd_aggregation_jobs — Idempotent CPD recomputation queue
CREATE TABLE cpd_aggregation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    idempotency_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V024', 'Layer 21 — Teacher CPD');
