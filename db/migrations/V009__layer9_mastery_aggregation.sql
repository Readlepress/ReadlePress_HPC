-- ============================================================================
-- Layer 9 — Mastery Aggregation Engine
-- EWM computation, growth curves, idempotent job queue
-- ============================================================================

-- 1. mastery_events — The verified observation records. Immutable after creation.
CREATE TABLE mastery_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    academic_year_id UUID REFERENCES academic_years(id),
    term_id UUID REFERENCES terms(id),
    assessor_id UUID NOT NULL REFERENCES users(id),
    rubric_completion_id UUID REFERENCES rubric_completion_records(id),
    numeric_value DECIMAL(3, 2) NOT NULL CHECK (numeric_value >= 0 AND numeric_value <= 1),
    descriptor_level_id UUID REFERENCES descriptor_levels(id),
    source_type TEXT NOT NULL DEFAULT 'DIRECT_OBSERVATION'
        CHECK (source_type IN (
            'DIRECT_OBSERVATION', 'SELF_ASSESSMENT', 'PEER_ASSESSMENT', 'HISTORICAL_ENTRY'
        )),
    observed_at TIMESTAMPTZ NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL,
    synced_at TIMESTAMPTZ,
    timestamp_source TEXT NOT NULL DEFAULT 'DEVICE_CLOCK',
    timestamp_confidence TEXT NOT NULL DEFAULT 'LOW'
        CHECK (timestamp_confidence IN ('HIGH', 'MEDIUM', 'LOW')),
    event_status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (event_status IN ('DRAFT', 'ACTIVE', 'SUPERSEDED', 'VOIDED')),
    superseded_by UUID REFERENCES mastery_events(id),
    evidence_record_ids UUID[] NOT NULL DEFAULT '{}',
    observation_note TEXT,
    metadata JSONB DEFAULT '{}',
    content_hash TEXT NOT NULL GENERATED ALWAYS AS (
        encode(sha256(
            (id::text || student_id::text || competency_id::text
             || numeric_value::text || observed_at::text)::bytea
        ), 'hex')
    ) STORED,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT mastery_no_naked_scoring CHECK (
        evidence_record_ids != '{}' OR
        (observation_note IS NOT NULL AND length(trim(observation_note)) > 0)
    )
);

-- Trigger: Immutability for ACTIVE mastery events
CREATE OR REPLACE FUNCTION protect_active_mastery_events()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP = 'DELETE' AND OLD.event_status = 'ACTIVE' THEN
        RAISE EXCEPTION 'Cannot delete ACTIVE mastery events. Use the amendment workflow.'
            USING ERRCODE = 'check_violation';
    END IF;

    IF TG_OP = 'UPDATE' AND OLD.event_status = 'ACTIVE' THEN
        IF NEW.event_status = 'SUPERSEDED' AND NEW.superseded_by IS NOT NULL THEN
            RETURN NEW;
        END IF;
        IF NEW.event_status = 'VOIDED' THEN
            RETURN NEW;
        END IF;
        RAISE EXCEPTION 'Cannot modify ACTIVE mastery events. Use the amendment workflow.'
            USING ERRCODE = 'check_violation';
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_active_mastery
    BEFORE UPDATE OR DELETE ON mastery_events
    FOR EACH ROW
    EXECUTE FUNCTION protect_active_mastery_events();

-- 2. aggregation_policy — Per-tenant EWM configuration
CREATE TABLE aggregation_policy (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    source_type TEXT NOT NULL,
    alpha DECIMAL(5, 3) NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_policy UNIQUE (tenant_id, source_type)
);

-- Seed default alpha values
-- (These are inserted per-tenant on tenant creation; global defaults here)

-- 3. mastery_aggregates — Pre-computed aggregate per student per competency
CREATE TABLE mastery_aggregates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    academic_year_id UUID REFERENCES academic_years(id),
    current_ewm DECIMAL(5, 4) CHECK (current_ewm >= 0 AND current_ewm <= 1),
    event_count INTEGER NOT NULL DEFAULT 0,
    last_event_at TIMESTAMPTZ,
    trend_direction TEXT CHECK (trend_direction IN ('IMPROVING', 'STABLE', 'DECLINING', 'INSUFFICIENT_DATA')),
    trend_slope DECIMAL(8, 6),
    confidence_score DECIMAL(3, 2) CHECK (confidence_score >= 0 AND confidence_score <= 1),
    pending_draft_count INTEGER NOT NULL DEFAULT 0,
    last_aggregated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_aggregate UNIQUE (tenant_id, student_id, competency_id, academic_year_id)
);

-- 4. longitudinal_growth_curves — JSONB time-series for charting
CREATE TABLE longitudinal_growth_curves (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    data_points JSONB NOT NULL DEFAULT '[]',
    last_updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_growth_curve UNIQUE (tenant_id, student_id, competency_id)
);

-- 5. mastery_aggregation_jobs — Idempotent computation job queue
CREATE TABLE mastery_aggregation_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    academic_year_id UUID REFERENCES academic_years(id),
    idempotency_key TEXT NOT NULL UNIQUE,
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PROCESSING', 'COMPLETED', 'FAILED', 'SUPERSEDED')),
    priority INTEGER NOT NULL DEFAULT 5,
    retry_count INTEGER NOT NULL DEFAULT 0,
    max_retries INTEGER NOT NULL DEFAULT 3,
    error_message TEXT,
    started_at TIMESTAMPTZ,
    completed_at TIMESTAMPTZ,
    queued_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. mastery_event_amendment_log — Corrections requiring dual approval
CREATE TABLE mastery_event_amendment_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    original_event_id UUID NOT NULL REFERENCES mastery_events(id),
    new_event_id UUID REFERENCES mastery_events(id),
    amendment_type TEXT NOT NULL
        CHECK (amendment_type IN ('CORRECTION', 'VOIDING', 'REASSESSMENT')),
    reason TEXT NOT NULL,
    before_state JSONB NOT NULL,
    after_state JSONB,
    requested_by UUID NOT NULL REFERENCES users(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'FIRST_APPROVED', 'APPROVED', 'REJECTED')),
    first_approver_id UUID REFERENCES users(id),
    first_approved_at TIMESTAMPTZ,
    second_approver_id UUID REFERENCES users(id),
    second_approved_at TIMESTAMPTZ,
    CONSTRAINT amendment_dual_approval CHECK (
        first_approver_id IS NULL OR
        second_approver_id IS NULL OR
        first_approver_id != second_approver_id
    ),
    CONSTRAINT amendment_self_approval CHECK (
        (first_approver_id IS NULL OR first_approver_id != requested_by)
        AND (second_approver_id IS NULL OR second_approver_id != requested_by)
    )
);

-- Append-only enforcement for mastery_event_amendment_log
CREATE RULE no_mastery_amendment_update AS ON UPDATE TO mastery_event_amendment_log DO INSTEAD NOTHING;
CREATE RULE no_mastery_amendment_delete AS ON DELETE TO mastery_event_amendment_log DO INSTEAD NOTHING;

-- 7. stage_readiness_assessments — Whether student is ready for next NEP stage
CREATE TABLE stage_readiness_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    from_stage_id UUID NOT NULL REFERENCES academic_stages(id),
    to_stage_id UUID NOT NULL REFERENCES academic_stages(id),
    academic_year_id UUID REFERENCES academic_years(id),
    is_ready BOOLEAN NOT NULL DEFAULT FALSE,
    total_bridge_competencies INTEGER NOT NULL DEFAULT 0,
    met_competencies INTEGER NOT NULL DEFAULT 0,
    gap_competency_ids UUID[] NOT NULL DEFAULT '{}',
    gap_details JSONB DEFAULT '{}',
    assessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_readiness UNIQUE (tenant_id, student_id, from_stage_id, to_stage_id, academic_year_id)
);

INSERT INTO schema_migrations (version, description) VALUES ('V009', 'Layer 9 — Mastery Aggregation Engine');
