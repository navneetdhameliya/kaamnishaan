# Decisions (Step 0)

| # | Decision | Why | Date |
|---|---|---|---|
| D-01 | One monorepo: `backend/`, `mobile/`, `web/`, `admin/`, `shared/`, `docs/` | API contract, tokens and translations change together; can split later | 2026-11-04 |
| D-02 | India first: `+91`, `Asia/Kolkata`, en/hi/gu first | First pilots are in India | 2026-11-04 |
| D-03 | Render (Singapore) for API + PostgreSQL, Vercel for web/admin, Cloudflare R2 for files | Closest Render region to India; existing team experience | 2026-11-04 |
| D-04 | Temporary `*.onrender.com` / `*.vercel.app` addresses until a domain is bought | No domain yet | 2026-11-04 |
| D-05 | Figma is the source of truth for tokens; `shared/design-tokens/build.mjs` generates Flutter, CSS and Tailwind | No hand-copied colours; CI fails if generated files are stale | 2026-11-04 |
| D-06 | Tailwind spacing scale replaced by Figma pixels (`p-16` = 16px); widths use `w-[256px]` | Same numbers in Figma and code | 2026-11-04 |
| D-07 | Contract first: `shared/api/openapi.yaml` changes before code; validated in CI | Mobile and web can build against a mock early | 2026-11-04 |
| D-08 | Phone OTP for technicians (MSG91 + DLT), email+password for managers/owners, 2-step for admins | PRD low-literacy rule; India SMS law | 2026-11-04 |
| D-09 | Offline-safe writes via device `Idempotency-Key` / `client_id` | Technicians often have no signal on site | 2026-11-04 |
| D-10 | Payments via Razorpay (UPI, cards); credits as a ledger | India first; credits model chosen 2026-11-03 | 2026-11-04 |
| D-11 | A user can belong to several companies; active company is chosen at login and switchable | Technicians who work for more than one company | 2026-11-04 |
| D-12 | INR prices ₹499 / ₹1,299 / ₹2,499 per month; USD $9 / $25 / $49 kept for other countries | India-first pricing | 2026-11-04 |
| D-13 | Evidence retained 7 years by default | Warranty and disputes | 2026-11-04 |
| D-14 | Backend follows "KaamNishaan — API Analysis (Final version)": `/api/v1` paths and names, error codes, OTP 10 min / 3 tries / 5 per hour, email login lock after 5 fails for 15 min, 30-day refresh extended on use | Approved contract | 2026-11-06 |
| D-15 | `{data, meta}` wrapper on lists only; single objects returned as is | Simpler app code; tab counts still in `meta.counts` | 2026-11-06 (default taken while Navneet was away; easy to change) |
| D-16 | API contract generated from the code (`shared/api/openapi.generated.json`), checked in CI | Code and contract can't drift | 2026-11-06 (default taken while Navneet was away) |
| D-17 | Job numbers per company start at J-1001; each technician has a daily job capacity (default 6) shown on Assign technician; a full day is a hint, not a block | M15, M17 | 2026-11-06 |
| D-18 | A technician's quick job can name a new customer (name, phone, address) on the spot; technicians read only customers of their own jobs | M16 quick job, Roles grid | 2026-11-06 |
| D-19 | Sync feed: cursor is the newest `updated_at` sent, next call overlaps 2 s; the app keeps the highest `version` per job. Jobs moved to someone else are listed in `removed_job_ids` | Offline-first technicians | 2026-11-06 |
| D-20 | Background work runs on ARQ + Render Redis (worker service in `render.yaml`); without Redis (your computer) tasks run inside the API | Light, async, one worker for thumbnails, SMS, AI, PDFs | 2026-11-07 (default taken; easy to change) |
| D-21 | Photo upload limit 12 MB (phone compresses to 2,560 px); originals are never changed; a 480 px thumbnail without EXIF/GPS is made for lists; each photo gets a SHA-256 fingerprint | Conflict #4; evidence integrity | 2026-11-07 |
| D-22 | Evidence lock is enforced twice: the API answers `409 evidence_locked`, and a database trigger refuses any change or delete of a locked photo (only processing results may still be written) | Proof must be trustworthy | 2026-11-07 |
| D-23 | Files: `KN_STORAGE_PROVIDER=local` (a folder, for your computer and tests) or `r2` (required on staging and production). Every file link is signed and expires in 15 minutes | No public file URLs | 2026-11-07 |
| D-24 | Checklist texts are stored per language in one JSON field with a status per language (ready, needs review, missing); the app shows the job's language and falls back to the source language | Simpler than a separate translations table; same behaviour | 2026-11-16 |
| D-25 | Attaching a checklist to a job copies its questions (snapshot), so editing a template never changes a running job; global templates are read-only for companies, who copy them to change them | M26, A23 | 2026-11-16 |
| D-26 | A job with checklists needs them finished (every required question that is shown, with its photo or signature) before "Make report" unlocks | M19 unlock rule | 2026-11-16 (default; easy to change) |
| D-27 | Typed notes (microphone off) are stored as voice notes with kind "typed", so M28 shows one list and the report reads one source | M27, M28 | 2026-11-16 |
| D-28 | Without an OpenAI key, voice notes stay "uploaded" with `waiting_for: transcription_service` and checklist translations stay "missing"; adding the key switches both on with no code change | Build before the key exists | 2026-11-16 |
| D-29 | Flutter is pinned to 3.47.9 in CI. Flutter 3.50 deprecates `package:flutter/material.dart` in favour of the `material_ui` package; we move when the mobile app build starts, not by accident | Reproducible builds | 2026-11-16 |
| D-30 | Report drafts run in the background with 3 visible steps; the app polls `GET /tasks/{id}`. Without an OpenAI key a plain draft is written from the checklist answers and notes, so the flow works before the key exists | M31, build before the key | 2026-11-16 |
| D-31 | The AI must link every sentence to a photo, answer or note id; made-up ids are dropped and sentences without evidence are flagged "unsupported claim" for the manager. Failed checks are always flagged by the server, not left to the AI | Trust in reports | 2026-11-16 |
| D-32 | The report prompt is stored in `prompt_versions` (one live version per task) and each report records the prompt version, tokens and cost (`ai_usage`) | Admin prompt management, AI cost tracking | 2026-11-16 |
| D-33 | Every draft, edit and regenerated part saves a full copy in `report_versions`; only owners and managers see the history | A15 | 2026-11-16 (default; easy to change) |
| D-34 | "Ask for changes" needs at least one reason; "other" needs a note. Old photos stay locked, but the technician can add new proof, remake the report and resend it; the report stays marked "changes requested" until resent | M33 | 2026-11-16 |
| D-35 | Approving a report completes the job. Sharing with the customer (PDF, link, WhatsApp) comes in Step 1f | Build order | 2026-11-16 |

## Still open
- Credit pack INR prices (placeholders ₹799 / 500 and ₹2,799 / 2,000).
- Figma: "Choose company" screen + company switcher; ₹ prices on pricing and billing screens (design first, before those screens are coded).
- Voice-call and WhatsApp Business providers (needed in Step 4).
- Where the manager's Capture button goes.
- Domain name (purchase planned 16 Nov 2026).
- Admin staff accounts with authenticator code (separate `staff_users` table) — next foundation step.
- Error messages translated by `Accept-Language` (codes are final; English text for now).
- Live technician location in v1, testimonial source, where public reviews show.
- Native-speaker review of the Hindi, Gujarati, Spanish and French texts of the 4 seeded HVAC checklists (marked needs_review).
