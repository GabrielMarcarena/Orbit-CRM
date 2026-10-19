> **Milestone 1 (Foundation) DONE on branch m1-foundation, 2026-10-19.** See docs/M1_REPORT.md. Next: Milestone 2 (intake, no texts). Needs from owner: Semaphore sender name, review link, Messenger link, staff list, domain.

> **UPDATE 2026-10-19: v1 scope replaced.** After brainstorming, v1 is the "lean core" in `docs/superpowers/specs/2026-10-19-orbit-v1-design.md`: Twenty + n8n + orbit_ledger + **Semaphore** SMS (Twilio does not work in the Philippines) + Messenger/IG as the chat channel + Cal.com cloud. Chatwoot, Mautic and Postiz are later phases. Read the spec first; the audit below is background and history.

# Orbit — Pending Work (project paused 2026-10-19)

## Status
- **Paused after Phase 0, the audit.** Nothing was built, deployed or configured, and no email or SMS was sent.
- The upstream clones (`~/orbit-audit`) were deleted, and Docker Engine was uninstalled (the owner ran the commands).
- The legacy app `../orbit-crm/` is untouched apart from a git safety snapshot: commit `f2daac5`, "Snapshot of legacy Orbit CRM (phase 17)".
- To resume, paste `CLAUDE_PROMPT.md` into a new Claude Code session.

## Goal
Orbit is a GoHighLevel-style platform: CRM, email, SMS, social scheduling, shared inbox, workflows and an Orbit dashboard. It is assembled from proven open-source apps, run as separate services and connected through their APIs and webhooks, not merged into one codebase. It is for the owner's own business first, and possibly for clients later.

## Decisions already made
1. **Twenty is the CRM of record, and n8n is the workflow engine.**
2. The legacy `orbit-crm` (Supabase, AI-built, never deployed) is **frozen as a reference**. Its ideas (idempotency keys, consent/quiet hours, webhook allow-list, "never claim success") become specs and tests.
3. **Use:** internal business use only for now.
4. **Hosting:** undecided. The WSL laptop (about 7 GB RAM) is enough for development of 1–2 services at a time. Use a 16 GB VPS for the full stack.
5. **Integration rules:** run the official images unmodified, never write directly to another app's database, and keep Orbit's own code separate from the upstreams.

## Upstream audit (verified via GitHub API + shallow clones on 2026-10-19)
| Repo | Ref / commit audited | License | Role |
|---|---|---|---|
| twentyhq/twenty | main `dd7099a02f83`; latest release `twenty/v2.48.0` | AGPLv3 + Application Exception; `@license Enterprise` files (billing, SSO, usage, record-share, domains, validation rules); MIT SDK/UI | CRM |
| n8n-io/n8n | master `b8a02f70dcdf`; target `n8n@2.43.7` | Sustainable Use License; `.ee` = Enterprise (SSO, LDAP, external secrets, log streaming, source control, environments) | Workflows |
| mautic/mautic | `7.2.1` `8cbb7ef874d5` | GPLv3 | Email; core SmsBundle has Twilio |
| chatwoot/chatwoot | `v4.18.0` `9f920b549c14` | MIT core; `enterprise/` is paid | Inbox |
| gitroomhq/postiz-app | `v2.25.1` `91c91f633a01` | AGPLv3 | Social (later) |
| SahibYar/open-agency-os ("Aperture") | main `6eefebc477cc` | MIT | Reference only |

**Key findings**
- **Twenty:** official compose = `server` + `worker` (`yarn worker:prod`) + Postgres 16 + Redis (`noeviction`), with `/healthz`. It needs `ENCRYPTION_KEY` and `SERVER_URL`. Webhooks are signed with `X-Twenty-Webhook-Signature` = HMAC-SHA256(`{timestamp}:{body}`) plus `X-Twenty-Webhook-Timestamp`.
- **Chatwoot:** `rails` + `sidekiq` + `pgvector/pgvector:pg16` + Redis with a password. Webhooks are signed with `X-Chatwoot-Signature: sha256=HMAC(ts.body)` plus `X-Chatwoot-Timestamp`. Verify that a CE image exists, or keep enterprise features off.
- **Mautic:** official image `mautic/mautic:7.x-apache` (apache is recommended over fpm). It needs MariaDB/MySQL. **Cron jobs are mandatory** (segments, campaigns, broadcasts). Webhooks carry `Webhook-Signature`.
- **Postiz:** public API at `/public/v1` (posts CRUD, find-slot, integrations, notifications). **It needs Temporal + Temporal Postgres + Elasticsearch, about 4 GB.** Its outgoing webhooks are **unsigned, best-effort and sent only on success**, so failures must be found by polling the API. Its sample compose ships default passwords and exposes port 7233.
- **Aperture:** a good layout reference (compose profiles, Caddy hostnames, playbooks). But it uses `:latest`, omits Twenty's worker, sets `N8N_BLOCK_ENV_ACCESS_IN_NODE=false` (unsafe), and its workflows do not dedupe or honor quiet hours. Do not fork it.

## License gates
- **Internal use:** every component is OK as-is.
- **Before any client gets access:** n8n's license forbids offering it to others commercially, so either buy an n8n commercial/Embed license or move client-facing automation elsewhere. Keep `n8n/specs/*.md` engine-neutral for that reason.
- **AGPL (Twenty, Postiz):** modifying them means offering the source to network users. The Application Exception lets Orbit's own API-based code stay proprietary.
- **GPL (Mautic):** obligations apply on distribution.
- ⚠ **Legal review needed:** AGPL/GPL obligations if Orbit becomes SaaS, and a trademark search for the name "Orbit" (it is common, e.g. orbit.love). Keep "Powered by …" notices, and never use upstream logos.

## Architecture
Caddy routes one hostname per app: `orbit.` (dashboard), `crm.` (Twenty), `inbox.` (Chatwoot), `mail.` (Mautic), `social.` (Postiz), and `flows.` (n8n, admins only). The flow between them is:
1. Upstream apps send signed webhooks to n8n.
2. n8n verifies the HMAC, checks the ledger, acts through REST APIs, and records the result.
3. n8n reads and writes **orbit_ledger**, a Postgres DB owned by Orbit, with tables `processed_events`, `id_map`, `consent`, `outbound_messages` (provider ID, status, `cancel_token`), `dead_letter` and `sync_conflicts`.
4. SMS goes through Twilio or Telnyx, and email through Mautic with an SMTP provider. Both stay in test mode until approved.

| Record | Source of truth |
|---|---|
| Person, company, opportunity, task, note, owner | Twenty |
| Email engagement, segments, unsubscribe | Mautic |
| SMS consent, STOP, quiet hours | orbit_ledger |
| Conversations | Chatwoot |
| Social posts and status | Postiz |
| Appointments | **Undecided** (Cal.com or Twenty calendar sync) |

Duplicates are matched on lowercased email and E.164 phone. Every write searches the target app first, then records the link in `id_map`.

## Security rules
- Secrets go only in untracked `.env` files and n8n's encrypted credential store, with a gitleaks pre-commit hook.
- Keep `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`.
- Back up `N8N_ENCRYPTION_KEY`, Twenty's `ENCRYPTION_KEY` and Chatwoot's `SECRET_KEY_BASE`.
- Only Caddy publishes ports. Change all sample passwords.
- Verify webhook HMACs with a constant-time compare, reject anything older than 5 minutes, then dedupe. Never trust Postiz webhooks.
- `ORBIT_SEND_MODE=test|live`. Test mode sends only to allow-listed own numbers and emails, or to Twilio test credentials and the Mailpit sink.
- Run nightly dumps with a **tested** restore. Redact PII from n8n logs and prune old executions.

## RAM needs
| Service | Approx. RAM |
|---|---|
| Twenty | 2 GB |
| Chatwoot | 2 GB |
| Mautic + MariaDB | 1.5 GB |
| n8n | 1 GB |
| Postgres/Redis | 1.5 GB |
| Postiz + Temporal + Elasticsearch | 4 GB |

The MVP without Postiz needs about 8–10 GB, and the full stack about 16 GB.

## Phased plan (resume here)
- [ ] **0.5** Re-clone the pins into `~/orbit-audit/upstream/` (outside the repo, never committed). Verify the Docker image tags exist. `git init` this folder.
- [ ] **1 Infrastructure** Install Docker (on WSL or a VPS). Compose profiles: `core` (Caddy, Postgres, Redis, n8n, Mailpit) and `crm` (Twenty server + worker). Healthchecks, named volumes, pinned tags. Backup/restore scripts, plus restart and persistence tests. No real sends.
- [ ] **2 CRM** Twenty API key and webhook to n8n. HMAC verification, ledger migrations, intake workflow (normalize, search, upsert, `id_map`). Test duplicates, bad signatures, replays and outages.
- [ ] **3 Email + SMS** Mautic with its cron jobs, Twilio in test mode, consent/STOP, quiet hours, reminders with cancel/reschedule, delivery callbacks. Choose the appointments tool.
- [ ] **4 Social** Postiz with Temporal (needs a 16 GB host). Schedule through the API, poll status, handle token expiry.
- [ ] **5 Conversations** Chatwoot CE. Match contacts to Twenty and add a note/link in Twenty.
- [ ] **6 Dashboard** Orbit portal with navigation, health and failed-operations views, and an About & Licenses page.
- [ ] **7 Production readiness** End-to-end, security, restore and regression tests. Client/licensing gate.

## Proposed directory structure
```
Orbit .2/  README.md  PENDING.md  LICENSES/THIRD_PARTY.md  docs/{adr,runbooks,versions.md}
  deploy/{compose.yml, env/*.env.example, caddy/Caddyfile, postgres-init/, mautic-cron/}
  ledger/migrations/*.sql   n8n/{workflows/*.json, specs/*.md}   dashboard/
  scripts/{backup.sh, restore.sh, health.sh, secret-scan.sh}   tests/{integration,e2e}/
```

## MVP acceptance criteria (end of Phase 3)
1. `docker compose --profile core --profile crm --profile marketing up -d` brings everything up healthy. It stays healthy after a restart and a reboot, with data intact.
2. A form submission creates exactly one Twenty person. The same email or phone in a different format updates that person and does not duplicate it.
3. A bad or stale webhook signature is rejected and logged. Replaying a valid webhook does not trigger a second action.
4. SMS reminders: test mode only, allow-listed numbers only, quiet hours and STOP respected, no send after cancellation. Provider ID and final status are recorded.
5. Transient failures retry with backoff, then land in `dead_letter`, are visible on the dashboard, and can be re-run without duplicates.
6. Last night's backup restores into a scratch stack with the same records.
7. The secret scan is clean, and no tokens appear in the frontend or logs.

## Open questions for the owner
- Hosting: WSL or a VPS (which provider, and what size)?
- SMS provider (Twilio or Telnyx) and email provider (Postmark, SES or another).
- Appointments: Cal.com or Twenty's calendar sync.
- Which social networks to connect first.
