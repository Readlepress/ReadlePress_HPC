-- ============================================================================
-- Layer 10 — 360° Feedback
-- Self/parent/peer assessment with k-anonymity enforcement
-- ============================================================================

-- 1. reflection_prompt_sets — Versioned collections of prompts
CREATE TABLE reflection_prompt_sets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    stage_id UUID NOT NULL REFERENCES academic_stages(id),
    feedback_type TEXT NOT NULL
        CHECK (feedback_type IN ('SELF', 'PARENT', 'PEER')),
    version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
    published_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. reflection_prompts — Individual prompts within a set
CREATE TABLE reflection_prompts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    prompt_set_id UUID NOT NULL REFERENCES reflection_prompt_sets(id) ON DELETE CASCADE,
    prompt_text TEXT NOT NULL,
    prompt_text_key TEXT REFERENCES localization_keys(key_code),
    response_type TEXT NOT NULL
        CHECK (response_type IN ('SCALE_3', 'SCALE_5', 'FREE_TEXT', 'MULTIPLE_CHOICE')),
    competency_id UUID REFERENCES competencies(id),
    display_order INTEGER NOT NULL,
    is_required BOOLEAN NOT NULL DEFAULT TRUE,
    options JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. feedback_requests — Invitations sent to respondents
CREATE TABLE feedback_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    prompt_set_id UUID NOT NULL REFERENCES reflection_prompt_sets(id),
    subject_student_id UUID NOT NULL REFERENCES student_profiles(id),
    respondent_user_id UUID NOT NULL REFERENCES users(id),
    feedback_type TEXT NOT NULL
        CHECK (feedback_type IN ('SELF', 'PARENT', 'PEER')),
    class_id UUID NOT NULL REFERENCES classes(id),
    term_id UUID REFERENCES terms(id),
    academic_year_id UUID REFERENCES academic_years(id),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'COMPLETED', 'EXPIRED', 'DECLINED')),
    dispatched_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    due_at TIMESTAMPTZ NOT NULL,
    completed_at TIMESTAMPTZ,
    moderation_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (moderation_status IN ('PENDING', 'APPROVED', 'FLAGGED', 'REJECTED')),
    moderation_overdue BOOLEAN NOT NULL DEFAULT FALSE,
    moderation_sla_hours INTEGER NOT NULL DEFAULT 72,
    moderated_by UUID REFERENCES users(id),
    moderated_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 4. feedback_responses — One response set per request
CREATE TABLE feedback_responses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    request_id UUID NOT NULL REFERENCES feedback_requests(id) ON DELETE RESTRICT,
    responded_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    is_complete BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_response_per_request UNIQUE (request_id)
);

-- 5. feedback_response_items — Individual prompt answers
CREATE TABLE feedback_response_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    response_id UUID NOT NULL REFERENCES feedback_responses(id) ON DELETE CASCADE,
    prompt_id UUID NOT NULL REFERENCES reflection_prompts(id),
    scale_value INTEGER,
    text_value TEXT,
    selected_options JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_item_per_prompt UNIQUE (response_id, prompt_id)
);

-- 6. peer_assessment_aggregates — k-anonymity-enforced published aggregate
CREATE TABLE peer_assessment_aggregates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    prompt_set_id UUID NOT NULL REFERENCES reflection_prompt_sets(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    term_id UUID REFERENCES terms(id),
    academic_year_id UUID REFERENCES academic_years(id),
    respondent_count INTEGER NOT NULL DEFAULT 0,
    k_threshold INTEGER NOT NULL DEFAULT 5,
    is_publishable BOOLEAN NOT NULL DEFAULT FALSE,
    mean_numeric_value DECIMAL(5, 4),
    median_numeric_value DECIMAL(5, 4),
    qualitative_themes JSONB,
    qualitative_publishable BOOLEAN NOT NULL DEFAULT FALSE,
    last_computed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_peer_aggregate UNIQUE (tenant_id, student_id, prompt_set_id, term_id)
);

-- 7. self_assessment_mastery_links — Teacher-controlled promotion
CREATE TABLE self_assessment_mastery_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    feedback_response_id UUID NOT NULL REFERENCES feedback_responses(id),
    mastery_event_id UUID REFERENCES mastery_events(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    self_rated_value DECIMAL(3, 2) NOT NULL,
    promotion_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (promotion_status IN ('PENDING', 'PROMOTED', 'REJECTED', 'EXPIRED')),
    promoted_by UUID REFERENCES users(id),
    promoted_at TIMESTAMPTZ,
    rejection_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 8. parent_observation_summaries — Teacher-authored synthesis of parent responses
CREATE TABLE parent_observation_summaries (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    term_id UUID REFERENCES terms(id),
    teacher_id UUID NOT NULL REFERENCES users(id),
    parent_response_ids UUID[] NOT NULL DEFAULT '{}',
    summary_text TEXT NOT NULL,
    key_observations JSONB DEFAULT '[]',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 9. feedback_response_rates — Response rate tracking per class
CREATE TABLE feedback_response_rates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    class_id UUID NOT NULL REFERENCES classes(id),
    prompt_set_id UUID NOT NULL REFERENCES reflection_prompt_sets(id),
    feedback_type TEXT NOT NULL,
    term_id UUID REFERENCES terms(id),
    total_requested INTEGER NOT NULL DEFAULT 0,
    total_completed INTEGER NOT NULL DEFAULT 0,
    response_rate DECIMAL(5, 4),
    last_computed_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_response_rate UNIQUE (tenant_id, class_id, prompt_set_id, feedback_type, term_id)
);

-- 10. moderation_anomaly_flags — Suspicious patterns flagged
CREATE TABLE moderation_anomaly_flags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    feedback_request_id UUID NOT NULL REFERENCES feedback_requests(id),
    flag_type TEXT NOT NULL
        CHECK (flag_type IN (
            'UNIFORM_RESPONSES', 'EXTREME_VALUES', 'SPEED_ANOMALY',
            'CONTENT_CONCERN', 'PATTERN_MATCH'
        )),
    severity TEXT NOT NULL DEFAULT 'LOW'
        CHECK (severity IN ('LOW', 'MEDIUM', 'HIGH')),
    details JSONB NOT NULL,
    reviewed BOOLEAN NOT NULL DEFAULT FALSE,
    reviewed_by UUID REFERENCES users(id),
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO schema_migrations (version, description) VALUES ('V010', 'Layer 10 — 360° Feedback');
