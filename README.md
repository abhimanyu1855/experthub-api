# ExpertHub API

Multi-tenant marketplace platform for expert services (consultations, coaching, medical). Built with Rails 8, PostgreSQL + pgvector, Solid Queue, ActionCable, and Kamal 2.

---

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Start](#quick-start)
3. [Environment Variables](#environment-variables)
4. [Multi-tenant Architecture](#multi-tenant-architecture)
5. [Demo Marketplace — SOS My Doctor](#demo-marketplace--sos-my-doctor)
6. [Deployment](#deployment)
7. [Testing](#testing)

---

## Prerequisites

| Tool | Version | Notes |
|------|---------|-------|
| Ruby | 3.3.7 | Use `rbenv` or `asdf` — see `.ruby-version` |
| Node | 20+ | Required for frontend only |
| Docker | 24+ | For local Postgres + Redis via `docker-compose.yml` |
| PostgreSQL | 16 with pgvector | Provided by `ankane/pgvector` Docker image |
| Redis | 7 | Provided by `redis:7-alpine` Docker image |

---

## Quick Start

```bash
# 1. Clone
git clone https://github.com/your-org/experthub-api
cd experthub-api

# 2. Install Ruby dependencies
bundle install

# 3. Copy environment file and fill in values
cp .env.example .env
# Edit .env — DATABASE_URL, REDIS_URL, and auth keys are required to boot.

# 4. Generate Active Record Encryption keys (paste output into .env)
bin/rails db:encryption:init

# 5. Start Postgres + Redis
docker compose up -d postgres redis

# 6. Set up the database
bin/rails db:create db:migrate

# 7. (Optional) Seed the demo marketplace
bin/rails db:seed

# 8. Start the server and background worker (two terminals, or use Foreman)
bin/rails server -p 3000
bin/jobs

# Or with Foreman / Overmind:
gem install foreman
foreman start -f Procfile.dev
```

The API will be available at `http://localhost:3000`.
Health check: `GET http://localhost:3000/up`

---

## Environment Variables

Copy `.env.example` to `.env`. Variables marked **Required** must be set before the app will boot in any environment.

| Variable | Required | Description |
|----------|----------|-------------|
| `DATABASE_URL` | ✅ | PostgreSQL connection string |
| `QUEUE_DATABASE_URL` | | Separate DB for Solid Queue (defaults to `DATABASE_URL`) |
| `REDIS_URL` | ✅ | Redis connection (ActionCable pub/sub) |
| `DEVISE_JWT_SECRET_KEY` | ✅ | JWT signing secret — generate with `bin/rails secret` |
| `ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY` | ✅ | AR encryption — generate with `bin/rails db:encryption:init` |
| `ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY` | ✅ | AR encryption deterministic key |
| `ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT` | ✅ | AR encryption salt |
| `RAILS_MASTER_KEY` | ✅ (prod) | Decrypts `config/credentials.yml.enc` |
| `APP_DOMAIN` | ✅ | Root domain for subdomain routing (e.g. `experthub.localhost`) |
| `FRONTEND_URL` | | Frontend origin for CORS (e.g. `http://localhost:5173`) |
| `CORS_EXTRA_ORIGINS` | | Comma-separated extra allowed CORS origins |
| `SMTP_ADDRESS` | | SMTP host (e.g. `smtp.resend.com`) |
| `SMTP_PORT` | | SMTP port (default `587`) |
| `SMTP_USER` | | SMTP username |
| `SMTP_PASSWORD` | | SMTP password / API key |
| `MAILER_FROM` | | Default from address for transactional email |
| `STRIPE_SECRET_KEY` | | Platform-level Stripe secret (optional — per-tenant keys stored in DB) |
| `PLATFORM_STRIPE_SECRET_KEY` | | ExpertHub's own Stripe account for platform billing |
| `PLATFORM_STRIPE_WEBHOOK_SECRET` | | Webhook signing secret for platform Stripe events |
| `STRIPE_STARTER_PRICE_ID` | | Stripe Price ID for Starter plan |
| `STRIPE_PRO_PRICE_ID` | | Stripe Price ID for Pro plan |
| `STRIPE_SCALE_PRICE_ID` | | Stripe Price ID for Scale plan |
| `OPENAI_API_KEY` | | GPT-4 — AI matching and session summaries |
| `ANTHROPIC_API_KEY` | | Claude — triage chatbot |
| `DAILY_API_KEY` | | Daily.co — video consultation rooms |
| `PLATFORM_FEE_PERCENT` | | Marketplace fee percentage (default `15`) |
| `SENTRY_DSN` | | Error tracking (optional) |

---

## Multi-tenant Architecture

ExpertHub is a **multi-tenant SaaS marketplace**. Each tenant is an independent marketplace (e.g. a medical clinic, a coaching platform) with its own branding, experts, clients, and Stripe account.

### Tenant identification

Requests are routed to the correct tenant by **subdomain**:

```
sosmydoctor.experthub.app  →  Tenant.find_by(ident: "sosmydoctor")
```

In development, configure `/etc/hosts` to point `*.experthub.localhost` to `127.0.0.1`, or pass the `X-Tenant-Id` header directly:

```bash
curl -H "X-Tenant-Id: sosmydoctor" http://localhost:3000/api/v1/services
```

### Key models

| Model | Description |
|-------|-------------|
| `Tenant` | Root of each marketplace — holds config, plan, feature flags |
| `User` | Polymorphic across tenants — role: `operator`, `expert`, or `client` |
| `Expert` | Expert profile with categories, services, and availability |
| `Booking` | Appointment request with lifecycle state machine |
| `PaymentConfig` | Per-tenant Stripe keys (encrypted at rest) |

All tenant-scoped models include `belongs_to :tenant` and are filtered via `Current.tenant` set in `ApplicationController`.

---

## Demo Marketplace — SOS My Doctor

Running `bin/rails db:seed` in the `development` environment automatically loads
`db/seeds/demo.rb`, which creates a fully-configured demo tenant called
**"SOS My Doctor"** (`ident: sosmydoctor`).

The seed is **idempotent** — safe to run multiple times without creating duplicates.

### What gets created

| Entity | Details |
|--------|---------|
| Tenant | name: "SOS My Doctor", ident: `sosmydoctor`, plan: `pro`, currency: INR |
| Feature flags | `ai_matching`, `triage_chatbot`, `session_summaries` all enabled |
| Stripe gateway | Test keys pre-configured (see seed file comments) |
| Categories | General Consultation, Specialist Consultation, Mental Health, Nutrition & Wellness |
| Experts | 3 doctors (GP, Cardiologist, Psychologist) with services + working hours |
| Client | 1 demo patient with 3 historical completed bookings and reviews |

### Login credentials

| Role | Email | Password |
|------|-------|----------|
| Operator (Admin) | `admin@sosmydoctor.com` | `Demo1234!` |
| Expert — Dr. Priya Sharma (GP) | `dr.priya@sosmydoctor.com` | `Demo1234!` |
| Expert — Dr. Rahul Menon (Cardiologist) | `dr.rahul@sosmydoctor.com` | `Demo1234!` |
| Expert — Dr. Ananya Patel (Psychologist) | `dr.ananya@sosmydoctor.com` | `Demo1234!` |
| Client — Raj Kumar | `patient@example.com` | `Demo1234!` |

### Services seeded

| Doctor | Service | Duration | Price (INR) |
|--------|---------|----------|-------------|
| Dr. Priya Sharma | General Consultation | 30 min | ₹500 |
| Dr. Priya Sharma | Follow-up Visit | 15 min | ₹250 |
| Dr. Rahul Menon | Cardiology Consultation | 45 min | ₹1,500 |
| Dr. Ananya Patel | Mental Health Session | 60 min | ₹1,200 |

### Stripe test keys

The demo seed uses Stripe **test** keys stored in `PaymentConfig` for the
`sosmydoctor` tenant. These allow end-to-end booking + payment flow testing
with [Stripe test cards](https://stripe.com/docs/testing#cards).

> **Important:** In production, each tenant enters their own Stripe keys via the
> admin panel. Keys are stored encrypted at rest using Rails Active Record
> Encryption. Never commit live/production Stripe keys to version control.

### Running the seed

```bash
# Start postgres + redis first, then:
bin/rails db:seed
```

To re-run just the demo seed without wiping the whole database:

```bash
bin/rails runner "load Rails.root.join('db/seeds/demo.rb')"
```

---

## Deployment

ExpertHub API uses [Kamal 2](https://kamal-deploy.org) for zero-downtime deploys.

### First-time setup

```bash
# 1. Copy secrets template and fill in real values
cp .kamal/secrets.example .kamal/secrets
# Edit .kamal/secrets — never commit this file

# 2. Build and push the Docker image, bootstrap servers
bundle exec kamal setup

# 3. Run database migrations
bundle exec kamal app exec --reuse 'bin/rails db:migrate'
```

### Day-to-day deploy

```bash
# Deploy latest commit
bundle exec kamal deploy

# Rollback to previous version
bundle exec kamal rollback

# Tail logs
bundle exec kamal app logs -f

# Open a console on the server
bundle exec kamal app exec --reuse 'bin/rails console'
```

### Server roles

| Role | Command | Purpose |
|------|---------|---------|
| `web` | `bin/rails server` (via `CMD` in Dockerfile) | Puma HTTP + ActionCable |
| `job` | `bin/jobs` | Solid Queue background worker |

See `config/deploy.yml` for full configuration — update server IPs, registry path, and domain before first deploy.

---

## Testing

```bash
# Run the full test suite
bundle exec rspec

# Run with coverage
COVERAGE=true bundle exec rspec

# Run a single spec file
bundle exec rspec spec/models/booking_spec.rb

# Security scan
bundle exec brakeman -q --no-pager

# Gem vulnerability audit
bundle exec bundler-audit check --update
```

CI runs automatically on every push and pull request via GitHub Actions (`.github/workflows/ci.yml`). It spins up Postgres (with pgvector) and Redis as service containers, runs the full RSpec suite, Brakeman, and bundler-audit.
