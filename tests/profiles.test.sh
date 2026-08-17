#!/usr/bin/env bash
# Profiles: own overlay, own state dir, own container name, safe names.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "FAIL $*" >&2; exit 1; }

cleanup() {
  rm -f "$ROOT/profiles/citest.env"
  rm -rf "$ROOT/state/profiles/citest"
}
trap cleanup EXIT

mkdir -p "$ROOT/profiles"
printf 'SSH_PORT=2999\nUI_PORT=8899\n' >"$ROOT/profiles/citest.env"

# The overlay applies and the profile gets its own state tree.
out="$("$ROOT/fakevps" -p citest status --json)"
printf '%s\n' "$out" | grep -q '"ssh_port": 2999' || fail "profile overlay not applied: $out"
[[ -d "$ROOT/state/profiles/citest" ]] || fail "profile state dir not created"

# Default run is untouched by the profile.
out="$("$ROOT/fakevps" status --json)"
printf '%s\n' "$out" | grep -q '"ssh_port": 2999' && fail "profile leaked into default config"

# Bad profile names are refused (they become paths and container names).
if "$ROOT/fakevps" -p 'bad/name' status >/dev/null 2>&1; then
  fail "slash in profile name accepted"
fi

# Static wiring.
grep -q 'FAST_NAME="fakevps-\$FAKEVPS_PROFILE"' "$ROOT/lib/common.sh" || fail "fast container name not per-profile"
grep -q 'FAKEVPS_STATE_DIR' "$ROOT/lib/ui-server.sh" || fail "cockpit not profile-aware"
grep -q 'FAKEVPS_STATE_DIR' "$ROOT/lib/ui_server.py" || fail "ui_server ignores FAKEVPS_STATE_DIR"
[[ -f "$ROOT/profiles/example.env.example" ]] || fail "profiles/example.env.example missing"
grep -q 'boot-fast:' "$ROOT/.github/workflows/checks.yml" || fail "CI boot job missing"

echo "profiles tests passed"
