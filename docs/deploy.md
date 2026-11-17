# Put the API live (free test server on Render)

Result: the API at **https://kaamnishaan-api.onrender.com** (try it at `/docs`), used by the mobile app,
website and admin panel. You do two things: create the file storage (Cloudflare R2) and create the
server (Render). About 20 minutes. Never paste keys into chat or into the code — only into Render.

Free plan limits (fine for testing):
- The API sleeps after 15 minutes without use. The first call after that takes about 1 minute.
- The free database is **deleted 30 days after it is created** (14 more days to upgrade). Upgrade the API
  ($7/month) and database ($6/month) in the Render dashboard before real customers use it.

## 1. Cloudflare R2 — where photos, voice notes and PDFs are kept (free up to 10 GB)

1. Sign in at https://dash.cloudflare.com (create a free account if needed).
2. Left menu → **R2 Object Storage**. If asked, turn R2 on (Cloudflare may ask for a card; the free
   10 GB is not charged).
3. **Create bucket** → name: `kaamnishaan-staging` → location: *Automatic* (or Asia-Pacific) → Create.
4. Back on the R2 page → **Manage API tokens** (or "API" → "Manage R2 API Tokens") → **Create API token**:
   - Permissions: **Object Read & Write**
   - Specify bucket: **kaamnishaan-staging** only
   - Create. The next screen shows three values **once** — keep the tab open for step 2:
     - **Access Key ID**
     - **Secret Access Key**
     - **Endpoint** for S3 clients: `https://<your account id>.r2.cloudflarestorage.com`
       (use the address only, without `/kaamnishaan-staging` at the end)

## 2. Render — the server and the database

1. Sign in at https://dashboard.render.com with **GitHub** (allow access to the `kaamnishaan` repository).
2. **New +** → **Blueprint** → pick `navneetdhameliya/kaamnishaan`, branch **main**.
3. Render reads `render.yaml` and shows two free items: `kaamnishaan-db` (database) and
   `kaamnishaan-api` (web service), both in Singapore.
4. It asks for four values:
   | Name | Value |
   |---|---|
   | `KN_STORAGE_ENDPOINT` | the R2 endpoint from step 1.4 |
   | `KN_STORAGE_ACCESS_KEY` | the Access Key ID |
   | `KN_STORAGE_SECRET_KEY` | the Secret Access Key |
   | `KN_OPENAI_API_KEY` | your OpenAI key, or leave empty for now |
5. **Deploy Blueprint**. The first build takes about 5–10 minutes. When the API shows **Live**, open
   https://kaamnishaan-api.onrender.com/api/v1/health — it should say `"status":"ok"`.

If Render says the name `kaamnishaan-api` is taken, it adds letters to the address
(for example `kaamnishaan-api-x1y2.onrender.com`). Then open the service → **Environment** and set
`KN_API_URL` to that address, and tell me so the apps use it.

## 3. Logging in on the test server (no SMS yet)

Login codes, invites and emails are not really sent yet. On this test server you read them here:

1. Render → `kaamnishaan-api` → **Environment** → `KN_TEST_OUTBOX_KEY` → click the eye icon and copy it.
2. Open `https://kaamnishaan-api.onrender.com/api/v1/dev/outbox?key=<that key>`
   — the newest login codes and emails are at the top.

**Forgot password (no email service yet):** in the app tap "Forgot password?", then open the outbox above.
The newest email "Reset your password" has a link to `https://kaamnishaan-web.vercel.app/reset-password?…`
— open it, type the new password, and log in with it in the app.

Email is switched off until an email service is chosen (`KN_EMAIL_ENABLED` is not set): new owners don't
have to confirm their email, and reports and review requests go by SMS, WhatsApp or link.

**App store links (website "Get the app"):** once the apps are published, add `KN_ANDROID_APP_URL`
(the Google Play page) and `KN_IOS_APP_URL` (the App Store page) on Render. Until then the website says
"The app is coming soon to Google Play and the App Store." Each button appears on its own as soon as its link is set.

**Contact page (website /contact):** each card shows once its value is set on Render —
`KN_SUPPORT_EMAIL` (e.g. support@yourdomain), `KN_SUPPORT_WHATSAPP` (digits with country code, e.g. 919876543210)
and `KN_HELP_URL`. The office line is `KN_OFFICE` (default "Ahmedabad, Gujarat, India"); support hours are
`KN_SUPPORT_OPEN` / `KN_SUPPORT_CLOSE` (default 09:00–19:00, Monday–Saturday, India time).

**Book a demo (website /book-demo):** 30-minute calls on weekdays at `KN_DEMO_TIMES` (default
["10:00","11:30","14:00","16:30"], India time), up to `KN_DEMO_DAYS_AHEAD` days ahead (default 14). A booked time
disappears for the next person. Demo bookings and contact messages are saved in the `leads` table (ticket KN-…);
nobody is notified yet, so check it until the admin panel shows them.

Keep this key private: anyone with it can read login codes on the test server. It can never be turned on
for the real (production) server.

## 4. Vercel — the website (customer report links)

The links in report SMS and emails open the website at `/r/<code>`. About 5 minutes.

1. Sign in at https://vercel.com with **GitHub** (allow access to the `kaamnishaan` repository).
2. **Add New… → Project** → import `navneetdhameliya/kaamnishaan`.
3. **Root Directory**: `web`. Framework: **Vite** (found by itself).
4. **Environment Variables**: `VITE_API_URL` = `https://kaamnishaan-api.onrender.com`
5. **Project name**: `kaamnishaan-web`, so the address is **https://kaamnishaan-web.vercel.app** (the API
   already sends links there and allows it). → **Deploy**.

If Vercel gives a different address, set it in Render → `kaamnishaan-api` → **Environment**:
`KN_WEB_URL` = that address, and add it to `KN_CORS_ORIGINS`. Every merge to `main` deploys again.

## After it is live

- Every merge to `main` deploys automatically (about 5 minutes).
- Logs: Render → `kaamnishaan-api` → **Logs**.
- Add or change a secret later: Render → `kaamnishaan-api` → **Environment** → Save (it restarts).
- Website and admin panel uploads from a browser will need a CORS rule on the R2 bucket; it is added
  when those apps are built.
- Paid upgrade later: switch the API and database plans in the dashboard; for a separate background
  worker and Redis ($7/month + free Redis), add them back to `render.yaml`.
