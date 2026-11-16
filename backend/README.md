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
6. Jobs: as the owner `POST /customers` (with `site` and `contact`) → `POST /jobs` with the customer and
   `assigned_to` → as the technician `GET /me/today` → `POST /jobs/{id}/start` → as the owner `GET /dashboard`.

### Try a photo (Step 1c)
With a started job (`POST /jobs/{id}/start` as the technician):
1. `POST /api/v1/uploads` with `{"kind": "photo", "content_type": "image/jpeg"}` → copy `url` and `upload_id`.
2. Send the file to that `url` from Terminal (Swagger can't send a raw file body):
   `curl -X PUT -H "Content-Type: image/jpeg" --data-binary @photo.jpg "<url>"`
3. `POST /api/v1/jobs/{id}/evidence` with `{"upload_id": "...", "stage": "before", "taken_at": "<now>"}`.
   The answer has signed `url` and `thumb_url` links you can open in the browser (they expire in 15 minutes).
4. `GET /api/v1/jobs/{id}/proof` shows the capture hub; add an "after" photo and `can_make_report` turns true.

Files are saved in `backend/var/uploads` on your computer. The live server uses Cloudflare R2.

### Try a checklist and a voice note (Step 1d)
1. As the owner, `GET /api/v1/checklist-templates?trade=hvac` lists the 4 ready-made HVAC checklists.
2. `POST /api/v1/jobs` with `"checklist_template_ids": ["<id>"]` (and `assigned_to`), then start the job as the technician.
3. `GET /api/v1/jobs/{id}/checklists` → `GET /api/v1/checklist-submissions/{checklist_id}?lang=hi` shows the questions in Hindi.
4. `PUT /api/v1/checklist-submissions/{checklist_id}/answers/{question_id}` with `{"value": "pass"}`.
   Questions with a photo rule answer `photo_required` until you add `"photo_id"` (a photo from Step 1c).
5. Voice: `POST /api/v1/uploads` with `{"kind": "audio", "content_type": "audio/mp4"}`, send the file with curl as for
   photos, then `POST /api/v1/jobs/{id}/voice-notes`. Without `KN_OPENAI_API_KEY` in `.env` it waits for transcription.
   `POST /api/v1/jobs/{id}/notes` with `{"text": "..."}` adds a typed note.

### Try a report: draft, review, approve (Step 1e)
1. As the technician, on a started job with a before and an after photo (and its checklists finished),
   `POST /api/v1/jobs/{id}/reports` → `{task_id, report_id}`.
2. `GET /api/v1/tasks/{task_id}` shows the 3 steps (collect evidence → write report → check against evidence).
   With `KN_OPENAI_API_KEY` the AI writes it; without a key a plain draft is written from the answers and notes.
3. `GET /api/v1/reports/{report_id}` shows the text, which photo or answer each sentence is based on, and flags.
   Change a part with `PATCH /api/v1/reports/{id}` (send `If-Match: <version>`), or rewrite one part with
   `POST /api/v1/reports/{id}/sections/advice/regenerate`.
4. `POST /api/v1/reports/{id}/submit` sends it for review; the job's photos, answers and voice notes lock.
5. As the owner, `GET /api/v1/reports?status=pending_review` is the review queue. Then
   `POST /api/v1/reports/{id}/approve` (job → completed), or `POST /api/v1/reports/{id}/request-changes` with
   `{"reasons": ["missing_photos"], "note": "Add the outdoor unit"}`; the technician adds proof, makes the report
   again and resends it. `GET /api/v1/reports/{id}/versions` shows every version.

### Try sending a report to the customer (Step 1f)
1. Approve a report (Step 1e). The PDF builds right away: `GET /api/v1/reports/{id}/pdf` gives its status
   and a 15-minute download link.
2. `GET /api/v1/reports/{id}/share` shows the customer's contact, which channels can be used and the message text.
3. `POST /api/v1/reports/{id}/send` with `{"channels": ["sms", "whatsapp", "email"]}`. Nothing is really sent yet:
   open `GET /api/v1/dev/outbox` to read the messages and copy the link (`.../r/<token>`).
4. Open the customer page as the customer would: `GET /api/v1/public/reports/<token>` (no login), the PDF at
   `GET /api/v1/public/reports/<token>/pdf`, and `POST /api/v1/public/reports/<token>/acknowledge` with
   `{"name": "R. Sharma"}`.
5. `DELETE /api/v1/share-links/{link_id}` turns the link off (the page then says so).

## Live test server
The free test server on Render: **https://kaamnishaan-api.onrender.com/docs**. How it was set up, and how to
read login codes there: [docs/deploy.md](../docs/deploy.md).

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
