-- ============================================================================
-- V029 — Blueprint Alignment: Layers 13–23
-- Additive-only ALTER TABLE ADD COLUMN IF NOT EXISTS for all layers.
-- No columns dropped. No tables dropped.
-- ============================================================================

-- --------------------------------------------------------------------------
-- Layer 13 — Credit Engine
-- --------------------------------------------------------------------------

-- 1. credit_frameworks
ALTER TABLE credit_frameworks ADD COLUMN IF NOT EXISTS framework_code TEXT;
ALTER TABLE credit_frameworks ADD COLUMN IF NOT EXISTS issuing_authority TEXT;
ALTER TABLE credit_frameworks ADD COLUMN IF NOT EXISTS applies_to_stages TEXT[];
ALTER TABLE credit_frameworks ADD COLUMN IF NOT EXISTS effective_from DATE;
ALTER TABLE credit_frameworks ADD COLUMN IF NOT EXISTS effective_to DATE;

-- 2. credit_domain_definitions
ALTER TABLE credit_domain_definitions ADD COLUMN IF NOT EXISTS label_regional TEXT;
ALTER TABLE credit_domain_definitions ADD COLUMN IF NOT EXISTS requires_competency_mastery BOOLEAN DEFAULT FALSE;
ALTER TABLE credit_domain_definitions ADD COLUMN IF NOT EXISTS allows_external_credits BOOLEAN DEFAULT TRUE;
ALTER TABLE credit_domain_definitions ADD COLUMN IF NOT EXISTS display_order INTEGER;
ALTER TABLE credit_domain_definitions ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT TRUE;

-- 3. credit_policies
ALTER TABLE credit_policies ADD COLUMN IF NOT EXISTS policy_code TEXT;
ALTER TABLE credit_policies ADD COLUMN IF NOT EXISTS domain_rules JSONB;
ALTER TABLE credit_policies ADD COLUMN IF NOT EXISTS min_hours_for_partial DECIMAL;
ALTER TABLE credit_policies ADD COLUMN IF NOT EXISTS credit_precision INTEGER DEFAULT 2;
ALTER TABLE credit_policies ADD COLUMN IF NOT EXISTS max_total_credits_per_year DECIMAL;
ALTER TABLE credit_policies ADD COLUMN IF NOT EXISTS superseded_by_id UUID;

-- 4. activity_templates
ALTER TABLE activity_templates ADD COLUMN IF NOT EXISTS framework_id UUID;
ALTER TABLE activity_templates ADD COLUMN IF NOT EXISTS activity_code TEXT;
ALTER TABLE activity_templates ADD COLUMN IF NOT EXISTS stage TEXT;
ALTER TABLE activity_templates ADD COLUMN IF NOT EXISTS activity_category TEXT;
ALTER TABLE activity_templates ADD COLUMN IF NOT EXISTS max_completions_per_year INTEGER;

-- 5. student_activity_records
ALTER TABLE student_activity_records ADD COLUMN IF NOT EXISTS term_id UUID;
ALTER TABLE student_activity_records ADD COLUMN IF NOT EXISTS activity_date DATE;
ALTER TABLE student_activity_records ADD COLUMN IF NOT EXISTS credit_policy_id UUID;
ALTER TABLE student_activity_records ADD COLUMN IF NOT EXISTS mastery_event_ids UUID[];
ALTER TABLE student_activity_records ADD COLUMN IF NOT EXISTS overlay_applied BOOLEAN DEFAULT FALSE;
ALTER TABLE student_activity_records ADD COLUMN IF NOT EXISTS credit_overlay_link_id UUID;

-- 6. hour_ledger_entries
ALTER TABLE hour_ledger_entries ADD COLUMN IF NOT EXISTS term_id UUID;
ALTER TABLE hour_ledger_entries ADD COLUMN IF NOT EXISTS activity_category TEXT;
ALTER TABLE hour_ledger_entries ADD COLUMN IF NOT EXISTS notional_hours_template DECIMAL;
ALTER TABLE hour_ledger_entries ADD COLUMN IF NOT EXISTS year_snapshot_id UUID;
ALTER TABLE hour_ledger_entries ADD COLUMN IF NOT EXISTS raw_credits_computed DECIMAL;
ALTER TABLE hour_ledger_entries ADD COLUMN IF NOT EXISTS recorded_by UUID;

-- 7. credit_ledger_entries
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS framework_id UUID;
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS evidence_triangle_verified BOOLEAN DEFAULT FALSE;
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS mastery_threshold_met BOOLEAN;
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS source_hour_entry_ids UUID[];
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS computation_run_id UUID;
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS year_snapshot_id UUID;
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS entry_status TEXT DEFAULT 'ACTIVE';
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS is_amended BOOLEAN DEFAULT FALSE;
ALTER TABLE credit_ledger_entries ADD COLUMN IF NOT EXISTS recorded_by UUID;

-- 8. external_credit_claims
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS academic_year_id UUID;
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS course_code TEXT;
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS course_title TEXT;
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS credits_claimed_value DECIMAL;
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS completion_date DATE;
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS certificate_evidence_id UUID;
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS certificate_hash TEXT;
ALTER TABLE external_credit_claims ADD COLUMN IF NOT EXISTS resulting_ledger_entry_id UUID;

-- 9. credit_summaries
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS framework_id UUID;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS domain_breakdown JSONB;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS external_credits_included DECIMAL DEFAULT 0;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS external_credits_pending DECIMAL DEFAULT 0;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS credit_policy_id UUID;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS year_snapshot_id UUID;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS is_snapshot_frozen BOOLEAN DEFAULT FALSE;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS pending_verification_count INTEGER DEFAULT 0;
ALTER TABLE credit_summaries ADD COLUMN IF NOT EXISTS computation_run_id UUID;

-- 10. credit_computation_jobs
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS job_type TEXT;
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS class_id UUID;
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS triggered_by_activity_id UUID;
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS started_at TIMESTAMPTZ;
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS completed_at TIMESTAMPTZ;
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS failed_at TIMESTAMPTZ;
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS failure_reason TEXT;
ALTER TABLE credit_computation_jobs ADD COLUMN IF NOT EXISTS max_retries INTEGER DEFAULT 3;

-- --------------------------------------------------------------------------
-- Layer 14 — Export Engine
-- --------------------------------------------------------------------------

-- 11. export_signing_keys
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS key_type TEXT;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS public_key_pem TEXT;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS private_key_ref TEXT;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS certificate_pem TEXT;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS issued_by TEXT;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS valid_from TIMESTAMPTZ;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS valid_to TIMESTAMPTZ;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS documents_signed INTEGER DEFAULT 0;
ALTER TABLE export_signing_keys ADD COLUMN IF NOT EXISTS last_used_at TIMESTAMPTZ;

-- 12. export_authorizations
ALTER TABLE export_authorizations ADD COLUMN IF NOT EXISTS scope_description TEXT;
ALTER TABLE export_authorizations ADD COLUMN IF NOT EXISTS academic_year_id UUID;
ALTER TABLE export_authorizations ADD COLUMN IF NOT EXISTS student_count INTEGER;
ALTER TABLE export_authorizations ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE export_authorizations ADD COLUMN IF NOT EXISTS used_at TIMESTAMPTZ;

-- 13. template_state_variants
ALTER TABLE template_state_variants ADD COLUMN IF NOT EXISTS variant_code TEXT;
ALTER TABLE template_state_variants ADD COLUMN IF NOT EXISTS variant_version INTEGER;
ALTER TABLE template_state_variants ADD COLUMN IF NOT EXISTS label TEXT;
ALTER TABLE template_state_variants ADD COLUMN IF NOT EXISTS published_by UUID;
ALTER TABLE template_state_variants ADD COLUMN IF NOT EXISTS published_at TIMESTAMPTZ;

-- 14. bulk_export_archives
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS failed_document_count INTEGER DEFAULT 0;
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS storage_provider_id UUID;
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS storage_object_key TEXT;
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS file_size_bytes BIGINT;
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS available_from TIMESTAMPTZ;
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS downloaded_count INTEGER DEFAULT 0;
ALTER TABLE bulk_export_archives ADD COLUMN IF NOT EXISTS last_downloaded_at TIMESTAMPTZ;

-- --------------------------------------------------------------------------
-- Layer 15 — Audit & Governance
-- --------------------------------------------------------------------------

-- 15. override_requests
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS override_type TEXT;
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS academic_year_id UUID;
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS legal_basis TEXT;
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS proposed_after_state JSONB;
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS supporting_document_ref TEXT;
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS urgency TEXT DEFAULT 'NORMAL';
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS escalation_required BOOLEAN DEFAULT FALSE;
ALTER TABLE override_requests ADD COLUMN IF NOT EXISTS escalated_to UUID;

-- 16. override_application_log
ALTER TABLE override_application_log ADD COLUMN IF NOT EXISTS entity_type TEXT;
ALTER TABLE override_application_log ADD COLUMN IF NOT EXISTS entity_id UUID;
ALTER TABLE override_application_log ADD COLUMN IF NOT EXISTS downstream_effects JSONB;
ALTER TABLE override_application_log ADD COLUMN IF NOT EXISTS override_hash TEXT;

-- 17. permission_snapshots
ALTER TABLE permission_snapshots ADD COLUMN IF NOT EXISTS snapshot_context TEXT;
ALTER TABLE permission_snapshots ADD COLUMN IF NOT EXISTS reference_entity_type TEXT;
ALTER TABLE permission_snapshots ADD COLUMN IF NOT EXISTS reference_entity_id UUID;
ALTER TABLE permission_snapshots ADD COLUMN IF NOT EXISTS active_role_assignments JSONB;

-- 18. governance_alerts
ALTER TABLE governance_alerts ADD COLUMN IF NOT EXISTS escalated_at TIMESTAMPTZ;
ALTER TABLE governance_alerts ADD COLUMN IF NOT EXISTS escalated_to UUID;
ALTER TABLE governance_alerts ADD COLUMN IF NOT EXISTS escalation_count INTEGER DEFAULT 0;

-- --------------------------------------------------------------------------
-- Layer 16 — AI Layer
-- --------------------------------------------------------------------------

-- 19. ai_generation_log
ALTER TABLE ai_generation_log ADD COLUMN IF NOT EXISTS injection_detected BOOLEAN DEFAULT FALSE;
ALTER TABLE ai_generation_log ADD COLUMN IF NOT EXISTS pii_scan_passed BOOLEAN DEFAULT TRUE;
ALTER TABLE ai_generation_log ADD COLUMN IF NOT EXISTS model_name TEXT;
ALTER TABLE ai_generation_log ADD COLUMN IF NOT EXISTS model_version TEXT;

-- 20. ai_consent_checks
ALTER TABLE ai_consent_checks ADD COLUMN IF NOT EXISTS consent_record_id UUID;

-- 21. bias_monitoring_runs
ALTER TABLE bias_monitoring_runs ADD COLUMN IF NOT EXISTS run_started_at TIMESTAMPTZ;
ALTER TABLE bias_monitoring_runs ADD COLUMN IF NOT EXISTS metrics JSONB;
ALTER TABLE bias_monitoring_runs ADD COLUMN IF NOT EXISTS thresholds_breached INTEGER DEFAULT 0;
ALTER TABLE bias_monitoring_runs ADD COLUMN IF NOT EXISTS breach_details JSONB;
ALTER TABLE bias_monitoring_runs ADD COLUMN IF NOT EXISTS alert_generated BOOLEAN DEFAULT FALSE;
ALTER TABLE bias_monitoring_runs ADD COLUMN IF NOT EXISTS governance_alert_id UUID;
ALTER TABLE bias_monitoring_runs ADD COLUMN IF NOT EXISTS run_status TEXT DEFAULT 'COMPLETED';

-- 22. bias_monitoring_policy
ALTER TABLE bias_monitoring_policy ADD COLUMN IF NOT EXISTS policy_code TEXT;
ALTER TABLE bias_monitoring_policy ADD COLUMN IF NOT EXISTS policy_version INTEGER DEFAULT 1;
ALTER TABLE bias_monitoring_policy ADD COLUMN IF NOT EXISTS metrics_config JSONB;
ALTER TABLE bias_monitoring_policy ADD COLUMN IF NOT EXISTS monitoring_schedule TEXT;
ALTER TABLE bias_monitoring_policy ADD COLUMN IF NOT EXISTS effective_from DATE;
ALTER TABLE bias_monitoring_policy ADD COLUMN IF NOT EXISTS effective_to DATE;
ALTER TABLE bias_monitoring_policy ADD COLUMN IF NOT EXISTS published_by UUID;

-- --------------------------------------------------------------------------
-- Layer 17 — District & State Governance
-- --------------------------------------------------------------------------

-- 23. governance_nodes
ALTER TABLE governance_nodes ADD COLUMN IF NOT EXISTS node_code TEXT;
ALTER TABLE governance_nodes ADD COLUMN IF NOT EXISTS metadata JSONB;

-- 24. policy_packs
ALTER TABLE policy_packs ADD COLUMN IF NOT EXISTS pack_code TEXT;
ALTER TABLE policy_packs ADD COLUMN IF NOT EXISTS description TEXT;

-- 25. effective_policy_cache
ALTER TABLE effective_policy_cache ADD COLUMN IF NOT EXISTS source_pack_ids UUID[];
ALTER TABLE effective_policy_cache ADD COLUMN IF NOT EXISTS computation_time_ms INTEGER;

-- 26. district_compliance_dashboard_cache
ALTER TABLE district_compliance_dashboard_cache ADD COLUMN IF NOT EXISTS indicator_summary JSONB;
ALTER TABLE district_compliance_dashboard_cache ADD COLUMN IF NOT EXISTS welfare_count_suppressed BOOLEAN DEFAULT TRUE;

-- 27. inter_district_transfer_records
ALTER TABLE inter_district_transfer_records ADD COLUMN IF NOT EXISTS transfer_reason TEXT;
ALTER TABLE inter_district_transfer_records ADD COLUMN IF NOT EXISTS acknowledged_by UUID;
ALTER TABLE inter_district_transfer_records ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ;

-- --------------------------------------------------------------------------
-- Layer 18 — Business & Procurement
-- --------------------------------------------------------------------------

-- 28. sla_definitions
ALTER TABLE sla_definitions ADD COLUMN IF NOT EXISTS sla_description TEXT;
ALTER TABLE sla_definitions ADD COLUMN IF NOT EXISTS measurement_method TEXT;

-- 29. support_tickets
ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS category TEXT;
ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS channel TEXT DEFAULT 'APP';
ALTER TABLE support_tickets ADD COLUMN IF NOT EXISTS resolution_notes TEXT;

-- 30. training_modules
ALTER TABLE training_modules ADD COLUMN IF NOT EXISTS module_code TEXT;
ALTER TABLE training_modules ADD COLUMN IF NOT EXISTS assessment_required BOOLEAN DEFAULT FALSE;

-- 31. exit_procedure_requests
ALTER TABLE exit_procedure_requests ADD COLUMN IF NOT EXISTS exit_reason TEXT;
ALTER TABLE exit_procedure_requests ADD COLUMN IF NOT EXISTS data_formats_requested TEXT[];
ALTER TABLE exit_procedure_requests ADD COLUMN IF NOT EXISTS account_closure_date DATE;

-- --------------------------------------------------------------------------
-- Layer 19 — SQAA Engine
-- --------------------------------------------------------------------------

-- 32. sqaa_indicator_definitions
ALTER TABLE sqaa_indicator_definitions ADD COLUMN IF NOT EXISTS indicator_description TEXT;
ALTER TABLE sqaa_indicator_definitions ADD COLUMN IF NOT EXISTS data_source_table TEXT;
ALTER TABLE sqaa_indicator_definitions ADD COLUMN IF NOT EXISTS formula_expression TEXT;

-- 33. sqaa_improvement_plans
ALTER TABLE sqaa_improvement_plans ADD COLUMN IF NOT EXISTS problem_summary TEXT;
ALTER TABLE sqaa_improvement_plans ADD COLUMN IF NOT EXISTS support_actions JSONB;
ALTER TABLE sqaa_improvement_plans ADD COLUMN IF NOT EXISTS district_support_officer_id UUID;
ALTER TABLE sqaa_improvement_plans ADD COLUMN IF NOT EXISTS plan_start_date DATE;
ALTER TABLE sqaa_improvement_plans ADD COLUMN IF NOT EXISTS plan_target_date DATE;

-- 34. sqaa_composite_scores
ALTER TABLE sqaa_composite_scores ADD COLUMN IF NOT EXISTS domain_breakdown JSONB;
ALTER TABLE sqaa_composite_scores ADD COLUMN IF NOT EXISTS evidence_summary JSONB;

-- --------------------------------------------------------------------------
-- Layer 20 — Policy Compliance Engine
-- --------------------------------------------------------------------------

-- 35. policy_directives
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS directive_uid TEXT;
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS directive_type TEXT;
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS urgency TEXT;
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS summary TEXT;
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS full_text TEXT;
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS issuing_authority TEXT;
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS issuing_authority_type TEXT;
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS applies_to_node_types TEXT[];
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS applies_to_state_codes TEXT[];
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS applies_to_stages TEXT[];
ALTER TABLE policy_directives ADD COLUMN IF NOT EXISTS supersedes_directive_id UUID;

-- 36. compliance_checklists
ALTER TABLE compliance_checklists ADD COLUMN IF NOT EXISTS compliance_evidence JSONB;
ALTER TABLE compliance_checklists ADD COLUMN IF NOT EXISTS auto_detected BOOLEAN DEFAULT FALSE;
ALTER TABLE compliance_checklists ADD COLUMN IF NOT EXISTS last_manual_check_at TIMESTAMPTZ;
ALTER TABLE compliance_checklists ADD COLUMN IF NOT EXISTS checked_by UUID;

-- 37. outbound_submission_records
ALTER TABLE outbound_submission_records ADD COLUMN IF NOT EXISTS academic_year_id UUID;
ALTER TABLE outbound_submission_records ADD COLUMN IF NOT EXISTS school_id UUID;
ALTER TABLE outbound_submission_records ADD COLUMN IF NOT EXISTS submission_type TEXT;

-- --------------------------------------------------------------------------
-- Layer 21 — Teacher CPD & NPST
-- --------------------------------------------------------------------------

-- 38. teacher_professional_profiles
ALTER TABLE teacher_professional_profiles ADD COLUMN IF NOT EXISTS cpd_hours_current_year DECIMAL DEFAULT 0;
ALTER TABLE teacher_professional_profiles ADD COLUMN IF NOT EXISTS npst_current_level TEXT;
ALTER TABLE teacher_professional_profiles ADD COLUMN IF NOT EXISTS last_assessment_date DATE;

-- 39. cpd_activity_records
ALTER TABLE cpd_activity_records ADD COLUMN IF NOT EXISTS certificate_evidence_id UUID;
ALTER TABLE cpd_activity_records ADD COLUMN IF NOT EXISTS activity_date DATE;
ALTER TABLE cpd_activity_records ADD COLUMN IF NOT EXISTS duration_hours DECIMAL;
ALTER TABLE cpd_activity_records ADD COLUMN IF NOT EXISTS completion_status TEXT DEFAULT 'COMPLETED';

-- 40. cpd_hours_ledger
ALTER TABLE cpd_hours_ledger ADD COLUMN IF NOT EXISTS year_snapshot_id UUID;
ALTER TABLE cpd_hours_ledger ADD COLUMN IF NOT EXISTS verified_at TIMESTAMPTZ;
ALTER TABLE cpd_hours_ledger ADD COLUMN IF NOT EXISTS verified_by UUID;

-- 41. peer_observation_records
ALTER TABLE peer_observation_records ADD COLUMN IF NOT EXISTS acknowledgement_status TEXT DEFAULT 'PENDING';
ALTER TABLE peer_observation_records ADD COLUMN IF NOT EXISTS acknowledged_at TIMESTAMPTZ;
ALTER TABLE peer_observation_records ADD COLUMN IF NOT EXISTS observation_date DATE;

-- 42. npst_competency_assessments
ALTER TABLE npst_competency_assessments ADD COLUMN IF NOT EXISTS assessment_type TEXT;
ALTER TABLE npst_competency_assessments ADD COLUMN IF NOT EXISTS evidence_record_ids UUID[];
ALTER TABLE npst_competency_assessments ADD COLUMN IF NOT EXISTS notes TEXT;

-- --------------------------------------------------------------------------
-- Layer 22 — Portability & Verifiable Credentials
-- --------------------------------------------------------------------------

-- 43. portability_packages
ALTER TABLE portability_packages ADD COLUMN IF NOT EXISTS package_format_version TEXT;
ALTER TABLE portability_packages ADD COLUMN IF NOT EXISTS sections_included TEXT[];
ALTER TABLE portability_packages ADD COLUMN IF NOT EXISTS sections_excluded TEXT[];
ALTER TABLE portability_packages ADD COLUMN IF NOT EXISTS delivery_method TEXT;
ALTER TABLE portability_packages ADD COLUMN IF NOT EXISTS delivered_at TIMESTAMPTZ;

-- 44. import_requests
ALTER TABLE import_requests ADD COLUMN IF NOT EXISTS bridge_report JSONB;
ALTER TABLE import_requests ADD COLUMN IF NOT EXISTS bridge_review_status TEXT;
ALTER TABLE import_requests ADD COLUMN IF NOT EXISTS reviewed_by UUID;
ALTER TABLE import_requests ADD COLUMN IF NOT EXISTS reviewed_at TIMESTAMPTZ;

-- 45. portability_consent_records
ALTER TABLE portability_consent_records ADD COLUMN IF NOT EXISTS consent_given BOOLEAN DEFAULT TRUE;
ALTER TABLE portability_consent_records ADD COLUMN IF NOT EXISTS expires_at TIMESTAMPTZ;
ALTER TABLE portability_consent_records ADD COLUMN IF NOT EXISTS consent_scope JSONB;

-- --------------------------------------------------------------------------
-- Layer 23 — Community & Partners
-- --------------------------------------------------------------------------

-- 46. community_partners
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS partner_code TEXT;
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS partner_name_regional TEXT;
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS expertise_areas TEXT[];
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS applicable_stages TEXT[];
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS vetting_conditions TEXT;
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS vetting_expires_at DATE;
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS mou_evidence_id UUID;
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS background_check_evidence_id UUID;
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS requires_teacher_supervision BOOLEAN DEFAULT TRUE;
ALTER TABLE community_partners ADD COLUMN IF NOT EXISTS created_by UUID;

-- 47. engagement_activity_templates
ALTER TABLE engagement_activity_templates ADD COLUMN IF NOT EXISTS template_code TEXT;
ALTER TABLE engagement_activity_templates ADD COLUMN IF NOT EXISTS activity_category TEXT;
ALTER TABLE engagement_activity_templates ADD COLUMN IF NOT EXISTS approval_required BOOLEAN DEFAULT FALSE;

-- 48. engagement_sessions
ALTER TABLE engagement_sessions ADD COLUMN IF NOT EXISTS session_time_start TIME;
ALTER TABLE engagement_sessions ADD COLUMN IF NOT EXISTS session_time_end TIME;
ALTER TABLE engagement_sessions ADD COLUMN IF NOT EXISTS duration_minutes INTEGER;
ALTER TABLE engagement_sessions ADD COLUMN IF NOT EXISTS notes TEXT;

-- 49. alumni_profiles
ALTER TABLE alumni_profiles ADD COLUMN IF NOT EXISTS graduation_school_id UUID;
ALTER TABLE alumni_profiles ADD COLUMN IF NOT EXISTS skills TEXT[];
ALTER TABLE alumni_profiles ADD COLUMN IF NOT EXISTS availability TEXT;

-- 50. partner_safeguarding_log
ALTER TABLE partner_safeguarding_log ADD COLUMN IF NOT EXISTS incident_date DATE;
ALTER TABLE partner_safeguarding_log ADD COLUMN IF NOT EXISTS students_involved_count INTEGER;
ALTER TABLE partner_safeguarding_log ADD COLUMN IF NOT EXISTS action_taken TEXT;
ALTER TABLE partner_safeguarding_log ADD COLUMN IF NOT EXISTS follow_up_required BOOLEAN DEFAULT FALSE;

-- --------------------------------------------------------------------------
-- Record migration
-- --------------------------------------------------------------------------
INSERT INTO schema_migrations (version, description)
VALUES ('V029', 'Blueprint alignment — Layers 13-23 additive columns');
