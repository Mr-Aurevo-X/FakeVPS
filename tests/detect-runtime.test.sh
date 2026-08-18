#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DET="$ROOT/provision/detect-runtime.sh"

expect() {
  local dir="$1" want="$2"
  local got
  got="$("$DET" "$dir")"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL $dir: got $got want $want" >&2
    exit 1
  fi
  echo "ok $dir -> $got"
}

expect "$ROOT/tests/fixtures/node-bot" node
expect "$ROOT/tests/fixtures/compose-bot" compose
expect "$ROOT/tests/fixtures/manifest-node" node
expect "$ROOT/examples" none
echo "detect-runtime tests passed"
