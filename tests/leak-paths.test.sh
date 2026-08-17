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

echo "leak-paths / no curl|bash ok"
