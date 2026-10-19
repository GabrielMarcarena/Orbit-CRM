-- Run inside the orbit_ledger database. Each check raises an exception on failure.
\set ON_ERROR_STOP on
BEGIN;

-- 1. webhook dedupe
INSERT INTO processed_events(source, event_id) VALUES ('twenty','evt-1');
DO $$ BEGIN
  BEGIN INSERT INTO processed_events(source, event_id) VALUES ('twenty','evt-1');
    RAISE EXCEPTION 'FAIL: duplicate processed_events accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;

-- 2. outbound: idem_key unique
INSERT INTO outbound_messages(idem_key, automation, opportunity_id, step, phone, body, due_at)
  VALUES ('k1','speed_to_lead','opp-1','sms1','+639171234567','hi', now());
DO $$ BEGIN
  BEGIN INSERT INTO outbound_messages(idem_key, automation, opportunity_id, step, phone, body, due_at)
    VALUES ('k1','other','opp-9','sms1','+639171234567','hi', now());
    RAISE EXCEPTION 'FAIL: duplicate idem_key accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;

-- 2b. same logical message (automation, opportunity, step) with a different idem_key/due_at is rejected while active
DO $$ BEGIN
  BEGIN INSERT INTO outbound_messages(idem_key, automation, opportunity_id, step, phone, body, due_at)
    VALUES ('k1-moved','speed_to_lead','opp-1','sms1','+639171234567','hi', now() + interval '10 hours');
    RAISE EXCEPTION 'FAIL: rescheduled duplicate of an active message accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
END $$;
-- 2c. after cancelling, a replacement is allowed
UPDATE outbound_messages SET status='cancelled' WHERE idem_key='k1';
INSERT INTO outbound_messages(idem_key, automation, opportunity_id, step, phone, body, due_at)
  VALUES ('k1-replacement','speed_to_lead','opp-1','sms1','+639171234567','hi', now() + interval '1 hour');

-- 3. status values
DO $$ BEGIN
  BEGIN INSERT INTO outbound_messages(idem_key, automation, opportunity_id, step, phone, body, due_at, status)
    VALUES ('k2','a','o','s','+639171234567','hi', now(), 'bogus');
    RAISE EXCEPTION 'FAIL: bad status accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 4. E.164 phones (outbound, consent, test_numbers)
DO $$ BEGIN
  BEGIN INSERT INTO outbound_messages(idem_key, automation, opportunity_id, step, phone, body, due_at)
    VALUES ('k3','a','o','s','09171234567','hi', now());
    RAISE EXCEPTION 'FAIL: non-E.164 outbound phone accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO consent(phone,status,source) VALUES ('09171234567','opted_in','x');
    RAISE EXCEPTION 'FAIL: non-E.164 consent phone accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN INSERT INTO test_numbers(phone) VALUES ('09171234567');
    RAISE EXCEPTION 'FAIL: non-E.164 test phone accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 5. automation switches: default off; live needs checklist; mode changes need changed_by and bump changed_at
INSERT INTO automation_switches(automation, changed_at) VALUES ('speed_to_lead', now() - interval '1 day');
DO $$ DECLARE t0 timestamptz; t1 timestamptz; BEGIN
  IF (SELECT mode FROM automation_switches WHERE automation='speed_to_lead') <> 'off' THEN
    RAISE EXCEPTION 'FAIL: switch not off by default'; END IF;
  BEGIN UPDATE automation_switches SET mode='test' WHERE automation='speed_to_lead';
    RAISE EXCEPTION 'FAIL: mode change without changed_by accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
  BEGIN UPDATE automation_switches SET mode='live', changed_by='owner' WHERE automation='speed_to_lead';
    RAISE EXCEPTION 'FAIL: live allowed without checklist_passed_at';
  EXCEPTION WHEN check_violation THEN NULL; END;
  SELECT changed_at INTO t0 FROM automation_switches WHERE automation='speed_to_lead';
  UPDATE automation_switches SET mode='test', changed_by='owner' WHERE automation='speed_to_lead';
  SELECT changed_at INTO t1 FROM automation_switches WHERE automation='speed_to_lead';
  IF t1 <= t0 THEN RAISE EXCEPTION 'FAIL: changed_at not bumped on mode change'; END IF;
  UPDATE automation_switches SET checklist_passed_at=now() WHERE automation='speed_to_lead';
  UPDATE automation_switches SET mode='live', changed_by='owner' WHERE automation='speed_to_lead';
  BEGIN INSERT INTO automation_switches(automation, mode) VALUES ('bogus','sometimes');
    RAISE EXCEPTION 'FAIL: bad mode accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 6. consent: one row per phone; status restricted
INSERT INTO consent(phone, status, source) VALUES ('+639171234567','opted_in','website');
DO $$ BEGIN
  BEGIN INSERT INTO consent(phone, status, source) VALUES ('+639171234567','opted_in','event');
    RAISE EXCEPTION 'FAIL: duplicate consent row accepted';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO consent(phone, status, source) VALUES ('+639170000009','maybe','x');
    RAISE EXCEPTION 'FAIL: bad consent status accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 7. alerts severity
DO $$ BEGIN
  BEGIN INSERT INTO alerts(severity, message) VALUES ('panic','x');
    RAISE EXCEPTION 'FAIL: bad severity accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

-- 8. id_map: one person may have many external ids; an external id maps to one person only
INSERT INTO id_map(twenty_person_id, kind, external_id) VALUES ('p1','meta_lead','L1'), ('p1','meta_lead','L2'), ('p1','meta_psid','S1');
DO $$ BEGIN
  BEGIN INSERT INTO id_map(twenty_person_id, kind, external_id) VALUES ('p2','meta_lead','L1');
    RAISE EXCEPTION 'FAIL: external id mapped to two persons';
  EXCEPTION WHEN unique_violation THEN NULL; END;
  BEGIN INSERT INTO id_map(twenty_person_id, kind, external_id) VALUES ('p2','bogus','X');
    RAISE EXCEPTION 'FAIL: bad id_map kind accepted';
  EXCEPTION WHEN check_violation THEN NULL; END;
END $$;

ROLLBACK;

-- 9. privileges: the account n8n will use must be able to read and write every table (committed nothing: rolled back)
BEGIN;
SET LOCAL ROLE orbit_ledger;
INSERT INTO processed_events(source, event_id) VALUES ('priv-test','1');
INSERT INTO dead_letter(automation, payload, error) VALUES ('priv-test','{}','x');
INSERT INTO alerts(severity, message) VALUES ('normal','priv-test');
SELECT count(*) FROM outbound_messages;
ROLLBACK;

SELECT 'LEDGER TESTS PASSED' AS result;
