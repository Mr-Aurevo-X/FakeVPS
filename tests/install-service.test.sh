#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
unit="$ROOT/contrib/fakevps.service"

grep -q '@FAKEVPS_ROOT@' "$unit" \
  || { echo "FAIL unit missing @FAKEVPS_ROOT@" >&2; exit 1; }
grep -q '@FAKEVPS_UP_ARGS@' "$unit" \
  || { echo "FAIL unit missing @FAKEVPS_UP_ARGS@" >&2; exit 1; }

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
sed -e "s|@FAKEVPS_ROOT@|/tmp/fakevps|g" \
    -e "s|@FAKEVPS_UP_ARGS@|up --fast|g" \
    "$unit" >"$tmp"
grep -q '/tmp/fakevps/fakevps up --fast' "$tmp" \
  || { echo "FAIL sed did not produce fast ExecStart" >&2; exit 1; }
echo "install-service template ok"
