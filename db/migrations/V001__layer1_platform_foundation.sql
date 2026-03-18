-- ============================================================================
-- Layer 1 — Platform Foundation
-- Multi-tenant isolation, consent management, audit logging, RBAC
-- ============================================================================

-- 1. tenants — The root table. Every other table has tenant_id FK to this.
CREATE TABLE tenants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    slug TEXT NOT NULL UNIQUE,
    domain TEXT,
    status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DEACTIVATED')),
    settings JSONB NOT NULL DEFAULT '{}',
    data_residency_region TEXT NOT NULL DEFAULT 'ap-south-1',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. users — All humans in the system. No user exists without a tenant.
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    email TEXT,
    phone TEXT,
    phone_country_code TEXT DEFAULT '+91',
    password_hash TEXT,
    display_name TEXT NOT NULL,
    preferred_language TEXT NOT NULL DEFAULT 'en',
    status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'SUSPENDED', 'DEACTIVATED', 'PENDING_VERIFICATION')),
    last_login_at TIMESTAMPTZ,
    failed_login_attempts INTEGER NOT NULL DEFAULT 0,
    locked_until TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT users_email_or_phone CHECK (email IS NOT NULL OR phone IS NOT NULL)
);

CREATE UNIQUE INDEX idx_users_email_tenant ON users(tenant_id, email) WHERE email IS NOT NULL;
CREATE UNIQUE INDEX idx_users_phone_tenant ON users(tenant_id, phone) WHERE phone IS NOT NULL;

-- 3. role_assignments — Maps users to roles within a tenant scope.
CREATE TABLE role_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role_code TEXT NOT NULL
        CHECK (role_code IN (
            'PLATFORM_ADMIN', 'STATE_ADMIN', 'DISTRICT_ADMIN',
            'BEO', 'PRINCIPAL', 'VICE_PRINCIPAL',
            'CLASS_TEACHER', 'SUBJECT_TEACHER', 'DEPARTMENT_HEAD',
            'COUNSELLOR', 'WELFARE_OFFICER', 'INCLUSION_COORDINATOR',
            'CRP', 'PARENT', 'STUDENT',
            'EXTERNAL_PARTNER', 'AUDIT_VIEWER'
        )),
    scope_type TEXT NOT NULL DEFAULT 'TENANT'
        CHECK (scope_type IN ('TENANT', 'SCHOOL', 'CLASS')),
    scope_id UUID,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    assigned_by UUID REFERENCES users(id),
    expires_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_role_per_scope UNIQUE (tenant_id, user_id, role_code, scope_type, scope_id)
);

-- 4. permissions — The atomic permission codes
CREATE TABLE permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code TEXT NOT NULL UNIQUE,
    description TEXT NOT NULL,
    category TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. role_permissions — Maps roles to permission sets
CREATE TABLE role_permissions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    role_code TEXT NOT NULL,
    permission_id UUID NOT NULL REFERENCES permissions(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_role_permission UNIQUE (role_code, permission_id)
);

-- 6. privacy_policy_versions — Versioned policy text registry
CREATE TABLE privacy_policy_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    version_number INTEGER NOT NULL,
    policy_text TEXT NOT NULL,
    effective_from TIMESTAMPTZ NOT NULL,
    effective_until TIMESTAMPTZ,
    published_at TIMESTAMPTZ,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'SUPERSEDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_policy_version UNIQUE (tenant_id, version_number)
);

-- 7. data_consent_records — DPDP Act consent tracking. One row per purpose per student.
CREATE TABLE data_consent_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL,
    consenting_user_id UUID NOT NULL REFERENCES users(id),
    consent_purpose_code TEXT NOT NULL
        CHECK (consent_purpose_code IN (
            'EDUCATIONAL_RECORD', 'ASSESSMENT_DATA', 'EVIDENCE_CAPTURE',
            'PARENT_COMMUNICATION', 'DISABILITY_DATA', 'AI_PROCESSING',
            'PORTABILITY_EXPORT', 'DIGILOCKER_DELIVERY', 'RESEARCH_ANONYMIZED'
        )),
    consent_status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (consent_status IN ('ACTIVE', 'WITHDRAWN', 'EXPIRED')),
    verification_method TEXT NOT NULL
        CHECK (verification_method IN ('OTP', 'WITNESSED_PAPER', 'GUARDIAN_PORTAL', 'SYSTEM')),
    policy_version_id UUID REFERENCES privacy_policy_versions(id),
    consent_given_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    consent_withdrawn_at TIMESTAMPTZ,
    withdrawal_reason TEXT,
    ip_address INET,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_consent_per_purpose UNIQUE (tenant_id, student_id, consent_purpose_code, consent_status)
);

-- 8. consent_otp_attempts — OTP verification audit trail. Append-only.
CREATE TABLE consent_otp_attempts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    phone TEXT NOT NULL,
    otp_hash TEXT NOT NULL,
    purpose TEXT NOT NULL,
    attempt_number INTEGER NOT NULL DEFAULT 1,
    is_successful BOOLEAN NOT NULL DEFAULT FALSE,
    attempted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL,
    ip_address INET,
    session_id TEXT
);

-- Append-only enforcement for consent_otp_attempts
CREATE RULE no_otp_update AS ON UPDATE TO consent_otp_attempts DO INSTEAD NOTHING;
CREATE RULE no_otp_delete AS ON DELETE TO consent_otp_attempts DO INSTEAD NOTHING;

-- 9. witnessed_consent_records — For zero-connectivity witnessed paper consent
CREATE TABLE witnessed_consent_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    consent_record_id UUID NOT NULL REFERENCES data_consent_records(id),
    witness_user_id UUID NOT NULL REFERENCES users(id),
    witness_role TEXT NOT NULL CHECK (witness_role IN ('CRP', 'BEO', 'PRINCIPAL')),
    photo_evidence_ref TEXT,
    witnessed_at TIMESTAMPTZ NOT NULL,
    principal_confirmed BOOLEAN NOT NULL DEFAULT FALSE,
    principal_confirmed_at TIMESTAMPTZ,
    principal_confirmed_by UUID REFERENCES users(id),
    confirmation_deadline TIMESTAMPTZ NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. audit_log — The hash-chained immutable event log
CREATE TABLE audit_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    event_type TEXT NOT NULL,
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    performed_by UUID NOT NULL REFERENCES users(id),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    before_state JSONB NULL,
    after_state JSONB NULL,
    metadata JSONB NULL,
    ip_address INET NULL,
    prev_log_hash TEXT NULL,
    row_hash TEXT NOT NULL DEFAULT ''
);

-- Trigger to compute row_hash on INSERT (immutable hash computation)
CREATE OR REPLACE FUNCTION compute_audit_row_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.row_hash := encode(sha256(
        (NEW.id::text || NEW.event_type || NEW.entity_id::text
         || extract(epoch from NEW.performed_at)::text
         || COALESCE(NEW.prev_log_hash, ''))::bytea
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_row_hash
    BEFORE INSERT ON audit_log
    FOR EACH ROW
    EXECUTE FUNCTION compute_audit_row_hash();

-- Append-only enforcement for audit_log
CREATE RULE no_audit_update AS ON UPDATE TO audit_log DO INSTEAD NOTHING;
CREATE RULE no_audit_delete AS ON DELETE TO audit_log DO INSTEAD NOTHING;

-- 11. storage_providers — Provider-agnostic storage abstraction
CREATE TABLE storage_providers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    provider_type TEXT NOT NULL
        CHECK (provider_type IN ('AWS_S3', 'NIC_OBJECT_STORE', 'LOCAL_FS')),
    name TEXT NOT NULL,
    config JSONB NOT NULL DEFAULT '{}',
    is_default BOOLEAN NOT NULL DEFAULT FALSE,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Migration tracking table
CREATE TABLE IF NOT EXISTS schema_migrations (
    version TEXT PRIMARY KEY,
    description TEXT,
    applied_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V001', 'Layer 1 — Platform Foundation');
