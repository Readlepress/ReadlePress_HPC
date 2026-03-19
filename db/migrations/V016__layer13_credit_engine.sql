-- ============================================================================
-- Layer 13 — Credit Engine
-- Credit frameworks, hour/credit ledgers, computation jobs
-- ============================================================================

-- 1. credit_frameworks — Versioned credit framework definitions
CREATE TABLE credit_frameworks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. credit_domain_definitions — Domains within a credit framework
CREATE TABLE credit_domain_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    framework_id UUID NOT NULL REFERENCES credit_frameworks(id),
    domain_code TEXT NOT NULL,
    name TEXT NOT NULL,
    domain_type TEXT NOT NULL
        CHECK (domain_type IN ('CURRICULAR', 'CO_CURRICULAR', 'EXPERIENTIAL', 'HYBRID')),
    max_credits_cap DECIMAL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. credit_policies — Hours-per-credit rules; immutable once PUBLISHED
CREATE TABLE credit_policies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    framework_id UUID NOT NULL REFERENCES credit_frameworks(id),
    version INTEGER NOT NULL,
    hours_per_credit DECIMAL NOT NULL,
    min_mastery_threshold DECIMAL DEFAULT 0.50,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED', 'ARCHIVED')),
    published_at TIMESTAMPTZ,
    effective_from DATE,
    effective_until DATE,
    rules JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger: block UPDATE on published credit policies
CREATE OR REPLACE FUNCTION protect_published_credit_policy()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'PUBLISHED' THEN
        RAISE EXCEPTION 'Cannot modify a PUBLISHED credit policy. Create a new version instead.'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_published_credit_policy
    BEFORE UPDATE ON credit_policies
    FOR EACH ROW
    EXECUTE FUNCTION protect_published_credit_policy();

-- 4. activity_templates — Template definitions for creditable activities
CREATE TABLE activity_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    description TEXT,
    credit_domain_id UUID NOT NULL REFERENCES credit_domain_definitions(id),
    notional_hours DECIMAL NOT NULL,
    evidence_types_required TEXT[] NOT NULL,
    credit_eligible BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. student_activity_records — Per-student activity participation records
CREATE TABLE student_activity_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    activity_template_id UUID NOT NULL REFERENCES activity_templates(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    academic_year_id UUID REFERENCES academic_years(id),
    hours_claimed DECIMAL,
    hours_verified DECIMAL,
    verification_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMPTZ,
    evidence_record_ids UUID[],
    evidence_triangle_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. hour_ledger_entries — Append-only record of credited hours
CREATE TABLE hour_ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    activity_record_id UUID NOT NULL REFERENCES student_activity_records(id),
    credit_policy_id UUID NOT NULL REFERENCES credit_policies(id),
    hours_credited DECIMAL NOT NULL,
    verified_at TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for hour_ledger_entries
CREATE RULE no_hour_ledger_update AS ON UPDATE TO hour_ledger_entries DO INSTEAD NOTHING;
CREATE RULE no_hour_ledger_delete AS ON DELETE TO hour_ledger_entries DO INSTEAD NOTHING;

-- Trigger: reject UPDATE on credit_policy_id after insert
CREATE OR REPLACE FUNCTION protect_hour_ledger_policy_id()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.credit_policy_id IS DISTINCT FROM NEW.credit_policy_id THEN
        RAISE EXCEPTION 'Cannot modify credit_policy_id on hour_ledger_entries after insert.'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_hour_ledger_policy_id
    BEFORE UPDATE ON hour_ledger_entries
    FOR EACH ROW
    EXECUTE FUNCTION protect_hour_ledger_policy_id();

-- 7. credit_ledger_entries — Append-only awarded credits per domain
CREATE TABLE credit_ledger_entries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    credit_domain_id UUID NOT NULL REFERENCES credit_domain_definitions(id),
    credit_policy_id UUID NOT NULL REFERENCES credit_policies(id),
    academic_year_id UUID REFERENCES academic_years(id),
    credits_claimed DECIMAL,
    credits_awarded DECIMAL,
    credits_capped BOOLEAN NOT NULL DEFAULT FALSE,
    overflow_credits_lost DECIMAL NOT NULL DEFAULT 0,
    applied_threshold DECIMAL,
    standard_threshold DECIMAL,
    overlay_used BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for credit_ledger_entries
CREATE RULE no_credit_ledger_update AS ON UPDATE TO credit_ledger_entries DO INSTEAD NOTHING;
CREATE RULE no_credit_ledger_delete AS ON DELETE TO credit_ledger_entries DO INSTEAD NOTHING;

-- 8. credit_ledger_amendment_log — Corrections requiring dual approval
CREATE TABLE credit_ledger_amendment_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    credit_entry_id UUID NOT NULL REFERENCES credit_ledger_entries(id),
    amendment_type TEXT NOT NULL,
    reason TEXT NOT NULL,
    before_state JSONB,
    after_state JSONB,
    requested_by UUID NOT NULL REFERENCES users(id),
    first_approver_id UUID REFERENCES users(id),
    second_approver_id UUID REFERENCES users(id),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'FIRST_APPROVED', 'APPROVED', 'REJECTED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT credit_amendment_dual_approval CHECK (
        first_approver_id IS NULL OR
        second_approver_id IS NULL OR
        first_approver_id != second_approver_id
    ),
    CONSTRAINT credit_amendment_self_approval CHECK (
        (first_approver_id IS NULL OR first_approver_id != requested_by)
        AND (second_approver_id IS NULL OR second_approver_id != requested_by)
    )
);

-- Append-only enforcement for credit_ledger_amendment_log
CREATE RULE no_credit_amendment_update AS ON UPDATE TO credit_ledger_amendment_log DO INSTEAD NOTHING;
CREATE RULE no_credit_amendment_delete AS ON DELETE TO credit_ledger_amendment_log DO INSTEAD NOTHING;

-- 9. external_credit_claims — Claims from external platforms
CREATE TABLE external_credit_claims (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    platform_name TEXT NOT NULL,
    certificate_ref TEXT,
    digital_signature_valid BOOLEAN,
    signature_verification_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'SIGNATURE_VERIFIED', 'SIGNATURE_FAILED', 'APPROVED', 'REJECTED')),
    reviewed_by UUID REFERENCES users(id),
    taxonomy_mapping JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. credit_summaries — Pre-computed credit totals per student per year
CREATE TABLE credit_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    academic_year_id UUID REFERENCES academic_years(id),
    total_credits DECIMAL,
    domain_breakdown JSONB,
    last_computed_at TIMESTAMPTZ,
    CONSTRAINT unique_credit_summary UNIQUE (tenant_id, student_id, academic_year_id)
);

-- 11. credit_computation_jobs — Idempotent credit computation queue
CREATE TABLE credit_computation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    academic_year_id UUID REFERENCES academic_years(id),
    idempotency_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'SUPERSEDED')),
    priority INTEGER NOT NULL DEFAULT 5,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    queued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V016', 'Layer 13 — Credit Engine');
