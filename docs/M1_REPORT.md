# Milestone 1 (Foundation) report, 2026-10-19

Status: **infrastructure for M1 is built and verified. M1 is not fully closed**: spec section 10 also lists starting the Semaphore sender-name registration and setting up the Meta app and Cal.com account. Those need you and are not started.

Command output for each check is in `docs/evidence/` (captured by re-running the checks after the review fixes).

## Verified
| Check | Evidence |
|---|---|
| Five upstream repos cloned at pins into ~/orbit-audit/upstream (reference only, not committed) | docs/versions.md |
| Image tags + digests resolved with `docker buildx imagetools inspect` | docs/versions.md (Mailpit is pinned by tag only, not digest) |
| Stack up: postgres, redis, n8n, mailpit, caddy, twenty-server healthy; twenty-worker running; routes crm./flows./mail.localhost return 200 | docs/evidence/m1-health.txt |
| Health script fails (exit 1) with n8n stopped, and when a container is missing; recovers | docs/evidence/m1-health.txt |
| Ledger tests: RED before the schema existed, GREEN after; migrations are tracked and not re-applied | docs/evidence/m1-ledger-tests.txt |
| Backup, then restore into a throwaway container: 238 tables, identical row counts | docs/evidence/m1-restore.txt |
| `restart` and `down`/`up` keep data (marker row, row counts) | run during the session; not re-captured |
| Secret scan: clean tree exits 0, planted fake token exits 1 | docs/evidence/m1-secret-scan.txt |

## Review (fresh reviewer, whole branch) and what was done
Fixed, each with a test or live check run before and after:
1. The app account `orbit_ledger` could not write to any ledger table. Fixed with grants (migration 0002); the test now writes as that role.
2. The Caddy healthcheck passed even when nothing listened. Now `nc -z 127.0.0.1 80` (checked against ports 80 and 81).
3. `health.sh` ignored containers that did not exist. Now compares against `docker compose config --services`.
4. Report claims had no attached output: evidence files added.
5. "Done" overstated: wording corrected above.
6. Automation switch changes did not record who/when. A trigger now requires `changed_by` and stamps `changed_at`.
7. Two ledger idempotency holes: a rescheduled text could be inserted twice, and a person with two lead ads could not be mapped. Fixed with logical-message uniqueness among active rows and a many-to-one `id_map`. The spec table was updated.
8. Backups stored every secret in plain text. `deploy/.env` is now included only when `ORBIT_BACKUP_PASSPHRASE` is set, and then encrypted.

## Not verified / limits
- Twenty has no business data yet (no workspace created), so the restore test covered its schema and migrations, not real records.
- n8n has no workflows or credentials yet; its editor has no extra basic-auth (localhost only).
- Backups are local only. The dumps contain customer data in clear text: protect them before copying off-machine. A full disaster restore (including database roles) is untested.
- Plain HTTP on localhost only. TLS, a real domain, a firewall and the VPS are Milestone 7.
- Chatwoot, Mautic, Postiz: repos cloned and tags verified, **not run** (about 1.5 GB RAM left with this stack up).

## Deferred minors (not fixed; your call)
Postgres user hardcoded as `postgres` in scripts; no `pg_dumpall` roles; restore edge cases; secret scan runs on the working tree rather than staged files and gitleaks is pinned by tag; password interpolated into init SQL (safe for generated hex); `deploy/.env` briefly world-readable before `chmod`; unused `ORBIT_SEND_MODE`; Mailpit not pinned by digest; no CHECKs on `attempts` or status transitions, `updated_at` never updated; test coverage still lacks a couple of positive cases.

## Rulings
- Executed straight from the approved plan file; no separate plan document was written.
- Twenty's key is hex because base64 broke the sed-based generator.
- `.gitleaks.toml` allowlists only the `generic-api-key` rule on deploy/.env.example (false positive on empty placeholders).
- Caddy `auto_https off` and ports bound to 127.0.0.1:8080, for local development only.
- Ledger changes shipped as a new migration (0002) instead of editing 0001, since 0001 had already been applied.

## Run it
`scripts/init-env.sh` (once), then `docker compose -f deploy/compose.yml --env-file deploy/.env --profile core --profile crm up -d`, then `scripts/health.sh`.
Back up `deploy/.env` somewhere safe: without N8N_ENCRYPTION_KEY and TWENTY_ENCRYPTION_KEY, stored credentials cannot be decrypted.
