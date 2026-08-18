#!/usr/bin/env bash
# Opt-in guest web panel: fakevps.bot.yml panel.start + BOT_PANEL_PORT.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "FAIL $*" >&2; exit 1; }

for f in "$ROOT/fakevps" "$ROOT"/lib/*.sh "$ROOT"/provision/*.sh; do
  bash -n "$f" || fail "syntax error in $f"
done
bash -n "$0" || fail "syntax error in $0"

BOT="$ROOT/provision/02-bot.sh"

# Wiring: no new CLI — attach/provision/restart-bot grow the existing unit.
grep -qE 'BOT_PANEL_PORT=.+02-bot\.sh' "$ROOT/lib/provision.sh" \
  || fail "provision_bot does not pass BOT_PANEL_PORT to 02-bot.sh"
grep -q 'bot-panel.service' "$BOT" \
  || fail "02-bot.sh does not install bot-panel.service"
grep -q 'yaml_get panel.start' "$BOT" \
  || fail "02-bot.sh does not read panel.start from the manifest"
grep -q 'Restart=on-failure' "$BOT" \
  || fail "02-bot.sh panel unit is not Restart=on-failure"
grep -q 'systemctl restart bot-panel.service' "$BOT" \
  || fail "02-bot.sh does not restart an already-active panel unit"
grep -q "trap 'panel_wanted || maybe_install_panel" "$BOT" \
  || fail "02-bot.sh does not clean leftover panel units on early exit"
grep -q 'journalctl -u bot-panel' "$BOT" \
  || fail "02-bot.sh healthcheck does not tail bot-panel on failure"
grep -q 'bot-panel.service' "$ROOT/fakevps" \
  || fail "restart-bot does not mention bot-panel.service"
# The old body exited right after the bot unit, so the panel never restarted.
python3 - "$ROOT/fakevps" <<'PY' || fail "restart-bot still exits before bot-panel can restart"
import pathlib
import sys
text = pathlib.Path(sys.argv[1]).read_text(encoding="utf-8")
start = text.find("cmd_restart_bot()")
if start < 0:
    sys.exit(1)
chunk = text[start:start + 1800]
bot = chunk.find("restart discord-bot.service")
panel = chunk.find("bot-panel.service")
early = chunk.find("exit 0")
if bot < 0 or panel < 0:
    sys.exit(1)
# The first exit 0 in the function must come after the panel restart mention.
if early < 0 or early < panel:
    sys.exit(1)
# Compose fallback must remain after the panel restart (panel-only systemd
# must not skip a Compose bot).
if chunk.find("docker compose") < panel:
    sys.exit(1)
sys.exit(0)
PY

# Extract helpers without running the guest deploy script.
# Do not sed-range the one-line log() — it would swallow the next `}` and
# execute the top-level `[[ ! -d $APP ]]` guard from 02-bot.sh.
log() { printf '[bot] %s\n' "$*"; }
# shellcheck disable=SC1090
source <(sed -n \
  -e '/^yaml_nested_get()/,/^}$/p' \
  -e '/^yaml_get()/,/^}$/p' \
  -e '/^panel_wanted()/,/^}$/p' \
  -e '/^write_panel_unit()/,/^}$/p' \
  -e '/^maybe_install_panel()/,/^}$/p' \
  "$BOT")

type yaml_get >/dev/null 2>&1 || fail "yaml_get not extractable from 02-bot.sh"
type panel_wanted >/dev/null 2>&1 || fail "panel_wanted not extractable from 02-bot.sh"
type write_panel_unit >/dev/null 2>&1 || fail "write_panel_unit not extractable from 02-bot.sh"
type maybe_install_panel >/dev/null 2>&1 || fail "maybe_install_panel not extractable from 02-bot.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
APP="$tmp"
export APP
export SYSTEMD_UNIT_DIR="$tmp/units"
export SYSTEMD_SKIP_CTL=1
mkdir -p "$SYSTEMD_UNIT_DIR"

# Manifest with nested panel.start
cat >"$tmp/fakevps.bot.yml" <<'YML'
runtime: node
panel:
  start: pnpm --filter @scope/dashboard start
YML

got="$(yaml_get panel.start || true)"
[[ "$got" == "pnpm --filter @scope/dashboard start" ]] \
  || fail "yaml_get panel.start got '$got'"
[[ "$(yaml_get runtime)" == "node" ]] || fail "yaml_get runtime broken after nested support"

BOT_PANEL_PORT=3000 panel_wanted || fail "panel_wanted false with port + panel.start"

# Rendered unit
BOT_PANEL_PORT=3000 maybe_install_panel \
  || fail "maybe_install_panel failed with port + panel.start"
unit="$SYSTEMD_UNIT_DIR/bot-panel.service"
[[ -f "$unit" ]] || fail "bot-panel.service was not written"
grep -q 'WorkingDirectory=/home/ubuntu/app\|WorkingDirectory='"$tmp" "$unit" \
  || fail "unit missing WorkingDirectory"
grep -q 'Restart=on-failure' "$unit" || fail "unit missing Restart=on-failure"
grep -q 'Environment=PORT=3000' "$unit" || fail "unit missing PORT=3000"
grep -q 'pnpm --filter @scope/dashboard start' "$unit" \
  || fail "unit ExecStart missing panel.start"
grep -q 'User=ubuntu' "$unit" || fail "unit missing User=ubuntu"
# Generic: never bake a product name into the unit.
if grep -qiE 'sentinel' "$unit"; then
  fail "unit hardcodes Sentinel"
fi

# BOT_PANEL_PORT empty → do not install (and drop a leftover unit)
BOT_PANEL_PORT='' maybe_install_panel \
  || fail "maybe_install_panel failed with empty port"
[[ ! -f "$unit" ]] || fail "empty BOT_PANEL_PORT still left bot-panel.service"

# Manifest without panel.start → do not install
cat >"$tmp/fakevps.bot.yml" <<'YML'
runtime: node
YML
BOT_PANEL_PORT=3000 panel_wanted && fail "panel_wanted true without panel.start"
BOT_PANEL_PORT=3000 maybe_install_panel \
  || fail "maybe_install_panel failed without panel.start"
[[ ! -f "$unit" ]] || fail "manifest without panel.start still wrote bot-panel.service"

# Invalid port is treated as unset
cat >"$tmp/fakevps.bot.yml" <<'YML'
runtime: node
panel:
  start: npm run panel
YML
BOT_PANEL_PORT=notaport panel_wanted && fail "panel_wanted true for non-numeric port"
BOT_PANEL_PORT=notaport maybe_install_panel \
  || fail "maybe_install_panel failed for invalid port"
[[ ! -f "$unit" ]] || fail "invalid BOT_PANEL_PORT wrote a unit"

echo "bot-panel tests passed"
