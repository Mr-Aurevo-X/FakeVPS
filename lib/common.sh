# Shared FakeVPS helpers. Sourced by ./fakevps — do not execute directly.
# Copyright (c) 2026 Mr-Aurevo-X

FAKEVPS_VERSION="0.1.0"

load_config() {
  RAM_MB=6144
  CPUS=4
  DISK_GB=40
  SSH_PORT=2222
  UI_PORT=8787
  SSH_USER=ubuntu
  BOT_DIR=""
  BOT_RUNTIME=auto
  BOT_PANEL_PORT=""
  BACKEND=kvm

  if [[ -f "$FAKEVPS_ROOT/config.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$FAKEVPS_ROOT/config.env"
    set +a
  fi

  STATE_DIR="$FAKEVPS_ROOT/state"
  SECRETS_DIR="$FAKEVPS_ROOT/secrets"
  SSH_KEY="$SECRETS_DIR/vps_ed25519"
  SSH_PUB="$SECRETS_DIR/vps_ed25519.pub"
  KNOWN_HOSTS="$STATE_DIR/known_hosts"
  LOG_FILE="$STATE_DIR/logs/fakevps.log"
}

reclaim_runtime_dirs() {
  # If this CLI ran as root, give state/secrets back to the repo owner (not root).
  [[ "$(id -u)" -eq 0 ]] || return 0
  local owner grp
  if [[ -n "${SUDO_USER:-}" ]]; then
    owner="$SUDO_USER"
    grp="$SUDO_USER"
  else
    owner="$(stat -c '%U' "$FAKEVPS_ROOT" 2>/dev/null || true)"
    grp="$(stat -c '%G' "$FAKEVPS_ROOT" 2>/dev/null || true)"
  fi
  if [[ -n "$owner" && "$owner" != "root" ]]; then
    chown -R "${owner}:${grp:-$owner}" "$STATE_DIR" "$SECRETS_DIR" 2>/dev/null || true
  fi
}

ensure_dirs() {
  mkdir -p "$STATE_DIR/kvm" "$STATE_DIR/fast" "$STATE_DIR/images" "$STATE_DIR/logs" "$SECRETS_DIR"
  reclaim_runtime_dirs
}

log() {
  local msg
  msg="$(date -Iseconds) $*"
  printf '[fakevps] %s\n' "$*"
  mkdir -p "$(dirname "$LOG_FILE")"
  printf '%s\n' "$msg" >>"$LOG_FILE"
}

die() {
  printf '[fakevps] error: %s\n' "$*" >&2
  exit 1
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "missing command: $1"
}

active_backend() {
  if [[ -f "$STATE_DIR/backend" ]]; then
    cat "$STATE_DIR/backend"
    return
  fi
  printf '%s\n' "$BACKEND"
}

set_backend() {
  printf '%s\n' "$1" >"$STATE_DIR/backend"
}

host_bind_ok() {
  local port="$1"
  ss -ltn 2>/dev/null | grep -E -q "127\\.0\\.0\\.1:${port}([[:space:]]|$)"
}

open_url() {
  local url="$1"
  if command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$url" >/dev/null 2>&1 &
    disown $! 2>/dev/null || true
  elif command -v wslview >/dev/null 2>&1; then
    wslview "$url" >/dev/null 2>&1 &
    disown $! 2>/dev/null || true
  fi
}

write_config_key() {
  local key="$1"
  local value="$2"
  local cfg="$FAKEVPS_ROOT/config.env"
  if [[ ! -f "$cfg" ]]; then
    cp "$FAKEVPS_ROOT/config.env.example" "$cfg"
  fi
  python3 - "$cfg" "$key" "$value" <<'PY'
from pathlib import Path
import sys
path, key, value = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
lines = path.read_text().splitlines()
out, found = [], False
for line in lines:
    if line.startswith(key + "="):
        out.append(f"{key}={value}")
        found = True
    else:
        out.append(line)
if not found:
    out.append(f"{key}={value}")
path.write_text("\n".join(out) + "\n")
PY
}
