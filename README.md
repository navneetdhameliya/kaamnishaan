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

## Getting started

```bash
node shared/design-tokens/build.mjs   # Figma tokens → Flutter / CSS / Tailwind
node shared/i18n/build.mjs            # translations → Flutter (GetX)
cd backend && python3 -m venv .venv && . .venv/bin/activate && pip install -e ".[dev]" && pytest
cd web && npm ci && npm run dev       # http://localhost:5173
cd admin && npm ci && npm run dev     # http://localhost:5174
cd mobile && flutter create . --org com.kaamnishaan --project-name kaamnishaan --platforms=android,ios,macos && flutter run
```

Docs: [database design](docs/database.md) · [API contract](shared/api/openapi.yaml) · [decisions](docs/decisions.md)
