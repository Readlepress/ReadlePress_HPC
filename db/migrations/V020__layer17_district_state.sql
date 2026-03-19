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
    metadata JSONB NOT NULL DEFAULT '{}',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. policy_packs — Versioned rule bundles deployed to governance nodes
CREATE TABLE policy_packs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    governance_node_id UUID NOT NULL REFERENCES governance_nodes(id),
    version INTEGER NOT NULL DEFAULT 1,
    rules JSONB NOT NULL,
    non_overridable_rules TEXT[] NOT NULL DEFAULT '{}',
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
    published_at TIMESTAMPTZ,
    effective_from DATE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. effective_policy_cache — Merged policy rules per governance node
CREATE TABLE effective_policy_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    governance_node_id UUID NOT NULL REFERENCES governance_nodes(id),
    merged_rules JSONB NOT NULL,
    cache_stale BOOLEAN NOT NULL DEFAULT FALSE,
    invalidated_at TIMESTAMPTZ,
    last_computed_at TIMESTAMPTZ,
    CONSTRAINT unique_effective_policy UNIQUE (tenant_id, governance_node_id)
);

-- 4. district_oversight_assignments — District officer school assignments
CREATE TABLE district_oversight_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    school_id UUID NOT NULL REFERENCES schools(id),
    scope TEXT[] NOT NULL DEFAULT '{}',
    assigned_at TIMESTAMPTZ,
    assigned_by UUID REFERENCES users(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. district_compliance_dashboard_cache — Per-school compliance metrics
CREATE TABLE district_compliance_dashboard_cache (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    metrics JSONB NOT NULL,
    welfare_flag BOOLEAN NOT NULL DEFAULT FALSE,
    last_computed_at TIMESTAMPTZ,
    CONSTRAINT unique_district_dashboard UNIQUE (tenant_id, school_id)
);

-- 6. protected_evidence_access_requests — Justified access to sensitive evidence
CREATE TABLE protected_evidence_access_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    requested_by UUID NOT NULL REFERENCES users(id),
    school_id UUID REFERENCES schools(id),
    evidence_ids UUID[],
    justification TEXT NOT NULL CHECK (length(justification) >= 100),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED')),
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
    portability_package_id UUID,
    status TEXT NOT NULL DEFAULT 'INITIATED'
        CHECK (status IN ('INITIATED', 'PACKAGE_GENERATED', 'RECEIVED', 'ACKNOWLEDGED', 'COMPLETED')),
    initiated_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. state_compliance_directives — State-level compliance requirements
CREATE TABLE state_compliance_directives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    directive_code TEXT,
    title TEXT NOT NULL,
    description TEXT,
    severity TEXT NOT NULL DEFAULT 'INFO'
        CHECK (severity IN ('INFO', 'WARNING', 'CRITICAL')),
    deadline DATE,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. school_directive_compliance — Per-school compliance tracking
CREATE TABLE school_directive_compliance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id),
    directive_id UUID NOT NULL REFERENCES state_compliance_directives(id),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'COMPLIANT', 'NON_COMPLIANT', 'SUSPENDED')),
    evidence_ref TEXT,
    verified_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_school_directive UNIQUE (tenant_id, school_id, directive_id)
);

-- 10. policy_pack_deployment_log — Tracks rollout of policy packs to schools
CREATE TABLE policy_pack_deployment_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    policy_pack_id UUID NOT NULL REFERENCES policy_packs(id),
    deployment_batch INTEGER,
    schools_in_batch INTEGER,
    deployment_status TEXT NOT NULL DEFAULT 'QUEUED'
        CHECK (deployment_status IN ('QUEUED', 'DEPLOYING', 'COMPLETED', 'FAILED')),
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V020', 'Layer 17 — District & State Governance');
