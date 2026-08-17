#!/usr/bin/env bash
# Deploy guards: compose env preflight, DATABASE_URL gate, monorepo build,
# no systemd unit on failed build, ephemeral wipe, cockpit folder picker.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "FAIL $*" >&2; exit 1; }

for f in "$ROOT/fakevps" "$ROOT"/lib/*.sh "$ROOT"/provision/*.sh; do
  bash -n "$f" || fail "syntax error in $f"
done

BOT="$ROOT/provision/02-bot.sh"
grep -q 'compose_env_preflight' "$BOT" || fail "02-bot.sh lacks compose env preflight"
grep -q 'missing_compose_env' "$BOT" || fail "02-bot.sh lacks missing_compose_env"
grep -q 'DATABASE_URL missing from .env' "$BOT" || fail "02-bot.sh lacks DATABASE_URL gate"
grep -q 'build:ci' "$BOT" || fail "02-bot.sh does not prefer root build:ci"
grep -q 'service NOT installed' "$BOT" || fail "02-bot.sh installs the unit even on failed build"
if grep -qE 'pnpm --filter "\./apps/bot\.\.\." build \|\| true' "$BOT"; then
  fail "02-bot.sh still swallows build failures with || true"
fi

# missing_compose_env: required vars without defaults, absent from .env.
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cat >"$tmp/docker-compose.yml" <<'YML'
services:
  app:
    environment:
      FOO: ${FOO}
      BAR: ${BAR:-fallback}
      BAZ: ${BAZ:?required}
YML
printf 'FOO=1\nEMPTY=\n' >"$tmp/.env"
# shellcheck disable=SC1090
source <(sed -n '/^missing_compose_env()/,/^}$/p' "$BOT")
# shellcheck disable=SC2034  # read by missing_compose_env
APP="$tmp"
out="$(missing_compose_env docker-compose.yml)"
[[ "$out" == "BAZ" ]] || fail "missing_compose_env returned '$out' (expected BAZ)"

# Ephemeral mode wiring.
grep -q -- '--wipe' "$ROOT/fakevps" || fail "fakevps down lacks --wipe"
grep -q 'wipe_state' "$ROOT/fakevps" || fail "fakevps lacks wipe_state"
grep -q 'is_ephemeral' "$ROOT/lib/common.sh" || fail "common.sh lacks is_ephemeral"
grep -q '^EPHEMERAL=false' "$ROOT/config.env.example" || fail "config.env.example lacks EPHEMERAL"
grep -q '"ephemeral"' "$ROOT/fakevps" || fail "status_json does not expose ephemeral"

# Cockpit folder picker.
grep -q '/api/browse' "$ROOT/lib/ui_server.py" || fail "ui_server.py lacks /api/browse"
grep -q 'safe_browse_path' "$ROOT/lib/ui_server.py" || fail "ui_server.py lacks safe_browse_path"
grep -q 'btn-browse' "$ROOT/ui/index.html" || fail "index.html lacks the browse button"
grep -q 'loadBrowse' "$ROOT/ui/app.js" || fail "app.js lacks the browse logic"

echo "deploy-guards tests passed"
