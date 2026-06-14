# ExpertHub — Free Deployment Guide

Deploy the full ExpertHub SaaS platform for **$0/month** using a carefully chosen stack
of free tiers that actually support your requirements (pgvector, Redis, wildcard subdomains,
background workers).

---

## Section 1: Architecture Overview

```
                          ┌─────────────────────────────┐
                          │        Custom Domain         │
                          │   (*.your-domain.com DNS)    │
                          └─────────┬───────────┬────────┘
                                    │           │
                   ┌────────────────▼──┐   ┌────▼───────────────┐
                   │  Vercel (Free)    │   │  Vercel (Free)      │
                   │  experthub.app    │   │  *.experthub.app    │
                   │  React SPA        │   │  Tenant sub-domains │
                   └────────────────┬──┘   └────┬───────────────┘
                                    │           │
                                    └─────┬─────┘
                                          │ HTTPS / WSS
                          ┌───────────────▼──────────────────┐
                          │        Render (Free)              │
                          │        experthub-api              │
                          │        Rails 8 API                │
                          │        + ActionCable (/cable)     │
                          └──────┬──────────────┬────────────┘
                                 │              │
               ┌─────────────────▼──┐    ┌──────▼──────────────┐
               │  Render (Free)     │    │  Upstash (Free)      │
               │  experthub-worker  │    │  Redis               │
               │  Solid Queue       │    │  ActionCable pub/sub │
               └──────────┬─────────┘    └─────────────────────┘
                          │
           ┌──────────────▼───────────────┐
           │  Supabase (Free)              │
           │  PostgreSQL + pgvector        │
           │  500 MB · 5 GB bandwidth      │
           └───────────────────────────────┘
```

### Free Service Limits at a Glance

| Service | Free Tier Limits | Spins Down? |
|---------|-----------------|-------------|
| **Vercel** | 100 GB bandwidth, unlimited deploys | No |
| **Render Web Service** | 750 hrs/month, 512 MB RAM | **Yes — sleeps after 15 min inactivity** |
| **Render Background Worker** | 750 hrs/month, 512 MB RAM | **Yes — sleeps after 15 min** |
| **Supabase** | 500 MB database, 5 GB bandwidth, 2 projects | No |
| **Upstash Redis** | 10,000 commands/day, 256 MB | No (requests fail when exceeded) |
| **Resend (email)** | 3,000 emails/month, 100/day | No |

> **Honest warning about Render's free tier:** The API and worker will go to sleep after
> 15 minutes of inactivity. The first request after sleeping takes ~30 seconds (cold start).
> See Section 11 for how to prevent this with a free uptime monitor.

---

## Section 2: Prerequisites

### Accounts to Create
- [ ] **GitHub** — push both repos here; Render and Vercel deploy from GitHub
- [ ] **Supabase** — supabase.com (PostgreSQL + pgvector)
- [ ] **Render** — render.com (Rails API + Solid Queue worker)
- [ ] **Upstash** — upstash.com (Redis for ActionCable)
- [ ] **Vercel** — vercel.com (React SPA + wildcard subdomains)
- [ ] **Resend** — resend.com (free transactional email)
- [ ] **Custom domain** *(optional but recommended for wildcard subdomains)* — Namecheap,
  Cloudflare, or any registrar. Required for `*.your-domain.com` multi-tenancy routing.

### Local Tools Needed
```bash
# Generate secrets before deployment
openssl rand -hex 64           # for DEVISE_JWT_SECRET_KEY
bin/rails db:encryption:init   # for Active Record Encryption keys
```

---

## Section 3: Database Setup (Supabase)

Supabase is the **only major free-tier provider** that ships pgvector, which ExpertHub
requires for AI-powered expert matching.

1. Go to [supabase.com](https://supabase.com) → **New project**
2. Choose a region close to your users
3. Set a strong database password and save it — you'll need it later
4. Wait ~2 minutes for the project to provision

### Enable pgvector

In the Supabase dashboard → **SQL Editor** → run:

```sql
create extension if not exists vector;
```

Verify it worked:
```sql
select * from pg_extension where extname = 'vector';
-- should return one row
```

### Get the Connection String

Go to **Settings → Database** → scroll to **Connection string**.

> **Important:** Use the **direct connection URL**, NOT the pooler (PgBouncer) URL.
> Rails requires a direct connection for migrations and certain ActiveRecord features.

The URL format:
```
postgresql://postgres:[YOUR-PASSWORD]@db.[PROJECT-REF].supabase.co:5432/postgres
```

Example:
```
postgresql://postgres:MySecurePass123@db.abcdefghijkl.supabase.co:5432/postgres
```

Save this as your `DATABASE_URL` environment variable.

### Optional: Separate Queue Database

If you want Solid Queue on its own connection (recommended for production):

```sql
-- In Supabase SQL Editor
create database experthub_queue;
```

Then set `QUEUE_DATABASE_URL` to the same host but with `/experthub_queue` at the end.
For the free tier, sharing the main database is fine.

---

## Section 4: Redis Setup (Upstash)

Upstash provides a serverless Redis instance with a generous free tier and **TLS by default**,
which is required for ActionCable in production.

1. Go to [upstash.com](https://upstash.com) → **Create Database**
2. Name: `experthub-redis`
3. Region: choose the same region as your Render deployment
4. Enable **TLS** (it's on by default)
5. Click **Create**

### Copy the Redis URL

From the Upstash dashboard → your database → **Details** tab:

- Copy the **Redis URL** (starts with `rediss://` — note the double `s` for TLS)

```
rediss://default:AxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxYYYY@your-endpoint.upstash.io:6379
```

Save this as your `REDIS_URL` environment variable.

> **Note:** `rediss://` (with double `s`) is the TLS Redis scheme. The `config/cable.yml`
> in this repo is already configured to handle this — see Section 6.

### Free Tier Limits

- **10,000 commands/day** — ActionCable uses ~2–5 commands per WebSocket message
- If exceeded, connections will fail until midnight UTC when the counter resets
- Upgrade to pay-as-you-go at $0.20 per 100k commands if needed

---

## Section 5: Deploy Rails API on Render

### Step 1: Push to GitHub

```bash
cd /path/to/experthub-api
git init  # if not already a git repo
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/experthub-api.git
git push -u origin main
```

### Step 2: Create the Web Service

1. Go to [render.com](https://render.com) → **New +** → **Web Service**
2. Connect your GitHub account and select the `experthub-api` repo
3. Configure:

| Setting | Value |
|---------|-------|
| **Name** | `experthub-api` |
| **Runtime** | Docker |
| **Instance Type** | Free |
| **Health Check Path** | `/up` |

4. Click **Create Web Service** — Render will build and deploy automatically

> **Alternatively**, use the included `render.yaml` Blueprint:
> Render dashboard → **New +** → **Blueprint** → connect the `experthub-api` repo.
> Render creates **experthub-api** (web) and **experthub-worker** (background worker)
> and prompts you to fill in secret env vars once via the shared `experthub-env` group.

### Step 3: Add Environment Variables

In Render dashboard → your service → **Environment** → add each variable.
When using `render.yaml` (Blueprint), Render prompts you to fill in all `sync: false`
values once — both the web service and worker share the `experthub-env` group.

#### Required

| Variable | Example / Value | How to Generate |
|----------|-----------------|-----------------|
| `DATABASE_URL` | `postgresql://postgres:...@db.xxxx.supabase.co:5432/postgres` | Section 3 — Supabase **direct** URL |
| `QUEUE_DATABASE_URL` | Same host, optional `/experthub_queue` database | Optional; defaults to `DATABASE_URL` |
| `REDIS_URL` | `rediss://default:...@xxxx.upstash.io:6379` | Section 4 — Upstash TLS URL |
| `RAILS_ENV` | `production` | Literal |
| `RAILS_MASTER_KEY` | 32-char hex key | `cat config/master.key` |
| `DEVISE_JWT_SECRET_KEY` | 128-char hex string | `openssl rand -hex 64` |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | From encryption init | `bin/rails db:encryption:init` |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | From encryption init | `bin/rails db:encryption:init` |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | From encryption init | `bin/rails db:encryption:init` |
| `APP_DOMAIN` | `experthub.app` | Your apex domain (no `https://`) |
| `FRONTEND_URL` | `https://experthub.app` | Vercel production URL |
| `CORS_EXTRA_ORIGINS` | `https://experthub.app,https://www.experthub.app` | Comma-separated allowed origins |
| `PLATFORM_FEE_PERCENT` | `15` | Platform commission % |

#### Email (Resend)

| Variable | Example / Value | Notes |
|----------|-----------------|-------|
| `SMTP_ADDRESS` | `smtp.resend.com` | Resend SMTP host |
| `SMTP_PORT` | `587` | STARTTLS port |
| `SMTP_DOMAIN` | `experthub.app` | Must match verified domain |
| `SMTP_USER` | `resend` | Literal |
| `SMTP_PASSWORD` | `re_xxxxxxx` | Resend API key |
| `MAILER_FROM` | `ExpertHub <noreply@experthub.app>` | From address |

#### Payments & Video (add when ready)

| Variable | Description |
|----------|-------------|
| `STRIPE_PUBLISHABLE_KEY` | Per-tenant marketplace Stripe publishable key (fallback) |
| `STRIPE_SECRET_KEY` | Per-tenant marketplace Stripe secret key (fallback) |
| `STRIPE_WEBHOOK_SECRET` | Stripe webhook signing secret |
| `PLATFORM_STRIPE_SECRET_KEY` | ExpertHub platform billing (charges marketplace admins) |
| `PLATFORM_STRIPE_WEBHOOK_SECRET` | Platform Stripe webhook secret |
| `STRIPE_STARTER_PRICE_ID` | Stripe Price ID for Starter plan |
| `STRIPE_PRO_PRICE_ID` | Stripe Price ID for Pro plan |
| `STRIPE_SCALE_PRICE_ID` | Stripe Price ID for Scale plan |
| `DAILY_API_KEY` | Daily.co video rooms |

#### AI & Monitoring (optional)

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | AI expert matching / triage |
| `ANTHROPIC_API_KEY` | Claude-powered features |
| `SENTRY_DSN` | Error monitoring |

### Step 4: Create the Background Worker (Solid Queue)

Solid Queue runs as a **separate process** — it cannot share the web service process.

1. Render dashboard → **New +** → **Background Worker**
2. Connect the same `experthub-api` GitHub repo
3. Configure:

| Setting | Value |
|---------|-------|
| **Name** | `experthub-worker` |
| **Runtime** | Docker |
| **Docker Command** | `bin/jobs` |
| **Instance Type** | Free |

4. Add the **same environment variables** as the web service — when using Blueprint,
   both services share the `experthub-env` group automatically
5. Click **Create Background Worker**

---

## Section 6: Configure cable.yml for Upstash TLS

Upstash requires TLS (`rediss://`) but Ruby's OpenSSL can be strict about certificate
verification in some environments. The production config in `config/cable.yml` includes
`ssl_params` to handle this:

```yaml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") { raise "REDIS_URL is not set" } %>
  channel_prefix: experthub_production
  ssl_params:
    verify_mode: <%= OpenSSL::SSL::VERIFY_NONE %>
```

> This is already applied in the repo. No action needed unless you see SSL errors in
> Render logs, in which case verify that `cable.yml` matches the above.

---

## Section 7: Run Database Migrations

After the first deploy succeeds, run migrations using the **Render Shell**:

1. Render dashboard → `experthub-api` service → **Shell** tab
2. Run:

```bash
bin/rails db:migrate
bin/rails db:seed
```

Or create a one-off job via Render's **Jobs** feature (New + → Job → same repo).

### Verify pgvector is Active

In the Render shell (or Supabase SQL Editor):

```bash
bin/rails runner "ActiveRecord::Base.connection.execute(\"SELECT extname FROM pg_extension WHERE extname = 'vector'\")"
```

---

## Section 8: Deploy Frontend on Vercel

### Step 1: Push Frontend to GitHub

```bash
cd /path/to/experthub-web
git init
git add .
git commit -m "Initial commit"
git remote add origin https://github.com/YOUR_USERNAME/experthub-web.git
git push -u origin main
```

### Step 2: Import on Vercel

1. Go to [vercel.com](https://vercel.com) → **Add New Project** → **Import Git Repository**
2. Select `experthub-web`
3. Framework preset: **Vite**
4. Build command: `npm run build` (auto-detected)
5. Output directory: `dist` (auto-detected)

> **Included config:** `vercel.json` in the repo rewrites all paths to `/index.html`
> (required for React Router client-side routing) and sets `X-Content-Type-Options: nosniff`
> and `X-Frame-Options: DENY` security headers.

### Step 3: Add Environment Variables

In Vercel → your project → **Settings** → **Environment Variables**:

| Variable | Value |
|----------|-------|
| `VITE_API_URL` | `https://experthub-api.onrender.com` |
| `VITE_APP_DOMAIN` | `your-domain.com` |
| `VITE_CABLE_URL` | `wss://experthub-api.onrender.com/cable` |

6. Click **Deploy**

### Step 4: Wildcard Subdomain Setup (Multi-Tenancy)

This is required for tenant subdomains like `sosmydoctor.your-domain.com` to route
to the same Vercel SPA.

#### Add Domains on Vercel

1. Vercel → your project → **Settings** → **Domains**
2. Add your apex domain: `your-domain.com`
3. Add the wildcard: `*.your-domain.com`

#### Configure DNS at Your Registrar

Add these DNS records at Namecheap / Cloudflare / your DNS provider:

| Type | Host / Name | Value | TTL |
|------|-------------|-------|-----|
| `A` | `@` | `76.76.21.21` | Auto |
| `CNAME` | `www` | `cname.vercel-dns.com` | Auto |
| `CNAME` | `*` | `cname.vercel-dns.com` | Auto |

> **Cloudflare note:** If using Cloudflare as your DNS proxy, set the wildcard CNAME
> to **DNS only** (grey cloud), not proxied. Vercel handles the CDN.

DNS propagation takes 5–30 minutes. Vercel will auto-provision TLS certificates for
both `your-domain.com` and `*.your-domain.com`.

#### How Multi-Tenancy Works

- `sosmydoctor.your-domain.com` → Vercel CDN → serves `index.html` (same SPA)
- The React app reads `window.location.hostname` to extract the tenant slug (`sosmydoctor`)
- It sends that slug (or a JWT containing it) to the Rails API
- Rails routes all requests to the correct tenant's data

#### Testing Without a Custom Domain

If you don't have a domain yet, test using the `X-Tenant-Id` header approach:
- Frontend at `your-app.vercel.app`
- Add `X-Tenant-Id: <tenant-slug>` header to all API requests
- Ensure the Rails API reads this header as a fallback when `APP_DOMAIN` subdomain parsing fails

---

## Section 9: Free Email with Resend

[Resend](https://resend.com) offers **3,000 emails/month and 100/day** on the free tier —
enough for a small-scale launch.

### Setup

1. Go to [resend.com](https://resend.com) → sign up
2. **Add a domain** (requires DNS verification) — or test with Resend's test domain
3. **API Keys** → Create API Key → copy it

### Environment Variables

```
SMTP_ADDRESS=smtp.resend.com
SMTP_PORT=587
SMTP_USER=resend
SMTP_PASSWORD=re_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx
SMTP_DOMAIN=your-domain.com
MAILER_FROM=ExpertHub <noreply@your-domain.com>
```

### DNS Records for Resend Domain Verification

Resend will give you SPF, DKIM, and DMARC records to add at your DNS provider.
Add all three — deliverability depends on it.

---

## Section 10: Free Tier Limits Summary

Be aware of these limits as your platform grows:

| Service | Free Limit | What Happens When Exceeded |
|---------|-----------|---------------------------|
| **Render Web Service** | 750 hrs/month, sleeps after 15 min inactivity | Cold start ~30s on next request |
| **Render Background Worker** | 750 hrs/month, sleeps after 15 min | Job processing pauses until wake |
| **Supabase** | 500 MB database, 5 GB bandwidth | Dashboard warning → upgrade required |
| **Upstash Redis** | 10,000 commands/day | WebSocket connections fail until midnight UTC |
| **Vercel** | 100 GB bandwidth, unlimited deploys | Soft limit — upgrade required for more |
| **Resend** | 3,000 emails/month, 100/day | Emails queued/rejected until next period |

### Upgrade Path (cheapest options)

| Service | Paid Plan | Monthly Cost |
|---------|-----------|-------------|
| Render | Starter instance | $7/month |
| Supabase | Pro | $25/month |
| Upstash | Pay-as-you-go | $0.20/100k commands |
| Vercel | Pro | $20/month |

---

## Section 11: Prevent Render Cold Starts (Optional but Recommended)

Render's free tier sleeps services after 15 minutes of inactivity. A simple ping every
5 minutes prevents this.

### Option A: UptimeRobot (Free)

1. Go to [uptimerobot.com](https://uptimerobot.com) → sign up
2. **New Monitor** → type: **HTTP(S)**
3. URL: `https://experthub-api.onrender.com/up`
4. Monitoring interval: **5 minutes**
5. Click **Create Monitor**

The `/up` endpoint returns a simple 200 response confirming the app and database are alive.

### Option B: Cron-job.org (Free)

1. Go to [cron-job.org](https://cron-job.org) → sign up
2. New cronjob → URL: `https://experthub-api.onrender.com/up`
3. Schedule: every 5 minutes
4. Save

> **Note:** Keeping the web service alive with pings will consume your 750 hrs/month.
> 24 hrs × 31 days = 744 hrs — you'll stay within limits but just barely. If you need
> more headroom, upgrade to Render's $7/month Starter plan.

---

## Section 12: Deployment Checklist

Complete these steps in order:

### Database & Redis
- [ ] Create Supabase project
- [ ] Run `create extension if not exists vector;` in Supabase SQL Editor
- [ ] Copy Supabase **direct** connection URL
- [ ] Create Upstash Redis database (TLS enabled)
- [ ] Copy Upstash `REDIS_URL` (starts with `rediss://`)

### API (Render)
- [ ] Push `experthub-api` to GitHub
- [ ] Generate secrets locally:
  - [ ] `openssl rand -hex 64` → `DEVISE_JWT_SECRET_KEY`
  - [ ] `bin/rails db:encryption:init` → three encryption keys
  - [ ] Note `config/master.key` contents → `RAILS_MASTER_KEY`
- [ ] Create Render Web Service (Docker, Free tier) **or** use Blueprint (`render.yaml`)
- [ ] Add all environment variables in Render dashboard (see Section 5 tables)
- [ ] Create Render Background Worker (`bin/jobs`, Free tier) — created automatically by Blueprint
- [ ] Wait for first deploy to succeed
- [ ] Run `bin/rails db:migrate` via Render Shell
- [ ] Run `bin/rails db:seed` via Render Shell
- [ ] Visit `https://experthub-api.onrender.com/up` → should return `{"status":"ok"}`

### Email
- [ ] Create Resend account
- [ ] Add and verify your domain
- [ ] Copy Resend API key → `SMTP_PASSWORD`
- [ ] Add Resend DNS records at your registrar

### Frontend (Vercel)
- [ ] Push `experthub-web` to GitHub
- [ ] Import project on Vercel
- [ ] Add environment variables (`VITE_API_URL`, `VITE_APP_DOMAIN`, `VITE_CABLE_URL`)
- [ ] Deploy

### Wildcard Subdomains
- [ ] Add `your-domain.com` to Vercel project
- [ ] Add `*.your-domain.com` to Vercel project
- [ ] Add DNS `A` record: `@` → `76.76.21.21`
- [ ] Add DNS `CNAME` record: `*` → `cname.vercel-dns.com`
- [ ] Wait for DNS propagation (5–30 min)
- [ ] Verify TLS certificates provisioned on Vercel

### Keep-Alive (Optional)
- [ ] Set up UptimeRobot monitor → `https://experthub-api.onrender.com/up` every 5 min

---

## Troubleshooting

### `PG::UndefinedFile: ERROR: could not open extension control file`
pgvector is not installed. Run `create extension if not exists vector;` in the Supabase
SQL Editor.

### `SSL SYSCALL error` on Redis
`REDIS_URL` is using `redis://` instead of `rediss://` (missing TLS). Copy the URL
from Upstash again — it must start with `rediss://`.

### Render deploy fails: `PORT already in use`
The `CMD` in `Dockerfile` now uses `${PORT:-3000}` to respect Render's dynamic port.
If you have an old Dockerfile, update the CMD:
```dockerfile
CMD ["sh", "-c", "bin/rails server -b 0.0.0.0 -p ${PORT:-3000}"]
```

### ActionCable connections dropping
Check that `REDIS_URL` is set correctly in the Render environment and that Upstash
daily command limit hasn't been reached (check Upstash dashboard).

### Wildcard subdomain SSL not working
Ensure the wildcard CNAME (`*`) is not proxied through Cloudflare (set to DNS only).
Vercel needs to handle TLS termination for wildcard domains.

### Cold starts on first request (~30s)
Expected behavior on Render's free tier. Set up UptimeRobot (Section 11) to prevent this.
