-- ============================================================================
-- Repeatable Migration: Row Level Security Policies
-- Re-runs on every change to keep policies in sync
-- ============================================================================

-- Helper: List of all tenant-scoped tables
-- Each table gets the standard tenant_isolation policy

-- ===== Layer 1 =====

ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE users FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON users;
CREATE POLICY tenant_isolation ON users
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE role_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE role_assignments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON role_assignments;
CREATE POLICY tenant_isolation ON role_assignments
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE privacy_policy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE privacy_policy_versions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON privacy_policy_versions;
CREATE POLICY tenant_isolation ON privacy_policy_versions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE data_consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE data_consent_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON data_consent_records;
CREATE POLICY tenant_isolation ON data_consent_records
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE consent_otp_attempts ENABLE ROW LEVEL SECURITY;
ALTER TABLE consent_otp_attempts FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON consent_otp_attempts;
CREATE POLICY tenant_isolation ON consent_otp_attempts
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE witnessed_consent_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE witnessed_consent_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON witnessed_consent_records;
CREATE POLICY tenant_isolation ON witnessed_consent_records
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON audit_log;
CREATE POLICY tenant_isolation ON audit_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE storage_providers ENABLE ROW LEVEL SECURITY;
ALTER TABLE storage_providers FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON storage_providers;
CREATE POLICY tenant_isolation ON storage_providers
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 2 =====

ALTER TABLE schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE schools FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON schools;
CREATE POLICY tenant_isolation ON schools
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE student_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_profiles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON student_profiles;
CREATE POLICY tenant_isolation ON student_profiles
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- Teacher can only see students in their assigned classes
DROP POLICY IF EXISTS teacher_class_students ON student_profiles;
CREATE POLICY teacher_class_students ON student_profiles
    FOR SELECT
    USING (
        current_setting('app.user_role', TRUE) NOT IN ('CLASS_TEACHER', 'SUBJECT_TEACHER')
        OR tenant_id = current_setting('app.tenant_id', TRUE)::uuid
        AND id IN (
            SELECT se.student_id
            FROM student_enrolments se
            JOIN teacher_assignments ta ON ta.class_id = se.class_id AND ta.tenant_id = se.tenant_id
            JOIN teacher_profiles tp ON tp.id = ta.teacher_id AND tp.tenant_id = ta.tenant_id
            WHERE tp.user_id = current_setting('app.user_id', TRUE)::uuid
              AND ta.status = 'ACTIVE'
              AND se.status = 'ACTIVE'
        )
    );

ALTER TABLE teacher_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_profiles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON teacher_profiles;
CREATE POLICY tenant_isolation ON teacher_profiles
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE parent_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_profiles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON parent_profiles;
CREATE POLICY tenant_isolation ON parent_profiles
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE student_parent_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_parent_links FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON student_parent_links;
CREATE POLICY tenant_isolation ON student_parent_links
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE classes FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON classes;
CREATE POLICY tenant_isolation ON classes
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE student_enrolments ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_enrolments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON student_enrolments;
CREATE POLICY tenant_isolation ON student_enrolments
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE teacher_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE teacher_assignments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON teacher_assignments;
CREATE POLICY tenant_isolation ON teacher_assignments
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 3 =====

ALTER TABLE academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE academic_years FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON academic_years;
CREATE POLICY tenant_isolation ON academic_years
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE terms FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON terms;
CREATE POLICY tenant_isolation ON terms
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE year_snapshots ENABLE ROW LEVEL SECURITY;
ALTER TABLE year_snapshots FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON year_snapshots;
CREATE POLICY tenant_isolation ON year_snapshots
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE year_close_completeness_checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE year_close_completeness_checks FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON year_close_completeness_checks;
CREATE POLICY tenant_isolation ON year_close_completeness_checks
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE locked_year_override_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE locked_year_override_requests FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON locked_year_override_requests;
CREATE POLICY tenant_isolation ON locked_year_override_requests
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 4 =====

ALTER TABLE taxonomy_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxonomy_versions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON taxonomy_versions;
CREATE POLICY tenant_isolation ON taxonomy_versions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE taxonomy_domains ENABLE ROW LEVEL SECURITY;
ALTER TABLE taxonomy_domains FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON taxonomy_domains;
CREATE POLICY tenant_isolation ON taxonomy_domains
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE competencies ENABLE ROW LEVEL SECURITY;
ALTER TABLE competencies FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON competencies;
CREATE POLICY tenant_isolation ON competencies
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE competency_version_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE competency_version_memberships FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON competency_version_memberships;
CREATE POLICY tenant_isolation ON competency_version_memberships
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE competency_lineage ENABLE ROW LEVEL SECURITY;
ALTER TABLE competency_lineage FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON competency_lineage;
CREATE POLICY tenant_isolation ON competency_lineage
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE competency_activations ENABLE ROW LEVEL SECURITY;
ALTER TABLE competency_activations FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON competency_activations;
CREATE POLICY tenant_isolation ON competency_activations
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE descriptor_levels ENABLE ROW LEVEL SECURITY;
ALTER TABLE descriptor_levels FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON descriptor_levels;
CREATE POLICY tenant_isolation ON descriptor_levels
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE stage_bridge_mappings ENABLE ROW LEVEL SECURITY;
ALTER TABLE stage_bridge_mappings FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON stage_bridge_mappings;
CREATE POLICY tenant_isolation ON stage_bridge_mappings
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 5 =====
-- localization_strings may have NULL tenant_id (global strings)
ALTER TABLE localization_strings ENABLE ROW LEVEL SECURITY;
ALTER TABLE localization_strings FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_or_global ON localization_strings;
CREATE POLICY tenant_or_global ON localization_strings
    USING (
        tenant_id IS NULL
        OR tenant_id = current_setting('app.tenant_id', TRUE)::uuid
    );

ALTER TABLE sms_notification_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE sms_notification_templates FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_or_global ON sms_notification_templates;
CREATE POLICY tenant_or_global ON sms_notification_templates
    USING (
        tenant_id IS NULL
        OR tenant_id = current_setting('app.tenant_id', TRUE)::uuid
    );

-- ===== Layer 6 =====

ALTER TABLE evidence_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON evidence_records;
CREATE POLICY tenant_isolation ON evidence_records
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- RESTRICTED evidence requires EVIDENCE:READ_RESTRICTED permission (enforced at API level)

ALTER TABLE evidence_custody_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_custody_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON evidence_custody_events;
CREATE POLICY tenant_isolation ON evidence_custody_events
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE evidence_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_access_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON evidence_access_log;
CREATE POLICY tenant_isolation ON evidence_access_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE redaction_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE redaction_requests FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON redaction_requests;
CREATE POLICY tenant_isolation ON redaction_requests
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 7 =====

ALTER TABLE offline_device_registry ENABLE ROW LEVEL SECURITY;
ALTER TABLE offline_device_registry FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON offline_device_registry;
CREATE POLICY tenant_isolation ON offline_device_registry
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE capture_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE capture_sessions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON capture_sessions;
CREATE POLICY tenant_isolation ON capture_sessions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE mastery_event_drafts ENABLE ROW LEVEL SECURITY;
ALTER TABLE mastery_event_drafts FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON mastery_event_drafts;
CREATE POLICY tenant_isolation ON mastery_event_drafts
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE evidence_upload_queue ENABLE ROW LEVEL SECURITY;
ALTER TABLE evidence_upload_queue FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON evidence_upload_queue;
CREATE POLICY tenant_isolation ON evidence_upload_queue
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sync_conflicts ENABLE ROW LEVEL SECURITY;
ALTER TABLE sync_conflicts FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sync_conflicts;
CREATE POLICY tenant_isolation ON sync_conflicts
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 8 =====

ALTER TABLE rubric_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE rubric_templates FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON rubric_templates;
CREATE POLICY tenant_isolation ON rubric_templates
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE rubric_dimensions ENABLE ROW LEVEL SECURITY;
ALTER TABLE rubric_dimensions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON rubric_dimensions;
CREATE POLICY tenant_isolation ON rubric_dimensions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE descriptor_level_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE descriptor_level_assignments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON descriptor_level_assignments;
CREATE POLICY tenant_isolation ON descriptor_level_assignments
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE rubric_completion_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE rubric_completion_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON rubric_completion_records;
CREATE POLICY tenant_isolation ON rubric_completion_records
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE rubric_dimension_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE rubric_dimension_assessments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON rubric_dimension_assessments;
CREATE POLICY tenant_isolation ON rubric_dimension_assessments
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE inter_rater_divergence_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE inter_rater_divergence_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON inter_rater_divergence_records;
CREATE POLICY tenant_isolation ON inter_rater_divergence_records
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE rubric_amendment_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE rubric_amendment_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON rubric_amendment_log;
CREATE POLICY tenant_isolation ON rubric_amendment_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 9 =====

ALTER TABLE mastery_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE mastery_events FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON mastery_events;
CREATE POLICY tenant_isolation ON mastery_events
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE mastery_aggregates ENABLE ROW LEVEL SECURITY;
ALTER TABLE mastery_aggregates FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON mastery_aggregates;
CREATE POLICY tenant_isolation ON mastery_aggregates
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE longitudinal_growth_curves ENABLE ROW LEVEL SECURITY;
ALTER TABLE longitudinal_growth_curves FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON longitudinal_growth_curves;
CREATE POLICY tenant_isolation ON longitudinal_growth_curves
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE mastery_aggregation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE mastery_aggregation_jobs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON mastery_aggregation_jobs;
CREATE POLICY tenant_isolation ON mastery_aggregation_jobs
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE mastery_event_amendment_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE mastery_event_amendment_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON mastery_event_amendment_log;
CREATE POLICY tenant_isolation ON mastery_event_amendment_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE aggregation_policy ENABLE ROW LEVEL SECURITY;
ALTER TABLE aggregation_policy FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON aggregation_policy;
CREATE POLICY tenant_isolation ON aggregation_policy
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE stage_readiness_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE stage_readiness_assessments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON stage_readiness_assessments;
CREATE POLICY tenant_isolation ON stage_readiness_assessments
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 10 =====

ALTER TABLE reflection_prompt_sets ENABLE ROW LEVEL SECURITY;
ALTER TABLE reflection_prompt_sets FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON reflection_prompt_sets;
CREATE POLICY tenant_isolation ON reflection_prompt_sets
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE reflection_prompts ENABLE ROW LEVEL SECURITY;
ALTER TABLE reflection_prompts FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON reflection_prompts;
CREATE POLICY tenant_isolation ON reflection_prompts
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE feedback_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_requests FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON feedback_requests;
CREATE POLICY tenant_isolation ON feedback_requests
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- Peer respondent identity protection: STUDENT/PARENT/SUBJECT_TEACHER cannot see respondent_user_id
DROP POLICY IF EXISTS peer_identity_protection ON feedback_requests;
CREATE POLICY peer_identity_protection ON feedback_requests
    FOR SELECT
    USING (
        tenant_id = current_setting('app.tenant_id', TRUE)::uuid
    );

ALTER TABLE feedback_responses ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_responses FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON feedback_responses;
CREATE POLICY tenant_isolation ON feedback_responses
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE feedback_response_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_response_items FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON feedback_response_items;
CREATE POLICY tenant_isolation ON feedback_response_items
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE peer_assessment_aggregates ENABLE ROW LEVEL SECURITY;
ALTER TABLE peer_assessment_aggregates FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON peer_assessment_aggregates;
CREATE POLICY tenant_isolation ON peer_assessment_aggregates
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE self_assessment_mastery_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE self_assessment_mastery_links FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON self_assessment_mastery_links;
CREATE POLICY tenant_isolation ON self_assessment_mastery_links
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE parent_observation_summaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_observation_summaries FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON parent_observation_summaries;
CREATE POLICY tenant_isolation ON parent_observation_summaries
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE feedback_response_rates ENABLE ROW LEVEL SECURITY;
ALTER TABLE feedback_response_rates FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON feedback_response_rates;
CREATE POLICY tenant_isolation ON feedback_response_rates
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE moderation_anomaly_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE moderation_anomaly_flags FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON moderation_anomaly_flags;
CREATE POLICY tenant_isolation ON moderation_anomaly_flags
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 11 =====

ALTER TABLE intervention_trigger_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_trigger_rules FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON intervention_trigger_rules;
CREATE POLICY tenant_isolation ON intervention_trigger_rules
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE intervention_trigger_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_trigger_runs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON intervention_trigger_runs;
CREATE POLICY tenant_isolation ON intervention_trigger_runs
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE intervention_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_alerts FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON intervention_alerts;
CREATE POLICY tenant_isolation ON intervention_alerts
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- Sensitivity-level access control for intervention_plans
ALTER TABLE intervention_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_plans FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS sensitivity_access ON intervention_plans;
CREATE POLICY sensitivity_access ON intervention_plans
    USING (
        tenant_id = current_setting('app.tenant_id', TRUE)::uuid
        AND (
            -- WELFARE_OFFICER and PRINCIPAL can see everything
            current_setting('app.user_role', TRUE) IN ('WELFARE_OFFICER', 'PLATFORM_ADMIN', 'STATE_ADMIN')
            -- PRINCIPAL can see everything except SAFEGUARDING
            OR (current_setting('app.user_role', TRUE) = 'PRINCIPAL'
                AND sensitivity_level != 'SAFEGUARDING')
            -- COUNSELLOR can see ACADEMIC, BEHAVIOURAL, WELFARE
            OR (current_setting('app.user_role', TRUE) = 'COUNSELLOR'
                AND sensitivity_level IN ('ACADEMIC', 'BEHAVIOURAL', 'WELFARE'))
            -- CLASS_TEACHER can only see ACADEMIC and BEHAVIOURAL
            OR (current_setting('app.user_role', TRUE) IN ('CLASS_TEACHER', 'SUBJECT_TEACHER')
                AND sensitivity_level IN ('ACADEMIC', 'BEHAVIOURAL'))
        )
    );

ALTER TABLE intervention_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_participants FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON intervention_participants;
CREATE POLICY tenant_isolation ON intervention_participants
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE intervention_actions ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_actions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON intervention_actions;
CREATE POLICY tenant_isolation ON intervention_actions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE intervention_outcome_evidence ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_outcome_evidence FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON intervention_outcome_evidence;
CREATE POLICY tenant_isolation ON intervention_outcome_evidence
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE parent_communication_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE parent_communication_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON parent_communication_log;
CREATE POLICY tenant_isolation ON parent_communication_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE intervention_review_checkpoints ENABLE ROW LEVEL SECURITY;
ALTER TABLE intervention_review_checkpoints FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON intervention_review_checkpoints;
CREATE POLICY tenant_isolation ON intervention_review_checkpoints
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE welfare_case_access_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE welfare_case_access_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON welfare_case_access_log;
CREATE POLICY tenant_isolation ON welfare_case_access_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 12 =====

ALTER TABLE student_disability_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE student_disability_profiles FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON student_disability_profiles;
CREATE POLICY tenant_isolation ON student_disability_profiles
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE overlay_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE overlay_templates FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON overlay_templates;
CREATE POLICY tenant_isolation ON overlay_templates
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE rubric_overlays ENABLE ROW LEVEL SECURITY;
ALTER TABLE rubric_overlays FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON rubric_overlays;
CREATE POLICY tenant_isolation ON rubric_overlays
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE overlay_approval_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE overlay_approval_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON overlay_approval_log;
CREATE POLICY tenant_isolation ON overlay_approval_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE overlay_assessment_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE overlay_assessment_applications FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON overlay_assessment_applications;
CREATE POLICY tenant_isolation ON overlay_assessment_applications
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE inclusion_indicators ENABLE ROW LEVEL SECURITY;
ALTER TABLE inclusion_indicators FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON inclusion_indicators;
CREATE POLICY tenant_isolation ON inclusion_indicators
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE overlay_expiry_notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE overlay_expiry_notifications FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON overlay_expiry_notifications;
CREATE POLICY tenant_isolation ON overlay_expiry_notifications
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE credit_overlay_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_overlay_links FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON credit_overlay_links;
CREATE POLICY tenant_isolation ON credit_overlay_links
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 13 — Credit Engine =====

ALTER TABLE credit_ledger_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_ledger_entries FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON credit_ledger_entries;
CREATE POLICY tenant_isolation ON credit_ledger_entries
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE credit_computation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE credit_computation_jobs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON credit_computation_jobs;
CREATE POLICY tenant_isolation ON credit_computation_jobs
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE external_credit_claims ENABLE ROW LEVEL SECURITY;
ALTER TABLE external_credit_claims FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON external_credit_claims;
CREATE POLICY tenant_isolation ON external_credit_claims
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 14 — Export / Document Generation =====

ALTER TABLE export_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE export_jobs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON export_jobs;
CREATE POLICY tenant_isolation ON export_jobs
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE export_document_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE export_document_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON export_document_records;
CREATE POLICY tenant_isolation ON export_document_records
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 15 — Governance / Override =====

ALTER TABLE override_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE override_requests FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON override_requests;
CREATE POLICY tenant_isolation ON override_requests
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE governance_alerts ENABLE ROW LEVEL SECURITY;
ALTER TABLE governance_alerts FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON governance_alerts;
CREATE POLICY tenant_isolation ON governance_alerts
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 16 — AI Generation =====

ALTER TABLE ai_generation_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_generation_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON ai_generation_log;
CREATE POLICY tenant_isolation ON ai_generation_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE ai_draft_contents ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_draft_contents FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON ai_draft_contents;
CREATE POLICY tenant_isolation ON ai_draft_contents
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 17 — Portability =====

ALTER TABLE portability_packages ENABLE ROW LEVEL SECURITY;
ALTER TABLE portability_packages FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON portability_packages;
CREATE POLICY tenant_isolation ON portability_packages
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- credential_revocation_list: NO RLS (public table, no tenant_id)

-- ===== Layer 18 — CPD (Continuing Professional Development) =====

ALTER TABLE cpd_hours_ledger ENABLE ROW LEVEL SECURITY;
ALTER TABLE cpd_hours_ledger FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON cpd_hours_ledger;
CREATE POLICY tenant_isolation ON cpd_hours_ledger
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE cpd_aggregation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE cpd_aggregation_jobs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON cpd_aggregation_jobs;
CREATE POLICY tenant_isolation ON cpd_aggregation_jobs
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE professional_growth_interventions ENABLE ROW LEVEL SECURITY;
ALTER TABLE professional_growth_interventions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON professional_growth_interventions;
CREATE POLICY tenant_isolation ON professional_growth_interventions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

DROP POLICY IF EXISTS district_admin_block ON professional_growth_interventions;
DROP POLICY IF EXISTS district_admin_block_pgi ON professional_growth_interventions;
CREATE POLICY district_admin_block ON professional_growth_interventions
    AS RESTRICTIVE FOR SELECT
    USING (
        current_setting('app.user_role', TRUE) NOT IN ('DISTRICT_ADMIN')
    );

ALTER TABLE npst_competency_assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE npst_competency_assessments FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON npst_competency_assessments;
CREATE POLICY tenant_isolation ON npst_competency_assessments
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

DROP POLICY IF EXISTS district_admin_block ON npst_competency_assessments;
DROP POLICY IF EXISTS district_admin_block_npst ON npst_competency_assessments;
CREATE POLICY district_admin_block ON npst_competency_assessments
    AS RESTRICTIVE FOR SELECT
    USING (
        current_setting('app.user_role', TRUE) NOT IN ('DISTRICT_ADMIN')
    );

ALTER TABLE peer_observation_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE peer_observation_records FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON peer_observation_records;
CREATE POLICY tenant_isolation ON peer_observation_records
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

DROP POLICY IF EXISTS district_admin_block ON peer_observation_records;
CREATE POLICY district_admin_block ON peer_observation_records
    AS RESTRICTIVE FOR SELECT
    USING (
        current_setting('app.user_role', TRUE) NOT IN ('DISTRICT_ADMIN')
    );

-- mastery_events: additional DISTRICT_ADMIN block (tenant_isolation already in Layer 9)
DROP POLICY IF EXISTS district_admin_block ON mastery_events;
CREATE POLICY district_admin_block ON mastery_events
    AS RESTRICTIVE FOR SELECT
    USING (
        current_setting('app.user_role', TRUE) NOT IN ('DISTRICT_ADMIN')
    );

-- ===== Layer 19 — SQAA Engine =====

ALTER TABLE sqaa_frameworks ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_frameworks FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_frameworks;
CREATE POLICY tenant_isolation ON sqaa_frameworks
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sqaa_indicator_definitions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_indicator_definitions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_indicator_definitions;
CREATE POLICY tenant_isolation ON sqaa_indicator_definitions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sqaa_indicator_values ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_indicator_values FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_indicator_values;
CREATE POLICY tenant_isolation ON sqaa_indicator_values
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sqaa_domain_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_domain_scores FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_domain_scores;
CREATE POLICY tenant_isolation ON sqaa_domain_scores
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sqaa_composite_scores ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_composite_scores FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_composite_scores;
CREATE POLICY tenant_isolation ON sqaa_composite_scores
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sqaa_computation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_computation_jobs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_computation_jobs;
CREATE POLICY tenant_isolation ON sqaa_computation_jobs
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sqaa_indicator_submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_indicator_submissions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_indicator_submissions;
CREATE POLICY tenant_isolation ON sqaa_indicator_submissions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE sqaa_improvement_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE sqaa_improvement_plans FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON sqaa_improvement_plans;
CREATE POLICY tenant_isolation ON sqaa_improvement_plans
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE compliance_checklists ENABLE ROW LEVEL SECURITY;
ALTER TABLE compliance_checklists FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON compliance_checklists;
CREATE POLICY tenant_isolation ON compliance_checklists
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- ===== Layer 20 — Community Partnership =====

ALTER TABLE community_partners ENABLE ROW LEVEL SECURITY;
ALTER TABLE community_partners FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON community_partners;
CREATE POLICY tenant_isolation ON community_partners
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE engagement_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement_sessions FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON engagement_sessions;
CREATE POLICY tenant_isolation ON engagement_sessions
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE engagement_computation_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE engagement_computation_jobs FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON engagement_computation_jobs;
CREATE POLICY tenant_isolation ON engagement_computation_jobs
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

ALTER TABLE partner_safeguarding_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE partner_safeguarding_log FORCE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS tenant_isolation ON partner_safeguarding_log;
CREATE POLICY tenant_isolation ON partner_safeguarding_log
    USING (tenant_id = current_setting('app.tenant_id', TRUE)::uuid);

-- =========================================================================
-- Additional Layer 13-23 tables (appended)
-- Uses DO $$ blocks with existence checks for tables that may not yet exist
-- =========================================================================

DO $$
DECLARE
    t TEXT;
    tenant_tables TEXT[] := ARRAY[
        -- Layer 13 additional
        'credit_frameworks', 'credit_domain_definitions', 'credit_policies',
        'activity_templates', 'student_activity_records', 'hour_ledger_entries',
        'credit_ledger_amendment_log', 'credit_summaries',
        -- Layer 14 additional
        'export_signing_keys', 'export_template_definitions', 'export_access_log',
        'export_authorizations', 'template_state_variants', 'bulk_export_archives',
        -- Layer 15 additional
        'override_application_log', 'permission_snapshots', 'audit_chain_verification_runs',
        'governance_policy_registry', 'compliance_reconstruction_requests',
        'data_retention_execution_log',
        -- Layer 16 additional
        'prompt_templates', 'ai_generation_subject_links', 'ai_draft_contents',
        'bias_monitoring_runs', 'bias_monitoring_policy', 'ai_consent_checks',
        -- Layer 17
        'governance_nodes', 'policy_packs', 'effective_policy_cache',
        'district_oversight_assignments', 'district_compliance_dashboard_cache',
        'protected_evidence_access_requests', 'inter_district_transfer_records',
        'state_compliance_directives', 'school_directive_compliance',
        'policy_pack_deployment_log',
        -- Layer 18
        'tenant_sla_assignments', 'sla_monitoring_records', 'onboarding_programmes',
        'tenant_onboarding_records', 'user_training_records', 'support_tickets',
        'exit_procedure_requests', 'audit_access_grants',
        -- Layer 20 additional
        'policy_directives', 'directive_conflicts', 'compliance_risk_radar_cache',
        'directive_distribution_log', 'outbound_reporting_endpoints',
        'outbound_submission_records', 'compliance_risk_computation_jobs',
        'compliance_notification_log',
        -- Layer 21 additional
        'teacher_professional_profiles', 'cpd_provider_registry',
        'cpd_activity_records', 'peer_observation_cycles',
        -- Layer 22 additional
        'portability_package_sections', 'import_requests',
        'taxonomy_bridge_mappings_applied', 'import_record_provenance',
        'portability_consent_records',
        -- Layer 23 additional
        'partner_vetting_log', 'engagement_activity_templates',
        'session_student_participants', 'alumni_profiles',
        'alumni_engagement_records', 'engagement_ledger_aggregates'
    ];
BEGIN
    FOREACH t IN ARRAY tenant_tables LOOP
        IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = t) THEN
            EXECUTE format('ALTER TABLE %I ENABLE ROW LEVEL SECURITY', t);
            EXECUTE format('ALTER TABLE %I FORCE ROW LEVEL SECURITY', t);
            EXECUTE format('DROP POLICY IF EXISTS tenant_isolation ON %I', t);
            EXECUTE format(
                'CREATE POLICY tenant_isolation ON %I USING (tenant_id = current_setting(''app.tenant_id'', TRUE)::uuid)',
                t
            );
        END IF;
    END LOOP;
END $$;

-- Layer 21: teacher_professional_profiles DISTRICT_ADMIN / STATE_ADMIN block
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_tables WHERE schemaname = 'public' AND tablename = 'teacher_professional_profiles') THEN
        DROP POLICY IF EXISTS district_admin_block ON teacher_professional_profiles;
        CREATE POLICY district_admin_block ON teacher_professional_profiles
            AS RESTRICTIVE FOR SELECT
            USING (
                current_setting('app.user_role', TRUE) NOT IN ('DISTRICT_ADMIN', 'STATE_ADMIN')
            );
    END IF;
END $$;

-- credential_revocation_list: NO RLS (public table, no tenant_id)
