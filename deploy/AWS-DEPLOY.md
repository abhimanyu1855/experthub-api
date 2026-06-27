# ExpertHub — AWS EC2 Free Tier Deploy

Single-server deployment using Docker Compose. No custom domain required — use [nip.io](https://nip.io) with your Elastic IP.

## Prerequisites

- AWS account (EC2 t2.micro free tier)
- Elastic IP attached to instance
- Repos cloned as siblings: `~/experthub-api` and `~/experthub-web`

## Quick start

```bash
# 1. On EC2: install Docker, add 2GB swap (see plan guide)

# 2. Secrets
cd ~/experthub-api
cp deploy/env.production.example .env.production
# Edit .env.production — set RAILS_MASTER_KEY, JWT key, encryption keys, POSTGRES_PASSWORD
# Set APP_DOMAIN=YOUR-IP-WITH-DASHES.nip.io (e.g. 54-123-45-67.nip.io)

# 3. Build frontend (env is baked in at build time)
cd ~/experthub-web
export VITE_API_URL=http://YOUR-IP-WITH-DASHES.nip.io
export VITE_APP_DOMAIN=YOUR-IP-WITH-DASHES.nip.io
export VITE_CABLE_URL=ws://YOUR-IP-WITH-DASHES.nip.io/cable
npm ci && npm run build

# 4. Start stack
cd ~/experthub-api
docker compose -f docker-compose.prod.yml up -d --build
docker compose -f docker-compose.prod.yml exec api bin/rails db:prepare
docker compose -f docker-compose.prod.yml exec api env SEED_DEMO=1 bin/rails db:seed

# 5. Verify
curl http://YOUR_ELASTIC_IP/up
```

## Tester URLs (nip.io)

| Purpose | URL |
|---------|-----|
| Platform signup | `http://54-123-45-67.nip.io/signup` |
| Tenant storefront | `http://sosmydoctor.54-123-45-67.nip.io/explore` |
| Admin login | `http://sosmydoctor.54-123-45-67.nip.io/login/expert` |

Use nip.io hostnames, not the raw IP, for tenant subdomains.

## Demo credentials

- Admin: `admin@sosmydoctor.com` / `Demo1234!`
- Client: `patient@example.com` / `Demo1234!`

## Environment notes

| Variable | EC2 / nip.io value |
|----------|-------------------|
| `FORCE_SSL` | `false` (HTTP only until you add a domain + HTTPS) |
| `SOLID_QUEUE_IN_PUMA` | `false` |
| `SOLID_CACHE` | `false` |

## Full walkthrough

See the AWS Free Tier plan in the repo wiki or project docs for EC2 launch, security groups, and billing alarms.
