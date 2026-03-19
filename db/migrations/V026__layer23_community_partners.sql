-- ============================================================================
-- Layer 23 — Community & Partners
-- Partner vetting, engagement sessions, alumni, safeguarding, hash-chained logs
-- ============================================================================

-- 103. community_partners — Vetted external partners
CREATE TABLE community_partners (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    partner_type TEXT NOT NULL
        CHECK (partner_type IN ('NGO', 'CORPORATE', 'GOVERNMENT', 'ALUMNI_NETWORK', 'INDIVIDUAL')),
    vetting_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (vetting_status IN (
            'PENDING', 'APPROVED', 'CONDITIONALLY_APPROVED', 'REJECTED', 'SUSPENDED'
        )),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    vetted_by UUID REFERENCES users(id),
    vetted_at TIMESTAMPTZ,
    suspension_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 104. partner_vetting_log — Append-only hash-chained vetting audit trail
CREATE TABLE partner_vetting_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    partner_id UUID NOT NULL REFERENCES community_partners(id),
    action TEXT NOT NULL,
    performed_by UUID NOT NULL REFERENCES users(id),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    details JSONB,
    prev_log_hash TEXT,
    log_hash TEXT NOT NULL DEFAULT ''
);

-- Hash chain trigger for partner_vetting_log
CREATE OR REPLACE FUNCTION compute_partner_vetting_log_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.log_hash := encode(sha256(
        (NEW.id::text || NEW.action
         || extract(epoch from NEW.performed_at)::text
         || COALESCE(NEW.prev_log_hash, ''))::bytea
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_partner_vetting_log_hash
    BEFORE INSERT ON partner_vetting_log
    FOR EACH ROW
    EXECUTE FUNCTION compute_partner_vetting_log_hash();

-- Append-only enforcement for partner_vetting_log
CREATE RULE no_partner_vetting_log_update AS ON UPDATE TO partner_vetting_log DO INSTEAD NOTHING;
CREATE RULE no_partner_vetting_log_delete AS ON DELETE TO partner_vetting_log DO INSTEAD NOTHING;

-- 105. engagement_activity_templates — Reusable activity type definitions
CREATE TABLE engagement_activity_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    activity_type TEXT NOT NULL
        CHECK (activity_type IN (
            'BAGLESS_DAY', 'VOCATIONAL', 'MENTORING', 'COMMUNITY_SERVICE', 'FIELD_VISIT'
        )),
    credit_domain_id UUID,
    notional_hours DECIMAL,
    evidence_types_required TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 106. engagement_sessions — Actual engagement events
CREATE TABLE engagement_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    partner_id UUID NOT NULL REFERENCES community_partners(id),
    activity_template_id UUID NOT NULL REFERENCES engagement_activity_templates(id),
    school_id UUID NOT NULL REFERENCES schools(id),
    session_date DATE NOT NULL,
    hours DECIMAL NOT NULL,
    facilitator_name TEXT,
    evidence_record_ids UUID[],
    verification_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'REJECTED')),
    verified_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger: reject engagement sessions with non-approved/inactive partners
CREATE OR REPLACE FUNCTION validate_partner_vetting()
RETURNS TRIGGER AS $$
DECLARE
    v_status TEXT;
    v_active BOOLEAN;
BEGIN
    SELECT vetting_status, is_active INTO v_status, v_active
    FROM community_partners WHERE id = NEW.partner_id;

    IF v_status IS NULL THEN
        RAISE EXCEPTION 'Partner not found'
            USING ERRCODE = 'foreign_key_violation';
    END IF;

    IF v_status NOT IN ('APPROVED', 'CONDITIONALLY_APPROVED') OR v_active IS NOT TRUE THEN
        RAISE EXCEPTION 'Partner must be APPROVED or CONDITIONALLY_APPROVED and active to create engagement sessions'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_validate_partner_vetting
    BEFORE INSERT ON engagement_sessions
    FOR EACH ROW
    EXECUTE FUNCTION validate_partner_vetting();

-- 107. session_student_participants — Student attendance per session
CREATE TABLE session_student_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    session_id UUID NOT NULL REFERENCES engagement_sessions(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    attendance_status TEXT NOT NULL DEFAULT 'PRESENT'
        CHECK (attendance_status IN ('PRESENT', 'ABSENT', 'EXCUSED')),
    credit_attributed BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 108. alumni_profiles — Former students returning as community partners
CREATE TABLE alumni_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    former_student_profile_id UUID REFERENCES student_profiles(id),
    adult_consent_record_id UUID NOT NULL REFERENCES data_consent_records(id),
    phone_encrypted TEXT,
    email_encrypted TEXT,
    graduation_year INTEGER,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 109. alumni_engagement_records — Alumni participation in sessions
CREATE TABLE alumni_engagement_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    alumni_id UUID NOT NULL REFERENCES alumni_profiles(id),
    session_id UUID NOT NULL REFERENCES engagement_sessions(id),
    engagement_type TEXT NOT NULL
        CHECK (engagement_type IN (
            'MENTORING', 'GUEST_LECTURE', 'CAREER_GUIDANCE', 'SKILL_WORKSHOP'
        )),
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 110. engagement_ledger_aggregates — Pre-computed engagement metrics per school
CREATE TABLE engagement_ledger_aggregates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    total_sessions INTEGER NOT NULL DEFAULT 0,
    total_sessions_verified INTEGER NOT NULL DEFAULT 0,
    total_partners_engaged INTEGER NOT NULL DEFAULT 0,
    partner_diversity_score DECIMAL,
    last_computed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_engagement_aggregate UNIQUE (tenant_id, school_id, academic_year_id)
);

-- 111. partner_safeguarding_log — Append-only hash-chained incident log
CREATE TABLE partner_safeguarding_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    partner_id UUID NOT NULL REFERENCES community_partners(id),
    severity TEXT NOT NULL
        CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    incident_description TEXT NOT NULL,
    reported_by UUID NOT NULL REFERENCES users(id),
    reported_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    prev_log_hash TEXT,
    log_hash TEXT NOT NULL DEFAULT ''
);

-- Hash chain trigger for partner_safeguarding_log
CREATE OR REPLACE FUNCTION compute_partner_safeguarding_log_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.log_hash := encode(sha256(
        (NEW.id::text || NEW.severity
         || extract(epoch from NEW.reported_at)::text
         || COALESCE(NEW.prev_log_hash, ''))::bytea
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_partner_safeguarding_log_hash
    BEFORE INSERT ON partner_safeguarding_log
    FOR EACH ROW
    EXECUTE FUNCTION compute_partner_safeguarding_log_hash();

-- Trigger: auto-suspend partner on CRITICAL safeguarding incident
CREATE OR REPLACE FUNCTION auto_suspend_on_critical_incident()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.severity = 'CRITICAL' THEN
        UPDATE community_partners
        SET vetting_status = 'SUSPENDED',
            is_active = FALSE,
            updated_at = now()
        WHERE id = NEW.partner_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_auto_suspend_critical
    AFTER INSERT ON partner_safeguarding_log
    FOR EACH ROW
    EXECUTE FUNCTION auto_suspend_on_critical_incident();

-- Append-only enforcement for partner_safeguarding_log
CREATE RULE no_partner_safeguarding_log_update AS ON UPDATE TO partner_safeguarding_log DO INSTEAD NOTHING;
CREATE RULE no_partner_safeguarding_log_delete AS ON DELETE TO partner_safeguarding_log DO INSTEAD NOTHING;

-- 112. engagement_computation_jobs — Idempotent engagement recomputation queue
CREATE TABLE engagement_computation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    idempotency_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V026', 'Layer 23 — Community & Partners');
