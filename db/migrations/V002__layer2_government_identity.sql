-- ============================================================================
-- Layer 2 — Government Identity
-- Permanent student/teacher identity anchored to government identifiers
-- ============================================================================

-- 1. schools — UDISE-coded school registry
CREATE TABLE schools (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    udise_code TEXT NOT NULL,
    name TEXT NOT NULL,
    name_local TEXT,
    address_line1 TEXT,
    address_line2 TEXT,
    district TEXT NOT NULL,
    block TEXT,
    state_code TEXT NOT NULL,
    pin_code TEXT,
    latitude DECIMAL(10, 8),
    longitude DECIMAL(11, 8),
    school_type TEXT NOT NULL DEFAULT 'GOVERNMENT'
        CHECK (school_type IN ('GOVERNMENT', 'GOVERNMENT_AIDED', 'PRIVATE', 'CENTRAL')),
    medium_of_instruction TEXT[] NOT NULL DEFAULT ARRAY['en'],
    status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'MERGED', 'CLOSED', 'SUSPENDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT udise_code_format CHECK (udise_code ~ '^\d{11}$'),
    CONSTRAINT unique_udise_per_tenant UNIQUE (tenant_id, udise_code)
);

-- 2. academic_stages — NEP 2020 stages
CREATE TABLE academic_stages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stage_code TEXT NOT NULL UNIQUE
        CHECK (stage_code IN ('FOUNDATIONAL', 'PREPARATORY', 'MIDDLE', 'SECONDARY')),
    name TEXT NOT NULL,
    grade_range_start INTEGER NOT NULL,
    grade_range_end INTEGER NOT NULL,
    display_mode TEXT NOT NULL
        CHECK (display_mode IN ('EMOJI_METAPHOR', 'LABEL_ONLY', 'LABEL_WITH_NUMBER', 'FULL_ACADEMIC')),
    show_numbers BOOLEAN NOT NULL DEFAULT FALSE,
    descriptor_style TEXT NOT NULL,
    ui_schema JSONB NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed NEP 2020 stages
INSERT INTO academic_stages (stage_code, name, grade_range_start, grade_range_end, display_mode, show_numbers, descriptor_style) VALUES
    ('FOUNDATIONAL', 'Foundational Stage', -2, 2, 'EMOJI_METAPHOR', FALSE, 'Stream / Mountain / Sky with icons'),
    ('PREPARATORY', 'Preparatory Stage', 3, 5, 'LABEL_ONLY', FALSE, 'Beginning / Developing / Proficient / Advanced'),
    ('MIDDLE', 'Middle Stage', 6, 8, 'LABEL_WITH_NUMBER', FALSE, 'Labels + optional numeric reference'),
    ('SECONDARY', 'Secondary Stage', 9, 12, 'FULL_ACADEMIC', TRUE, 'Formal descriptor with criteria text');

-- 3. student_profiles — Permanent student identity
CREATE TABLE student_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    apaar_id TEXT,
    apaar_verification_status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (apaar_verification_status IN ('PENDING', 'VERIFIED', 'MISMATCH', 'MANUALLY_CONFIRMED')),
    first_name TEXT NOT NULL,
    last_name TEXT,
    first_name_local TEXT,
    last_name_local TEXT,
    date_of_birth DATE NOT NULL,
    gender TEXT NOT NULL CHECK (gender IN ('MALE', 'FEMALE', 'OTHER', 'PREFER_NOT_TO_SAY')),
    aadhaar_last_four TEXT CHECK (aadhaar_last_four ~ '^\d{4}$'),
    mother_tongue TEXT,
    blood_group TEXT,
    photo_url TEXT,
    dedup_status TEXT NOT NULL DEFAULT 'UNIQUE'
        CHECK (dedup_status IN ('UNIQUE', 'CANDIDATE', 'CONFIRMED_DUPLICATE', 'CANONICAL')),
    dedup_canonical_id UUID REFERENCES student_profiles(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE UNIQUE INDEX idx_student_apaar ON student_profiles(tenant_id, apaar_id)
    WHERE apaar_id IS NOT NULL AND dedup_status NOT IN ('CONFIRMED_DUPLICATE');

-- 4. teacher_profiles — Permanent teacher identity
CREATE TABLE teacher_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    teacher_code TEXT,
    first_name TEXT NOT NULL,
    last_name TEXT,
    first_name_local TEXT,
    last_name_local TEXT,
    date_of_birth DATE,
    qualification TEXT,
    specialization TEXT[],
    years_of_experience INTEGER,
    status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'ON_LEAVE', 'TRANSFERRED', 'RETIRED', 'SUSPENDED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_teacher_code_per_tenant UNIQUE (tenant_id, teacher_code)
);

-- 5. parent_profiles — Guardian identity linked to students
CREATE TABLE parent_profiles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    user_id UUID NOT NULL REFERENCES users(id),
    first_name TEXT NOT NULL,
    last_name TEXT,
    phone TEXT,
    relationship_type TEXT NOT NULL
        CHECK (relationship_type IN ('MOTHER', 'FATHER', 'GUARDIAN', 'OTHER')),
    preferred_language TEXT NOT NULL DEFAULT 'en',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 6. student_parent_links — Many-to-many: one student can have multiple guardians
CREATE TABLE student_parent_links (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id) ON DELETE CASCADE,
    parent_id UUID NOT NULL REFERENCES parent_profiles(id) ON DELETE CASCADE,
    is_primary BOOLEAN NOT NULL DEFAULT FALSE,
    consent_record_id UUID REFERENCES data_consent_records(id),
    linked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_student_parent UNIQUE (tenant_id, student_id, parent_id)
);

-- 7. classes — Class sections within a school year
CREATE TABLE classes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE RESTRICT,
    academic_year_label TEXT NOT NULL,
    grade INTEGER NOT NULL,
    section TEXT NOT NULL DEFAULT 'A',
    stage_id UUID NOT NULL REFERENCES academic_stages(id),
    medium_of_instruction TEXT NOT NULL DEFAULT 'en',
    max_strength INTEGER,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_class_section UNIQUE (tenant_id, school_id, academic_year_label, grade, section)
);

-- 8. student_enrolments — Yearly enrolment records linking student to class
CREATE TABLE student_enrolments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    student_id UUID NOT NULL REFERENCES student_profiles(id) ON DELETE RESTRICT,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE RESTRICT,
    academic_year_label TEXT NOT NULL,
    roll_number TEXT,
    enrolment_date DATE NOT NULL DEFAULT CURRENT_DATE,
    status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'TRANSFERRED', 'WITHDRAWN', 'PROMOTED', 'DETAINED', 'GRADUATED')),
    exit_date DATE,
    exit_reason TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_enrolment UNIQUE (tenant_id, student_id, class_id, academic_year_label)
);

-- 9. teacher_assignments — Links teachers to classes
CREATE TABLE teacher_assignments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    teacher_id UUID NOT NULL REFERENCES teacher_profiles(id) ON DELETE RESTRICT,
    class_id UUID NOT NULL REFERENCES classes(id) ON DELETE RESTRICT,
    subject TEXT,
    is_class_teacher BOOLEAN NOT NULL DEFAULT FALSE,
    academic_year_label TEXT NOT NULL,
    assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'ACTIVE'
        CHECK (status IN ('ACTIVE', 'ENDED', 'TRANSFERRED')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_teacher_class UNIQUE (tenant_id, teacher_id, class_id, academic_year_label)
);

INSERT INTO schema_migrations (version, description) VALUES ('V002', 'Layer 2 — Government Identity');
