-- ============================================================================
-- Repeatable Migration: Indexes
-- Performance-critical indexes for all layers
-- ============================================================================

-- ===== Layer 1 =====
CREATE INDEX IF NOT EXISTS idx_audit_log_tenant_time ON audit_log(tenant_id, performed_at DESC);
CREATE INDEX IF NOT EXISTS idx_audit_log_entity ON audit_log(entity_type, entity_id);
CREATE INDEX IF NOT EXISTS idx_audit_log_event_type ON audit_log(event_type);
CREATE INDEX IF NOT EXISTS idx_role_assignments_user ON role_assignments(user_id, is_active);
CREATE INDEX IF NOT EXISTS idx_role_assignments_role ON role_assignments(role_code, tenant_id);
CREATE INDEX IF NOT EXISTS idx_consent_records_student ON data_consent_records(student_id, consent_purpose_code);
CREATE INDEX IF NOT EXISTS idx_consent_otp_phone ON consent_otp_attempts(phone, attempted_at DESC);

-- ===== Layer 2 =====
CREATE INDEX IF NOT EXISTS idx_schools_district ON schools(tenant_id, district);
CREATE INDEX IF NOT EXISTS idx_student_profiles_apaar ON student_profiles(apaar_id) WHERE apaar_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_student_profiles_dedup ON student_profiles(dedup_status) WHERE dedup_status != 'UNIQUE';
CREATE INDEX IF NOT EXISTS idx_student_enrolments_class ON student_enrolments(class_id, status);
CREATE INDEX IF NOT EXISTS idx_student_enrolments_student ON student_enrolments(student_id, academic_year_label);
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_class ON teacher_assignments(class_id, status);
CREATE INDEX IF NOT EXISTS idx_teacher_assignments_teacher ON teacher_assignments(teacher_id, academic_year_label);

-- ===== Layer 3 =====
CREATE INDEX IF NOT EXISTS idx_academic_years_school ON academic_years(school_id, status);
CREATE INDEX IF NOT EXISTS idx_terms_year ON terms(academic_year_id);

-- ===== Layer 4 =====
CREATE INDEX IF NOT EXISTS idx_competencies_stage ON competencies(stage_id, status);
CREATE INDEX IF NOT EXISTS idx_competencies_domain ON competencies(domain_id);
CREATE INDEX IF NOT EXISTS idx_competencies_uid ON competencies(uid);
CREATE INDEX IF NOT EXISTS idx_competency_lineage_source ON competency_lineage(source_competency_id);
CREATE INDEX IF NOT EXISTS idx_competency_lineage_target ON competency_lineage(target_competency_id);
CREATE INDEX IF NOT EXISTS idx_competency_activations_comp ON competency_activations(competency_id, tenant_id);

-- ===== Layer 5 =====
CREATE INDEX IF NOT EXISTS idx_localization_strings_key ON localization_strings(key_id, language_code);
CREATE INDEX IF NOT EXISTS idx_localization_strings_status ON localization_strings(status);

-- ===== Layer 6 =====
CREATE INDEX IF NOT EXISTS idx_evidence_records_trust ON evidence_records(trust_level, tenant_id);
CREATE INDEX IF NOT EXISTS idx_evidence_records_uploader ON evidence_records(uploaded_by, uploaded_at DESC);
CREATE INDEX IF NOT EXISTS idx_evidence_custody_evidence ON evidence_custody_events(evidence_id, performed_at);
CREATE INDEX IF NOT EXISTS idx_evidence_access_log_evidence ON evidence_access_log(evidence_id, accessed_at DESC);

-- ===== Layer 7 =====
CREATE INDEX IF NOT EXISTS idx_mastery_drafts_teacher ON mastery_event_drafts(teacher_id, sync_status);
CREATE INDEX IF NOT EXISTS idx_mastery_drafts_student ON mastery_event_drafts(student_id, competency_id);
CREATE INDEX IF NOT EXISTS idx_mastery_drafts_sync ON mastery_event_drafts(sync_status) WHERE sync_status != 'SYNCED';
CREATE INDEX IF NOT EXISTS idx_capture_sessions_teacher ON capture_sessions(teacher_id, started_at DESC);
CREATE INDEX IF NOT EXISTS idx_evidence_upload_status ON evidence_upload_queue(upload_status) WHERE upload_status != 'UPLOADED';

-- ===== Layer 8 =====
CREATE INDEX IF NOT EXISTS idx_rubric_completions_student ON rubric_completion_records(student_id, term_id);
CREATE INDEX IF NOT EXISTS idx_rubric_completions_assessor ON rubric_completion_records(assessor_id, status);
CREATE INDEX IF NOT EXISTS idx_rubric_completions_class ON rubric_completion_records(class_id, academic_year_id);
CREATE INDEX IF NOT EXISTS idx_divergence_records_student ON inter_rater_divergence_records(student_id, status);

-- ===== Layer 9 =====
CREATE INDEX IF NOT EXISTS idx_mastery_events_student_comp ON mastery_events(student_id, competency_id, observed_at);
CREATE INDEX IF NOT EXISTS idx_mastery_events_class ON mastery_events(class_id, academic_year_id);
CREATE INDEX IF NOT EXISTS idx_mastery_events_status ON mastery_events(event_status);
CREATE INDEX IF NOT EXISTS idx_mastery_aggregates_student ON mastery_aggregates(student_id, academic_year_id);
CREATE INDEX IF NOT EXISTS idx_mastery_agg_jobs_status ON mastery_aggregation_jobs(status) WHERE status IN ('PENDING', 'PROCESSING');
CREATE INDEX IF NOT EXISTS idx_mastery_agg_jobs_idemp ON mastery_aggregation_jobs(idempotency_key);

-- ===== Layer 10 =====
CREATE INDEX IF NOT EXISTS idx_feedback_requests_student ON feedback_requests(subject_student_id, status);
CREATE INDEX IF NOT EXISTS idx_feedback_requests_respondent ON feedback_requests(respondent_user_id, status);
CREATE INDEX IF NOT EXISTS idx_feedback_requests_moderation ON feedback_requests(moderation_status, moderation_overdue);
CREATE INDEX IF NOT EXISTS idx_peer_aggregates_student ON peer_assessment_aggregates(student_id, is_publishable);
CREATE INDEX IF NOT EXISTS idx_self_links_status ON self_assessment_mastery_links(promotion_status) WHERE promotion_status = 'PENDING';

-- ===== Layer 11 =====
CREATE INDEX IF NOT EXISTS idx_intervention_alerts_student ON intervention_alerts(student_id, status);
CREATE INDEX IF NOT EXISTS idx_intervention_plans_student ON intervention_plans(student_id, status);
CREATE INDEX IF NOT EXISTS idx_intervention_plans_sensitivity ON intervention_plans(sensitivity_level, status);
CREATE INDEX IF NOT EXISTS idx_intervention_review_dates ON intervention_review_checkpoints(scheduled_date, status)
    WHERE status = 'SCHEDULED';
CREATE INDEX IF NOT EXISTS idx_welfare_access_plan ON welfare_case_access_log(plan_id, accessed_at DESC);

-- ===== Layer 12 =====
CREATE INDEX IF NOT EXISTS idx_disability_profiles_student ON student_disability_profiles(student_id);
CREATE INDEX IF NOT EXISTS idx_rubric_overlays_student ON rubric_overlays(student_id, status);
CREATE INDEX IF NOT EXISTS idx_rubric_overlays_expiry ON rubric_overlays(effective_until, status)
    WHERE status = 'ACTIVE';
CREATE INDEX IF NOT EXISTS idx_overlay_approval_overlay ON overlay_approval_log(overlay_id, performed_at);
CREATE INDEX IF NOT EXISTS idx_inclusion_indicators_school ON inclusion_indicators(school_id, academic_year_id);
CREATE INDEX IF NOT EXISTS idx_credit_overlay_links_student ON credit_overlay_links(student_id, is_active);

-- JSONB GIN indexes for policy packs and metadata
CREATE INDEX IF NOT EXISTS idx_evidence_records_metadata ON evidence_records USING GIN (metadata);
CREATE INDEX IF NOT EXISTS idx_mastery_events_metadata ON mastery_events USING GIN (metadata);

-- ===== Layer 13 — Credit Engine =====
CREATE INDEX IF NOT EXISTS idx_credit_ledger_student_year ON credit_ledger_entries(student_id, academic_year_id);
CREATE INDEX IF NOT EXISTS idx_credit_computation_jobs_status ON credit_computation_jobs(status)
    WHERE status IN ('PENDING', 'PROCESSING');

-- ===== Layer 14 — Export / Document Generation =====
CREATE INDEX IF NOT EXISTS idx_export_jobs_status_tenant ON export_jobs(status, tenant_id);
CREATE INDEX IF NOT EXISTS idx_export_document_records_job ON export_document_records(export_job_id);

-- ===== Layer 15 — Governance / Override =====
CREATE INDEX IF NOT EXISTS idx_override_requests_status_tenant ON override_requests(status, tenant_id);

-- ===== Layer 16 — AI Generation =====
CREATE INDEX IF NOT EXISTS idx_ai_generation_log_tenant_created ON ai_generation_log(tenant_id, created_at);

-- ===== Layer 19 — SQAA Engine =====
CREATE INDEX IF NOT EXISTS idx_sqaa_indicator_values_school_year ON sqaa_indicator_values(school_id, academic_year_id);
CREATE INDEX IF NOT EXISTS idx_sqaa_computation_jobs_status ON sqaa_computation_jobs(status)
    WHERE status IN ('PENDING', 'PROCESSING');
CREATE INDEX IF NOT EXISTS idx_compliance_checklists_school_directive ON compliance_checklists(school_id, directive_id);

-- ===== Layer 18 — CPD =====
CREATE INDEX IF NOT EXISTS idx_cpd_hours_ledger_teacher ON cpd_hours_ledger(teacher_id);
CREATE INDEX IF NOT EXISTS idx_cpd_aggregation_jobs_status ON cpd_aggregation_jobs(status)
    WHERE status IN ('PENDING', 'PROCESSING');

-- ===== Layer 17 — Portability =====
CREATE INDEX IF NOT EXISTS idx_portability_packages_student ON portability_packages(student_id);

-- ===== Layer 20 — Community Partnership =====
CREATE INDEX IF NOT EXISTS idx_engagement_sessions_partner_school ON engagement_sessions(partner_id, school_id);
CREATE INDEX IF NOT EXISTS idx_engagement_computation_jobs_status ON engagement_computation_jobs(status)
    WHERE status IN ('PENDING', 'PROCESSING');
CREATE INDEX IF NOT EXISTS idx_partner_safeguarding_log_partner_severity ON partner_safeguarding_log(partner_id, severity);
CREATE INDEX IF NOT EXISTS idx_community_partners_vetting_active ON community_partners(vetting_status, is_active);
