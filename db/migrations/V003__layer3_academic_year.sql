-- ============================================================================
-- Layer 3 — Academic Year Lifecycle
-- State machine, Merkle-root year snapshot, year-close workflow
-- ============================================================================

-- 1. academic_years — Year records with status state machine
CREATE TABLE academic_years (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    school_id UUID NOT NULL REFERENCES schools(id) ON DELETE RESTRICT,
    label TEXT NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    status TEXT NOT NULL DEFAULT 'PLANNING'
        CHECK (status IN ('PLANNING', 'ACTIVE', 'REVIEW', 'LOCKED')),
    year_snapshot_id UUID,
    locked_at TIMESTAMPTZ,
    locked_by UUID REFERENCES users(id),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_year_per_school UNIQUE (tenant_id, school_id, label),
    CONSTRAINT valid_date_range CHECK (end_date > start_date)
);

-- Trigger: Enforce one-way state machine transitions
CREATE OR REPLACE FUNCTION enforce_year_state_machine()
RETURNS TRIGGER AS $$
DECLARE
    valid_transitions TEXT[][] := ARRAY[
        ARRAY['PLANNING', 'ACTIVE'],
        ARRAY['ACTIVE', 'REVIEW'],
        ARRAY['REVIEW', 'LOCKED']
    ];
    is_valid BOOLEAN := FALSE;
    t TEXT[];
BEGIN
    IF OLD.status = NEW.status THEN
        RETURN NEW;
    END IF;

    FOREACH t SLICE 1 IN ARRAY valid_transitions LOOP
        IF OLD.status = t[1] AND NEW.status = t[2] THEN
            is_valid := TRUE;
            EXIT;
        END IF;
    END LOOP;

    IF NOT is_valid THEN
        RAISE EXCEPTION 'Invalid academic year state transition from % to %', OLD.status, NEW.status
            USING ERRCODE = 'check_violation';
    END IF;

    IF NEW.status = 'LOCKED' THEN
        NEW.locked_at := now();
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_year_state_machine
    BEFORE UPDATE ON academic_years
    FOR EACH ROW
    EXECUTE FUNCTION enforce_year_state_machine();

-- 2. terms — Term subdivisions within a year
CREATE TABLE terms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    name TEXT NOT NULL,
    term_number INTEGER NOT NULL,
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_term UNIQUE (tenant_id, academic_year_id, term_number),
    CONSTRAINT valid_term_dates CHECK (end_date > start_date)
);

-- 3. year_snapshots — The Merkle-root snapshot created at year-lock
CREATE TABLE year_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id) ON DELETE RESTRICT,
    merkle_root_hash TEXT NOT NULL,
    total_leaf_count INTEGER NOT NULL,
    tree_depth INTEGER NOT NULL,
    snapshot_hash TEXT NOT NULL,
    taxonomy_snapshot JSONB NOT NULL,
    rubric_snapshot JSONB NOT NULL DEFAULT '{}',
    credit_policy_snapshot JSONB NOT NULL DEFAULT '{}',
    school_identity_snapshot JSONB NOT NULL,
    policy_pack_snapshot JSONB NOT NULL DEFAULT '{}',
    external_anchor_ref TEXT,
    external_anchor_timestamp TIMESTAMPTZ,
    tsa_response BYTEA,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT unique_snapshot_per_year UNIQUE (tenant_id, academic_year_id)
);

-- Add FK from academic_years to year_snapshots
ALTER TABLE academic_years
    ADD CONSTRAINT fk_year_snapshot
    FOREIGN KEY (year_snapshot_id) REFERENCES year_snapshots(id);

-- 4. year_close_completeness_checks — Records each completeness check run
CREATE TABLE year_close_completeness_checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    check_type TEXT NOT NULL
        CHECK (check_type IN (
            'PENDING_AGGREGATION_JOBS', 'PENDING_CREDIT_JOBS', 'PENDING_SQAA_JOBS',
            'PENDING_DRAFTS', 'OPEN_OVERRIDES', 'UNVERIFIED_CPD', 'QUEUE_DRAIN'
        )),
    check_result TEXT NOT NULL CHECK (check_result IN ('PASS', 'FAIL', 'WARNING')),
    blocking BOOLEAN NOT NULL DEFAULT TRUE,
    details JSONB,
    checked_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    checked_by UUID REFERENCES users(id)
);

-- 5. locked_year_override_requests — Override workflow for locked data
CREATE TABLE locked_year_override_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    tenant_id UUID NOT NULL REFERENCES tenants(id) ON DELETE RESTRICT,
    academic_year_id UUID NOT NULL REFERENCES academic_years(id),
    entity_type TEXT NOT NULL,
    entity_id UUID NOT NULL,
    reason TEXT NOT NULL,
    requested_by UUID NOT NULL REFERENCES users(id),
    requested_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'FIRST_APPROVED', 'APPROVED', 'REJECTED')),
    first_approver_id UUID REFERENCES users(id),
    first_approved_at TIMESTAMPTZ,
    second_approver_id UUID REFERENCES users(id),
    second_approved_at TIMESTAMPTZ,
    rejection_reason TEXT,
    CONSTRAINT dual_approval_check CHECK (
        first_approver_id IS NULL OR
        second_approver_id IS NULL OR
        first_approver_id != second_approver_id
    ),
    CONSTRAINT self_approval_check CHECK (
        (first_approver_id IS NULL OR first_approver_id != requested_by)
        AND (second_approver_id IS NULL OR second_approver_id != requested_by)
    )
);

-- Trigger: Prevent data modification in LOCKED academic years
CREATE OR REPLACE FUNCTION prevent_locked_year_modification()
RETURNS TRIGGER AS $$
DECLARE
    year_status TEXT;
BEGIN
    IF TG_TABLE_NAME = 'student_enrolments' THEN
        SELECT ay.status INTO year_status
        FROM academic_years ay
        JOIN classes c ON c.academic_year_label = ay.label AND c.school_id = ay.school_id AND c.tenant_id = ay.tenant_id
        WHERE c.id = NEW.class_id AND ay.tenant_id = NEW.tenant_id
        LIMIT 1;

        IF year_status = 'LOCKED' THEN
            RAISE EXCEPTION 'Cannot modify data in a LOCKED academic year'
                USING ERRCODE = 'check_violation';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

INSERT INTO schema_migrations (version, description) VALUES ('V003', 'Layer 3 — Academic Year Lifecycle');
