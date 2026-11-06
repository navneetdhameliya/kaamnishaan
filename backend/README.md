# KaamNishaan backend

FastAPI + PostgreSQL (SQLAlchemy 2 async, Alembic). OpenAI is called from here only.

## Run locally
```bash
cd backend
python3 -m venv .venv && . .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env            # never commit .env
docker compose up -d            # local Postgres 16
alembic upgrade head
uvicorn app.main:app --reload   # http://localhost:8000/docs
```

## Try the API in your browser
1. Run it locally (steps above), then open http://localhost:8000/docs
2. **Log in by phone:** `POST /api/v1/auth/otp/send` with `{"phone": "9876543210"}`.
   SMS is not really sent on your computer: the code is printed in the terminal, and
   `GET /api/v1/dev/outbox` shows it too (local only, never on the live server).
3. `POST /api/v1/auth/otp/verify` with the `challenge_id` and `code` → copy `access_token`.
4. Click **Authorize** (top right), paste the token, and every other endpoint now works as that person.
5. Owner flow: `POST /auth/register` → `POST /companies` → `POST /auth/refresh` (token now carries the company)
   → `POST /invites` → log in with the invited phone → `GET /invites/mine` → `POST /invites/{id}/accept`.

## Checks
Tests use a real PostgreSQL database `kaamnishaan_test` (override with `KN_TEST_DATABASE_URL`);
it is migrated once per run and emptied between tests.
```bash
ruff check . && ruff format --check . && pytest
python scripts/export_openapi.py    # after any endpoint change; CI fails if it is stale
```

## Conventions
- All settings via `KN_*` environment variables (`app/core/config.py`). Secrets live in Render, never in git.
- The backend contract is **KaamNishaan — API Analysis (Final version)** (Google Doc, copy in the project).
- All routes live under `/api/v1`. The contract the apps build against is generated from the code:
  `shared/api/openapi.generated.json`. `shared/api/openapi.yaml` is the earlier hand-written draft for
  slices not built yet; each slice replaces its part of it.
- Lists answer `{"data": [...], "meta": {"counts": {...}, "next_cursor": ...}}`; single objects are returned as is.
- Errors answer `{"error": {"code", "message", "fields", "details"}}`; codes match the drawn error states.
- Tenant data is always filtered by the company in the access token, never by an id from the URL or body.
- Every table: UUID primary key, `created_at`, `updated_at`, and a `company_id` for tenant data.
