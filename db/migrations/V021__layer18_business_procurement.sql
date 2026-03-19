-- ============================================================================
-- Layer 18 — Business & Procurement
-- SLA management, onboarding, training, support, exit procedures
-- ============================================================================

-- 1. sla_definitions — Global SLA tier definitions
CREATE TABLE sla_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tier_code TEXT NOT NULL
        CHECK (tier_code IN ('SCHOOL_STANDARD', 'DISTRICT_PREMIUM', 'STATE_ENTERPRISE')),
    uptime_commitment DECIMAL NOT NULL,
    api_response_p95_ms INTEGER NOT NULL,
    rpo_minutes INTEGER NOT NULL,
    rto_minutes INTEGER NOT NULL,
    p1_response_minutes INTEGER NOT NULL,
    p2_response_minutes INTEGER NOT NULL,
    exit_export_days INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_sla_tier UNIQUE (tier_code)
);

-- 2. tenant_sla_assignments — Maps tenants to their SLA tier
CREATE TABLE tenant_sla_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    sla_definition_id UUID NOT NULL REFERENCES sla_definitions(id),
    custom_overrides JSONB NOT NULL DEFAULT '{}',
    effective_from DATE,
    effective_until DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_tenant_sla UNIQUE (tenant_id)
);

-- 3. sla_monitoring_records — Continuous SLA metric measurements
CREATE TABLE sla_monitoring_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    metric_name TEXT NOT NULL,
    metric_value DECIMAL NOT NULL,
    threshold_value DECIMAL NOT NULL,
    is_compliant BOOLEAN NOT NULL,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. onboarding_programmes — Onboarding programme definitions
CREATE TABLE onboarding_programmes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    programme_type TEXT,
    phases JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. tenant_onboarding_records — Tracks tenant onboarding progress
CREATE TABLE tenant_onboarding_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    programme_id UUID NOT NULL REFERENCES onboarding_programmes(id),
    current_phase TEXT,
    completion_percentage DECIMAL NOT NULL DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_tenant_onboarding UNIQUE (tenant_id)
);

-- 6. training_modules — Global training content registry
CREATE TABLE training_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    platform_version_from TEXT,
    platform_version_to TEXT,
    is_stale BOOLEAN NOT NULL DEFAULT FALSE,
    content_ref TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. user_training_records — Per-user training completion tracking
CREATE TABLE user_training_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    module_id UUID NOT NULL REFERENCES training_modules(id),
    status TEXT NOT NULL DEFAULT 'NOT_STARTED'
        CHECK (status IN ('NOT_STARTED', 'IN_PROGRESS', 'COMPLETED', 'REQUIRES_REFRESH')),
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. support_tickets — Tenant support ticket system
CREATE TABLE support_tickets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    submitted_by UUID NOT NULL REFERENCES users(id),
    priority TEXT NOT NULL DEFAULT 'P3'
        CHECK (priority IN ('P1', 'P2', 'P3', 'P4')),
    subject TEXT NOT NULL,
    description TEXT,
    status TEXT NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN', 'IN_PROGRESS', 'RESOLVED', 'CLOSED')),
    response_sla_deadline TIMESTAMPTZ,
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. exit_procedure_requests — Tenant exit and data export workflow
CREATE TABLE exit_procedure_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    requested_by UUID NOT NULL REFERENCES users(id),
    status TEXT NOT NULL DEFAULT 'INITIATED'
        CHECK (status IN (
            'INITIATED', 'DATA_PACKAGING', 'QUALITY_VERIFICATION',
            'DELIVERED', 'ACKNOWLEDGED', 'COMPLETED', 'ACCOUNT_CLOSED'
        )),
    package_acknowledged_at TIMESTAMPTZ,
    deletion_scheduled_date DATE,
    export_delivery_deadline DATE,
    legal_hold_prevents_deletion BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. audit_access_grants — Time-bounded audit access for external auditors
CREATE TABLE audit_access_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    granted_to UUID NOT NULL REFERENCES users(id),
    scope TEXT[] NOT NULL,
    granted_by UUID NOT NULL REFERENCES users(id),
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V021', 'Layer 18 — Business & Procurement');
