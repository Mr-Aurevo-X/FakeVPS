#!/usr/bin/env bash
# First-boot guest packages: Docker, swap, firewall.
set -euo pipefail

log() { printf '[guest] %s\n' "$*"; }

if ! command -v docker >/dev/null 2>&1; then
  log "installing Docker"
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker ubuntu 2>/dev/null || true
fi

if [[ ! -f /swapfile ]]; then
  log "creating 2G swap"
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
fi

if command -v ufw >/dev/null 2>&1; then
  ufw --force reset >/dev/null || true
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 22/tcp
  if [[ -n "${BOT_PANEL_PORT:-}" ]]; then
    ufw allow "${BOT_PANEL_PORT}/tcp"
  fi
  ufw --force enable >/dev/null || true
fi

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq git jq ca-certificates curl >/dev/null
log "packages ready"
