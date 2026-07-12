#!/usr/bin/env bash
# Convert Elastic IP to nip.io APP_DOMAIN. Example: 54.123.45.67 → 54-123-45-67.nip.io
set -euo pipefail
if [[ $# -lt 1 ]]; then
  echo "Usage: $0 ELASTIC_IP" >&2
  echo "Example: $0 54.123.45.67" >&2
  exit 1
fi
echo "${1//./-}.nip.io"
