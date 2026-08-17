#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export FAKEVPS_ROOT="$ROOT"
export PYTHONPATH="$ROOT/lib"

python3 - <<'PY'
import ui_server as u

assert u.parse_host_header("127.0.0.1:8787") == "127.0.0.1"
assert u.parse_host_header("[::1]:8787") == "::1"
assert u.parse_host_header("localhost") == "localhost"
assert u.normalize_client_ip("::ffff:127.0.0.1") == "127.0.0.1"
assert u.loopback_request_ok("127.0.0.1:8787", "127.0.0.1")
assert u.loopback_request_ok("localhost:8787", "127.0.0.1")
assert u.loopback_request_ok("[::1]:8787", "::1")
assert not u.loopback_request_ok("evil.example", "127.0.0.1")
assert not u.loopback_request_ok("127.0.0.1", "8.8.8.8")
assert not u.loopback_request_ok("", "127.0.0.1")
print("cockpit host/bind checks ok")
PY

if grep -n '0.0.0.0' "$ROOT/lib/ui_server.py"; then
  echo "FAIL ui_server mentions 0.0.0.0" >&2
  exit 1
fi
echo "cockpit-bind tests passed"
