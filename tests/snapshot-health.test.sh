#!/usr/bin/env bash
# Snapshots (kvm) and the post-deploy healthcheck stay wired.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "FAIL $*" >&2; exit 1; }

"$ROOT/fakevps" --help | grep -q 'snapshot' || fail "help missing snapshot"
grep -q 'cmd_snapshot()' "$ROOT/fakevps" || fail "cmd_snapshot missing"
grep -q 'snapshots need the kvm backend' "$ROOT/fakevps" || fail "fast refusal missing"
grep -q 'qemu-img snapshot -c' "$ROOT/fakevps" || fail "snapshot save missing"
grep -q 'qemu-img snapshot -a' "$ROOT/fakevps" || fail "snapshot restore missing"

# Without a disk (or without qemu-img on this machine) the command must
# fail with a clear message, not crash.
if out="$("$ROOT/fakevps" snapshot list 2>&1)"; then
  # A disk may exist on a dev machine; then listing must work.
  :
else
  printf '%s\n' "$out" | grep -qiE 'no node disk|kvm backend|qemu-img' \
    || fail "snapshot list bad error: $out"
fi

# Healthcheck: present, gating, with journal output on failure.
grep -q 'healthcheck()' "$ROOT/provision/02-bot.sh" || fail "healthcheck missing"
grep -q 'healthcheck || exit 1' "$ROOT/provision/02-bot.sh" || fail "healthcheck does not gate the deploy"
grep -q 'journalctl -u discord-bot -n 25' "$ROOT/provision/02-bot.sh" || fail "healthcheck has no journal tail"
grep -q 'bot_process_up' "$ROOT/provision/02-bot.sh" || fail "bot_process_up missing"

echo "snapshot-health tests passed"
