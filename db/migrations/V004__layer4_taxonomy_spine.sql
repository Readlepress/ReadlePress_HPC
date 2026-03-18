-- ============================================================================
-- Layer 4 — Taxonomy Spine
-- NCF 2023 competency framework — versioned, permanent UIDs, lineage mapping
-- ============================================================================

-- 1. taxonomy_versions — Versioned competency framework releases
CREATE TABLE taxonomy_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    version_code TEXT NOT NULL,
    framework_name TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED', 'ARCHIVED')),
    published_at TIMESTAMPTZ,
    effective_from DATE,
    effective_until DATE,
    change_summary TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_taxonomy_version UNIQUE (tenant_id, version_code)
);

-- 2. taxonomy_domains — High-level learning domains
CREATE TABLE taxonomy_domains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    domain_code TEXT NOT NULL,
    name TEXT NOT NULL,
    name_local TEXT,
    description TEXT,
    display_order INTEGER NOT NULL DEFAULT 0,
    color_hex TEXT,
    icon_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_domain_code UNIQUE (tenant_id, domain_code)
);

-- 3. competencies — Individual competency definitions. UID is permanent.
CREATE TABLE competencies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    uid TEXT NOT NULL UNIQUE,
    domain_id UUID NOT NULL REFERENCES taxonomy_domains(id),
    stage_id UUID NOT NULL REFERENCES academic_stages(id),
    grade INTEGER NOT NULL,
    subdomain TEXT,
    sequence_number INTEGER NOT NULL,
    name TEXT NOT NULL,
    name_local TEXT,
    description TEXT,
    learning_outcomes TEXT[],
    status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'SUPERSEDED', 'DEPRECATED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT competency_uid_format CHECK (
        uid ~ '^COMP-[A-Z0-9]+-[A-Z]+-G[0-9]+-[A-Z]+-[A-Z]+-[0-9]+$'
    )
);

-- Trigger: Block UPDATE on competency UIDs — ever. And block non-PLATFORM_ADMIN updates.
CREATE OR REPLACE FUNCTION protect_competency_uid()
RETURNS TRIGGER AS $$
DECLARE
    v_role TEXT;
BEGIN
    IF OLD.uid != NEW.uid THEN
        RAISE EXCEPTION 'Competency UIDs are immutable and cannot be changed'
            USING ERRCODE = 'check_violation';
    END IF;

    v_role := current_setting('app.user_role', TRUE);
    IF v_role IS NOT NULL AND v_role != 'PLATFORM_ADMIN' THEN
        RAISE EXCEPTION 'Only PLATFORM_ADMIN can update competency records. Current role: %', v_role
            USING ERRCODE = 'insufficient_privilege';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_competency_uid
    BEFORE UPDATE ON competencies
    FOR EACH ROW
    EXECUTE FUNCTION protect_competency_uid();

-- 4. competency_version_memberships — Which competencies are active in which version
CREATE TABLE competency_version_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    taxonomy_version_id UUID NOT NULL REFERENCES taxonomy_versions(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    added_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_competency_version UNIQUE (taxonomy_version_id, competency_id)
);

-- 5. competency_lineage — Maps retired competencies to successors
CREATE TABLE competency_lineage (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    source_competency_id UUID NOT NULL REFERENCES competencies(id),
    target_competency_id UUID NOT NULL REFERENCES competencies(id),
    lineage_type TEXT NOT NULL
        CHECK (lineage_type IN ('SUPERSEDED_BY', 'RENAMED', 'SPLIT_FROM', 'MERGED_INTO', 'REFINED')),
    weight DECIMAL(5, 4) NOT NULL DEFAULT 1.0
        CHECK (weight > 0 AND weight <= 1),
    effective_from DATE NOT NULL,
    notes TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT no_self_lineage CHECK (source_competency_id != target_competency_id)
);

-- 6. competency_activations — Tenant-level activation of competencies
CREATE TABLE competency_activations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    competency_id UUID NOT NULL REFERENCES competencies(id),
    is_suppressed BOOLEAN NOT NULL DEFAULT FALSE,
    suppressed_reason TEXT,
    activated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    suppressed_at TIMESTAMPTZ,
    CONSTRAINT unique_activation UNIQUE (tenant_id, competency_id)
);

-- 7. descriptor_levels — Assessment levels for each competency
CREATE TABLE descriptor_levels (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    competency_id UUID NOT NULL REFERENCES competencies(id),
    level_code TEXT NOT NULL
        CHECK (level_code IN ('BEGINNING', 'DEVELOPING', 'PROFICIENT', 'ADVANCED')),
    numeric_value DECIMAL(3, 2) NOT NULL
        CHECK (numeric_value >= 0 AND numeric_value <= 1),
    label TEXT NOT NULL,
    label_local TEXT,
    description TEXT,
    criteria TEXT[],
    display_order INTEGER NOT NULL,
    metaphor_icon TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_descriptor_level UNIQUE (competency_id, level_code)
);

-- 8. stage_bridge_mappings — Prerequisites for stage transitions
CREATE TABLE stage_bridge_mappings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    from_stage_id UUID NOT NULL REFERENCES academic_stages(id),
    to_stage_id UUID NOT NULL REFERENCES academic_stages(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    minimum_mastery_level DECIMAL(3, 2) NOT NULL DEFAULT 0.50,
    is_mandatory BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_bridge UNIQUE (from_stage_id, to_stage_id, competency_id),
    CONSTRAINT different_stages CHECK (from_stage_id != to_stage_id)
);

INSERT INTO schema_migrations (version, description) VALUES ('V004', 'Layer 4 — Taxonomy Spine');
