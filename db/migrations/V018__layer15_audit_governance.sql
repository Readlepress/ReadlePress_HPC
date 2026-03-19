-- ============================================================================
-- Layer 15 — Audit & Governance
-- Override workflows, permission snapshots, compliance reconstruction
-- ============================================================================

-- 1. override_requests — Formal override workflow with dual approval
CREATE TABLE override_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    override_category TEXT NOT NULL
        CHECK (override_category IN (
            'LOCKED_YEAR_DATA', 'IDENTITY_CORRECTION', 'AUDIT_TRAIL_CORRECTION',
            'EXPORT_REGENERATION', 'MASTERY_CORRECTION'
        )),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    entity_version_hash TEXT NOT NULL,
    justification TEXT NOT NULL CHECK (length(justification) >= 50),
    before_state JSONB NOT NULL,
    requested_by UUID NOT NULL REFERENCES users(id),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN (
            'PENDING', 'FIRST_APPROVED', 'APPROVED', 'APPLIED',
            'REJECTED', 'WITHDRAWN', 'EXPIRED'
        )),
    first_approver_id UUID REFERENCES users(id),
    second_approver_id UUID REFERENCES users(id),
    applied_at TIMESTAMPTZ,
    applied_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT override_dual_approval CHECK (
        first_approver_id IS NULL OR
        second_approver_id IS NULL OR
        first_approver_id != second_approver_id
    ),
    CONSTRAINT override_self_approval CHECK (
        (first_approver_id IS NULL OR first_approver_id != requested_by)
        AND (second_approver_id IS NULL OR second_approver_id != requested_by)
    )
);

-- 2. override_application_log — Immutable record of applied overrides
CREATE TABLE override_application_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    override_id UUID NOT NULL REFERENCES override_requests(id),
    before_state JSONB,
    after_state JSONB,
    change_diff JSONB,
    applied_by UUID NOT NULL REFERENCES users(id),
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for override_application_log
CREATE RULE no_override_app_log_update AS ON UPDATE TO override_application_log DO INSTEAD NOTHING;
CREATE RULE no_override_app_log_delete AS ON DELETE TO override_application_log DO INSTEAD NOTHING;

-- 3. permission_snapshots — Point-in-time capture of user permissions at events
CREATE TABLE permission_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    event_type TEXT NOT NULL,
    event_entity_id UUID,
    user_id UUID NOT NULL REFERENCES users(id),
    permissions_at_event JSONB NOT NULL,
    role_at_event TEXT,
    captured_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for permission_snapshots
CREATE RULE no_perm_snapshot_update AS ON UPDATE TO permission_snapshots DO INSTEAD NOTHING;
CREATE RULE no_perm_snapshot_delete AS ON DELETE TO permission_snapshots DO INSTEAD NOTHING;

-- 4. audit_chain_verification_runs — Results of nightly hash chain checks
CREATE TABLE audit_chain_verification_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    table_name TEXT NOT NULL,
    total_rows BIGINT,
    broken_chains BIGINT,
    first_broken_id UUID,
    run_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    run_duration_ms INTEGER
);

-- 5. governance_policy_registry — Central registry of governance rules
CREATE TABLE governance_policy_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    policy_key TEXT NOT NULL,
    policy_value JSONB,
    category TEXT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_policy_key_per_tenant UNIQUE (tenant_id, policy_key)
);

-- 6. compliance_reconstruction_requests — Full student record reconstruction
CREATE TABLE compliance_reconstruction_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    requested_by UUID NOT NULL REFERENCES users(id),
    reason TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED')),
    output_data JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. data_retention_execution_log — Record of retention policy executions
CREATE TABLE data_retention_execution_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    policy_key TEXT NOT NULL,
    records_affected INTEGER,
    action_type TEXT,
    executed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    executed_by UUID NOT NULL REFERENCES users(id)
);

-- Append-only enforcement for data_retention_execution_log
CREATE RULE no_retention_log_update AS ON UPDATE TO data_retention_execution_log DO INSTEAD NOTHING;
CREATE RULE no_retention_log_delete AS ON DELETE TO data_retention_execution_log DO INSTEAD NOTHING;

-- 8. governance_alerts — Alerts for governance violations or concerns
CREATE TABLE governance_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    alert_type TEXT NOT NULL,
    severity TEXT NOT NULL DEFAULT 'INFO'
        CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    entity_type TEXT,
    entity_id UUID,
    message TEXT NOT NULL,
    requires_written_resolution BOOLEAN NOT NULL DEFAULT FALSE,
    resolution_status TEXT NOT NULL DEFAULT 'OPEN'
        CHECK (resolution_status IN ('OPEN', 'ACKNOWLEDGED', 'RESOLVED')),
    resolution_notes TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    auto_escalate_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT resolution_notes_required CHECK (
        NOT (requires_written_resolution = TRUE AND resolution_status = 'RESOLVED')
        OR (resolution_notes IS NOT NULL AND length(resolution_notes) >= 100)
    )
);

INSERT INTO schema_migrations (version, description) VALUES ('V018', 'Layer 15 — Audit & Governance');
