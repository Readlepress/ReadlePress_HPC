-- V030: Soft-delete triggers
-- Every table with a deleted_at column gets a BEFORE UPDATE trigger that
-- logs the soft-delete event into soft_delete_log, reading session variables
-- app.user_id and app.deletion_reason.

-- Generic trigger function shared by all soft-deletable tables
CREATE OR REPLACE FUNCTION log_soft_delete()
RETURNS TRIGGER AS $$
DECLARE
  v_user_id UUID;
  v_reason TEXT;
BEGIN
  IF OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    v_user_id := current_setting('app.user_id', TRUE)::UUID;
    v_reason := COALESCE(current_setting('app.deletion_reason', TRUE), 'No reason provided');

    INSERT INTO soft_delete_log (tenant_id, table_name, record_id, deleted_by, deletion_reason, deleted_at)
    VALUES (
      CASE WHEN TG_TABLE_NAME = 'tenants' THEN NEW.id ELSE NEW.tenant_id END,
      TG_TABLE_NAME,
      NEW.id,
      COALESCE(v_user_id, '00000000-0000-0000-0000-000000000000'::UUID),
      v_reason,
      NEW.deleted_at
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Attach the trigger to every table that has deleted_at (except soft_delete_log itself)
DO $$
DECLARE
  tbl TEXT;
BEGIN
  FOR tbl IN
    SELECT table_name FROM information_schema.columns
    WHERE column_name = 'deleted_at' AND table_schema = 'public'
      AND table_name != 'soft_delete_log'
  LOOP
    EXECUTE format(
      'CREATE TRIGGER trg_soft_delete_%s BEFORE UPDATE ON %I FOR EACH ROW EXECUTE FUNCTION log_soft_delete()',
      tbl, tbl
    );
  END LOOP;
END $$;

-- Migration tracking
INSERT INTO schema_migrations (version, description)
VALUES ('V030', 'Soft-delete triggers for all deleted_at tables')
ON CONFLICT (version) DO NOTHING;
