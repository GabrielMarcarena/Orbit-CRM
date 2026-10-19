# Orbit v1: Lean Core Design (Philippines, local service business)

## 1. Purpose
- **Who it's for:** a local service business in the Philippines, run by the owner plus 1–3 staff.
- **Where leads come from:** Facebook/Instagram, the website form, Google and referrals, phone calls, and events.
- **Two goals:**
  1. **Now:** no lead is forgotten, every lead gets a reply within minutes, and the whole pipeline is visible on one screen.
  2. **Later:** Orbit can become a product for clients.
- **What success looks like for v1:**
  - Every lead from every source appears exactly once in Twenty, with its source and an assigned owner.
  - Automatic texts go out on time, never twice, never in quiet hours, and never after the customer opts out.
  - Every failure is visible and can be recovered.

## 2. Scope
**In v1:** Twenty CRM, n8n automations, the `orbit_ledger` database, Semaphore SMS (outgoing only), Facebook/Instagram lead ads and Messenger/IG conversations as lead sources, Cal.com cloud booking, the alert router, and backups.

**Not in v1 (later phases, in order):**
1. Chatwoot shared inbox
2. Mautic email campaigns
3. Postiz social posting
4. The Orbit-branded dashboard
5. Product readiness for clients
6. An Android SMS/call gateway (missed-call text-back)
7. WhatsApp alerts (after Meta approval)

**Also not in v1:** quote generation, payments processing and Viber.

## 3. Components
| Component | Role | Hosting |
|---|---|---|
| Twenty (server + worker, Postgres 16, Redis) | CRM of record and the team's daily screen | VPS (Docker) |
| n8n (Community edition) | All automations | VPS, admin-only URL |
| orbit_ledger (separate database on the same Postgres server) | Dedupe, consent, outbound log, schedules, switches, failures | VPS |
| Semaphore | Outgoing SMS from a registered sender name | Cloud API, about ₱0.56 per text |
| Meta (Facebook Page / Instagram) | Lead ads, plus Messenger/IG conversation webhooks | Cloud |
| Cal.com cloud (free) | Booking page, plus booking webhooks | Cloud |
| Telegram bot, email service (Resend or Postmark free tier) | Alerts | Cloud |
| Caddy | TLS, plus hostnames `crm.` and `flows.` | VPS |

Each service runs from its official, pinned Docker image, never `:latest`. Apps never write to each other's databases; all writes go through their APIs.

The VPS is a 4–8 GB server in Singapore (about $10–25 a month). Development happens on the owner's laptop, which has 7 GB of RAM.

## 4. Data model
**Twenty (source of truth for the business)**
- **Person:** name, phone (E.164, +63…), email, lead source (Facebook ad, Instagram, Messenger, Website, Event, Google, Referral, Walk-in/Call), SMS consent (yes/no, with date), and owner.
- **Opportunity pipeline:** New → Contacted → Quote sent → Booked → Job done → Paid → Review requested, or Lost.
  - Opportunity fields: amount (the quote amount), lost reason (Price / Timing / No reply / Other), and booking time.
- Tasks and notes come built into Twenty.

**orbit_ledger (owned by Orbit)**
| Table | What it holds |
|---|---|
| `processed_events` | `(source, event_id)` unique; webhook dedupe |
| `id_map` | Many external IDs per Twenty person: rows of `(twenty_person_id, kind, external_id)`, kind = meta_psid / meta_lead / calcom_attendee; `(kind, external_id)` is unique |
| `consent` | Phone, status (opted_in / opted_out), source, timestamp |
| `outbound_messages` | Unique `idem_key`; also `automation`, `opportunity_id`, `step` columns, unique among active rows (scheduled / sent / delivered), so a rescheduled message must update or replace the old row, never add a second one; phone, body, due_at, status (scheduled / skipped / sent / delivered / failed / cancelled), Semaphore message ID, attempts, last_error |
| `automation_switches` | Automation name, mode (off / test / live), changed_by (required for any mode other than off), changed_at (set automatically on every mode change), checklist_passed_at |
| `test_numbers` | The allow-list used in test mode |
| `dead_letter` | Failed items with their payload and error, and a `resolved_at` |
| `alerts` | Severity, message, the channels it was sent to, and a timestamp |

## 5. Lead flow
**Intake.** The same n8n workflow handles every source:
1. Verify the signature or token, then dedupe through `processed_events`.
2. Normalize the details: lowercase the email; convert phones from 09xx to +639xx.
3. Search Twenty by phone, then by email. Update the person if found; otherwise create them.
4. Create an opportunity at **New** with the lead source, unless this person already has an open opportunity.
5. Assign an owner, taking turns among active staff, and create a Twenty task: "New lead: call/message within 15 min".
6. If consent is given and the speed-to-lead automation isn't off, schedule the speed-to-lead SMS for now. It respects quiet hours and includes the booking link and the Messenger link.

| Source | How it enters |
|---|---|
| Website form, event QR-code form | Posts to an n8n webhook with a honeypot field, Cloudflare Turnstile and a rate limit. Includes a consent checkbox and a privacy notice |
| Facebook/Instagram lead ads | The n8n Facebook Lead Ads trigger. The lead form includes a consent question |
| Messenger/IG conversation | Meta webhook (signature verified). A new sender becomes a lead; later messages from the same sender are added as notes. Staff reply in Meta Business Suite in v1 |
| Google, referral, call or walk-in | Staff create the person in Twenty. Twenty's `person.created` webhook (HMAC verified) runs steps 4–6 |

**Follow-ups.** Each follow-up is checked again just before it sends.

| Automation | Trigger | Action | Stops when |
|---|---|---|---|
| Lead follow-up | Stage still New/Contacted after 1 day | SMS #2 | Booked, replied (Messenger), Lost, opted out |
| Lead call task | Still New/Contacted after 3 days | Twenty task "Call this lead" | (same) |
| Quote follow-up | Quote sent with no booking after 2 days | SMS "Any questions about your quote? Book: …" | Booked, Lost, opted out |
| Quote call task | Still Quote sent after 5 days | Twenty task "Call about quote" | (same) |
| Booking reminders | Cal.com booking created | SMS at 24 hours and 2 hours before | Cancelled, rescheduled (replaced), opted out |
| Booking cancelled | Cal.com cancelled | Cancel reminders, set stage to Quote sent, create a task | — |
| Review request | Stage set to Paid | SMS with the Google review link 2 hours later, then set stage to Review requested | Lost, opted out |

"Contacted" is set by staff, or automatically when a Messenger reply arrives.

**Leads without a phone number** (common from Messenger/IG) get no SMS. Staff reply in Meta Business Suite, and the follow-up call tasks still apply. If the lead later shares a number and consents, staff add it in Twenty and the SMS automations take over.

## 6. Messaging rules
- **Every SMS** comes from the registered Semaphore sender name. It is transactional and service-related only, with no promotions, and it ends with "Reply STOP to opt out" plus the Messenger link or business number for replies.
- **Quiet hours** are 20:00–08:00 Asia/Manila. Texts due in that window move to 08:00.
- **Before each send,** Orbit checks:
  - the automation switch (off means skip; test means send only to `test_numbers`)
  - that consent is still opted in
  - that the opportunity's stage still qualifies
  - that no message with the same `idem_key` has already been sent
- **Opt-out:** a STOP sent on Messenger, or entered by staff, marks the person `opted_out`. Every scheduled message for them is cancelled.
- **Delivery:** after sending, Orbit polls Semaphore for the message status. A message counts as delivered only when Semaphore confirms it. A failed message creates a Twenty task for the owner.

## 7. Failures and alerts
- **Retries:** a transient error (a timeout, a 5xx, a 429) is retried up to 3 times, waiting 1, 5 and then 15 minutes. After that, the item goes to `dead_letter` and a Twenty task is created. Fixed items can be re-run safely because of the `idem_key`.
- **Alert router:**
  - **Urgent** (a service is down, the Meta token is expired, the Semaphore balance is low, 3 or more failures in an hour): Semaphore SMS to the owner, a Telegram message and an email.
  - **Normal:** a Twenty task, plus a daily 08:00 email summary.
  - **WhatsApp** is reserved for later.
- **Daily health check:** Twenty `/healthz`, n8n's health endpoint, the database connection, Meta token validity, the Semaphore balance, the `dead_letter` count, and "no leads in 3 days".

## 8. Security and privacy
- **Signatures and tokens:**
  - Meta: `X-Hub-Signature-256`
  - Cal.com: `X-Cal-Signature-256`
  - Twenty: HMAC on timestamp plus body
  - Forms: Turnstile plus a secret
  - Any request older than 5 minutes is rejected, and requests are compared in constant time.
- **Secrets:** stored only in n8n's encrypted credential store, with `N8N_BLOCK_ENV_ACCESS_IN_NODE=true`. `.env` files stay out of git, and gitleaks runs as a pre-commit hook.
- **Network:** only Caddy publishes ports. n8n's editor sits behind Caddy basic-auth, and the VPS firewall allows only ports 22, 80 and 443.
- **Backups:** nightly `pg_dump` of the Twenty database and `orbit_ledger`, plus an n8n export, all copied off the server. A restore is tested monthly. The encryption keys (`N8N_ENCRYPTION_KEY`, Twenty's `ENCRYPTION_KEY`) are backed up separately.
- **Privacy:** under the Data Privacy Act of 2012, forms carry a consent checkbox and privacy notice, data is collected only for service purposes, deletion is available on request, and PII is pruned from n8n logs. ⚠ Get a quick legal or NPC check before going live.

## 9. Go-live and testing
- **Per-feature switches:** every automation starts at *off*, moves to *test*, then to *live*. *Live* is allowed only after `checklist_passed_at` is set. Each change records who made it and when.
- **Automated tests:** scripts post fake webhooks (valid, bad signature, stale, duplicate) and use a **fake Semaphore endpoint**, so no credits are spent and no real people are texted. Each automation has a scripted scenario. For example: book, cancel one minute before the reminder, and assert that no SMS was sent.
- **Manual checklist:** each automation has a plain-language checklist the owner can run on their own phone in test mode.
- **Rule:** a test only counts as passed when it actually ran, and its output is attached to the milestone report.

## 10. Milestones
1. **Foundation:** Docker on the laptop; Twenty, n8n, Postgres, Redis, Caddy, `orbit_ledger` migrations and backup/restore scripts. Start the Semaphore sender-name registration and set up the Meta app and Cal.com account.
2. **Intake, no texts:** website and event forms, manual entry in Twenty, and Facebook/Instagram lead ads. Dedupe and owner assignment.
3. **Messenger/IG conversations become leads and notes.**
4. **Texting in test mode:** speed-to-lead, lead follow-up and quote follow-up, plus quiet hours, consent, STOP and delivery polling.
5. **Booking:** Cal.com webhooks, reminders, reschedule and cancel.
6. **Review request, alert router and daily health check.**
7. **Move to the VPS, restore test, then go live one feature at a time.**

## 11. Licensing (product goal)
- **Internal use:** all components are fine.
- **Before offering Orbit to clients:** n8n's Sustainable Use License does not allow it, so either get an n8n commercial/Embed license or move the automations elsewhere. Each automation therefore also has an engine-neutral spec in `n8n/specs/`.
- **Twenty** runs as an unmodified AGPL image. Orbit's own code that talks to it through the API may stay proprietary under Twenty's Application Exception. Notices and attribution are kept.
- ⚠ Do a trademark check on the name "Orbit" before any commercial use.

## 12. Open items for the owner
- The business name for the Semaphore sender (up to 11 characters, and it must not contain TEST, SMS, SMART or SUN).
- The Google review link, the Messenger link (m.me/…) and business hours, if they differ from 08:00–20:00.
- The staff list (names and phone numbers) for owner assignment and test numbers.
- The domain name.
