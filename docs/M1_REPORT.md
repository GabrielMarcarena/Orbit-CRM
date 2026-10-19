# Milestone 1 (Foundation) report, 2026-10-19

## Done and verified (commands were run in this session)
| Check | Result |
|---|---|
| Five upstream repos cloned at pins to ~/orbit-audit/upstream (reference only, not committed) | Done; hashes in docs/versions.md |
| Image tags + digests verified with `docker buildx imagetools inspect` (all 9 images) | Done |
| `docker compose --profile core --profile crm config -q` | OK |
| Stack up: postgres, redis, n8n, mailpit, caddy, twenty-server healthy; twenty-worker running | Yes (scripts/health.sh exit 0) |
| Routes via Caddy: crm./flows./mail.localhost on port 8080 | HTTP 200 each |
| Ledger tests (scripts/ledger-test.sh): RED before migration, GREEN after, re-run idempotent | PASSED |
| Backup then restore into a throwaway container: 238 tables, row counts identical to live (incl. marker row) | PASSED |
| Persistence: `restart` and `down`/`up` (volumes kept): marker row present, counts unchanged | PASSED |
| Secret scan (gitleaks v8.30.1): clean tree exit 0; planted fake token detected exit 1 | PASSED |
| Health script: exit 0 healthy; exit 1 with n8n stopped; recovers | PASSED |

## Not verified / limits
- Twenty has no business data yet (no workspace created), so the restore test covered its schema and migrations, not real records.
- n8n has no workflows and no credentials yet.
- Backups are local only (backups/, git-ignored). Copy them off-machine; the restore test does not cover the twenty-files volume tarball.
- Plain HTTP on localhost only. TLS, real domain, firewall and VPS hosting are Milestone 7.
- Chatwoot, Mautic, Postiz: repos cloned and tags verified, **not run** (laptop has ~1.5 GB RAM free with this stack up).

## Rulings
- Executed straight from the approved plan file; no separate plan document was written.
- Twenty's key is hex (`openssl rand -hex 32`) because base64 broke the sed-based generator.
- `.gitleaks.toml` allowlists only the `generic-api-key` rule on deploy/.env.example (empty placeholders caused a false positive).
- Used Caddy `auto_https off` and ports bound to 127.0.0.1:8080, for local development only.

## Run it
`scripts/init-env.sh` (once), then `docker compose -f deploy/compose.yml --env-file deploy/.env --profile core --profile crm up -d`, then `scripts/health.sh`.
Back up `deploy/.env` somewhere safe: without N8N_ENCRYPTION_KEY and TWENTY_ENCRYPTION_KEY, stored credentials cannot be decrypted.
