#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if git grep -nE '/home/[^/]+/Documents/(FakeVPS|TestFakeVPS)' -- .; then
  echo "FAIL personal Documents path in tracked files" >&2
  exit 1
fi

if grep -R -nE 'curl .+\|[[:space:]]*(ba)?sh' provision/; then
  echo "FAIL provision still pipes curl into a shell" >&2
  exit 1
fi
grep -q 'sha256sum -c' provision/02-bot.sh \
  || { echo "FAIL Node install must verify sha256" >&2; exit 1; }
grep -q 'NODE_DIST_VER=22.23.2' provision/02-bot.sh \
  || { echo "FAIL expected Node 22.23.2 pin" >&2; exit 1; }

echo "leak-paths / no curl|bash ok"
