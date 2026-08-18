#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

help_out="$("$ROOT/fakevps" --help)"
printf '%s\n' "$help_out" | grep -q 'Copyright (c) 2026 Mr-Aurevo-X' \
  || { echo "FAIL help missing copyright" >&2; exit 1; }
printf '%s\n' "$help_out" | grep -q 'https://github.com/Mr-Aurevo-X/FakeVPS' \
  || { echo "FAIL help missing origin URL" >&2; exit 1; }
printf '%s\n' "$help_out" | grep -q 'restart-bot' \
  || { echo "FAIL help missing restart-bot" >&2; exit 1; }
grep -q 'ui_stop' "$ROOT/fakevps" \
  || { echo "FAIL down must stop the cockpit" >&2; exit 1; }
grep -q "pgrep -f 'lib/ui_server.py'" "$ROOT/lib/ui-server.sh" \
  || { echo "FAIL ui_stop must reap leftover cockpits" >&2; exit 1; }

for f in LICENSE README.md SECURITY.md CONTRIBUTING.md ui/index.html; do
  grep -q 'https://github.com/Mr-Aurevo-X/FakeVPS' "$ROOT/$f" \
    || { echo "FAIL $f missing origin URL" >&2; exit 1; }
done
grep -q 'Google Fonts\|fonts.googleapis.com\|fonts.gstatic.com' "$ROOT/ui/index.html" \
  && { echo "FAIL index.html still phones home for fonts" >&2; exit 1; }
grep -q 'aucune collecte' "$ROOT/ui/index.html" \
  || { echo "FAIL footer missing privacy line" >&2; exit 1; }
grep -q 'Public snapshot' "$ROOT/README.md" \
  || { echo "FAIL README missing public snapshot" >&2; exit 1; }
grep -q 'your own GitHub' "$ROOT/README.md" \
  || { echo "FAIL README missing fork-your-own-repo" >&2; exit 1; }
if grep -q 'This repository is \*\*private\*\*' "$ROOT/CONTRIBUTING.md"; then
  echo "FAIL CONTRIBUTING still calls the repo private" >&2
  exit 1
fi
if grep -q 'private for now' "$ROOT/SECURITY.md"; then
  echo "FAIL SECURITY still says private for now" >&2
  exit 1
fi
if grep -qE '\*\*Required:\*\*|\*\*Obligatoire' "$ROOT/README.md"; then
  echo "FAIL README still treats attribution as required" >&2
  exit 1
fi
if grep -qE 'You must keep|Every copy or fork MUST' "$ROOT/LICENSE"; then
  echo "FAIL LICENSE still treats attribution as required" >&2
  exit 1
fi
grep -q 'requested, not required' "$ROOT/LICENSE" \
  || { echo "FAIL LICENSE missing requested-not-required" >&2; exit 1; }
echo "usage/credit/origin tests passed"
