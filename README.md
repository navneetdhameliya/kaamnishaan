# KaamNishaan

Proof-of-work SaaS for HVAC and field-service teams: photos, checklists and voice notes become an AI-drafted job report the customer can trust.

Monorepo layout (set up in Step 0):

| Folder | What | Stack |
|---|---|---|
| `backend/` | API, AI orchestration, jobs, reports, reviews, billing | Python · FastAPI · PostgreSQL |
| `mobile/` | Technician + manager app (phone, iPad, Mac) | Flutter · GetX |
| `web/` | Marketing website + customer report page | React · TypeScript · Tailwind |
| `admin/` | Super-admin panel | React · TypeScript · Tailwind |
| `shared/` | Design tokens, translations, API contract | JSON · OpenAPI |
| `docs/` | Architecture, database, decisions | Markdown |

Design source of truth: Figma file "KaamnNishaan" (approved 4 Nov 2026).
