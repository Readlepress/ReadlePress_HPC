-- ============================================================================
-- Layer 20 — Policy Compliance Engine
-- Directives, conflict detection, checklists, risk radar, outbound reporting
-- ============================================================================

-- 70. policy_directives — Government and institutional policy directives
CREATE TABLE policy_directives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    directive_code TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    title TEXT NOT NULL,
    description TEXT,
    affected_modules TEXT[],
    policy_pack_key TEXT,
    severity TEXT NOT NULL DEFAULT 'INFO'
        CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    evidence_types_accepted TEXT[],
    auto_checkable BOOLEAN NOT NULL DEFAULT FALSE,
    max_staleness_days INTEGER NOT NULL DEFAULT 30,
    deadline DATE,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED', 'WITHDRAWN')),
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_directive_version UNIQUE (tenant_id, directive_code, version)
);

-- 71. directive_conflicts — Detected conflicts between directives
CREATE TABLE directive_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    directive_a_id UUID NOT NULL REFERENCES policy_directives(id),
    directive_b_id UUID NOT NULL REFERENCES policy_directives(id),
    conflict_type TEXT,
    resolution_status TEXT NOT NULL DEFAULT 'DETECTED'
        CHECK (resolution_status IN ('DETECTED', 'RESOLVED', 'ESCALATED')),
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 72. compliance_checklists — Per-school compliance status per directive
CREATE TABLE compliance_checklists (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    directive_id UUID NOT NULL REFERENCES policy_directives(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN (
            'PENDING', 'EVIDENCE_SUBMITTED', 'VERIFIED_COMPLIANT',
            'NON_COMPLIANT', 'SUSPENDED', 'OVERDUE'
        )),
    last_auto_check_at TIMESTAMPTZ,
    auto_check_data_as_of TIMESTAMPTZ,
    evidence_ref TEXT,
    verified_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_checklist UNIQUE (tenant_id, school_id, directive_id, academic_year_id)
);

-- 73. compliance_risk_radar_cache — Pre-computed risk metrics per school
CREATE TABLE compliance_risk_radar_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    overdue_count INTEGER NOT NULL DEFAULT 0,
    conflict_suspended_count INTEGER NOT NULL DEFAULT 0,
    critical_overdue_count INTEGER NOT NULL DEFAULT 0,
    risk_score DECIMAL,
    last_computed_at TIMESTAMPTZ,
    CONSTRAINT unique_risk_radar UNIQUE (tenant_id, school_id)
);

-- 74. directive_distribution_log — Tracks directive distribution to schools
CREATE TABLE directive_distribution_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    directive_id UUID NOT NULL REFERENCES policy_directives(id),
    channel TEXT NOT NULL
        CHECK (channel IN ('SMS', 'EMAIL', 'APP_NOTIFICATION', 'PORTAL')),
    recipient_count INTEGER,
    sent_at TIMESTAMPTZ,
    delivery_status TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 75. outbound_reporting_endpoints — External portal configuration
CREATE TABLE outbound_reporting_endpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    endpoint_name TEXT NOT NULL,
    endpoint_url TEXT NOT NULL,
    portal_type TEXT NOT NULL
        CHECK (portal_type IN ('UDISE_PLUS', 'PARAKH', 'STATE_SCERT', 'CUSTOM')),
    auth_secret_ref TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 76. outbound_submission_records — Tracks submissions to external portals
CREATE TABLE outbound_submission_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    endpoint_id UUID NOT NULL REFERENCES outbound_reporting_endpoints(id),
    checklist_id UUID NOT NULL REFERENCES compliance_checklists(id),
    payload_hash TEXT NOT NULL,
    portal_reference_number TEXT,
    submission_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (submission_status IN ('PENDING', 'SUBMITTED', 'ACCEPTED', 'REJECTED', 'FAILED')),
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    submitted_at TIMESTAMPTZ,
    response_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 77. compliance_risk_computation_jobs — Idempotent risk recomputation queue
CREATE TABLE compliance_risk_computation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    idempotency_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 78. directive_module_impacts — Maps directives to modules they affect
CREATE TABLE directive_module_impacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    directive_id UUID NOT NULL REFERENCES policy_directives(id),
    module_name TEXT,
    impact_type TEXT,
    auto_config JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 79. compliance_notification_log — Notification history for compliance events
CREATE TABLE compliance_notification_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    directive_id UUID NOT NULL REFERENCES policy_directives(id),
    school_id UUID NOT NULL REFERENCES schools(id),
    notification_type TEXT,
    sent_to UUID NOT NULL REFERENCES users(id),
    sent_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V023', 'Layer 20 — Policy Compliance Engine');
