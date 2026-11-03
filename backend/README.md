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

## Checks
```bash
ruff check . && ruff format --check . && pytest
```

## Conventions
- All settings via `KN_*` environment variables (`app/core/config.py`). Secrets live in Render, never in git.
- API is versioned under `/v1`. The contract lives in `shared/api/openapi.yaml` — change the contract first, then the code.
- Every table: UUID primary key, `created_at`, `updated_at`, and a `company_id` for tenant data.
