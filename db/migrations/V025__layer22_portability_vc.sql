-- ============================================================================
-- Layer 22 — Portability & Verifiable Credentials
-- Student data portability, package signing, import workflows, consent
-- ============================================================================

-- 90. portability_standards — Data portability format definitions
CREATE TABLE portability_standards (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    standard_code TEXT NOT NULL UNIQUE,
    name TEXT NOT NULL,
    version INTEGER NOT NULL DEFAULT 1,
    schema_definition JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 91. portability_packages — Exported student data packages
CREATE TABLE portability_packages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    standard_id UUID NOT NULL REFERENCES portability_standards(id),
    consent_scope TEXT[],
    signing_key_id UUID,
    payload_hash TEXT NOT NULL,
    package_status TEXT NOT NULL DEFAULT 'GENERATED'
        CHECK (package_status IN ('GENERATED', 'DELIVERED', 'REVOKED')),
    revocation_status TEXT
        CHECK (revocation_status IN (NULL, 'REVOKED')),
    revoked_at TIMESTAMPTZ,
    revocation_reason TEXT,
    generated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 92. portability_package_sections — Individual sections within a package
CREATE TABLE portability_package_sections (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    package_id UUID NOT NULL REFERENCES portability_packages(id),
    section_type TEXT NOT NULL,
    content_hash TEXT NOT NULL,
    signature TEXT,
    is_excluded BOOLEAN NOT NULL DEFAULT FALSE,
    exclusion_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 93. import_requests — Incoming transfer requests
CREATE TABLE import_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    receiving_school_id UUID NOT NULL REFERENCES schools(id),
    package_id UUID NOT NULL REFERENCES portability_packages(id),
    received_package_hash TEXT NOT NULL,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN (
            'PENDING', 'INTEGRITY_VERIFIED', 'BRIDGE_REVIEW',
            'ACCEPTED', 'REJECTED', 'COMPLETED'
        )),
    records_imported INTEGER NOT NULL DEFAULT 0,
    records_skipped INTEGER NOT NULL DEFAULT 0,
    imported_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_import_hash UNIQUE (tenant_id, received_package_hash)
);

-- 94. credential_revocation_list — Public revocation registry (no tenant_id)
CREATE TABLE credential_revocation_list (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    package_id UUID NOT NULL REFERENCES portability_packages(id),
    revocation_status TEXT NOT NULL,
    revocation_reason_code TEXT NOT NULL,
    revoked_at TIMESTAMPTZ NOT NULL,
    issued_by_udise TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Append-only enforcement for credential_revocation_list
CREATE RULE no_revocation_list_update AS ON UPDATE TO credential_revocation_list DO INSTEAD NOTHING;
CREATE RULE no_revocation_list_delete AS ON DELETE TO credential_revocation_list DO INSTEAD NOTHING;

-- 95. taxonomy_bridge_mappings_applied — Competency mapping during import
CREATE TABLE taxonomy_bridge_mappings_applied (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    package_id UUID NOT NULL REFERENCES portability_packages(id),
    source_competency_uid TEXT NOT NULL,
    target_competency_uid TEXT NOT NULL,
    equivalence_weight DECIMAL,
    lineage_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 96. import_record_provenance — Tracks lineage of imported records
CREATE TABLE import_record_provenance (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    import_request_id UUID NOT NULL REFERENCES import_requests(id),
    source_entity_id_hash TEXT NOT NULL,
    source_entity_type TEXT NOT NULL,
    imported_entity_id UUID,
    imported_entity_type TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 97. portability_consent_records — Consent for data portability operations
CREATE TABLE portability_consent_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    consent_purpose TEXT NOT NULL,
    consent_status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (consent_status IN ('ACTIVE', 'WITHDRAWN')),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V025', 'Layer 22 — Portability & Verifiable Credentials');
