#!/usr/bin/env bash
# Phase 5 — verify deployment health and print tester URLs.
# Usage: ./deploy/verify.sh 54.123.45.67
set -euo pipefail

ELASTIC_IP="${1:-}"
if [[ -z "$ELASTIC_IP" ]]; then
  echo "Usage: $0 ELASTIC_IP" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NIP_DOMAIN=$("$SCRIPT_DIR/nip-domain.sh" "$ELASTIC_IP")

echo "==> Health check (via nginx → Rails /up)"
if curl -sf "http://${ELASTIC_IP}/up" | head -c 200; then
  echo ""
  echo "OK: /up responded"
else
  echo "FAIL: curl http://${ELASTIC_IP}/up did not succeed" >&2
  exit 1
fi

echo ""
echo "==> Tester URLs (always use nip.io hostnames, not raw IP)"
cat <<EOF

| Purpose                      | URL |
|------------------------------|-----|
| Create marketplace (admin)   | http://${NIP_DOMAIN}/signup |
| SOS My Doctor — browse       | http://sosmydoctor.${NIP_DOMAIN}/explore |
| SOS My Doctor — admin login  | http://sosmydoctor.${NIP_DOMAIN}/login/expert |
| SOS My Doctor — client login | http://sosmydoctor.${NIP_DOMAIN}/login/customer |
| Fitness Zone — browse        | http://fitnesszone.${NIP_DOMAIN}/explore |

Demo credentials:
  Admin:  admin@sosmydoctor.com / Demo1234!
  Client: patient@example.com / Demo1234!

EOF
