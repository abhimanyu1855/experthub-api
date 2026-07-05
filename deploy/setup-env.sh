#!/usr/bin/env bash
# Create .env.production from template and print secret generation hints.
# Usage: ./deploy/setup-env.sh 54.123.45.67
set -euo pipefail

ELASTIC_IP="${1:-}"
API_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$API_DIR"

if [[ -z "$ELASTIC_IP" ]]; then
  echo "Usage: $0 ELASTIC_IP" >&2
  exit 1
fi

NIP_DOMAIN=$(bash deploy/nip-domain.sh "$ELASTIC_IP")

if [[ -f .env.production ]]; then
  echo ".env.production already exists — not overwriting."
  exit 0
fi

cp deploy/env.production.example .env.production
sed -i.bak "s/54-123-45-67/${ELASTIC_IP//./-}/g" .env.production
rm -f .env.production.bak

echo "Created .env.production with APP_DOMAIN=${NIP_DOMAIN}"
echo ""
echo "Fill in these values (generate on your Mac if needed):"
echo "  RAILS_MASTER_KEY          → cat config/master.key"
echo "  DEVISE_JWT_SECRET_KEY     → openssl rand -hex 64"
echo "  ACTIVE_RECORD_ENCRYPTION_* → bin/rails db:encryption:init"
echo "  POSTGRES_PASSWORD         → pick a strong password"
echo ""
echo "Edit: nano .env.production"
