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

# AUTO_DEPLOY=false must keep `up` from starting the bot on its own.
grep -q 'auto_deploy_enabled' "$ROOT/lib/common.sh" || fail "common.sh lacks auto_deploy_enabled"
grep -qc 'auto_deploy_enabled' "$ROOT/lib/provision.sh" >/dev/null || fail "provision.sh does not gate on AUTO_DEPLOY"
grep -q '^AUTO_DEPLOY=true' "$ROOT/config.env.example" || fail "config.env.example lacks AUTO_DEPLOY"
# shellcheck disable=SC1090
source <(sed -n '/^auto_deploy_enabled()/,/^}$/p' "$ROOT/lib/common.sh")
if AUTO_DEPLOY=false auto_deploy_enabled; then
  fail "auto_deploy_enabled true despite AUTO_DEPLOY=false"
fi
AUTO_DEPLOY=true auto_deploy_enabled || fail "auto_deploy_enabled false despite AUTO_DEPLOY=true"

# Compose → Node fallback is opt-in via fakevps.bot.yml (`fallback: node`).
grep -q 'yaml_get fallback' "$BOT" || fail "02-bot.sh does not read fallback from the manifest"
grep -q 'add fallback: node' "$BOT" || fail "02-bot.sh lacks the fallback: node hint"
if grep -q 'trying infra compose + Node' "$BOT"; then
  grep -B 25 'trying infra compose + Node' "$BOT" | grep -q 'fallback_node' \
    || fail "infra compose + Node fallback is not gated on fallback: node"
fi
# Silent auto-start of Node after a compose-without-bot must not remain unconditional.
if grep -n 'compose has no bot process — starting Node service' "$BOT" >/dev/null; then
  grep -B 20 'compose has no bot process — starting Node service' "$BOT" | grep -q 'fallback_node' \
    || fail "Node after compose is still unconditional"
fi

grep -q 'docker builder prune -af' "$BOT" || fail "02-bot.sh does not prune the build cache after deploy"
grep -q 'docker image prune -f' "$BOT" || fail "02-bot.sh does not prune dangling images after deploy"

# Cockpit folder picker.
grep -q '/api/browse' "$ROOT/lib/ui_server.py" || fail "ui_server.py lacks /api/browse"
grep -q 'safe_browse_path' "$ROOT/lib/ui_server.py" || fail "ui_server.py lacks safe_browse_path"
grep -q 'btn-browse' "$ROOT/ui/index.html" || fail "index.html lacks the browse button"
grep -q 'loadBrowse' "$ROOT/ui/app.js" || fail "app.js lacks the browse logic"
grep -q 'diag.disk-full.t' "$ROOT/ui/app.js" || fail "app.js lacks the disk-full diagnostic"
grep -q '^BACKEND=fast' "$ROOT/config.env.example" || fail "config.env.example default BACKEND is not fast"
grep -q 'BACKEND=fast' "$ROOT/lib/common.sh" || fail "common.sh default BACKEND is not fast"
grep -q 'banner.fast' "$ROOT/ui/app.js" || fail "app.js lacks the fast-mode banner"
grep -q 'id="fast-banner"' "$ROOT/ui/index.html" || fail "index.html lacks the fast-mode banner"
grep -q 'tests/fixtures/node-bot' "$ROOT/.github/workflows/checks.yml" || fail "CI boot-fast does not attach the node-bot fixture"
grep -q '1.0 final' "$ROOT/CONTRIBUTING.md" || fail "CONTRIBUTING.md missing the 1.0 final"
grep -q '0.3 freeze' "$ROOT/CONTRIBUTING.md" || fail "CONTRIBUTING.md missing the 0.3 freeze history"
grep -q 'rewrite_injected_loopback_env' "$ROOT/lib/ssh.sh" \
  || fail "ssh.sh does not rewrite loopback URLs on inject"
grep -q 'rewrite_loopback_env.py' "$ROOT/lib/ssh.sh" \
  || fail "ssh.sh does not call rewrite_loopback_env.py"

echo "deploy-guards tests passed"
