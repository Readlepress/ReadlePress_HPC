-- ============================================================================
-- Layer 14 — Export Engine
-- HPC generation, document signing, bulk export workflows
-- ============================================================================

-- 1. export_signing_keys — Digital signing key registry
CREATE TABLE export_signing_keys (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    key_identifier TEXT NOT NULL UNIQUE,
    provider TEXT NOT NULL DEFAULT 'EMUDHRA',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    is_revoked BOOLEAN NOT NULL DEFAULT FALSE,
    revoked_at TIMESTAMPTZ,
    revoked_reason TEXT,
    valid_from TIMESTAMPTZ,
    valid_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. export_template_definitions — HPC and certificate template registry
CREATE TABLE export_template_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    template_code TEXT NOT NULL
        CHECK (template_code IN (
            'HPC_FOUNDATIONAL', 'HPC_PREPARATORY', 'HPC_MIDDLE', 'HPC_SECONDARY',
            'MERKLE_CERTIFICATE', 'CREDIT_CERTIFICATE', 'PORTABILITY_PACKAGE'
        )),
    stage_id UUID REFERENCES academic_stages(id),
    version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
    field_inclusion_policy JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Trigger: block UPDATE on published export templates
CREATE OR REPLACE FUNCTION protect_published_export_template()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.status = 'PUBLISHED' THEN
        RAISE EXCEPTION 'Cannot modify a PUBLISHED export template. Create a new version instead.'
            USING ERRCODE = 'check_violation';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_published_export_template
    BEFORE UPDATE ON export_template_definitions
    FOR EACH ROW
    EXECUTE FUNCTION protect_published_export_template();

-- 3. export_jobs — Individual or bulk export job records
CREATE TABLE export_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    template_id UUID NOT NULL REFERENCES export_template_definitions(id),
    student_id UUID REFERENCES student_profiles(id),
    academic_year_id UUID REFERENCES academic_years(id),
    batch_id UUID,
    job_type TEXT NOT NULL DEFAULT 'SINGLE'
        CHECK (job_type IN ('SINGLE', 'BULK')),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'CANCELLED')),
    failure_reason TEXT,
    snapshot_verified BOOLEAN NOT NULL DEFAULT FALSE,
    estimated_completion_at TIMESTAMPTZ,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. export_document_records — Generated documents with hash and signature
CREATE TABLE export_document_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    export_job_id UUID NOT NULL REFERENCES export_jobs(id),
    storage_ref TEXT,
    output_hash TEXT NOT NULL,
    signature_value TEXT,
    signing_key_id UUID REFERENCES export_signing_keys(id),
    is_signed BOOLEAN NOT NULL DEFAULT FALSE,
    file_size_bytes BIGINT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. export_access_log — Immutable log of document access events
CREATE TABLE export_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    document_id UUID NOT NULL REFERENCES export_document_records(id),
    accessed_by UUID NOT NULL REFERENCES users(id),
    access_type TEXT NOT NULL
        CHECK (access_type IN ('VIEW', 'DOWNLOAD', 'SHARE', 'VERIFY')),
    accessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    ip_address INET
);

-- Append-only enforcement for export_access_log
CREATE RULE no_export_access_log_update AS ON UPDATE TO export_access_log DO INSTEAD NOTHING;
CREATE RULE no_export_access_log_delete AS ON DELETE TO export_access_log DO INSTEAD NOTHING;

-- 6. export_authorizations — Dual-approval workflow for bulk exports
CREATE TABLE export_authorizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    academic_year_id UUID REFERENCES academic_years(id),
    authorization_type TEXT NOT NULL
        CHECK (authorization_type IN ('BULK_YEAR_END', 'GOVERNMENT_SUBMISSION', 'SPECIAL_REQUEST')),
    requested_by UUID NOT NULL REFERENCES users(id),
    first_approver_id UUID REFERENCES users(id),
    second_approver_id UUID REFERENCES users(id),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'FIRST_APPROVED', 'APPROVED', 'REJECTED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT export_auth_dual_approval CHECK (
        first_approver_id IS NULL OR
        second_approver_id IS NULL OR
        first_approver_id != second_approver_id
    ),
    CONSTRAINT export_auth_self_approval CHECK (
        (first_approver_id IS NULL OR first_approver_id != requested_by)
        AND (second_approver_id IS NULL OR second_approver_id != requested_by)
    )
);

-- 7. template_state_variants — State-level overrides for export templates
CREATE TABLE template_state_variants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    base_template_id UUID NOT NULL REFERENCES export_template_definitions(id),
    state_code TEXT NOT NULL,
    overrides JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. bulk_export_archives — Packaged archive of bulk export runs
CREATE TABLE bulk_export_archives (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    export_authorization_id UUID NOT NULL REFERENCES export_authorizations(id),
    manifest JSONB,
    total_documents INTEGER,
    completed_documents INTEGER NOT NULL DEFAULT 0,
    failed_documents INTEGER NOT NULL DEFAULT 0,
    archive_storage_ref TEXT,
    status TEXT NOT NULL DEFAULT 'ASSEMBLING'
        CHECK (status IN ('ASSEMBLING', 'COMPLETED', 'PARTIAL', 'FAILED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V017', 'Layer 14 — Export Engine');
