# Prompt to resume Orbit (paste everything below into a new Claude Code session opened in `~/orbit-crm-new-phase/Orbit .2`)

---

I'm building **Orbit**, my own GoHighLevel-style platform: CRM, email automation, SMS, social media scheduling, a shared customer inbox, workflow automation, and an Orbit-branded dashboard. I'm not an experienced developer, so explain decisions in plain language and recommend one option rather than listing many.

**Read `docs/superpowers/specs/2026-10-19-orbit-v1-design.md` first (the approved v1 design: Philippines, local service business, Semaphore SMS, Twenty + n8n), then `PENDING.md` for the audit background.** It holds the completed Phase 0 audit and the decisions I've already approved. Don't re-litigate those decisions unless you find a concrete problem:
- **v1 scope:** **Twenty** is the CRM of record and **n8n** the workflow engine. **Semaphore** sends outgoing SMS (Twilio does not work in the Philippines). Messenger/Instagram is the two-way chat channel, and Cal.com cloud handles booking. Chatwoot, Mautic and Postiz are **later phases**, not v1.
- The self-hosted pieces run as **separate, unmodified official Docker images**, connected only through their APIs and signed webhooks. A small Orbit-owned Postgres DB, `orbit_ledger`, holds idempotency keys, ID mapping, consent, outbound messages and dead-letter records.
- It's for **my own business only** for now. Clients may come later, and that requires the n8n license and legal review gate described in `PENDING.md`.
- `../orbit-crm/` is my older, AI-built Supabase CRM. It is **frozen as a reference: never modify it.** Its git snapshot is commit `f2daac5`. You may read it for ideas (idempotency, consent, quiet hours, webhook allow-list).

**Current state:** the design is approved and committed (`789c779`). Nothing is built yet. The upstream clones were deleted and Docker may be uninstalled, so check before assuming.

**Start with Milestone 1 of the spec (Foundation), via the writing-plans skill if no implementation plan exists yet. First:**
1. Check `git status` and what's on disk, and whether Docker is installed.
2. Ask me for the open items in section 12 of the spec (sender name, review link, staff list, domain).
3. Verify that the pinned Docker image tags for Twenty and n8n exist (no `:latest`).
4. Write the implementation plan for Milestone 1, and **wait for my approval** before installing or building anything.

**Rules you must follow:**
- Check `git status` before changes. Keep each phase focused, and never use destructive git commands or delete databases or files without my explicit approval.
- Pin exact versions and never use `:latest`. Upgrade one service at a time.
- Never write directly to another app's database.
- No real email or SMS to real recipients. Keep `ORBIT_SEND_MODE=test` until I approve going live.
- Never put secrets in git, the frontend or logs. Keep `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`.
- Verify webhook signatures (Twenty, Chatwoot, Mautic). Never trust Postiz webhooks: poll its API for status.
- Don't remove license, copyright or attribution notices, and don't copy enterprise-licensed code (Twenty `@license Enterprise` files, n8n `.ee`, Chatwoot `enterprise/`).
- Don't claim something works unless you ran it. A successful API call doesn't mean a message was delivered or a post was published.
- After each phase, report: what was done, files changed, commands run, tests that actually passed or failed, what is still unconfigured, risks and license notes, and what needs my approval next. Then stop and wait.
