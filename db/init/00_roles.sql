-- ReadlePress Database Role Architecture
-- Four PostgreSQL roles as specified in the architecture

-- app_rw: Application read/write — used by API server. NEVER granted SUPERUSER.
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_rw') THEN
    CREATE ROLE app_rw LOGIN PASSWORD 'app_rw_dev_password';
  END IF;
END $$;

-- app_ro: Read-only for reporting and analytics
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'app_ro') THEN
    CREATE ROLE app_ro LOGIN PASSWORD 'app_ro_dev_password';
  END IF;
END $$;

-- audit_viewer: Procurement authority — read-only on aggregate tables only, RLS blocks student data
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'audit_viewer') THEN
    CREATE ROLE audit_viewer LOGIN PASSWORD 'audit_viewer_dev_password';
  END IF;
END $$;

-- migration_runner: Runs Flyway migrations only
DO $$ BEGIN
  IF NOT EXISTS (SELECT FROM pg_roles WHERE rolname = 'migration_runner') THEN
    CREATE ROLE migration_runner LOGIN PASSWORD 'migration_runner_dev_password';
  END IF;
END $$;

-- Grant schema usage
GRANT USAGE ON SCHEMA public TO app_rw, app_ro, audit_viewer, migration_runner;
GRANT CREATE ON SCHEMA public TO migration_runner;

-- migration_runner needs full DDL privileges
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON TABLES TO migration_runner;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON SEQUENCES TO migration_runner;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT ALL ON FUNCTIONS TO migration_runner;

-- app_rw gets DML privileges (INSERT, UPDATE, DELETE, SELECT)
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE ON SEQUENCES TO app_rw;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT EXECUTE ON FUNCTIONS TO app_rw;

-- app_ro gets SELECT only
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO app_ro;

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";
