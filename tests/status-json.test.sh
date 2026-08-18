#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# Do not print the JSON (may contain a host bot path). Check keys only.
tmp="$(mktemp)"
metrics="$(mktemp)"
trap 'rm -f "$tmp" "$metrics"' EXIT
if ! "$ROOT/fakevps" status --json >"$tmp"; then
  echo "FAIL fakevps status --json exited non-zero" >&2
  exit 1
fi
python3 - "$tmp" <<'PY'
import json
import sys
from pathlib import Path

raw = Path(sys.argv[1]).read_text(encoding="utf-8")
data = json.loads(raw)
blob = json.dumps(data)
if "DISCORD_TOKEN" in blob:
    raise SystemExit("FAIL status JSON leaked DISCORD_TOKEN")
for key in ("services", "token_present", "runtime", "bot_dir_display", "bot_attached"):
    if key not in data:
        raise SystemExit(f"FAIL missing {key}")
if "bot_dir" in data:
    raise SystemExit("FAIL status JSON must not include raw bot_dir")
if not isinstance(data["services"], list):
    raise SystemExit("FAIL services must be a list")
if not isinstance(data["token_present"], bool):
    raise SystemExit("FAIL token_present must be a bool")
if not isinstance(data["bot_attached"], bool):
    raise SystemExit("FAIL bot_attached must be a bool")
if "disk_host_backed" not in data:
    raise SystemExit("FAIL missing disk_host_backed")
if not isinstance(data["disk_host_backed"], bool):
    raise SystemExit("FAIL disk_host_backed must be a bool")
if "disk_envelope_gb" not in data:
    raise SystemExit("FAIL missing disk_envelope_gb")
if not isinstance(data["disk_envelope_gb"], int):
    raise SystemExit("FAIL disk_envelope_gb must be an int")
shown = str(data.get("bot_dir_display") or "")
if shown.startswith("/home/") or shown.startswith("/Users/"):
    raise SystemExit("FAIL bot_dir_display looks like a raw home path")
print("status --json fields ok")
PY

if ! "$ROOT/fakevps" metrics >"$metrics"; then
  echo "FAIL fakevps metrics exited non-zero" >&2
  exit 1
fi
python3 - "$metrics" <<'PY'
import json
import sys
from pathlib import Path

data = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8") or "{}")
if not isinstance(data, dict):
    raise SystemExit("FAIL metrics must be a JSON object")
if "DISCORD_TOKEN" in json.dumps(data):
    raise SystemExit("FAIL metrics leaked DISCORD_TOKEN")
print("metrics json ok")
PY
