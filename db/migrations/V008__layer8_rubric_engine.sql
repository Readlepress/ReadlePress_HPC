-- ============================================================================
-- Layer 8 — Rubric Engine
-- Stage-specific assessment rubrics with multi-assessor support
-- ============================================================================

-- 1. rubric_templates — Stage-specific rubric definitions
CREATE TABLE rubric_templates (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    stage_id UUID NOT NULL REFERENCES academic_stages(id),
    version INTEGER NOT NULL DEFAULT 1,
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'PUBLISHED', 'ARCHIVED')),
    competency_ids UUID[] NOT NULL DEFAULT '{}',
    assessment_type TEXT NOT NULL DEFAULT 'INDIVIDUAL'
        CHECK (assessment_type IN ('INDIVIDUAL', 'GROUP', 'SELF', 'PEER')),
    max_group_size INTEGER DEFAULT 10,
    published_at TIMESTAMPTZ,
    created_by UUID NOT NULL REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. rubric_dimensions — Individual assessment dimensions within a template
CREATE TABLE rubric_dimensions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    template_id UUID NOT NULL REFERENCES rubric_templates(id) ON DELETE CASCADE,
    competency_id UUID NOT NULL REFERENCES competencies(id),
    name TEXT NOT NULL,
    description TEXT,
    weight DECIMAL(5, 4) NOT NULL DEFAULT 1.0 CHECK (weight > 0),
    display_order INTEGER NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 3. descriptor_level_assignments — Which levels apply to which dimensions
CREATE TABLE descriptor_level_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    dimension_id UUID NOT NULL REFERENCES rubric_dimensions(id) ON DELETE CASCADE,
    descriptor_level_id UUID NOT NULL REFERENCES descriptor_levels(id),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_level_assignment UNIQUE (dimension_id, descriptor_level_id)
);

-- 4. rubric_completion_records — A teacher's completed assessment for a student
CREATE TABLE rubric_completion_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    template_id UUID NOT NULL REFERENCES rubric_templates(id),
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    assessor_id UUID NOT NULL REFERENCES users(id),
    class_id UUID NOT NULL REFERENCES classes(id),
    term_id UUID REFERENCES terms(id),
    academic_year_id UUID REFERENCES academic_years(id),
    overall_numeric_value DECIMAL(3, 2) CHECK (overall_numeric_value >= 0 AND overall_numeric_value <= 1),
    status TEXT NOT NULL DEFAULT 'DRAFT'
        CHECK (status IN ('DRAFT', 'SUBMITTED', 'VERIFIED', 'AMENDED')),
    is_group_assessment BOOLEAN NOT NULL DEFAULT FALSE,
    group_session_id UUID,
    completed_at TIMESTAMPTZ,
    verified_at TIMESTAMPTZ,
    verified_by UUID REFERENCES users(id),
    evidence_record_ids UUID[] NOT NULL DEFAULT '{}',
    observation_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 5. rubric_dimension_assessments — Individual dimension ratings
CREATE TABLE rubric_dimension_assessments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    completion_id UUID NOT NULL REFERENCES rubric_completion_records(id) ON DELETE CASCADE,
    dimension_id UUID NOT NULL REFERENCES rubric_dimensions(id),
    descriptor_level_id UUID NOT NULL REFERENCES descriptor_levels(id),
    numeric_value DECIMAL(3, 2) NOT NULL CHECK (numeric_value >= 0 AND numeric_value <= 1),
    assessor_note TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_dimension_assessment UNIQUE (completion_id, dimension_id)
);

-- 6. inter_rater_divergence_records — Flags significant divergence
CREATE TABLE inter_rater_divergence_records (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id),
    competency_id UUID NOT NULL REFERENCES competencies(id),
    term_id UUID REFERENCES terms(id),
    assessor_a_id UUID NOT NULL REFERENCES users(id),
    assessor_b_id UUID NOT NULL REFERENCES users(id),
    completion_a_id UUID NOT NULL REFERENCES rubric_completion_records(id),
    completion_b_id UUID NOT NULL REFERENCES rubric_completion_records(id),
    value_a DECIMAL(3, 2) NOT NULL,
    value_b DECIMAL(3, 2) NOT NULL,
    divergence DECIMAL(3, 3) NOT NULL,
    threshold DECIMAL(3, 3) NOT NULL DEFAULT 0.250,
    status TEXT NOT NULL DEFAULT 'OPEN'
        CHECK (status IN ('OPEN', 'RESOLVED', 'ESCALATED')),
    alert_role TEXT NOT NULL DEFAULT 'CLASS_TEACHER'
        CHECK (alert_role IN ('CLASS_TEACHER', 'DEPARTMENT_HEAD', 'PRINCIPAL')),
    resolution_note TEXT,
    resolved_by UUID REFERENCES users(id),
    resolved_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 7. rubric_amendment_log — Immutable log of corrections to verified completions
CREATE TABLE rubric_amendment_log (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    completion_id UUID NOT NULL REFERENCES rubric_completion_records(id),
    amendment_type TEXT NOT NULL
        CHECK (amendment_type IN ('CORRECTION', 'REASSESSMENT', 'ADMINISTRATIVE')),
    before_state JSONB NOT NULL,
    after_state JSONB NOT NULL,
    reason TEXT NOT NULL,
    amended_by UUID NOT NULL REFERENCES users(id),
    amended_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    approved_by UUID REFERENCES users(id),
    approved_at TIMESTAMPTZ
);

-- Append-only enforcement for rubric_amendment_log
CREATE RULE no_amendment_update AS ON UPDATE TO rubric_amendment_log DO INSTEAD NOTHING;
CREATE RULE no_amendment_delete AS ON DELETE TO rubric_amendment_log DO INSTEAD NOTHING;

INSERT INTO schema_migrations (version, description) VALUES ('V008', 'Layer 8 — Rubric Engine');
