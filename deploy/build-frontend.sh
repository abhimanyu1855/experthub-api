#!/usr/bin/env bash
# Phase 4 — build React frontend with nip.io env vars baked in.
# Usage: ./deploy/build-frontend.sh 54.123.45.67
# Run from experthub-web repo root (or pass WEB_DIR).
set -euo pipefail

ELASTIC_IP="${1:-}"
WEB_DIR="${WEB_DIR:-$(cd "$(dirname "$0")/../../experthub-web" 2>/dev/null && pwd || echo "")}"

if [[ -z "$ELASTIC_IP" ]]; then
  echo "Usage: $0 ELASTIC_IP" >&2
  echo "Example: $0 54.123.45.67" >&2
  exit 1
fi

if [[ -z "$WEB_DIR" || ! -d "$WEB_DIR" ]]; then
  echo "experthub-web not found. Clone it as a sibling of experthub-api, or set WEB_DIR." >&2
  exit 1
fi

NIP_DOMAIN=$(bash "$(dirname "$0")/nip-domain.sh" "$ELASTIC_IP")
BASE_URL="http://${NIP_DOMAIN}"

echo "==> Building frontend for ${NIP_DOMAIN}"
cd "$WEB_DIR"
export VITE_API_URL="${BASE_URL}"
export VITE_APP_DOMAIN="${NIP_DOMAIN}"
export VITE_CABLE_URL="ws://${NIP_DOMAIN}/cable"

if [[ -f package-lock.json ]]; then
  npm ci
else
  npm install
fi
npm run build

echo "==> dist/ ready at ${WEB_DIR}/dist"
echo "nginx will mount ../experthub-web/dist from experthub-api docker-compose.prod.yml"
