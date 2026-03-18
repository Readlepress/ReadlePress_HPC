-- ============================================================================
-- Layer 6 — Evidence Ledger
-- Provider-agnostic evidence storage with custody chain and redaction support
-- ============================================================================

-- 1. evidence_records — One row per uploaded evidence item
CREATE TABLE evidence_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    storage_provider_id UUID NOT NULL REFERENCES storage_providers(id),
    content_ref TEXT,
    content_type TEXT NOT NULL
        CHECK (content_type IN ('IMAGE', 'AUDIO', 'VIDEO', 'DOCUMENT', 'CERTIFICATE')),
    mime_type TEXT NOT NULL,
    file_size_bytes BIGINT,
    original_filename TEXT,
    content_hash TEXT NOT NULL,
    trust_level TEXT NOT NULL
        CHECK (trust_level IN (
            'INSTITUTIONAL', 'TEACHER_DIRECT', 'PARTNER_SUBMITTED',
            'EXTERNAL_CERTIFICATE', 'PARENT_UPLOADED'
        )),
    classification TEXT NOT NULL DEFAULT 'STANDARD'
        CHECK (classification IN ('STANDARD', 'SENSITIVE', 'RESTRICTED')),
    uploaded_by UUID NOT NULL REFERENCES users(id),
    uploaded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    verified_by UUID REFERENCES users(id),
    verified_at TIMESTAMPTZ,
    is_redacted BOOLEAN NOT NULL DEFAULT FALSE,
    redacted_at TIMESTAMPTZ,
    redacted_by UUID REFERENCES users(id),
    -- EXIF integrity analysis results
    exif_timestamp TIMESTAMPTZ,
    exif_gps_lat DECIMAL(10, 8),
    exif_gps_lon DECIMAL(11, 8),
    exif_device_make TEXT,
    exif_device_model TEXT,
    exif_editing_software TEXT,
    integrity_score DECIMAL(3, 2) CHECK (integrity_score >= 0 AND integrity_score <= 1),
    integrity_flags TEXT[] NOT NULL DEFAULT '{}',
    integrity_recommendation TEXT
        CHECK (integrity_recommendation IS NULL OR
               integrity_recommendation IN ('ACCEPT', 'REVIEW', 'QUERY_TEACHER')),
    gps_distance_from_school_km DECIMAL(10, 3),
    exif_analysis_completed_at TIMESTAMPTZ,
    metadata JSONB DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. evidence_custody_events — Immutable chain of events for each evidence record
CREATE TABLE evidence_custody_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    evidence_id UUID NOT NULL REFERENCES evidence_records(id) ON DELETE RESTRICT,
    event_type TEXT NOT NULL
        CHECK (event_type IN (
            'UPLOADED', 'VERIFIED', 'ATTACHED', 'DETACHED',
            'REDACTED', 'ACCESSED', 'TRANSFERRED', 'INTEGRITY_CHECKED'
        )),
    performed_by UUID NOT NULL REFERENCES users(id),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    details JSONB,
    prev_event_hash TEXT,
    event_hash TEXT NOT NULL DEFAULT ''
);

CREATE OR REPLACE FUNCTION compute_custody_event_hash()
RETURNS TRIGGER AS $$
BEGIN
    NEW.event_hash := encode(sha256(
        (NEW.id::text || NEW.event_type || NEW.evidence_id::text
         || extract(epoch from NEW.performed_at)::text
         || COALESCE(NEW.prev_event_hash, ''))::bytea
    ), 'hex');
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_custody_event_hash
    BEFORE INSERT ON evidence_custody_events
    FOR EACH ROW
    EXECUTE FUNCTION compute_custody_event_hash();

-- Append-only enforcement for custody events
CREATE RULE no_custody_update AS ON UPDATE TO evidence_custody_events DO INSTEAD NOTHING;
CREATE RULE no_custody_delete AS ON DELETE TO evidence_custody_events DO INSTEAD NOTHING;

-- 3. evidence_access_log — Every access to RESTRICTED evidence is logged
CREATE TABLE evidence_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    evidence_id UUID NOT NULL REFERENCES evidence_records(id),
    accessed_by UUID NOT NULL REFERENCES users(id),
    accessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    access_type TEXT NOT NULL CHECK (access_type IN ('VIEW', 'DOWNLOAD', 'SHARE')),
    ip_address INET,
    user_agent TEXT,
    access_granted BOOLEAN NOT NULL DEFAULT TRUE,
    denial_reason TEXT
);

-- 4. redaction_requests — DPDP Act erasure workflow
CREATE TABLE redaction_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    evidence_id UUID NOT NULL REFERENCES evidence_records(id),
    requested_by UUID NOT NULL REFERENCES users(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    reason TEXT NOT NULL,
    legal_basis TEXT NOT NULL
        CHECK (legal_basis IN ('DPDP_ERASURE', 'COURT_ORDER', 'ADMINISTRATIVE', 'CONSENT_WITHDRAWN')),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'APPROVED', 'EXECUTED', 'REJECTED')),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ,
    executed_at TIMESTAMPTZ,
    rejection_reason TEXT
);

INSERT INTO schema_migrations (version, description) VALUES ('V006', 'Layer 6 — Evidence Ledger');
