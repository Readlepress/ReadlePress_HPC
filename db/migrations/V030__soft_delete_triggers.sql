-- ============================================================================
-- V030 — Soft-delete triggers
-- Every table with a deleted_at column gets a BEFORE UPDATE trigger that
-- logs the soft-delete event into soft_delete_log, reading session variables
-- app.user_id and app.deletion_reason.
-- ============================================================================

-- Generic trigger function shared by all soft-deletable tables
CREATE OR REPLACE FUNCTION log_soft_delete()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
        INSERT INTO soft_delete_log (tenant_id, table_name, record_id, deleted_by, deletion_reason)
        VALUES (
            COALESCE(NEW.tenant_id, current_setting('app.tenant_id', TRUE)::uuid),
            TG_TABLE_NAME,
            NEW.id,
            COALESCE(current_setting('app.user_id', TRUE)::uuid, '00000000-0000-0000-0000-000000000000'::uuid),
            COALESCE(current_setting('app.deletion_reason', TRUE), 'No reason provided')
        );
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- tenants
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'tenants' AND column_name = 'deleted_at') THEN
        DROP TRIGGER IF EXISTS trg_soft_delete_tenants ON tenants;
        CREATE TRIGGER trg_soft_delete_tenants
            BEFORE UPDATE ON tenants
            FOR EACH ROW
            EXECUTE FUNCTION log_soft_delete();
    END IF;
END $$;

-- users
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'users' AND column_name = 'deleted_at') THEN
        DROP TRIGGER IF EXISTS trg_soft_delete_users ON users;
        CREATE TRIGGER trg_soft_delete_users
            BEFORE UPDATE ON users
            FOR EACH ROW
            EXECUTE FUNCTION log_soft_delete();
    END IF;
END $$;

-- schools
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'schools' AND column_name = 'deleted_at') THEN
        DROP TRIGGER IF EXISTS trg_soft_delete_schools ON schools;
        CREATE TRIGGER trg_soft_delete_schools
            BEFORE UPDATE ON schools
            FOR EACH ROW
            EXECUTE FUNCTION log_soft_delete();
    END IF;
END $$;

-- student_profiles
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'student_profiles' AND column_name = 'deleted_at') THEN
        DROP TRIGGER IF EXISTS trg_soft_delete_student_profiles ON student_profiles;
        CREATE TRIGGER trg_soft_delete_student_profiles
            BEFORE UPDATE ON student_profiles
            FOR EACH ROW
            EXECUTE FUNCTION log_soft_delete();
    END IF;
END $$;

-- evidence_records
DO $$ BEGIN
    IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'evidence_records' AND column_name = 'deleted_at') THEN
        DROP TRIGGER IF EXISTS trg_soft_delete_evidence_records ON evidence_records;
        CREATE TRIGGER trg_soft_delete_evidence_records
            BEFORE UPDATE ON evidence_records
            FOR EACH ROW
            EXECUTE FUNCTION log_soft_delete();
    END IF;
END $$;

-- Migration tracking
INSERT INTO schema_migrations (version, description)
VALUES ('V030', 'Soft-delete triggers for all deleted_at tables')
ON CONFLICT (version) DO NOTHING;
