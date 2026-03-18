-- ============================================================================
-- V015 — pgaudit Configuration
-- Statement-level and object-level auditing for sensitive operations.
-- All blocks check for pgaudit extension availability.
-- ============================================================================

DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgaudit') THEN
        -- Global/session defaults for database
        EXECUTE format('ALTER DATABASE %I SET pgaudit.log = ''write, ddl''', current_database());
        EXECUTE format('ALTER DATABASE %I SET pgaudit.log_catalog = off', current_database());
        EXECUTE format('ALTER DATABASE %I SET pgaudit.log_relation = on', current_database());
        EXECUTE format('ALTER DATABASE %I SET pgaudit.log_statement_once = on', current_database());

        -- Role-specific overrides
        -- audit_viewer: full audit trail (sensitive role)
        ALTER ROLE audit_viewer SET pgaudit.log = 'read, write, ddl, function';

        -- app_rw: write operations only (INSERT/UPDATE/DELETE)
        ALTER ROLE app_rw SET pgaudit.log = 'write';
    END IF;
END $$;

-- ============================================================
-- Object-level auditing on sensitive tables
-- Uses pgaudit.role: create audit role, grant on tables, set role
-- ============================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pgaudit') THEN
        -- Create audit role for object-level logging (NOLOGIN)
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'pgaudit_objects') THEN
            CREATE ROLE pgaudit_objects NOLOGIN;
        END IF;

        GRANT USAGE ON SCHEMA public TO pgaudit_objects;

        -- Grant on sensitive tables (enables object-level audit when accessed)
        GRANT SELECT, INSERT, UPDATE, DELETE ON student_disability_profiles TO pgaudit_objects;
        GRANT SELECT, INSERT, UPDATE, DELETE ON welfare_case_access_log TO pgaudit_objects;
        GRANT SELECT, INSERT, UPDATE, DELETE ON intervention_plans TO pgaudit_objects;
        GRANT SELECT, INSERT, UPDATE, DELETE ON data_consent_records TO pgaudit_objects;
        GRANT SELECT, INSERT, UPDATE, DELETE ON audit_log TO pgaudit_objects;

        -- Enable object-level auditing via pgaudit.role
        EXECUTE format('ALTER DATABASE %I SET pgaudit.role = ''pgaudit_objects''', current_database());
    END IF;
EXCEPTION
    WHEN undefined_object THEN
        RAISE NOTICE 'pgaudit extension not fully available — skipping object-level audit setup';
    WHEN OTHERS THEN
        RAISE NOTICE 'pgaudit object-level setup: %', SQLERRM;
END $$;

INSERT INTO schema_migrations (version, description)
VALUES ('V015', 'pgaudit configuration: statement-level and object-level auditing');
