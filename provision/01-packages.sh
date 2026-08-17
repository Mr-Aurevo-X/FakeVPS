#!/usr/bin/env bash
# First-boot guest packages: Docker, swap, firewall.
# Copyright (c) 2026 Mr-Aurevo-X
set -euo pipefail

log() { printf '[guest] %s\n' "$*"; }

if ! command -v docker >/dev/null 2>&1; then
  log "installing Docker"
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker ubuntu 2>/dev/null || true
fi

# Nested overlayfs (Docker-in-Docker on overlay) fails whiteouts
# (hsperfdata_root/.wh.*). Pick a graph driver that matches the backing FS.
mkdir -p /etc/docker
backing="$(findmnt -n -o FSTYPE /var/lib/docker 2>/dev/null || findmnt -n -o FSTYPE / || true)"
driver="vfs"
case "$backing" in
  ext4|xfs) driver="overlay2" ;;
  btrfs) driver="btrfs" ;;
  overlay|overlay2)
    if command -v fuse-overlayfs >/dev/null 2>&1; then
      driver="fuse-overlayfs"
    else
      driver="vfs"
    fi
    ;;
esac
log "docker storage-driver=$driver (backing=$backing)"
printf '%s\n' "{\"storage-driver\":\"${driver}\",\"features\":{\"containerd-snapshotter\":false}}" >/etc/docker/daemon.json
systemctl enable docker >/dev/null 2>&1 || true
systemctl restart docker >/dev/null 2>&1 || systemctl start docker >/dev/null 2>&1 || true

if [[ ! -f /swapfile ]]; then
  log "creating 2G swap"
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  if swapon /swapfile; then
    grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >>/etc/fstab
  else
    log "swap skipped (not available in this node)"
    rm -f /swapfile
  fi
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
