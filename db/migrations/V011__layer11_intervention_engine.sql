-- ============================================================================
-- Layer 11 — Intervention Engine
-- Alert triggers, support plans, multi-agency coordination
-- ============================================================================

-- 1. intervention_trigger_rules — Configurable rule engine for alert generation
CREATE TABLE intervention_trigger_rules (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    description TEXT,
    rule_type TEXT NOT NULL
        CHECK (rule_type IN ('MASTERY_DECLINE', 'ATTENDANCE_DROP', 'ENGAGEMENT_LOW', 'CUSTOM')),
    conditions JSONB NOT NULL,
    sensitivity_level TEXT NOT NULL DEFAULT 'ACADEMIC'
        CHECK (sensitivity_level IN ('ACADEMIC', 'BEHAVIOURAL', 'WELFARE', 'SAFEGUARDING')),
    alert_role TEXT NOT NULL DEFAULT 'CLASS_TEACHER',
    suppress_if_open BOOLEAN NOT NULL DEFAULT TRUE,
    stale_threshold_hours INTEGER NOT NULL DEFAULT 24,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    priority INTEGER NOT NULL DEFAULT 5,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. intervention_trigger_runs — Audit log of every trigger evaluation run
CREATE TABLE intervention_trigger_runs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    rule_id UUID NOT NULL REFERENCES intervention_trigger_rules(id),
    run_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    students_evaluated INTEGER NOT NULL DEFAULT 0,
    alerts_generated INTEGER NOT NULL DEFAULT 0,
    alerts_suppressed INTEGER NOT NULL DEFAULT 0,
    stale_aggregates_skipped INTEGER NOT NULL DEFAULT 0,
    execution_time_ms INTEGER,
    details JSONB DEFAULT '{}'
);

-- 3. intervention_alerts — Generated when trigger rules fire
CREATE TABLE intervention_alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    trigger_rule_id UUID NOT NULL REFERENCES intervention_trigger_rules(id),
    trigger_run_id UUID NOT NULL REFERENCES intervention_trigger_runs(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    sensitivity_level TEXT NOT NULL DEFAULT 'ACADEMIC'
        CHECK (sensitivity_level IN ('ACADEMIC', 'BEHAVIOURAL', 'WELFARE', 'SAFEGUARDING')),
    alert_data JSONB NOT NULL,
    status TEXT NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN', 'ACKNOWLEDGED', 'CONVERTED', 'DISMISSED')),
    acknowledged_by UUID REFERENCES users(id),
    acknowledged_at TIMESTAMPTZ,
    dismissed_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. intervention_plans — Formal support plans
CREATE TABLE intervention_plans (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    alert_id UUID REFERENCES intervention_alerts(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    sensitivity_level TEXT NOT NULL DEFAULT 'ACADEMIC'
        CHECK (sensitivity_level IN ('ACADEMIC', 'BEHAVIOURAL', 'WELFARE', 'SAFEGUARDING')),
    title TEXT NOT NULL,
    description TEXT,
    objectives JSONB DEFAULT '[]',
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'ACTIVE', 'ON_HOLD', 'CLOSED', 'ESCALATED')),
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    closed_at TIMESTAMPTZ,
    closed_by UUID REFERENCES users(id),
    closure_type TEXT CHECK (closure_type IN ('RESOLVED', 'TRANSFERRED', 'GRADUATED', 'ESCALATED')),
    closure_approved_by UUID REFERENCES users(id),
    closure_approved_at TIMESTAMPTZ,
    next_review_date DATE,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. intervention_participants — Internal staff and external agencies
CREATE TABLE intervention_participants (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    plan_id UUID NOT NULL REFERENCES intervention_plans(id) ON DELETE CASCADE,
    participant_type TEXT NOT NULL
        CHECK (participant_type IN ('STAFF', 'EXTERNAL_AGENCY', 'PARENT', 'SPECIALIST')),
    user_id UUID REFERENCES users(id),
    external_name TEXT,
    external_org TEXT,
    role_description TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    joined_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. intervention_actions — Operational log of sessions, referrals, meetings
CREATE TABLE intervention_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    plan_id UUID NOT NULL REFERENCES intervention_plans(id) ON DELETE CASCADE,
    action_type TEXT NOT NULL
        CHECK (action_type IN (
            'SESSION', 'REFERRAL', 'MEETING', 'OBSERVATION',
            'PARENT_CONTACT', 'RESOURCE_PROVISION', 'NOTE'
        )),
    description TEXT NOT NULL,
    performed_by UUID NOT NULL REFERENCES users(id),
    performed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    outcome_note TEXT,
    evidence_record_ids UUID[] DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. intervention_outcome_evidence — Required for closure
CREATE TABLE intervention_outcome_evidence (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    plan_id UUID NOT NULL REFERENCES intervention_plans(id) ON DELETE CASCADE,
    evidence_type TEXT NOT NULL
        CHECK (evidence_type IN (
            'MASTERY_EVENT', 'ATTENDANCE_RECORD', 'COUNSELLOR_REPORT',
            'EXTERNAL_AGENCY_REPORT', 'PARENT_ACKNOWLEDGEMENT'
        )),
    mastery_event_id UUID REFERENCES mastery_events(id),
    structured_data JSONB,
    description TEXT,
    submitted_by UUID NOT NULL REFERENCES users(id),
    submitted_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. parent_communication_log — Every formal parent contact recorded
CREATE TABLE parent_communication_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    plan_id UUID REFERENCES intervention_plans(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    parent_id UUID NOT NULL REFERENCES parent_profiles(id),
    communication_type TEXT NOT NULL
        CHECK (communication_type IN ('SMS', 'PHONE_CALL', 'IN_PERSON', 'APP_MESSAGE', 'LETTER')),
    subject TEXT NOT NULL,
    content_summary TEXT,
    communicated_by UUID NOT NULL REFERENCES users(id),
    communicated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    parent_response TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. intervention_review_checkpoints — Scheduled review dates
CREATE TABLE intervention_review_checkpoints (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    plan_id UUID NOT NULL REFERENCES intervention_plans(id) ON DELETE CASCADE,
    scheduled_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'SCHEDULED'
        CHECK (status IN ('SCHEDULED', 'COMPLETED', 'OVERDUE', 'CANCELLED')),
    review_notes TEXT,
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 10. welfare_case_access_log — Dedicated access log for WELFARE/SAFEGUARDING
CREATE TABLE welfare_case_access_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    plan_id UUID NOT NULL REFERENCES intervention_plans(id),
    accessed_by UUID NOT NULL REFERENCES users(id),
    access_role TEXT NOT NULL,
    accessed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    access_type TEXT NOT NULL CHECK (access_type IN ('VIEW', 'EDIT', 'EXPORT')),
    ip_address INET
);

INSERT INTO schema_migrations (version, description) VALUES ('V011', 'Layer 11 — Intervention Engine');
