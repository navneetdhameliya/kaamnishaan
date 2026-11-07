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

## Still open
- Credit pack INR prices (placeholders ₹799 / 500 and ₹2,799 / 2,000).
- Figma: "Choose company" screen + company switcher; ₹ prices on pricing and billing screens (design first, before those screens are coded).
- Voice-call and WhatsApp Business providers (needed in Step 4).
- Where the manager's Capture button goes.
- Domain name (purchase planned 16 Nov 2026).
- Admin staff accounts with authenticator code (separate `staff_users` table) — next foundation step.
- Error messages translated by `Accept-Language` (codes are final; English text for now).
- Live technician location in v1, testimonial source, where public reviews show.
