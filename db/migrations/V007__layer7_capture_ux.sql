-- ============================================================================
-- Layer 7 — Capture UX (Offline-First)
-- Teacher observation capture with bi-temporal timestamps and sync
-- ============================================================================

-- 1. offline_device_registry — Maps device IDs to registered teacher devices
CREATE TABLE offline_device_registry (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    device_id TEXT NOT NULL,
    device_name TEXT,
    device_platform TEXT CHECK (device_platform IN ('ANDROID', 'IOS', 'WEB')),
    app_version TEXT,
    last_sync_at TIMESTAMPTZ,
    last_gps_fix_at TIMESTAMPTZ,
    gps_clock_offset_ms BIGINT,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    registered_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_device UNIQUE (tenant_id, device_id)
);

-- 2. capture_sessions — A teacher's capture context for a session
CREATE TABLE capture_sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    device_id TEXT,
    session_type TEXT NOT NULL DEFAULT 'OBSERVATION'
        CHECK (session_type IN ('OBSERVATION', 'ASSESSMENT', 'GROUP_ACTIVITY', 'FIELD_TRIP')),
    activity_description TEXT,
    location_lat DECIMAL(10, 8),
    location_lon DECIMAL(11, 8),
    location_accuracy_m DECIMAL(10, 2),
    started_at TIMESTAMPTZ NOT NULL,
    ended_at TIMESTAMPTZ,
    is_offline BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. mastery_event_drafts — Offline queue entries for observation captures
CREATE TABLE mastery_event_drafts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    local_id TEXT NOT NULL,
    capture_session_id UUID REFERENCES capture_sessions(id),
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    observed_at TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ,
    timestamp_source TEXT NOT NULL DEFAULT 'DEVICE_CLOCK'
        CHECK (timestamp_source IN ('GPS_FIX', 'GPS_OFFSET', 'NTP_SYNCED', 'DEVICE_CLOCK')),
    timestamp_confidence TEXT NOT NULL DEFAULT 'LOW'
        CHECK (timestamp_confidence IN ('HIGH', 'MEDIUM', 'LOW')),
    numeric_value DECIMAL(3, 2) NOT NULL CHECK (numeric_value >= 0 AND numeric_value <= 1),
    descriptor_level_id UUID REFERENCES descriptor_levels(id),
    observation_note TEXT,
    evidence_local_ids TEXT[] NOT NULL DEFAULT '{}',
    source_type TEXT NOT NULL DEFAULT 'DIRECT_OBSERVATION'
        CHECK (source_type IN (
            'DIRECT_OBSERVATION', 'SELF_ASSESSMENT', 'PEER_ASSESSMENT', 'HISTORICAL_ENTRY'
        )),
    sync_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (sync_status IN ('PENDING', 'SYNCING', 'SYNCED', 'CONFLICT', 'FAILED')),
    sync_error TEXT,
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_local_id UNIQUE (tenant_id, local_id)
);

-- 4. evidence_upload_queue — Offline queue for photos and media
CREATE TABLE evidence_upload_queue (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    local_id TEXT NOT NULL,
    draft_id UUID REFERENCES mastery_event_drafts(id),
    content_type TEXT NOT NULL,
    mime_type TEXT NOT NULL,
    local_file_path TEXT NOT NULL,
    file_size_bytes BIGINT,
    content_hash TEXT,
    upload_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (upload_status IN ('PENDING', 'UPLOADING', 'UPLOADED', 'FAILED')),
    evidence_record_id UUID REFERENCES evidence_records(id),
    upload_error TEXT,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 5,
    device_id TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_upload_local_id UNIQUE (tenant_id, local_id)
);

-- 5. sync_conflicts — Records conflicts detected during sync
CREATE TABLE sync_conflicts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    draft_id UUID NOT NULL REFERENCES mastery_event_drafts(id),
    existing_event_id UUID,
    conflict_type TEXT NOT NULL
        CHECK (conflict_type IN ('DUPLICATE', 'DIVERGENT', 'TIMESTAMP_MISMATCH')),
    device_version JSONB NOT NULL,
    server_version JSONB,
    resolution TEXT
        CHECK (resolution IS NULL OR resolution IN ('KEEP_DEVICE', 'KEEP_SERVER', 'MERGE', 'DISCARD')),
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V007', 'Layer 7 — Capture UX');
