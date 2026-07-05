#!/usr/bin/env bash
# Phase 3 — bootstrap Ubuntu EC2 for ExpertHub (Docker, git, 2GB swap).
# Run on the server as ubuntu user after SSH:
#   curl -fsSL https://raw.githubusercontent.com/abhimanyu1855/experthub-api/main/deploy/bootstrap-server.sh | bash
# Or from a cloned repo:
#   bash deploy/bootstrap-server.sh
set -euo pipefail

echo "==> apt update & upgrade"
sudo apt update && sudo apt upgrade -y

echo "==> Docker"
if ! command -v docker >/dev/null 2>&1; then
  curl -fsSL https://get.docker.com | sh
  sudo usermod -aG docker "$USER"
fi

echo "==> git"
sudo apt install -y git

echo "==> 2GB swap (critical on t2.micro 1GB RAM)"
if [[ ! -f /swapfile ]]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi

echo "==> Done. Log out and back in (or: newgrp docker) so docker group applies."
echo "Next: clone repos and run deploy/first-boot.sh"
