-- 0002: fixes from the Milestone 1 review. Runs in one transaction (psql -1).

-- Guard: these tables must still be empty (nothing real has been written yet).
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM id_map) OR EXISTS (SELECT 1 FROM outbound_messages) THEN
    RAISE EXCEPTION '0002 expects empty id_map and outbound_messages';
  END IF;
END $$;

-- 1. Privileges: tables are created by the postgres user, so give the app account access.
GRANT USAGE ON SCHEMA public TO orbit_ledger;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO orbit_ledger;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO orbit_ledger;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO orbit_ledger;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT ON SEQUENCES TO orbit_ledger;

-- 2. outbound_messages: store the logical message identity and forbid two ACTIVE copies of it.
--    Rescheduling (quiet hours, moved booking) = UPDATE due_at on the existing row, or cancel it and insert a replacement.
ALTER TABLE outbound_messages
  ADD COLUMN IF NOT EXISTS automation text,
  ADD COLUMN IF NOT EXISTS opportunity_id text,
  ADD COLUMN IF NOT EXISTS step text;
ALTER TABLE outbound_messages
  ALTER COLUMN automation SET NOT NULL,
  ALTER COLUMN opportunity_id SET NOT NULL,
  ALTER COLUMN step SET NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS outbound_active_logical_uq
  ON outbound_messages (automation, opportunity_id, step)
  WHERE status IN ('scheduled','sent','delivered');

-- 3. id_map: many external ids per person, each external id belongs to exactly one person.
DROP TABLE id_map;
CREATE TABLE id_map (
  id bigserial PRIMARY KEY,
  twenty_person_id text NOT NULL,
  kind text NOT NULL CHECK (kind IN ('meta_psid','meta_lead','calcom_attendee')),
  external_id text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (kind, external_id));
CREATE INDEX id_map_person_idx ON id_map (twenty_person_id);
GRANT SELECT, INSERT, UPDATE, DELETE ON id_map TO orbit_ledger;
GRANT USAGE, SELECT ON SEQUENCE id_map_id_seq TO orbit_ledger;

-- 4. automation_switches: every mode change must name who made it, and stamps the time.
CREATE OR REPLACE FUNCTION automation_switch_audit() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' OR NEW.mode IS DISTINCT FROM OLD.mode THEN
    IF NEW.mode <> 'off' AND NEW.changed_by IS NULL THEN
      RAISE EXCEPTION 'changed_by is required when switching an automation on' USING ERRCODE = 'check_violation';
    END IF;
    IF TG_OP = 'UPDATE' THEN NEW.changed_at := now(); END IF;
  END IF;
  RETURN NEW;
END $$;
DROP TRIGGER IF EXISTS automation_switch_audit ON automation_switches;
CREATE TRIGGER automation_switch_audit BEFORE INSERT OR UPDATE ON automation_switches
  FOR EACH ROW EXECUTE FUNCTION automation_switch_audit();

INSERT INTO schema_migrations(version) VALUES ('0002_review_fixes') ON CONFLICT DO NOTHING;
