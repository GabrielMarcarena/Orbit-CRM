-- Run inside the orbit_ledger database. Each check raises an exception on failure.
\set ON_ERROR_STOP on
BEGIN;

-- 1. webhook dedupe: same (source,event_id) twice must fail
INSERT INTO processed_events(source, event_id) VALUES ('twenty','evt-1');
DO $$ BEGIN
  BEGIN INSERT INTO processed_events(source, event_id) VALUES ('twenty','evt-1');
    RAISE EXCEPTION 'FAIL: duplicate processed_events accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;

-- 2. outbound idempotency: same idem_key twice must fail
INSERT INTO outbound_messages(idem_key, phone, body, due_at) VALUES ('k1','+639171234567','hi', now());
DO $$ BEGIN
  BEGIN INSERT INTO outbound_messages(idem_key, phone, body, due_at) VALUES ('k1','+639171234567','hi', now());
    RAISE EXCEPTION 'FAIL: duplicate idem_key accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;

-- 3. status must be one of the allowed values
DO $$ BEGIN
  BEGIN INSERT INTO outbound_messages(idem_key, phone, body, due_at, status) VALUES ('k2','+639171234567','hi', now(), 'bogus');
    RAISE EXCEPTION 'FAIL: bad status accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 4. phone must be E.164
DO $$ BEGIN
  BEGIN INSERT INTO outbound_messages(idem_key, phone, body, due_at) VALUES ('k3','09171234567','hi', now());
    RAISE EXCEPTION 'FAIL: non-E.164 phone accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 5. automations default to off, mode restricted
INSERT INTO automation_switches(automation) VALUES ('speed_to_lead');
DO $$ BEGIN
  IF (SELECT mode FROM automation_switches WHERE automation='speed_to_lead') <> 'off' THEN
    RAISE EXCEPTION 'FAIL: switch not off by default'; END IF;
  BEGIN UPDATE automation_switches SET mode='live' WHERE automation='speed_to_lead';
    RAISE EXCEPTION 'FAIL: live allowed without checklist_passed_at';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 6. consent: one row per phone, status restricted
INSERT INTO consent(phone, status, source) VALUES ('+639171234567','opted_in','website');
DO $$ BEGIN
  BEGIN INSERT INTO consent(phone, status, source) VALUES ('+639171234567','opted_in','event');
    RAISE EXCEPTION 'FAIL: duplicate consent row accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;

ROLLBACK;
SELECT 'LEDGER TESTS PASSED' AS result;
