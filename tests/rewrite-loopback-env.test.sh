#!/usr/bin/env bash
# Loopback DATABASE_URL/REDIS_URL → compose service names (guest inject).
set -euo pipefail
export PYTHONDONTWRITEBYTECODE=1
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PY="$ROOT/lib/rewrite_loopback_env.py"

fail() { echo "FAIL $*" >&2; exit 1; }

[[ -f "$PY" ]] || fail "rewrite_loopback_env.py missing"
python3 -m py_compile "$PY" || fail "rewrite_loopback_env.py does not compile"
grep -q 'rewrite_injected_loopback_env' "$ROOT/lib/ssh.sh" \
  || fail "ssh.sh does not call rewrite_injected_loopback_env"
grep -q 'rewrite_injected_loopback_env "\$tmp"' "$ROOT/lib/ssh.sh" \
  || fail "inject_bot_env does not rewrite the temp env before scp"
grep -q '^Path(dest).write_text' "$ROOT/lib/ssh.sh" \
  || fail "inject python write_text is indented (env file would not always be written)"
grep -q 'ensure_fast_guest_docker_cidr' "$ROOT/lib/ssh.sh" \
  || fail "ssh.sh does not move guest docker0 off 172.16/12 before joining"
grep -q '10.255.0.1/24' "$ROOT/provision/01-packages.sh" \
  || fail "01-packages.sh does not pin guest docker BIP away from host compose"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cat >"$tmp/inspect.json" <<'JSON'
[
  {
    "Name": "/sentinel-postgres",
    "NetworkSettings": {
      "Networks": {
        "bridge": {},
        "testbotlocal_default": {}
      },
      "Ports": {
        "5432/tcp": [{"HostIp": "127.0.0.1", "HostPort": "5433"}]
      }
    }
  },
  {
    "Name": "/sentinel-redis",
    "NetworkSettings": {
      "Networks": {"testbotlocal_default": {}},
      "Ports": {
        "6379/tcp": [{"HostIp": "127.0.0.1", "HostPort": "6379"}]
      }
    }
  },
  {
    "Name": "/sentinel-lavalink",
    "NetworkSettings": {
      "Networks": {"testbotlocal_default": {}},
      "Ports": {
        "2333/tcp": [{"HostIp": "127.0.0.1", "HostPort": "2333"}]
      }
    }
  }
]
JSON

printf '%s\n' \
  'DATABASE_URL=postgresql://user:pass@localhost:5433/sentinel' \
  'REDIS_URL=redis://127.0.0.1:6379' \
  'LAVALINK_HOST=127.0.0.1' \
  'LAVALINK_PORT=2333' \
  'KEEP=ok' >"$tmp/env"

report="$(python3 "$PY" --apply "$tmp/env" --inspect-json "$tmp/inspect.json")"
printf '%s\n' "$report" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["rewritten"] == ["DATABASE_URL", "REDIS_URL", "LAVALINK_HOST"], r
assert r["networks"] == ["testbotlocal_default"], r
assert r["unresolved"] == [], r
'
grep -q 'DATABASE_URL=postgresql://user:pass@sentinel-postgres:5432/sentinel?connect_timeout=5' "$tmp/env" \
  || fail "DATABASE_URL not rewritten to compose service ($(cat "$tmp/env"))"
grep -q 'REDIS_URL=redis://sentinel-redis:6379' "$tmp/env" \
  || fail "REDIS_URL not rewritten"
grep -q 'LAVALINK_HOST=sentinel-lavalink' "$tmp/env" \
  || fail "LAVALINK_HOST not rewritten"
grep -q 'KEEP=ok' "$tmp/env" || fail "unrelated key dropped"
if grep -q '@localhost' "$tmp/env"; then
  fail "loopback host left in rewritten env"
fi

# Host file is left alone when there is nothing to map.
printf 'DATABASE_URL=postgresql://user:pass@db.example:5432/app\n' >"$tmp/remote"
report="$(python3 "$PY" --apply "$tmp/remote" --inspect-json "$tmp/inspect.json")"
printf '%s\n' "$report" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["rewritten"] == []
assert r["loopback"] == []
'
grep -q 'db.example:5432' "$tmp/remote" || fail "non-loopback URL was rewritten"

# Unresolved loopback stays, and is reported (no publisher for 6543).
printf 'DATABASE_URL=postgresql://user:pass@localhost:6543/sentinel\n' >"$tmp/miss"
report="$(python3 "$PY" --apply "$tmp/miss" --inspect-json "$tmp/inspect.json")"
printf '%s\n' "$report" | python3 -c '
import json, sys
r = json.load(sys.stdin)
assert r["rewritten"] == []
assert r["unresolved"] == ["DATABASE_URL"]
'
grep -q '@localhost:6543' "$tmp/miss" || fail "unresolved URL was mutated"

# Report JSON never includes credential values.
if printf '%s\n' "$report" | grep -q 'pass'; then
  fail "rewrite report leaked a credential"
fi

python3 -c '
import json, sys
from pathlib import Path
sys.path.insert(0, "'"$ROOT"'/lib")
from rewrite_loopback_env import publishers_from_inspect
payload = json.loads(Path("'"$tmp"'/inspect.json").read_text())
pubs = publishers_from_inspect(payload)
assert pubs[5433].name == "sentinel-postgres"
assert pubs[5433].container_port == 5432
assert pubs[5433].network == "testbotlocal_default"
'

echo "rewrite-loopback-env tests passed"
