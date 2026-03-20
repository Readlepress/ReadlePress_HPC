-- ============================================================================
-- V027 — Blueprint Alignment: Layers 1-5
-- Additive migration to align existing schema with the Master Blueprint.
-- Uses IF NOT EXISTS / ADD COLUMN IF NOT EXISTS throughout for idempotency.
-- Does NOT drop or recreate any existing tables.
-- ============================================================================

-- =====================
-- LAYER 1 — Platform Foundation
-- =====================

-- 1.1 roles — System-defined role catalogue (Blueprint Table 1.3)
CREATE TABLE IF NOT EXISTS roles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    label TEXT NOT NULL,
    scope TEXT NOT NULL,
    description TEXT,
    is_system_role BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1.2 sessions — Active session registry (Blueprint Table 1.7)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    token_hash TEXT NOT NULL UNIQUE,
    issued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    ip_address INET,
    user_agent TEXT,
    device_id TEXT,
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT
);

-- 1.3 token_invalidation_queue — Immediate permission revocation (Blueprint Table 1.8)
CREATE TABLE IF NOT EXISTS token_invalidation_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    reason TEXT NOT NULL,
    queued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    processed_at TIMESTAMPTZ
);

-- 1.4 soft_delete_log — Tracks who soft-deleted what and why (Blueprint Table 1.10)
CREATE TABLE IF NOT EXISTS soft_delete_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    table_name TEXT NOT NULL,
    record_id UUID NOT NULL,
    deleted_by UUID NOT NULL REFERENCES users(id),
    deletion_reason TEXT NOT NULL,
    deleted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1.5 request_log — API request audit trail (Blueprint Table 1.12)
CREATE TABLE IF NOT EXISTS request_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID,
    user_id UUID,
    session_id UUID,
    http_method TEXT NOT NULL,
    path TEXT NOT NULL,
    status_code SMALLINT NOT NULL,
    request_id UUID NOT NULL,
    ip_address INET,
    user_agent TEXT,
    duration_ms INTEGER,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 1.6 ALTER TABLE tenants — add blueprint columns
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS tenant_type TEXT DEFAULT 'SCHOOL';
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS parent_tenant_id UUID REFERENCES tenants(id);
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS onboarded_at TIMESTAMPTZ DEFAULT now();
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS onboarded_by UUID;
ALTER TABLE tenants ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 1.7 ALTER TABLE users — add blueprint columns
ALTER TABLE users ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS preferred_name TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS phone_e164 TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS government_id_type TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS government_id_ref TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_enabled BOOLEAN DEFAULT FALSE;
ALTER TABLE users ADD COLUMN IF NOT EXISTS mfa_secret_encrypted TEXT;
ALTER TABLE users ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 1.8 ALTER TABLE permissions — add blueprint columns
ALTER TABLE permissions ADD COLUMN IF NOT EXISTS resource TEXT;
ALTER TABLE permissions ADD COLUMN IF NOT EXISTS action TEXT;

-- 1.9 ALTER TABLE audit_log — add blueprint columns
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS actor_user_id UUID;
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS actor_role_code TEXT;
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS subject_entity_type TEXT;
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS subject_entity_id UUID;
ALTER TABLE audit_log ADD COLUMN IF NOT EXISTS occurred_at TIMESTAMPTZ DEFAULT now();

-- 1.10 Trigger: on role_assignments INSERT/UPDATE of revoked_at → queue token invalidation
--      (V001 created role_assignments; blueprint calls it user_role_assignments)
CREATE OR REPLACE FUNCTION trg_fn_role_revocation_invalidate_tokens()
RETURNS TRIGGER AS $$
BEGIN
    IF (TG_OP = 'INSERT') OR
       (TG_OP = 'UPDATE' AND OLD.is_active IS DISTINCT FROM NEW.is_active) OR
       (TG_OP = 'UPDATE' AND NEW.expires_at IS NOT NULL AND OLD.expires_at IS DISTINCT FROM NEW.expires_at) THEN
        INSERT INTO token_invalidation_queue (user_id, tenant_id, reason)
        VALUES (
            NEW.user_id,
            NEW.tenant_id,
            CASE
                WHEN TG_OP = 'INSERT' THEN 'ROLE_ASSIGNED'
                ELSE 'ROLE_CHANGED'
            END
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_role_assignment_invalidate_tokens ON role_assignments;
CREATE TRIGGER trg_role_assignment_invalidate_tokens
    AFTER INSERT OR UPDATE ON role_assignments
    FOR EACH ROW
    EXECUTE FUNCTION trg_fn_role_revocation_invalidate_tokens();

-- 1.11 Indexes on sessions and request_log
CREATE INDEX IF NOT EXISTS idx_sessions_user_tenant
    ON sessions(user_id, tenant_id) WHERE revoked_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_sessions_token_hash
    ON sessions(token_hash);
CREATE INDEX IF NOT EXISTS idx_request_log_tenant_time
    ON request_log(tenant_id, occurred_at DESC);
CREATE INDEX IF NOT EXISTS idx_request_log_request_id
    ON request_log(request_id);

-- =====================
-- LAYER 2 — Government Identity
-- =====================

-- 2.1 student_deduplication_log (Blueprint Table 2.4)
CREATE TABLE IF NOT EXISTS student_deduplication_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    student_profile_id UUID NOT NULL REFERENCES student_profiles(id),
    matched_profile_id UUID NOT NULL REFERENCES student_profiles(id),
    match_score DECIMAL(5,4),
    resolution TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.2 identity_change_log — Append-only (Blueprint Table 2.11)
CREATE TABLE IF NOT EXISTS identity_change_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    field_name TEXT NOT NULL,
    old_value TEXT,
    new_value TEXT,
    changed_by UUID NOT NULL REFERENCES users(id),
    change_reason TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for identity_change_log
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_rules
        WHERE tablename = 'identity_change_log' AND rulename = 'no_identity_change_update'
    ) THEN
        CREATE RULE no_identity_change_update AS ON UPDATE TO identity_change_log DO INSTEAD NOTHING;
    END IF;
    IF NOT EXISTS (
        SELECT 1 FROM pg_rules
        WHERE tablename = 'identity_change_log' AND rulename = 'no_identity_change_delete'
    ) THEN
        CREATE RULE no_identity_change_delete AS ON DELETE TO identity_change_log DO INSTEAD NOTHING;
    END IF;
END $$;

-- 2.3 transfer_records (Blueprint Table 2.12)
CREATE TABLE IF NOT EXISTS transfer_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    from_school_id UUID NOT NULL REFERENCES schools(id),
    to_school_id UUID REFERENCES schools(id),
    from_class_id UUID REFERENCES classes(id),
    transfer_type TEXT NOT NULL,
    transfer_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'INITIATED',
    initiated_by UUID NOT NULL REFERENCES users(id),
    portability_package_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2.4 ALTER TABLE schools — add blueprint columns
ALTER TABLE schools ADD COLUMN IF NOT EXISTS school_name_regional TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS management_type TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS board_affiliation TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS board_affiliation_code TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS stage_coverage TEXT[];
ALTER TABLE schools ADD COLUMN IF NOT EXISTS village_town TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS block_name TEXT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS established_year SMALLINT;
ALTER TABLE schools ADD COLUMN IF NOT EXISTS principal_user_id UUID REFERENCES users(id);
ALTER TABLE schools ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- 2.5 ALTER TABLE student_profiles — add blueprint columns
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS full_name TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS full_name_regional TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS mother_tongue TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS home_language TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS social_category TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS religion TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS nationality TEXT DEFAULT 'INDIAN';
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS father_name TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS mother_name TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS guardian_name TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS guardian_relationship TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS aadhaar_ref_encrypted TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS is_bpl_family BOOLEAN;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS udid_number_encrypted TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS udid_disability_category TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS udid_disability_percentage SMALLINT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS udid_verified_at TIMESTAMPTZ;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS udid_document_ref TEXT;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;
ALTER TABLE student_profiles ADD COLUMN IF NOT EXISTS photo_evidence_id UUID;

-- =====================
-- LAYER 3 — Academic Year Lifecycle
-- =====================

-- 3.1 year_state_transitions (Blueprint Table 3.2)
CREATE TABLE IF NOT EXISTS year_state_transitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    from_status TEXT NOT NULL,
    to_status TEXT NOT NULL,
    transitioned_by UUID NOT NULL REFERENCES users(id),
    transitioned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT
);

-- 3.2 term_state_transitions (Blueprint Table 3.4)
CREATE TABLE IF NOT EXISTS term_state_transitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    term_id UUID NOT NULL REFERENCES terms(id),
    from_status TEXT NOT NULL,
    to_status TEXT NOT NULL,
    transitioned_by UUID NOT NULL REFERENCES users(id),
    transitioned_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.3 rollover_jobs (Blueprint Table 3.8)
CREATE TABLE IF NOT EXISTS rollover_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    from_year_id UUID NOT NULL REFERENCES academic_years(id),
    to_year_id UUID NOT NULL REFERENCES academic_years(id),
    status TEXT NOT NULL DEFAULT 'PENDING',
    job_type TEXT,
    total_students INTEGER,
    processed_students INTEGER DEFAULT 0,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.4 student_promotion_decisions (Blueprint Table 3.9)
CREATE TABLE IF NOT EXISTS student_promotion_decisions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    decision TEXT NOT NULL CHECK (decision IN ('PROMOTED', 'DETAINED', 'GRADUATED', 'TRANSFERRED')),
    decided_by UUID NOT NULL REFERENCES users(id),
    decided_at TIMESTAMPTZ,
    remarks TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3.5 pre_year_staging (Blueprint Table 3.10)
CREATE TABLE IF NOT EXISTS pre_year_staging (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id),
    academic_year_id UUID REFERENCES academic_years(id),
    staging_type TEXT NOT NULL,
    staging_data JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================
-- LAYER 4 — Taxonomy Spine
-- =====================

-- 4.1 taxonomy_frameworks (Blueprint Table 4.1)
CREATE TABLE IF NOT EXISTS taxonomy_frameworks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    framework_code TEXT NOT NULL,
    name TEXT NOT NULL,
    issuing_authority TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_taxonomy_framework_tenant_code UNIQUE (tenant_id, framework_code)
);

-- 4.2 competency_localizations (Blueprint Table 4.8)
CREATE TABLE IF NOT EXISTS competency_localizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    language_code TEXT NOT NULL,
    localized_name TEXT NOT NULL,
    localized_description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_competency_localizations_comp_lang
    ON competency_localizations(competency_id, language_code);

-- 4.3 competency_descriptor_bindings (Blueprint Table 4.11)
CREATE TABLE IF NOT EXISTS competency_descriptor_bindings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    descriptor_set_code TEXT NOT NULL,
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4.4 taxonomy_change_proposals (Blueprint Table 4.12)
CREATE TABLE IF NOT EXISTS taxonomy_change_proposals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    taxonomy_version_id UUID REFERENCES taxonomy_versions(id),
    proposal_type TEXT NOT NULL,
    proposed_changes JSONB NOT NULL,
    justification TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'DRAFT',
    submitted_by UUID REFERENCES users(id),
    reviewed_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- =====================
-- LAYER 5 — Localization
-- =====================

-- 5.1 localization_namespaces (Blueprint Table 5.2)
CREATE TABLE IF NOT EXISTS localization_namespaces (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    namespace_code TEXT NOT NULL UNIQUE,
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5.2 localization_fallback_chains (Blueprint Table 5.5)
CREATE TABLE IF NOT EXISTS localization_fallback_chains (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    language_code TEXT NOT NULL,
    fallback_language_code TEXT NOT NULL,
    priority INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5.3 localization_fallback_events (Blueprint Table 5.6)
CREATE TABLE IF NOT EXISTS localization_fallback_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    requested_key TEXT NOT NULL,
    requested_language TEXT NOT NULL,
    served_language TEXT NOT NULL,
    context TEXT,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_fallback_events_tenant_key
    ON localization_fallback_events(tenant_id, requested_key, occurred_at DESC);

-- 5.4 export_language_selections (Blueprint Table 5.8)
CREATE TABLE IF NOT EXISTS export_language_selections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    export_type TEXT NOT NULL,
    primary_language TEXT NOT NULL,
    secondary_language TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5.5 translation_review_requests (Blueprint Table 5.9)
CREATE TABLE IF NOT EXISTS translation_review_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID REFERENCES tenants(id),
    string_id UUID NOT NULL REFERENCES localization_strings(id),
    requested_by UUID NOT NULL REFERENCES users(id),
    review_status TEXT NOT NULL DEFAULT 'PENDING',
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5.6 ALTER TABLE localization_keys — add blueprint columns
ALTER TABLE localization_keys ADD COLUMN IF NOT EXISTS namespace_code TEXT;
ALTER TABLE localization_keys ADD COLUMN IF NOT EXISTS base_text_english TEXT;

-- =====================
-- Migration tracking
-- =====================
INSERT INTO schema_migrations (version, description)
VALUES ('V027', 'Blueprint alignment — Layers 1-5')
ON CONFLICT (version) DO NOTHING;
