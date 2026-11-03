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

## Still open
- INR plan prices (pricing is designed in USD).
- Voice-call and WhatsApp Business providers (needed in Step 4).
- Where the manager's Capture button goes.
- Domain name.
