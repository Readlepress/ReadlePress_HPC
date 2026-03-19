-- ============================================================================
-- Layer 18 — Business & Procurement
-- SLA management, onboarding, training, support, exit procedures
-- ============================================================================

-- 1. sla_definitions — SLA tier definitions with per-metric targets
CREATE TABLE sla_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    tier_code TEXT NOT NULL
        CHECK (tier_code IN ('SCHOOL_STANDARD', 'DISTRICT_PREMIUM', 'STATE_ENTERPRISE')),
    metric_code TEXT NOT NULL,
    target_value DECIMAL NOT NULL,
    unit TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_sla_tier_metric UNIQUE (tier_code, metric_code)
);

-- 2. tenant_sla_assignments — Maps tenants to their SLA tier
CREATE TABLE tenant_sla_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    sla_tier TEXT NOT NULL,
    custom_overrides JSONB NOT NULL DEFAULT '{}',
    effective_from DATE,
    effective_until DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. sla_monitoring_records — Continuous SLA metric measurements
CREATE TABLE sla_monitoring_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    metric_code TEXT NOT NULL,
    measured_value DECIMAL,
    target_value DECIMAL,
    is_within_sla BOOLEAN,
    measured_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. onboarding_programmes — Onboarding programme definitions
CREATE TABLE onboarding_programmes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    programme_type TEXT,
    name TEXT NOT NULL,
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. training_modules — Training content registry per tenant
CREATE TABLE training_modules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    title TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    content_ref TEXT,
    platform_version_from TEXT,
    platform_version_to TEXT,
    is_stale BOOLEAN NOT NULL DEFAULT FALSE,
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
    reported_by UUID NOT NULL REFERENCES users(id),
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
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT deletion_requires_acknowledgement CHECK (
        deletion_scheduled_date IS NULL OR package_acknowledged_at IS NOT NULL
    )
);

-- 10. audit_access_grants — Time-bounded audit access for external auditors
CREATE TABLE audit_access_grants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    scope TEXT[] NOT NULL,
    granted_by UUID NOT NULL REFERENCES users(id),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

INSERT INTO schema_migrations (version, description) VALUES ('V021', 'Layer 18 — Business & Procurement');
