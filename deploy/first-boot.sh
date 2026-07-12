#!/usr/bin/env bash
# Phase 4 — first boot: docker compose up, migrate, seed demo data.
# Prerequisites: bootstrap-server.sh, .env.production, frontend dist/ built.
# Usage: ./deploy/first-boot.sh
set -euo pipefail

API_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$API_DIR"
COMPOSE="docker compose -f docker-compose.prod.yml"

if [[ ! -f .env.production ]]; then
  echo "Missing .env.production — run: ./deploy/setup-env.sh YOUR_ELASTIC_IP" >&2
  exit 1
fi

WEB_DIST="../experthub-web/dist"
if [[ ! -f "$WEB_DIST/index.html" ]]; then
  echo "Missing ${WEB_DIST} — run: ./deploy/build-frontend.sh YOUR_ELASTIC_IP" >&2
  exit 1
fi

echo "==> Starting stack"
$COMPOSE up -d --build

echo "==> Waiting for postgres"
sleep 5

echo "==> db:prepare"
$COMPOSE exec -T api bin/rails db:prepare

echo "==> Seeding demo tenants (sosmydoctor, fitnesszone, ...)"
$COMPOSE exec -T api env SEED_DEMO=1 bin/rails db:seed

echo "==> Done. Run ./deploy/verify.sh YOUR_ELASTIC_IP"
