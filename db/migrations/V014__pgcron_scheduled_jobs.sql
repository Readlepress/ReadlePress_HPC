-- ============================================================================
-- V014 — pg_cron Scheduled Jobs
-- Nightly maintenance, audit verification, mastery sweep, retention reporting
-- All jobs wrapped in DO blocks that check for pg_cron availability.
-- ============================================================================

-- ============================================================
-- Helper: run_nightly_audit_verification()
-- Iterates through all tenants, calls verify_audit_chain,
-- inserts CRITICAL audit log entry if broken chains found.
-- ============================================================
CREATE OR REPLACE FUNCTION run_nightly_audit_verification()
RETURNS void AS $$
DECLARE
    r RECORD;
    v_total BIGINT;
    v_broken BIGINT;
    v_first_broken UUID;
    v_performed_by UUID;
BEGIN
    FOR r IN SELECT id FROM tenants WHERE status = 'ACTIVE'
    LOOP
        SELECT * INTO v_total, v_broken, v_first_broken
        FROM verify_audit_chain(r.id);

        IF v_broken > 0 THEN
            -- Get a valid user for performed_by (required by audit_log FK)
            SELECT id INTO v_performed_by
            FROM users u
            WHERE u.tenant_id = r.id
              AND u.status = 'ACTIVE'
            ORDER BY created_at ASC
            LIMIT 1;

            IF v_performed_by IS NOT NULL THEN
                PERFORM insert_audit_log(
                    r.id,
                    'AUDIT_CHAIN_BROKEN_CRITICAL',
                    'AUDIT',
                    COALESCE(v_first_broken, gen_random_uuid()),
                    v_performed_by,
                    NULL,
                    NULL,
                    jsonb_build_object(
                        'total_records', v_total,
                        'broken_chains', v_broken,
                        'first_broken_id', v_first_broken,
                        'source', 'nightly_audit_verification'
                    ),
                    NULL
                );
            END IF;
        END IF;
    END LOOP;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- Helper: process_pending_mastery_aggregation_jobs()
-- Processes PENDING jobs older than 1 hour: compute_ewm,
-- update mastery_aggregates, mark COMPLETED.
-- ============================================================
CREATE OR REPLACE FUNCTION process_pending_mastery_aggregation_jobs()
RETURNS INTEGER AS $$
DECLARE
    job RECORD;
    v_ewm DECIMAL;
    v_count INTEGER;
    v_last_event_at TIMESTAMPTZ;
    v_trend TEXT := 'INSUFFICIENT_DATA';
    v_confidence DECIMAL;
    v_processed INTEGER := 0;
BEGIN
    FOR job IN
        SELECT id, tenant_id, student_id, competency_id, academic_year_id
        FROM mastery_aggregation_jobs
        WHERE status = 'PENDING'
          AND queued_at < now() - interval '1 hour'
    LOOP
        BEGIN
            -- Compute EWM
            SELECT compute_ewm(
                job.tenant_id, job.student_id, job.competency_id, job.academic_year_id
            ) INTO v_ewm;

            -- Get event count and last_event_at
            SELECT
                COUNT(*)::INTEGER,
                MAX(observed_at)
            INTO v_count, v_last_event_at
            FROM mastery_events
            WHERE tenant_id = job.tenant_id
              AND student_id = job.student_id
              AND competency_id = job.competency_id
              AND event_status = 'ACTIVE'
              AND (job.academic_year_id IS NULL OR academic_year_id = job.academic_year_id);

            -- Trend calculation (need at least 3 events)
            IF v_count >= 3 THEN
                WITH ordered AS (
                    SELECT numeric_value,
                           row_number() OVER (ORDER BY observed_at DESC) AS rn
                    FROM mastery_events
                    WHERE tenant_id = job.tenant_id
                      AND student_id = job.student_id
                      AND competency_id = job.competency_id
                      AND event_status = 'ACTIVE'
                      AND (job.academic_year_id IS NULL OR academic_year_id = job.academic_year_id)
                    ORDER BY observed_at DESC
                    LIMIT 5
                ),
                recent_avg AS (
                    SELECT AVG(numeric_value) AS v FROM ordered WHERE rn <= 2
                ),
                older_avg AS (
                    SELECT AVG(numeric_value) AS v FROM ordered WHERE rn > 2
                )
                SELECT
                    CASE
                        WHEN (SELECT v FROM recent_avg) > (SELECT v FROM older_avg) + 0.05 THEN 'IMPROVING'
                        WHEN (SELECT v FROM recent_avg) < (SELECT v FROM older_avg) - 0.05 THEN 'DECLINING'
                        ELSE 'STABLE'
                    END
                INTO v_trend;
            END IF;

            v_confidence := LEAST(1.0, v_count / 10.0);

            -- Upsert mastery_aggregates
            INSERT INTO mastery_aggregates
                (tenant_id, student_id, competency_id, academic_year_id, current_ewm,
                 event_count, last_event_at, trend_direction, confidence_score, last_aggregated_at)
            VALUES
                (job.tenant_id, job.student_id, job.competency_id, job.academic_year_id, v_ewm,
                 v_count, v_last_event_at, v_trend, v_confidence, now())
            ON CONFLICT (tenant_id, student_id, competency_id, academic_year_id)
            DO UPDATE SET
                current_ewm = EXCLUDED.current_ewm,
                event_count = EXCLUDED.event_count,
                last_event_at = EXCLUDED.last_event_at,
                trend_direction = EXCLUDED.trend_direction,
                confidence_score = EXCLUDED.confidence_score,
                last_aggregated_at = now(),
                updated_at = now();

            -- Mark job COMPLETED
            UPDATE mastery_aggregation_jobs
            SET status = 'COMPLETED', completed_at = now()
            WHERE id = job.id;

            v_processed := v_processed + 1;
        EXCEPTION WHEN OTHERS THEN
            UPDATE mastery_aggregation_jobs
            SET status = 'FAILED', error_message = SQLERRM, retry_count = retry_count + 1
            WHERE id = job.id;
        END;
    END LOOP;

    RETURN v_processed;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================================
-- pg_cron job scheduling (only if extension is available)
-- ============================================================

-- Job 1: Nightly audit chain verification (2 AM daily)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('nightly-audit-chain-verification', '0 2 * * *', $BODY$
            SELECT run_nightly_audit_verification();
        $BODY$);
    END IF;
END $$;

-- Job 2: Nightly mastery aggregation sweep (3 AM daily)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('nightly-mastery-aggregation-sweep', '0 3 * * *', $BODY$
            SELECT process_pending_mastery_aggregation_jobs();
        $BODY$);
    END IF;
END $$;

-- Job 3: Weekly stale draft cleanup (Sunday 4 AM)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('weekly-stale-draft-cleanup', '0 4 * * 0', $BODY$
            UPDATE mastery_event_drafts
            SET sync_status = 'FAILED', sync_error = 'STALE_DRAFT_EXPIRED'
            WHERE sync_status = 'PENDING'
              AND created_at < now() - interval '30 days';
        $BODY$);
    END IF;
END $$;

-- Job 4: Daily intervention review checkpoint check (8 AM daily)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('daily-intervention-review-checkpoint', '0 8 * * *', $BODY$
            UPDATE intervention_review_checkpoints
            SET status = 'OVERDUE'
            WHERE scheduled_date <= CURRENT_DATE
              AND status = 'SCHEDULED';
        $BODY$);
    END IF;
END $$;

-- Job 5: Daily moderation SLA enforcement (every hour)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('hourly-moderation-sla-enforcement', '0 * * * *', $BODY$
            UPDATE feedback_requests
            SET moderation_overdue = TRUE
            WHERE moderation_status = 'PENDING'
              AND status = 'COMPLETED'
              AND moderation_overdue = FALSE
              AND completed_at + (moderation_sla_hours || ' hours')::interval < now();
        $BODY$);
    END IF;
END $$;

-- Job 6: Monthly data retention check (1st of month, 1 AM)
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        PERFORM cron.schedule('monthly-data-retention-check', '0 1 1 * *', $BODY$
            DO $inner$
            DECLARE
                v_count BIGINT;
                v_tenant RECORD;
                v_performed_by UUID;
            BEGIN
                FOR v_tenant IN SELECT id FROM tenants WHERE status = 'ACTIVE'
                LOOP
                    SELECT COUNT(*) INTO v_count
                    FROM consent_otp_attempts
                    WHERE tenant_id = v_tenant.id
                      AND attempted_at < now() - interval '90 days';

                    IF v_count > 0 THEN
                        SELECT id INTO v_performed_by
                        FROM users WHERE tenant_id = v_tenant.id AND status = 'ACTIVE' LIMIT 1;
                        IF v_performed_by IS NOT NULL THEN
                            PERFORM insert_audit_log(
                                v_tenant.id,
                                'RETENTION_REPORT.CONSENT_OTP_90D',
                                'RETENTION',
                                gen_random_uuid(),
                                v_performed_by,
                                NULL, NULL,
                                jsonb_build_object('count_older_than_90d', v_count, 'source', 'monthly_retention_check'),
                                NULL
                            );
                        END IF;
                    END IF;
                END LOOP;
            END $inner$;
        $BODY$);
    END IF;
END $$;

INSERT INTO schema_migrations (version, description)
VALUES ('V014', 'pg_cron scheduled jobs: audit verification, mastery sweep, retention');
