-- ============================================================================
-- Layer 17 — District & State Governance
-- Hierarchical policy packs, oversight, compliance directives, transfers
-- ============================================================================

-- 1. governance_nodes — Hierarchical governance structure
CREATE TABLE governance_nodes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    node_type TEXT NOT NULL
        CHECK (node_type IN ('NATIONAL', 'STATE', 'DISTRICT', 'BLOCK', 'SCHOOL')),
    parent_node_id UUID REFERENCES governance_nodes(id),
    name TEXT NOT NULL,
    code TEXT,
    level INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. policy_packs — Versioned rule bundles deployed to governance nodes
CREATE TABLE policy_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    node_id UUID NOT NULL REFERENCES governance_nodes(id),
    version INTEGER NOT NULL DEFAULT 1,
    rules JSONB NOT NULL,
    override_rules JSONB NOT NULL DEFAULT '{}',
    non_overridable_keys TEXT[] NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
    published_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. effective_policy_cache — Merged policy rules per governance node
CREATE TABLE effective_policy_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    node_id UUID NOT NULL REFERENCES governance_nodes(id),
    merged_rules JSONB NOT NULL,
    cache_stale BOOLEAN NOT NULL DEFAULT FALSE,
    invalidated_at TIMESTAMPTZ,
    recomputed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. district_oversight_assignments — District officer school assignments
CREATE TABLE district_oversight_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    school_id UUID NOT NULL REFERENCES schools(id),
    scope TEXT[] NOT NULL DEFAULT '{}',
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

-- 5. district_compliance_dashboard_cache — Per-school compliance metrics
CREATE TABLE district_compliance_dashboard_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    compliance_summary JSONB,
    welfare_flag BOOLEAN NOT NULL DEFAULT FALSE,
    last_computed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. protected_evidence_access_requests — Justified access to sensitive evidence
CREATE TABLE protected_evidence_access_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    requester_id UUID NOT NULL REFERENCES users(id),
    school_id UUID REFERENCES schools(id),
    evidence_id UUID REFERENCES evidence_records(id),
    justification TEXT NOT NULL CHECK (length(justification) >= 100),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED')),
    approved_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. inter_district_transfer_records — Student transfer workflow
CREATE TABLE inter_district_transfer_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    from_school_id UUID NOT NULL REFERENCES schools(id),
    to_school_id UUID NOT NULL REFERENCES schools(id),
    from_district TEXT,
    to_district TEXT,
    portability_package_id UUID,
    status TEXT NOT NULL DEFAULT 'INITIATED'
        CHECK (status IN (
            'INITIATED', 'PACKAGE_GENERATED', 'DELIVERED',
            'ACKNOWLEDGED', 'COMPLETED'
        )),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. state_compliance_directives — State-level compliance requirements
CREATE TABLE state_compliance_directives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    directive_code TEXT,
    title TEXT NOT NULL,
    description TEXT,
    deadline DATE,
    priority TEXT NOT NULL DEFAULT 'MEDIUM'
        CHECK (priority IN ('LOW', 'MEDIUM', 'HIGH', 'CRITICAL')),
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'ACTIVE', 'COMPLETED', 'SUPERSEDED')),
    evidence_types_accepted TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. school_directive_compliance — Per-school compliance tracking
CREATE TABLE school_directive_compliance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    directive_id UUID NOT NULL REFERENCES state_compliance_directives(id),
    status TEXT NOT NULL DEFAULT 'NOT_STARTED'
        CHECK (status IN (
            'NOT_STARTED', 'IN_PROGRESS', 'EVIDENCE_SUBMITTED',
            'VERIFIED_COMPLIANT', 'OVERDUE', 'SUSPENDED'
        )),
    last_auto_check_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. policy_pack_deployment_log — Tracks rollout of policy packs to schools
CREATE TABLE policy_pack_deployment_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    policy_pack_id UUID NOT NULL REFERENCES policy_packs(id),
    batch_number INTEGER,
    schools_in_batch INTEGER,
    deployment_status TEXT NOT NULL DEFAULT 'QUEUED'
        CHECK (deployment_status IN ('QUEUED', 'DEPLOYING', 'COMPLETED', 'FAILED')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for policy_pack_deployment_log
CREATE RULE no_deployment_log_update AS ON UPDATE TO policy_pack_deployment_log DO INSTEAD NOTHING;
CREATE RULE no_deployment_log_delete AS ON DELETE TO policy_pack_deployment_log DO INSTEAD NOTHING;

INSERT INTO schema_migrations (version, description) VALUES ('V020', 'Layer 17 — District & State Governance');
