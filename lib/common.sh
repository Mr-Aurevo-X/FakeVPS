# Shared FakeVPS helpers. Sourced by ./fakevps — do not execute directly.
# Copyright (c) 2026 Mr-Aurevo-X

FAKEVPS_VERSION="0.2.0"

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
  BACKEND=fast
  EPHEMERAL=false
  AUTO_DEPLOY=true

  if [[ -f "$FAKEVPS_ROOT/config.env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source "$FAKEVPS_ROOT/config.env"
    set +a
  fi

  STATE_DIR="$FAKEVPS_ROOT/state"
  # Profiles: ./fakevps -p <name> overlays profiles/<name>.env and moves all
  # state under state/profiles/<name>, so two nodes never share a disk,
  # a container name, or ports (set distinct ports in the profile).
  if [[ -n "${FAKEVPS_PROFILE:-}" ]]; then
    if [[ ! "$FAKEVPS_PROFILE" =~ ^[A-Za-z0-9_-]+$ ]]; then
      printf 'invalid profile name: %s\n' "$FAKEVPS_PROFILE" >&2
      exit 2
    fi
    if [[ -f "$FAKEVPS_ROOT/profiles/${FAKEVPS_PROFILE}.env" ]]; then
      set -a
      # shellcheck disable=SC1090
      source "$FAKEVPS_ROOT/profiles/${FAKEVPS_PROFILE}.env"
      set +a
    fi
    STATE_DIR="$FAKEVPS_ROOT/state/profiles/$FAKEVPS_PROFILE"
    FAST_NAME="fakevps-$FAKEVPS_PROFILE"
  fi
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
  mkdir -p \
    "$STATE_DIR/kvm" \
    "$STATE_DIR/fast/docker" \
    "$STATE_DIR/fast/containerd" \
    "$STATE_DIR/images" \
    "$STATE_DIR/logs" \
    "$SECRETS_DIR"
  reclaim_runtime_dirs
}

redact_log_text() {
  printf '%s' "$1" | python3 -c '
import os
import sys

text = sys.stdin.read()
home = os.path.expanduser("~")
if home and home not in {"", "/", "~"}:
    text = text.replace(home, "~")
sys.stdout.write(text)
'
}

log() {
  local msg shown
  shown="$(redact_log_text "$*")"
  msg="$(date -Iseconds) ${shown}"
  printf '[fakevps] %s\n' "$shown"
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

is_ephemeral() {
  case "${EPHEMERAL:-false}" in
    true|1|yes|on) return 0 ;;
    *) return 1 ;;
  esac
}

auto_deploy_enabled() {
  case "${AUTO_DEPLOY:-true}" in
    false|0|no|off) return 1 ;;
    *) return 0 ;;
  esac
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

# Basename or ~/… — never a raw personal home path in UI/JSON display.
display_bot_dir() {
  local dir="${1:-}"
  python3 - "$dir" <<'PY'
import os
import sys

path = (sys.argv[1] or "").strip()
if not path:
    print("")
    raise SystemExit
home = os.path.expanduser("~")
expanded = os.path.expanduser(path)
real = os.path.abspath(expanded)
if path == "~" or path.startswith("~/"):
    print(path)
    raise SystemExit
if real == home:
    print("~")
    raise SystemExit
if home and (real.startswith(home + os.sep)):
    print("~/" + real[len(home) + 1 :].replace(os.sep, "/"))
    raise SystemExit
print(os.path.basename(real.rstrip(os.sep)) or real)
PY
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
import shlex
import sys
path, key, value = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
quoted = shlex.quote(value)
lines = path.read_text().splitlines()
out, found = [], False
for line in lines:
    if line.startswith(key + "="):
        out.append(f"{key}={quoted}")
        found = True
    else:
        out.append(line)
if not found:
    out.append(f"{key}={quoted}")
path.write_text("\n".join(out) + "\n")
PY
}
