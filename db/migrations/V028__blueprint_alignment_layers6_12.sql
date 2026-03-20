-- ============================================================================
-- V028 — Blueprint Alignment for Layers 6-12
-- Additive-only: CREATE TABLE IF NOT EXISTS / ALTER TABLE ADD COLUMN IF NOT EXISTS
-- ============================================================================

-- ========================================
-- LAYER 6 — Evidence Ledger additions
-- ========================================

-- 6.1 evidence_competency_tags
CREATE TABLE IF NOT EXISTS evidence_competency_tags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    evidence_id     UUID NOT NULL REFERENCES evidence_records(id) ON DELETE RESTRICT,
    competency_id   UUID NOT NULL REFERENCES competencies(id) ON DELETE RESTRICT,
    tagged_by       UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6.2 evidence_activity_tags
CREATE TABLE IF NOT EXISTS evidence_activity_tags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    evidence_id     UUID NOT NULL REFERENCES evidence_records(id) ON DELETE RESTRICT,
    activity_type   TEXT NOT NULL,
    tagged_by       UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6.3 evidence_deduplication_log
CREATE TABLE IF NOT EXISTS evidence_deduplication_log (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    evidence_id     UUID NOT NULL REFERENCES evidence_records(id) ON DELETE RESTRICT,
    duplicate_of_id UUID NOT NULL REFERENCES evidence_records(id) ON DELETE RESTRICT,
    match_method    TEXT NOT NULL,
    match_score     DECIMAL,
    resolution      TEXT,
    resolved_by     UUID REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6.4 evidence_consent_links
CREATE TABLE IF NOT EXISTS evidence_consent_links (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    evidence_id       UUID NOT NULL REFERENCES evidence_records(id) ON DELETE RESTRICT,
    consent_record_id UUID NOT NULL REFERENCES data_consent_records(id) ON DELETE RESTRICT,
    linked_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6.5 evidence_group_captures
CREATE TABLE IF NOT EXISTS evidence_group_captures (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    capture_session_id  UUID NOT NULL REFERENCES capture_sessions(id) ON DELETE RESTRICT,
    evidence_ids        UUID[] NOT NULL DEFAULT '{}',
    student_ids         UUID[] NOT NULL DEFAULT '{}',
    captured_by         UUID NOT NULL REFERENCES users(id),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6.6 ALTER evidence_records
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS student_profile_id   UUID REFERENCES student_profiles(id);
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS academic_year_id     UUID REFERENCES academic_years(id);
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS observed_at          TIMESTAMPTZ;
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS recorded_at         TIMESTAMPTZ;
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS capture_role        TEXT;
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS verification_status TEXT DEFAULT 'UNVERIFIED';
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS privacy_status      TEXT DEFAULT 'STANDARD';
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS offline_captured    BOOLEAN DEFAULT FALSE;
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS partner_id          UUID;
ALTER TABLE evidence_records ADD COLUMN IF NOT EXISTS deleted_at          TIMESTAMPTZ;

-- 6.7 ALTER evidence_access_log
ALTER TABLE evidence_access_log ADD COLUMN IF NOT EXISTS access_role    TEXT;
ALTER TABLE evidence_access_log ADD COLUMN IF NOT EXISTS access_purpose TEXT;
ALTER TABLE evidence_access_log ADD COLUMN IF NOT EXISTS request_id     UUID;

-- 6.8 ALTER redaction_requests
ALTER TABLE redaction_requests ADD COLUMN IF NOT EXISTS request_type   TEXT;
ALTER TABLE redaction_requests ADD COLUMN IF NOT EXISTS target_action  TEXT DEFAULT 'REDACT';
ALTER TABLE redaction_requests ADD COLUMN IF NOT EXISTS deadline_date  DATE;

-- 6.9 Append-only rules on evidence_access_log
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_rules
        WHERE rulename = 'no_access_log_update'
          AND tablename = 'evidence_access_log'
    ) THEN
        CREATE RULE no_access_log_update AS ON UPDATE TO evidence_access_log DO INSTEAD NOTHING;
    END IF;
END $$;

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_rules
        WHERE rulename = 'no_access_log_delete'
          AND tablename = 'evidence_access_log'
    ) THEN
        CREATE RULE no_access_log_delete AS ON DELETE TO evidence_access_log DO INSTEAD NOTHING;
    END IF;
END $$;

-- ========================================
-- LAYER 7 — Capture UX additions
-- ========================================

-- 7.1 offline_queue_entries
CREATE TABLE IF NOT EXISTS offline_queue_entries (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    session_id      UUID NOT NULL REFERENCES capture_sessions(id) ON DELETE RESTRICT,
    entry_type      TEXT NOT NULL,
    payload         JSONB NOT NULL DEFAULT '{}',
    local_id        TEXT,
    sync_status     TEXT NOT NULL DEFAULT 'QUEUED',
    device_id       TEXT,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7.2 draft_edit_history
CREATE TABLE IF NOT EXISTS draft_edit_history (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    draft_id        UUID NOT NULL REFERENCES mastery_event_drafts(id) ON DELETE RESTRICT,
    edited_by       UUID NOT NULL REFERENCES users(id),
    field_changed   TEXT NOT NULL,
    old_value       TEXT,
    new_value       TEXT,
    edited_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7.3 sync_logs
CREATE TABLE IF NOT EXISTS sync_logs (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    device_id           TEXT NOT NULL,
    sync_started_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    sync_completed_at   TIMESTAMPTZ,
    entries_sent        INTEGER NOT NULL DEFAULT 0,
    entries_accepted    INTEGER NOT NULL DEFAULT 0,
    entries_conflicted  INTEGER NOT NULL DEFAULT 0,
    errors              JSONB,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7.4 queue_overflow_events
CREATE TABLE IF NOT EXISTS queue_overflow_events (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    device_id       TEXT NOT NULL,
    queue_size      INTEGER NOT NULL,
    overflow_action TEXT NOT NULL,
    occurred_at     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7.5 capture_shortcuts
CREATE TABLE IF NOT EXISTS capture_shortcuts (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id         UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id        UUID NOT NULL REFERENCES teacher_profiles(id) ON DELETE RESTRICT,
    shortcut_name     TEXT NOT NULL,
    competency_ids    UUID[] NOT NULL DEFAULT '{}',
    descriptor_presets JSONB,
    created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7.6 ALTER capture_sessions
ALTER TABLE capture_sessions ADD COLUMN IF NOT EXISTS academic_year_id UUID REFERENCES academic_years(id);
ALTER TABLE capture_sessions ADD COLUMN IF NOT EXISTS sync_status      TEXT;
ALTER TABLE capture_sessions ADD COLUMN IF NOT EXISTS entry_count      INTEGER DEFAULT 0;
ALTER TABLE capture_sessions ADD COLUMN IF NOT EXISTS conflict_count   INTEGER DEFAULT 0;

-- 7.7 ALTER mastery_event_drafts
ALTER TABLE mastery_event_drafts ADD COLUMN IF NOT EXISTS competency_uid      TEXT;
ALTER TABLE mastery_event_drafts ADD COLUMN IF NOT EXISTS draft_status        TEXT DEFAULT 'DRAFT';
ALTER TABLE mastery_event_drafts ADD COLUMN IF NOT EXISTS substitute_teacher  BOOLEAN DEFAULT FALSE;
ALTER TABLE mastery_event_drafts ADD COLUMN IF NOT EXISTS ai_assisted         BOOLEAN DEFAULT FALSE;

-- ========================================
-- LAYER 8 — Rubric Engine additions
-- ========================================

-- 8.1 descriptor_sets
CREATE TABLE IF NOT EXISTS descriptor_sets (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id   UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    set_code    TEXT NOT NULL,
    name        TEXT NOT NULL,
    stage_code  TEXT,
    levels      JSONB NOT NULL DEFAULT '[]',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_descriptor_sets_tenant_code UNIQUE (tenant_id, set_code)
);

-- 8.2 rubric_dimension_bindings
CREATE TABLE IF NOT EXISTS rubric_dimension_bindings (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    dimension_id        UUID NOT NULL REFERENCES rubric_dimensions(id) ON DELETE RESTRICT,
    descriptor_set_code TEXT NOT NULL,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8.3 rubric_template_year_assignments
CREATE TABLE IF NOT EXISTS rubric_template_year_assignments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    template_id     UUID NOT NULL REFERENCES rubric_templates(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    school_id       UUID NOT NULL REFERENCES schools(id) ON DELETE RESTRICT,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8.4 rubric_group_assessments
CREATE TABLE IF NOT EXISTS rubric_group_assessments (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    template_id     UUID NOT NULL REFERENCES rubric_templates(id) ON DELETE RESTRICT,
    class_id        UUID NOT NULL REFERENCES classes(id) ON DELETE RESTRICT,
    student_ids     UUID[] NOT NULL DEFAULT '{}',
    group_name      TEXT,
    assessed_by     UUID NOT NULL REFERENCES users(id),
    assessed_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8.5 rubric_group_individual_overrides
CREATE TABLE IF NOT EXISTS rubric_group_individual_overrides (
    id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id           UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    group_assessment_id UUID NOT NULL REFERENCES rubric_group_assessments(id) ON DELETE CASCADE,
    student_id          UUID NOT NULL REFERENCES student_profiles(id) ON DELETE RESTRICT,
    dimension_id        UUID NOT NULL REFERENCES rubric_dimensions(id) ON DELETE RESTRICT,
    override_level_code TEXT NOT NULL,
    override_note       TEXT,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8.6 ALTER rubric_templates
ALTER TABLE rubric_templates ADD COLUMN IF NOT EXISTS template_code              TEXT;
ALTER TABLE rubric_templates ADD COLUMN IF NOT EXISTS label_regional             TEXT;
ALTER TABLE rubric_templates ADD COLUMN IF NOT EXISTS framework_id               UUID;
ALTER TABLE rubric_templates ADD COLUMN IF NOT EXISTS superseded_by_id           UUID REFERENCES rubric_templates(id);
ALTER TABLE rubric_templates ADD COLUMN IF NOT EXISTS default_descriptor_set_code TEXT;
ALTER TABLE rubric_templates ADD COLUMN IF NOT EXISTS inter_rater_threshold      DECIMAL DEFAULT 0.250;
ALTER TABLE rubric_templates ADD COLUMN IF NOT EXISTS inter_rater_alert_role     TEXT;

-- ========================================
-- LAYER 9 — Mastery Aggregation additions
-- ========================================

-- 9.1 domain_aggregates
CREATE TABLE IF NOT EXISTS domain_aggregates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id      UUID NOT NULL REFERENCES student_profiles(id) ON DELETE RESTRICT,
    domain_id       UUID NOT NULL REFERENCES taxonomy_domains(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    aggregate_value DECIMAL,
    event_count     INTEGER NOT NULL DEFAULT 0,
    last_computed_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_domain_agg UNIQUE (tenant_id, student_id, domain_id, academic_year_id)
);

-- 9.2 class_mastery_aggregates
CREATE TABLE IF NOT EXISTS class_mastery_aggregates (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    class_id        UUID NOT NULL REFERENCES classes(id) ON DELETE RESTRICT,
    competency_id   UUID NOT NULL REFERENCES competencies(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    class_average   DECIMAL,
    student_count   INTEGER NOT NULL DEFAULT 0,
    last_computed_at TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT uq_class_mastery_agg UNIQUE (tenant_id, class_id, competency_id, academic_year_id)
);

-- 9.3 mastery_outlier_flags
CREATE TABLE IF NOT EXISTS mastery_outlier_flags (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id       UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id      UUID NOT NULL REFERENCES student_profiles(id) ON DELETE RESTRICT,
    competency_id   UUID NOT NULL REFERENCES competencies(id) ON DELETE RESTRICT,
    flag_type       TEXT NOT NULL,
    flag_reason     TEXT,
    flagged_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    reviewed        BOOLEAN NOT NULL DEFAULT FALSE,
    reviewed_by     UUID REFERENCES users(id),
    reviewed_at     TIMESTAMPTZ
);

-- 9.4 ALTER mastery_events
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS taxonomy_version_id    UUID;
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS descriptor_level_code  TEXT;
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS descriptor_set_code    TEXT;
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS numeric_value_version  TEXT;
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS is_amended             BOOLEAN DEFAULT FALSE;
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS amendment_of_event_id  UUID;
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS applied_overlay_id     UUID;
ALTER TABLE mastery_events ADD COLUMN IF NOT EXISTS ai_assisted            BOOLEAN DEFAULT FALSE;

-- 9.5 ALTER mastery_aggregates
ALTER TABLE mastery_aggregates ADD COLUMN IF NOT EXISTS recency_weighted_mastery DECIMAL;
ALTER TABLE mastery_aggregates ADD COLUMN IF NOT EXISTS simple_average_mastery   DECIMAL;
ALTER TABLE mastery_aggregates ADD COLUMN IF NOT EXISTS peak_mastery             DECIMAL;
ALTER TABLE mastery_aggregates ADD COLUMN IF NOT EXISTS computation_run_id       UUID;
ALTER TABLE mastery_aggregates ADD COLUMN IF NOT EXISTS year_snapshot_id         UUID;
ALTER TABLE mastery_aggregates ADD COLUMN IF NOT EXISTS is_snapshot_frozen       BOOLEAN DEFAULT FALSE;

-- ========================================
-- LAYER 10 — 360° Feedback additions
-- ========================================

-- 10.1 ALTER reflection_prompt_sets
ALTER TABLE reflection_prompt_sets ADD COLUMN IF NOT EXISTS prompt_set_code TEXT;
ALTER TABLE reflection_prompt_sets ADD COLUMN IF NOT EXISTS term_context    TEXT;
ALTER TABLE reflection_prompt_sets ADD COLUMN IF NOT EXISTS language_code   TEXT;

-- 10.2 ALTER feedback_requests
ALTER TABLE feedback_requests ADD COLUMN IF NOT EXISTS request_type      TEXT;
ALTER TABLE feedback_requests ADD COLUMN IF NOT EXISTS escalated_to      UUID;
ALTER TABLE feedback_requests ADD COLUMN IF NOT EXISTS escalation_reason TEXT;

-- 10.3 ALTER feedback_responses
ALTER TABLE feedback_responses ADD COLUMN IF NOT EXISTS respondent_user_id  UUID;
ALTER TABLE feedback_responses ADD COLUMN IF NOT EXISTS subject_student_id  UUID;
ALTER TABLE feedback_responses ADD COLUMN IF NOT EXISTS response_language   TEXT;
ALTER TABLE feedback_responses ADD COLUMN IF NOT EXISTS ai_summarised       BOOLEAN DEFAULT FALSE;
ALTER TABLE feedback_responses ADD COLUMN IF NOT EXISTS ai_summary_text     TEXT;

-- 10.4 ALTER peer_assessment_aggregates
ALTER TABLE peer_assessment_aggregates ADD COLUMN IF NOT EXISTS competency_uid    TEXT;
ALTER TABLE peer_assessment_aggregates ADD COLUMN IF NOT EXISTS computation_run_id UUID;
ALTER TABLE peer_assessment_aggregates ADD COLUMN IF NOT EXISTS distribution       JSONB;
ALTER TABLE peer_assessment_aggregates ADD COLUMN IF NOT EXISTS moderated_count    INTEGER DEFAULT 0;

-- ========================================
-- LAYER 11 — Intervention Engine additions
-- ========================================

-- 11.1 ALTER intervention_trigger_rules
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS rule_code             TEXT;
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS rule_version          INTEGER DEFAULT 1;
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS rule_expression       JSONB;
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS default_assignee_role TEXT;
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS alert_priority        TEXT;
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS cooldown_days         INTEGER;
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS effective_from        DATE;
ALTER TABLE intervention_trigger_rules ADD COLUMN IF NOT EXISTS effective_to          DATE;

-- 11.2 ALTER intervention_alerts
ALTER TABLE intervention_alerts ADD COLUMN IF NOT EXISTS academic_year_id  UUID;
ALTER TABLE intervention_alerts ADD COLUMN IF NOT EXISTS rule_code         TEXT;
ALTER TABLE intervention_alerts ADD COLUMN IF NOT EXISTS signal_type       TEXT;
ALTER TABLE intervention_alerts ADD COLUMN IF NOT EXISTS signal_data       JSONB;
ALTER TABLE intervention_alerts ADD COLUMN IF NOT EXISTS alert_priority    TEXT;
ALTER TABLE intervention_alerts ADD COLUMN IF NOT EXISTS detection_run_id  UUID;
ALTER TABLE intervention_alerts ADD COLUMN IF NOT EXISTS notified_users    UUID[];

-- 11.3 ALTER intervention_plans
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS problem_description        TEXT;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS support_approach            TEXT;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS expected_outcome            TEXT;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS plan_start_date             DATE;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS plan_review_date            DATE;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS plan_target_date            DATE;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS closure_requires_evidence   BOOLEAN DEFAULT TRUE;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS assigned_to                UUID;
ALTER TABLE intervention_plans ADD COLUMN IF NOT EXISTS recurrence_of_plan_id      UUID;

-- 11.4 ALTER intervention_review_checkpoints
ALTER TABLE intervention_review_checkpoints ADD COLUMN IF NOT EXISTS checkpoint_number      INTEGER;
ALTER TABLE intervention_review_checkpoints ADD COLUMN IF NOT EXISTS review_summary         TEXT;
ALTER TABLE intervention_review_checkpoints ADD COLUMN IF NOT EXISTS plan_status_at_review  TEXT;
ALTER TABLE intervention_review_checkpoints ADD COLUMN IF NOT EXISTS overdue_alert_sent     BOOLEAN DEFAULT FALSE;

-- ========================================
-- LAYER 12 — Inclusion / UDID additions
-- ========================================

-- 12.1 ALTER student_disability_profiles
ALTER TABLE student_disability_profiles ADD COLUMN IF NOT EXISTS udid_disability_subcategory TEXT;
ALTER TABLE student_disability_profiles ADD COLUMN IF NOT EXISTS has_iep                    BOOLEAN DEFAULT FALSE;
ALTER TABLE student_disability_profiles ADD COLUMN IF NOT EXISTS iep_document_evidence_id   UUID;
ALTER TABLE student_disability_profiles ADD COLUMN IF NOT EXISTS iep_review_date            DATE;
ALTER TABLE student_disability_profiles ADD COLUMN IF NOT EXISTS profile_status             TEXT DEFAULT 'ACTIVE';
ALTER TABLE student_disability_profiles ADD COLUMN IF NOT EXISTS created_by                 UUID;

-- 12.2 ALTER overlay_templates
ALTER TABLE overlay_templates ADD COLUMN IF NOT EXISTS template_code             TEXT;
ALTER TABLE overlay_templates ADD COLUMN IF NOT EXISTS applies_to_stages         TEXT[];
ALTER TABLE overlay_templates ADD COLUMN IF NOT EXISTS requires_iep              BOOLEAN DEFAULT FALSE;
ALTER TABLE overlay_templates ADD COLUMN IF NOT EXISTS target_accommodation_tier TEXT;

-- 12.3 ALTER rubric_overlays
ALTER TABLE rubric_overlays ADD COLUMN IF NOT EXISTS overlay_scope               TEXT DEFAULT 'COMPETENCY';
ALTER TABLE rubric_overlays ADD COLUMN IF NOT EXISTS academic_year_id            UUID;
ALTER TABLE rubric_overlays ADD COLUMN IF NOT EXISTS modified_evidence_requirement TEXT;
ALTER TABLE rubric_overlays ADD COLUMN IF NOT EXISTS allowed_response_formats    TEXT[];
ALTER TABLE rubric_overlays ADD COLUMN IF NOT EXISTS extra_time_multiplier       DECIMAL DEFAULT 1.0;
ALTER TABLE rubric_overlays ADD COLUMN IF NOT EXISTS expiry_warning_sent         BOOLEAN DEFAULT FALSE;
ALTER TABLE rubric_overlays ADD COLUMN IF NOT EXISTS renewed_from_overlay_id     UUID;

-- 12.4 ALTER credit_overlay_links
ALTER TABLE credit_overlay_links ADD COLUMN IF NOT EXISTS academic_year_id      UUID;
ALTER TABLE credit_overlay_links ADD COLUMN IF NOT EXISTS credit_domain_bucket  TEXT;
ALTER TABLE credit_overlay_links ADD COLUMN IF NOT EXISTS threshold_rationale   TEXT;
ALTER TABLE credit_overlay_links ADD COLUMN IF NOT EXISTS approved_by           UUID;

-- ========================================
-- Schema migration record
-- ========================================
INSERT INTO schema_migrations (version, description)
VALUES ('V028', 'Blueprint alignment — Layers 6-12 additive columns and tables');
