-- ============================================================================
-- V013 — Gap Fixes: Partitioning, Extensions, audit_viewer Restrictions
-- ============================================================================

-- ============================================================
-- Gap #2: mastery_events partitioned by academic_year_id
-- ============================================================
-- PostgreSQL requires partitioning at CREATE TABLE time.
-- Strategy: create a partitioned copy, migrate data, swap names.

-- Step 1: Create the partitioned replacement table
CREATE TABLE mastery_events_partitioned (
    id UUID NOT NULL DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL,
    student_id UUID NOT NULL,
    competency_id UUID NOT NULL,
    class_id UUID NOT NULL,
    academic_year_id UUID,
    term_id UUID,
    assessor_id UUID NOT NULL,
    rubric_completion_id UUID,
    numeric_value DECIMAL(3, 2) NOT NULL CHECK (numeric_value >= 0 AND numeric_value <= 1),
    descriptor_level_id UUID,
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
    superseded_by UUID,
    evidence_record_ids UUID[] NOT NULL DEFAULT '{}',
    observation_note TEXT,
    metadata JSONB DEFAULT '{}',
    content_hash TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT mastery_no_naked_scoring_part CHECK (
        evidence_record_ids != '{}' OR
        (observation_note IS NOT NULL AND length(trim(observation_note)) > 0)
    ),
    PRIMARY KEY (id, academic_year_id)
) PARTITION BY LIST (academic_year_id);

-- Default partition for NULL academic_year_id and unmatched values
CREATE TABLE mastery_events_default PARTITION OF mastery_events_partitioned DEFAULT;

-- Step 2: Migrate existing data
INSERT INTO mastery_events_partitioned
SELECT * FROM mastery_events;

-- Step 3: Drop old triggers, rules, policies on old table
DROP TRIGGER IF EXISTS trg_protect_active_mastery ON mastery_events;
DROP TRIGGER IF EXISTS trg_mastery_content_hash ON mastery_events;

-- Step 4: Swap tables
ALTER TABLE mastery_events RENAME TO mastery_events_old;
ALTER TABLE mastery_events_partitioned RENAME TO mastery_events;

-- Step 5: Recreate triggers on the new partitioned table
CREATE TRIGGER trg_mastery_content_hash
    BEFORE INSERT ON mastery_events
    FOR EACH ROW
    EXECUTE FUNCTION compute_mastery_content_hash();

CREATE TRIGGER trg_protect_active_mastery
    BEFORE UPDATE OR DELETE ON mastery_events
    FOR EACH ROW
    EXECUTE FUNCTION protect_active_mastery_events();

-- Step 6: Recreate indexes on partitioned table
CREATE INDEX idx_mastery_events_student_comp_p ON mastery_events(student_id, competency_id, observed_at);
CREATE INDEX idx_mastery_events_class_p ON mastery_events(class_id, academic_year_id);
CREATE INDEX idx_mastery_events_status_p ON mastery_events(event_status);
CREATE INDEX idx_mastery_events_metadata_p ON mastery_events USING GIN (metadata);

-- Step 7: Drop old table
DROP TABLE mastery_events_old CASCADE;

-- ============================================================
-- Gap #3: pg_cron and pgaudit extensions
-- These may not be available on all PostgreSQL installations.
-- We attempt to create them; failure is non-fatal.
-- ============================================================
DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pg_cron;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron extension not available — scheduled jobs will use application-level scheduling';
END $$;

DO $$
BEGIN
    CREATE EXTENSION IF NOT EXISTS pgaudit;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pgaudit extension not available — audit logging uses application-level audit_log table';
END $$;

-- ============================================================
-- Gap #16: audit_viewer role RLS restrictions
-- audit_viewer can only read aggregate/summary tables.
-- Student-level data is blocked entirely.
-- ============================================================

-- Grant SELECT on aggregate-only tables to audit_viewer
DO $$
DECLARE
    aggregate_tables TEXT[] := ARRAY[
        'mastery_aggregates', 'inclusion_indicators',
        'peer_assessment_aggregates', 'feedback_response_rates',
        'year_snapshots', 'year_close_completeness_checks',
        'schema_migrations', 'academic_stages', 'supported_languages'
    ];
    t TEXT;
BEGIN
    FOREACH t IN ARRAY aggregate_tables LOOP
        EXECUTE format('GRANT SELECT ON %I TO audit_viewer', t);
    END LOOP;
END $$;

-- Create specific RLS policies for audit_viewer on student-level tables
-- These explicitly DENY access to the audit_viewer role

DO $$
DECLARE
    student_data_tables TEXT[] := ARRAY[
        'student_profiles', 'student_enrolments', 'student_parent_links',
        'parent_profiles', 'data_consent_records', 'consent_otp_attempts',
        'mastery_events', 'mastery_event_drafts', 'evidence_records',
        'rubric_completion_records', 'feedback_requests', 'feedback_responses',
        'feedback_response_items', 'intervention_plans', 'intervention_alerts',
        'student_disability_profiles', 'rubric_overlays',
        'self_assessment_mastery_links', 'welfare_case_access_log'
    ];
    t TEXT;
BEGIN
    FOREACH t IN ARRAY student_data_tables LOOP
        EXECUTE format('DROP POLICY IF EXISTS audit_viewer_block ON %I', t);
        EXECUTE format(
            'CREATE POLICY audit_viewer_block ON %I FOR SELECT TO audit_viewer USING (FALSE)',
            t
        );
    END LOOP;
END $$;

INSERT INTO schema_migrations (version, description)
VALUES ('V013', 'Gap fixes: partitioning, extensions, audit_viewer RLS');
