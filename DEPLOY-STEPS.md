# ExpertHub — Step-by-Step Deploy Guide

You’ve already pushed both repos to GitHub. Follow these steps **in order**.
Keep this doc open and fill in the **Secrets Worksheet** as you go.

> **Time estimate:** ~45–60 minutes first time (mostly waiting on Supabase/Render/Vercel).

---

## Before you start

| What | Where |
|------|--------|
| API repo on GitHub | `experthub-api` |
| Frontend repo on GitHub | `experthub-web` |
| This guide | `experthub-api/DEPLOY-STEPS.md` |
| Deep reference | `experthub-api/DEPLOYMENT.md` |

**Accounts to create (all free tier):**

1. [supabase.com](https://supabase.com) — PostgreSQL + pgvector  
2. [upstash.com](https://upstash.com) — Redis for ActionCable  
3. [render.com](https://render.com) — Rails API + background worker  
4. [vercel.com](https://vercel.com) — React frontend  
5. [resend.com](https://resend.com) — email (optional for day one)  
6. [uptimerobot.com](https://uptimerobot.com) — optional, stops Render cold starts  

---

## Part A — Generate secrets on your Mac (15 min)

Do this **before** opening Render. You’ll paste these values into Render in Part C.

Open Terminal:

```bash
cd ~/Desktop/experthub-api   # or wherever you cloned experthub-api
```

### A1. Rails master key

```bash
cat config/master.key
```

Copy the output (one line, ~32 characters).  
Save it as **`RAILS_MASTER_KEY`** in the worksheet below.

> If `config/master.key` is missing, run `bin/rails credentials:edit` once locally to create it.

### A2. JWT secret

```bash
openssl rand -hex 64
```

Copy the full output. Save as **`DEVISE_JWT_SECRET_KEY`**.

> Render Blueprint can auto-generate this (`generateValue: true`). If Render already filled it during Blueprint apply, you can use Render’s value instead.

### A3. Active Record encryption keys

```bash
bin/rails db:encryption:init
```

You’ll see output like:

```
active_record_encryption:
  primary_key: xxxxxxxxx
  deterministic_key: xxxxxxxxx
  key_derivation_salt: xxxxxxxxx
```

Copy each value into:

- `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY`
- `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY`
- `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT`

### A4. Domain placeholders (update later if you don’t have a domain yet)

For **first deploy without a custom domain**, use your Vercel URL once you have it (Part D). Until then, use placeholders:

| Variable | First deploy (no custom domain) | After you add a domain |
|----------|-----------------------------------|-------------------------|
| `APP_DOMAIN` | `onrender.com` *(temporary)* | `yourdomain.com` |
| `FRONTEND_URL` | `https://YOUR-PROJECT.vercel.app` | `https://yourdomain.com` |
| `CORS_EXTRA_ORIGINS` | `https://YOUR-PROJECT.vercel.app` | `https://yourdomain.com,https://www.yourdomain.com` |
| `SMTP_DOMAIN` | `onrender.com` | `yourdomain.com` |
| `MAILER_FROM` | `ExpertHub <onboarding@resend.dev>` | `ExpertHub <noreply@yourdomain.com>` |

---

## Secrets Worksheet (fill this in)

Copy this table into Notes and fill every **Required** row before Part C.

| Variable | Required? | Your value (paste here) | Where you got it |
|----------|-----------|-------------------------|------------------|
| `DATABASE_URL` | **Yes** | | Part B1 — Supabase |
| `REDIS_URL` | **Yes** | | Part B2 — Upstash |
| `RAILS_MASTER_KEY` | **Yes** | | Part A1 |
| `DEVISE_JWT_SECRET_KEY` | **Yes** | | Part A2 or Render auto-gen |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | **Yes** | | Part A3 |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | **Yes** | | Part A3 |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | **Yes** | | Part A3 |
| `APP_DOMAIN` | **Yes** | | Part A4 |
| `FRONTEND_URL` | **Yes** | | Part A4 / after Vercel deploy |
| `CORS_EXTRA_ORIGINS` | **Yes** | | Part A4 |
| `RAILS_ENV` | Auto | `production` | Already set in render.yaml |
| `PLATFORM_FEE_PERCENT` | Auto | `15` | Already set in render.yaml |
| `SMTP_ADDRESS` | Auto | `smtp.resend.com` | Already set in render.yaml |
| `SMTP_PORT` | Auto | `587` | Already set in render.yaml |
| `SMTP_USER` | Auto | `resend` | Already set in render.yaml |
| `QUEUE_DATABASE_URL` | No | *(leave empty — uses DATABASE_URL)* | |
| `SMTP_PASSWORD` | No | Resend API key | Part E (email) |
| `SMTP_DOMAIN` | No | your domain | Part A4 |
| `MAILER_FROM` | No | | Part A4 |
| `STRIPE_*` / `DAILY_*` / `OPENAI_*` / `SENTRY_DSN` | No | *(leave empty for v1)* | Add when you need payments/AI |

---

## Part B — Supabase + Upstash (20 min)

### B1. Supabase (database)

1. Go to [supabase.com/dashboard](https://supabase.com/dashboard) → **New project**
2. Pick a region (same as you’ll use for Render, e.g. Oregon / Frankfurt)
3. Set a **database password** → save it in your password manager
4. Wait until the project status is **Active**

**Enable pgvector:**

1. Left sidebar → **SQL Editor** → **New query**
2. Run:

```sql
create extension if not exists vector;
```

3. Click **Run**. You should see “Success”.

**Get `DATABASE_URL`:**

1. Left sidebar → **Project Settings** (gear) → **Database**
2. Scroll to **Connection string** → tab **URI**
3. Choose **Direct connection** (not “Transaction pooler”)
4. Copy the URI. It looks like:

```
postgresql://postgres.[PROJECT-REF]:[YOUR-PASSWORD]@aws-0-[region].pooler.supabase.com:5432/postgres
```

   **Important:** Replace `[YOUR-PASSWORD]` with the password you set in step 3.

5. Paste into your worksheet as **`DATABASE_URL`**

---

### B2. Upstash (Redis)

1. Go to [console.upstash.com](https://console.upstash.com) → **Create database**
2. Name: `experthub-redis`
3. Region: same region as Render/Supabase
4. **TLS: enabled** (default)
5. Click **Create**

**Get `REDIS_URL`:**

1. Open the database → **Details** tab
2. Copy **Redis URL** — it must start with **`rediss://`** (double `s` = TLS)

Example:

```
rediss://default:AXxxxx...@xxxx.upstash.io:6379
```

3. Paste into worksheet as **`REDIS_URL`**

---

## Part C — Render Blueprint (where secrets actually go)

This is the part that was unclear: **secrets are entered in two possible places**.

### C1. Apply Blueprint (first time — main place)

1. Go to [dashboard.render.com](https://dashboard.render.com)
2. Click **New +** (top right) → **Blueprint**
3. Connect GitHub if asked → select repo **`experthub-api`**
4. Render reads `render.yaml` and shows a **review screen** titled something like **“Sync Blueprint”**
5. On that screen you’ll see a list of **environment variables** with empty inputs for every `sync: false` key, including:
   - `DATABASE_URL`
   - `REDIS_URL`
   - `RAILS_MASTER_KEY`
   - encryption keys
   - `APP_DOMAIN`, `FRONTEND_URL`, `CORS_EXTRA_ORIGINS`
   - optional Stripe/AI keys
6. **Paste each value from your Secrets Worksheet** into the matching field
7. For optional vars you don’t have yet (Stripe, OpenAI, etc.): leave blank or type a single space if Render requires non-empty — you can update later
8. Click **Apply** (bottom of page)

Render will create:

- Web service: **`experthub-api`**
- Environment group: **`experthub-env`** (shared config)

> **Free plan note:** Render does **not** offer background workers on the free tier.
> Jobs run inside the web process via `SOLID_QUEUE_IN_PUMA=true` (already set in `render.yaml`).
> For a dedicated worker later, upgrade to Render Starter ($7/mo).

First deploy takes **5–15 minutes**. Watch the **Logs** tab on `experthub-api`.

---

### C2. Edit secrets later (if you missed one)

**Option 1 — Environment group (recommended, one place for both services):**

1. [dashboard.render.com](https://dashboard.render.com)
2. Left sidebar → **Environment Groups**
3. Click **`experthub-env`**
4. **Add / Edit** variables → paste values → **Save changes**
5. Render will **redeploy** both API and worker automatically

**Option 2 — Per service:**

1. Dashboard → click **`experthub-api`**
2. Left sidebar → **Environment**
3. Variables listed here come from **`experthub-env`** — click **Edit** or link to the group
4. Same for **`experthub-worker`**

```
Render Dashboard
├── Environment Groups          ← EDIT ALL SECRETS HERE (best)
│   └── experthub-env
│       ├── DATABASE_URL
│       ├── REDIS_URL
│       ├── RAILS_MASTER_KEY
│       └── ...
├── experthub-api (Web Service)
│   └── Environment             ← shows linked group vars (read-only view)
└── experthub-worker (Worker)
    └── Environment             ← same group
```

---

### C3. Run database migrations

After **`experthub-api`** shows **Live** (green):

1. Dashboard → **`experthub-api`**
2. Top tabs → **Shell** (or **Connect** → Shell)
3. Run:

```bash
bin/rails db:migrate
bin/rails db:seed
```

4. Exit shell

**Verify API:**

Open in browser:

```
https://experthub-api.onrender.com/up
```

*(Replace with your actual Render URL if the service name differs.)*

You should see a JSON health response (status ok).

> **Cold start:** Free tier sleeps after 15 min. First request may take ~30s.

---

## Part D — Vercel (frontend)

### D1. Import project

1. [vercel.com/new](https://vercel.com/new)
2. Import Git repo **`experthub-web`**
3. Framework: **Vite** (auto-detected)
4. Build: `npm run build` · Output: `dist`
5. **Do not deploy yet** — add env vars first (D2)

### D2. Environment variables (Vercel UI)

1. On the import screen, expand **Environment Variables**
2. Add these (Production + Preview + Development):

| Name | Value |
|------|--------|
| `VITE_API_URL` | `https://experthub-api.onrender.com` *(your Render web URL, no trailing slash)* |
| `VITE_APP_DOMAIN` | `onrender.com` *(temporary)* or `yourdomain.com` |
| `VITE_CABLE_URL` | `wss://experthub-api.onrender.com/cable` *(same host as API, `wss://`)* |

3. Click **Deploy**
4. When done, copy your Vercel URL, e.g. `https://experthub-web-abc123.vercel.app`

### D3. Point Render back at Vercel (important)

Go back to Render → **Environment Groups** → **`experthub-env`** and update:

| Variable | New value |
|----------|-----------|
| `FRONTEND_URL` | `https://experthub-web-abc123.vercel.app` |
| `CORS_EXTRA_ORIGINS` | `https://experthub-web-abc123.vercel.app` |

Save → wait for redeploy.

### D4. Test the app

1. Open your Vercel URL
2. For tenant subdomains without a custom domain, use local-style testing or add a domain later (see `DEPLOYMENT.md` Section 8)
3. API calls should go to Render (check browser Network tab → requests to `onrender.com`, not `localhost`)

---

## Part E — Email with Resend (optional, do when ready)

1. [resend.com](https://resend.com) → sign up
2. **API Keys** → Create → copy key (`re_...`)
3. Render → **Environment Groups** → **`experthub-env`**:

| Variable | Value |
|----------|--------|
| `SMTP_PASSWORD` | your Resend API key |
| `MAILER_FROM` | `ExpertHub <onboarding@resend.dev>` *(Resend test sender)* |

For production email from your domain, verify the domain in Resend and add DNS records they provide.

---

## Part F — Keep API awake (optional)

1. [uptimerobot.com](https://uptimerobot.com) → **Add monitor**
2. Type: **HTTP(s)**
3. URL: `https://experthub-api.onrender.com/up`
4. Interval: **5 minutes**

---

## Part G — Custom domain + wildcard tenants (when you have a domain)

See **`DEPLOYMENT.md` Section 8** for:

- Vercel: add `yourdomain.com` and `*.yourdomain.com`
- DNS: `A` `@` → `76.76.21.21`, `CNAME` `*` → `cname.vercel-dns.com`
- Update `APP_DOMAIN`, `VITE_APP_DOMAIN`, `CORS_EXTRA_ORIGINS`, `FRONTEND_URL`

---

## Quick checklist

```
[ ] Part A — Secrets generated (master key, JWT, encryption)
[ ] Part B1 — Supabase project + pgvector + DATABASE_URL
[ ] Part B2 — Upstash Redis + REDIS_URL (rediss://)
[ ] Part C1 — Render Blueprint → paste secrets on Apply screen → Apply
[ ] Part C3 — Shell: db:migrate + db:seed
[ ] Part C3 — /up returns OK
[ ] Part D — Vercel deploy + VITE_* env vars
[ ] Part D3 — Update FRONTEND_URL + CORS on Render
[ ] Part F — UptimeRobot (optional)
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| “Where do I paste secrets?” | **Environment Groups → experthub-env** OR the Blueprint **Apply** form before first deploy |
| Deploy fails immediately | Check Render **Logs** — usually missing `RAILS_MASTER_KEY` or bad `DATABASE_URL` |
| `PG::UndefinedFile` / vector error | Run `create extension if not exists vector;` in Supabase SQL Editor |
| Redis SSL errors | `REDIS_URL` must be `rediss://` (from Upstash), not `redis://` |
| Frontend calls localhost | Redeploy Vercel after setting `VITE_API_URL`; hard refresh browser |
| CORS errors | Update `CORS_EXTRA_ORIGINS` on Render to match exact Vercel URL (https, no trailing slash) |
| Worker not processing jobs | Check **`experthub-worker`** logs; same env group must have `DATABASE_URL` |

---

## What to send if you’re stuck

1. Render service name + screenshot of **Environment Groups → experthub-env** (blur secret values)
2. Last 30 lines of **experthub-api → Logs**
3. Browser Network tab: failing request URL and status code
