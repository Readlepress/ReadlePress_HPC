-- ============================================================================
-- Repeatable Migration: Database Functions
-- ============================================================================

-- Audit log insertion helper
CREATE OR REPLACE FUNCTION insert_audit_log(
    p_tenant_id UUID,
    p_event_type TEXT,
    p_entity_type TEXT,
    p_entity_id UUID,
    p_performed_by UUID,
    p_before_state JSONB DEFAULT NULL,
    p_after_state JSONB DEFAULT NULL,
    p_metadata JSONB DEFAULT NULL,
    p_ip_address INET DEFAULT NULL
) RETURNS UUID AS $$
DECLARE
    v_prev_hash TEXT;
    v_new_id UUID;
BEGIN
    SELECT row_hash INTO v_prev_hash
    FROM audit_log
    WHERE tenant_id = p_tenant_id
    ORDER BY performed_at DESC
    LIMIT 1;

    INSERT INTO audit_log (
        tenant_id, event_type, entity_type, entity_id,
        performed_by, before_state, after_state, metadata,
        ip_address, prev_log_hash
    ) VALUES (
        p_tenant_id, p_event_type, p_entity_type, p_entity_id,
        p_performed_by, p_before_state, p_after_state, p_metadata,
        p_ip_address, v_prev_hash
    ) RETURNING id INTO v_new_id;

    RETURN v_new_id;
END;
$$ LANGUAGE plpgsql;

-- Audit hash chain verification
CREATE OR REPLACE FUNCTION verify_audit_chain(p_tenant_id UUID)
RETURNS TABLE (
    total_records BIGINT,
    broken_chains BIGINT,
    first_broken_id UUID
) AS $$
BEGIN
    RETURN QUERY
    WITH ordered_logs AS (
        SELECT
            id, row_hash, prev_log_hash,
            LAG(row_hash) OVER (ORDER BY performed_at, id) AS expected_prev_hash
        FROM audit_log
        WHERE tenant_id = p_tenant_id
        ORDER BY performed_at, id
    ),
    broken AS (
        SELECT id
        FROM ordered_logs
        WHERE prev_log_hash IS NOT NULL
          AND prev_log_hash != expected_prev_hash
    )
    SELECT
        (SELECT COUNT(*) FROM audit_log WHERE tenant_id = p_tenant_id)::BIGINT,
        (SELECT COUNT(*) FROM broken)::BIGINT,
        (SELECT b.id FROM broken b LIMIT 1);
END;
$$ LANGUAGE plpgsql;

-- EWM (Exponentially Weighted Moving Average) computation
CREATE OR REPLACE FUNCTION compute_ewm(
    p_tenant_id UUID,
    p_student_id UUID,
    p_competency_id UUID,
    p_academic_year_id UUID DEFAULT NULL
) RETURNS DECIMAL AS $$
DECLARE
    v_ewm DECIMAL := NULL;
    v_alpha DECIMAL;
    v_event RECORD;
    v_default_alpha DECIMAL := 0.400;
BEGIN
    FOR v_event IN
        SELECT
            me.numeric_value,
            me.source_type,
            COALESCE(ap.alpha, v_default_alpha) AS alpha
        FROM mastery_events me
        LEFT JOIN aggregation_policy ap
            ON ap.tenant_id = me.tenant_id AND ap.source_type = me.source_type AND ap.is_active = TRUE
        WHERE me.tenant_id = p_tenant_id
          AND me.student_id = p_student_id
          AND me.competency_id = p_competency_id
          AND me.event_status = 'ACTIVE'
          AND (p_academic_year_id IS NULL OR me.academic_year_id = p_academic_year_id)
        ORDER BY me.observed_at ASC
    LOOP
        v_alpha := v_event.alpha;
        IF v_ewm IS NULL THEN
            v_ewm := v_event.numeric_value;
        ELSE
            v_ewm := v_alpha * v_event.numeric_value + (1.0 - v_alpha) * v_ewm;
        END IF;
    END LOOP;

    RETURN v_ewm;
END;
$$ LANGUAGE plpgsql;

-- Merkle tree computation for year-lock
CREATE OR REPLACE FUNCTION compute_merkle_root(p_academic_year_id UUID, p_tenant_id UUID)
RETURNS TABLE (
    root_hash TEXT,
    leaf_count INTEGER,
    tree_depth INTEGER
) AS $$
DECLARE
    v_leaves TEXT[];
    v_level TEXT[];
    v_next_level TEXT[];
    v_i INTEGER;
    v_depth INTEGER := 0;
BEGIN
    SELECT ARRAY_AGG(
        encode(sha256(('LEAF:' || id::text || ':' || content_hash)::bytea), 'hex')
        ORDER BY id
    )
    INTO v_leaves
    FROM mastery_events
    WHERE tenant_id = p_tenant_id
      AND academic_year_id = p_academic_year_id
      AND event_status = 'ACTIVE';

    IF v_leaves IS NULL OR array_length(v_leaves, 1) IS NULL THEN
        root_hash := encode(sha256('EMPTY_TREE'::bytea), 'hex');
        leaf_count := 0;
        tree_depth := 0;
        RETURN NEXT;
        RETURN;
    END IF;

    leaf_count := array_length(v_leaves, 1);
    v_level := v_leaves;

    WHILE array_length(v_level, 1) > 1 LOOP
        v_next_level := ARRAY[]::TEXT[];
        v_i := 1;

        WHILE v_i <= array_length(v_level, 1) LOOP
            IF v_i + 1 <= array_length(v_level, 1) THEN
                v_next_level := v_next_level || encode(
                    sha256(('NODE:' || v_level[v_i] || ':' || v_level[v_i + 1])::bytea), 'hex'
                );
            ELSE
                v_next_level := v_next_level || encode(
                    sha256(('NODE:' || v_level[v_i] || ':' || v_level[v_i])::bytea), 'hex'
                );
            END IF;
            v_i := v_i + 2;
        END LOOP;

        v_level := v_next_level;
        v_depth := v_depth + 1;
    END LOOP;

    root_hash := v_level[1];
    tree_depth := v_depth;
    RETURN NEXT;
END;
$$ LANGUAGE plpgsql;

-- Year-close completeness check
CREATE OR REPLACE FUNCTION check_year_close_readiness(
    p_academic_year_id UUID,
    p_tenant_id UUID
) RETURNS TABLE (
    check_type TEXT,
    check_result TEXT,
    blocking BOOLEAN,
    details JSONB
) AS $$
BEGIN
    -- Check pending mastery aggregation jobs
    RETURN QUERY
    SELECT
        'PENDING_AGGREGATION_JOBS'::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END::TEXT,
        TRUE,
        jsonb_build_object('pending_count', COUNT(*))
    FROM mastery_aggregation_jobs
    WHERE tenant_id = p_tenant_id
      AND status IN ('PENDING', 'PROCESSING');

    -- Check pending drafts
    RETURN QUERY
    SELECT
        'PENDING_DRAFTS'::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END::TEXT,
        TRUE,
        jsonb_build_object('pending_draft_count', COUNT(*))
    FROM mastery_event_drafts
    WHERE tenant_id = p_tenant_id
      AND sync_status IN ('PENDING', 'SYNCING');

    -- Check open override requests
    RETURN QUERY
    SELECT
        'OPEN_OVERRIDES'::TEXT,
        CASE WHEN COUNT(*) > 0 THEN 'FAIL' ELSE 'PASS' END::TEXT,
        TRUE,
        jsonb_build_object('open_overrides', COUNT(*))
    FROM locked_year_override_requests
    WHERE tenant_id = p_tenant_id
      AND academic_year_id = p_academic_year_id
      AND status IN ('PENDING', 'FIRST_APPROVED');
END;
$$ LANGUAGE plpgsql;

-- k-anonymity threshold computation for small classes
CREATE OR REPLACE FUNCTION compute_k_threshold(class_size INTEGER, default_k INTEGER DEFAULT 5)
RETURNS INTEGER AS $$
BEGIN
    IF class_size < 12 THEN
        RETURN GREATEST(default_k, CEIL(class_size * 0.6)::INTEGER);
    END IF;
    RETURN default_k;
END;
$$ LANGUAGE plpgsql IMMUTABLE;

-- Inclusion indicator suppression check
CREATE OR REPLACE FUNCTION should_suppress_inclusion_indicators(
    p_school_id UUID,
    p_tenant_id UUID,
    p_k_threshold INTEGER DEFAULT 3
) RETURNS BOOLEAN AS $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM student_disability_profiles
    WHERE tenant_id = p_tenant_id
      AND student_id IN (
          SELECT sp.id FROM student_profiles sp
          JOIN student_enrolments se ON se.student_id = sp.id
          JOIN classes c ON c.id = se.class_id
          WHERE c.school_id = p_school_id
            AND se.status = 'ACTIVE'
      )
      AND is_active = TRUE;

    RETURN v_count < p_k_threshold;
END;
$$ LANGUAGE plpgsql;
