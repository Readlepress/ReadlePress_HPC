-- ============================================================================
-- Layer 12 — Inclusion / UDID Engine
-- Accommodation overlays, disability data encryption, inclusion indicators
-- ============================================================================

-- 1. student_disability_profiles — Application-layer encrypted UDID fields
CREATE TABLE student_disability_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    udid_number_encrypted TEXT,
    udid_disability_category_encrypted TEXT,
    udid_disability_percentage_encrypted INTEGER,
    disability_category TEXT NOT NULL
        CHECK (disability_category IN (
            'VISUAL', 'HEARING', 'SPEECH_LANGUAGE', 'LOCOMOTOR',
            'INTELLECTUAL', 'MENTAL_ILLNESS', 'MULTIPLE', 'SPECIFIC_LEARNING',
            'AUTISM', 'CEREBRAL_PALSY', 'OTHER'
        )),
    disability_tier TEXT NOT NULL DEFAULT 'TIER_1'
        CHECK (disability_tier IN ('TIER_1', 'TIER_2', 'TIER_3')),
    support_needs TEXT[] DEFAULT '{}',
    verification_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (verification_status IN ('PENDING', 'VERIFIED', 'EXPIRED')),
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES users(id),
    consent_record_id UUID REFERENCES data_consent_records(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_disability_profile UNIQUE (tenant_id, student_id)
);

-- 2. overlay_templates — Pre-defined accommodation templates
CREATE TABLE overlay_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    disability_category TEXT NOT NULL,
    disability_tier TEXT NOT NULL,
    modifications JSONB NOT NULL,
    modified_mastery_threshold DECIMAL(3, 2),
    modified_evidence_requirements JSONB,
    modified_time_allowance_factor DECIMAL(3, 2) DEFAULT 1.0,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. rubric_overlays — Time-bounded, approved overlays modifying assessment
CREATE TABLE rubric_overlays (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    disability_profile_id UUID NOT NULL REFERENCES student_disability_profiles(id),
    overlay_template_id UUID REFERENCES overlay_templates(id),
    competency_ids UUID[] NOT NULL DEFAULT '{}',
    modifications JSONB NOT NULL,
    modified_mastery_threshold DECIMAL(3, 2),
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PENDING_APPROVAL', 'ACTIVE', 'EXPIRED', 'REJECTED', 'REVOKED')),
    submitted_by UUID NOT NULL REFERENCES users(id),
    submitted_at TIMESTAMPTZ,
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    rejected_by UUID REFERENCES users(id),
    rejected_at TIMESTAMPTZ,
    rejection_reason TEXT,
    revoked_by UUID REFERENCES users(id),
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    effective_from DATE NOT NULL,
    effective_until DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT overlay_self_approval_check CHECK (
        approved_by IS NULL OR submitted_by != approved_by
    ),
    CONSTRAINT valid_overlay_dates CHECK (effective_until > effective_from)
);

-- 4. overlay_approval_log — Immutable governance trail
CREATE TABLE overlay_approval_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    overlay_id UUID NOT NULL REFERENCES rubric_overlays(id),
    action TEXT NOT NULL
        CHECK (action IN ('SUBMITTED', 'APPROVED', 'REJECTED', 'REVOKED', 'EXPIRED', 'ESCALATED')),
    performed_by UUID NOT NULL REFERENCES users(id),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    details JSONB DEFAULT '{}'
);

-- Append-only enforcement for overlay_approval_log
CREATE RULE no_overlay_log_update AS ON UPDATE TO overlay_approval_log DO INSTEAD NOTHING;
CREATE RULE no_overlay_log_delete AS ON DELETE TO overlay_approval_log DO INSTEAD NOTHING;

-- 5. overlay_assessment_applications — Evidence that overlays were actually applied
CREATE TABLE overlay_assessment_applications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    overlay_id UUID NOT NULL REFERENCES rubric_overlays(id),
    mastery_event_id UUID REFERENCES mastery_events(id),
    rubric_completion_id UUID REFERENCES rubric_completion_records(id),
    applied_modifications JSONB NOT NULL,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    applied_by UUID NOT NULL REFERENCES users(id)
);

-- 6. inclusion_indicators — School-level aggregate metrics for SQAA
CREATE TABLE inclusion_indicators (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    academic_year_id UUID REFERENCES academic_years(id),
    total_disability_profiles INTEGER NOT NULL DEFAULT 0,
    active_overlays_count INTEGER NOT NULL DEFAULT 0,
    overlay_application_rate DECIMAL(5, 4),
    assessment_coverage_rate DECIMAL(5, 4),
    counts_suppressed BOOLEAN NOT NULL DEFAULT FALSE,
    k_anonymity_threshold INTEGER NOT NULL DEFAULT 3,
    last_computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_inclusion_indicator UNIQUE (tenant_id, school_id, academic_year_id)
);

-- 7. overlay_expiry_notifications — Tracks expiry warnings
CREATE TABLE overlay_expiry_notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    overlay_id UUID NOT NULL REFERENCES rubric_overlays(id),
    notification_type TEXT NOT NULL
        CHECK (notification_type IN ('14_DAY', '7_DAY', '1_DAY', 'EXPIRED')),
    sent_to UUID NOT NULL REFERENCES users(id),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    acknowledged BOOLEAN NOT NULL DEFAULT FALSE,
    acknowledged_at TIMESTAMPTZ
);

-- 8. credit_overlay_links — Connects overlays to credit engine's threshold verification
CREATE TABLE credit_overlay_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    overlay_id UUID NOT NULL REFERENCES rubric_overlays(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    standard_threshold DECIMAL(3, 2) NOT NULL,
    modified_threshold DECIMAL(3, 2) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_credit_overlay UNIQUE (overlay_id, competency_id)
);

INSERT INTO schema_migrations (version, description) VALUES ('V012', 'Layer 12 — Inclusion / UDID Engine');
