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

for f in LICENSE README.md SECURITY.md CONTRIBUTING.md ui/index.html; do
  grep -q 'https://github.com/Mr-Aurevo-X/FakeVPS' "$ROOT/$f" \
    || { echo "FAIL $f missing origin URL" >&2; exit 1; }
done
grep -q 'Google Fonts\|fonts.googleapis.com\|fonts.gstatic.com' "$ROOT/ui/index.html" \
  && { echo "FAIL index.html still phones home for fonts" >&2; exit 1; }
grep -q 'aucune collecte' "$ROOT/ui/index.html" \
  || { echo "FAIL footer missing privacy line" >&2; exit 1; }
echo "usage/credit/origin tests passed"
