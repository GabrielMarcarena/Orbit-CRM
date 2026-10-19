-- orbit_ledger initial schema (spec section 4). Idempotent: safe to re-run.
CREATE TABLE IF NOT EXISTS schema_migrations (
  version text PRIMARY KEY, applied_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS processed_events (
  id bigserial PRIMARY KEY,
  source text NOT NULL,
  event_id text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (source, event_id));

CREATE TABLE IF NOT EXISTS id_map (
  id bigserial PRIMARY KEY,
  twenty_person_id text UNIQUE,
  meta_psid text UNIQUE,
  meta_lead_id text UNIQUE,
  calcom_attendee text,
  created_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS consent (
  phone text PRIMARY KEY CHECK (phone ~ '^\+[1-9][0-9]{7,14}$'),
  status text NOT NULL CHECK (status IN ('opted_in','opted_out')),
  source text NOT NULL,
  changed_at timestamptz NOT NULL DEFAULT now());

CREATE TABLE IF NOT EXISTS outbound_messages (
  id bigserial PRIMARY KEY,
  idem_key text NOT NULL UNIQUE,
  phone text NOT NULL CHECK (phone ~ '^\+[1-9][0-9]{7,14}$'),
  body text NOT NULL,
  due_at timestamptz NOT NULL,
  status text NOT NULL DEFAULT 'scheduled'
    CHECK (status IN ('scheduled','skipped','sent','delivered','failed','cancelled')),
  provider_message_id text,
  attempts int NOT NULL DEFAULT 0,
  last_error text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS outbound_due_idx ON outbound_messages (due_at) WHERE status = 'scheduled';

CREATE TABLE IF NOT EXISTS automation_switches (
  automation text PRIMARY KEY,
  mode text NOT NULL DEFAULT 'off' CHECK (mode IN ('off','test','live')),
  changed_by text,
  changed_at timestamptz NOT NULL DEFAULT now(),
  checklist_passed_at timestamptz,
  CHECK (mode <> 'live' OR checklist_passed_at IS NOT NULL));

CREATE TABLE IF NOT EXISTS test_numbers (
  phone text PRIMARY KEY CHECK (phone ~ '^\+[1-9][0-9]{7,14}$'),
  label text);

CREATE TABLE IF NOT EXISTS dead_letter (
  id bigserial PRIMARY KEY,
  automation text NOT NULL,
  payload jsonb NOT NULL,
  error text NOT NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  resolved_at timestamptz);

CREATE TABLE IF NOT EXISTS alerts (
  id bigserial PRIMARY KEY,
  severity text NOT NULL CHECK (severity IN ('urgent','normal')),
  message text NOT NULL,
  channels text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now());

INSERT INTO schema_migrations(version) VALUES ('0001_init') ON CONFLICT DO NOTHING;
