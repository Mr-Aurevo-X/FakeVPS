# Live VPS-envelope telemetry (not host /proc).
# Copyright (c) 2026 Mr-Aurevo-X

fast_cgroup_dir() {
  local id dir
  command -v docker >/dev/null 2>&1 || return 1
  id="$(docker inspect -f '{{.Id}}' "$FAST_NAME" 2>/dev/null || true)"
  [[ -n "$id" ]] || return 1
  dir="/sys/fs/cgroup/system.slice/docker-${id}.scope"
  [[ -r "$dir/memory.current" ]] || return 1
  printf '%s\n' "$dir"
}

read_first_u64() {
  local file="$1"
  local key="${2:-}"
  local val=0
  if [[ -n "$key" ]]; then
    val="$(awk -v k="$key" '$1 == k { print $2; exit }' "$file" 2>/dev/null || true)"
  else
    val="$(tr -d '[:space:]' <"$file" 2>/dev/null || true)"
  fi
  [[ "$val" =~ ^[0-9]+$ ]] || val=0
  printf '%s\n' "$val"
}

node_uptime_sec() {
  local be started
  be="$(active_backend 2>/dev/null || echo "$BACKEND")"
  if [[ "$be" == "fast" ]] && command -v docker >/dev/null 2>&1 && fast_running; then
    started="$(docker inspect -f '{{.State.StartedAt}}' "$FAST_NAME" 2>/dev/null || true)"
    python3 -c 'import sys
from datetime import datetime, timezone
raw = sys.argv[1].strip()
if not raw:
    print(0)
    raise SystemExit
ts = datetime.fromisoformat(raw.replace("Z", "+00:00"))
print(max(int((datetime.now(timezone.utc) - ts).total_seconds()), 0))
' "$started" 2>/dev/null || echo 0
    return
  fi
  guest_ssh "awk '{print int(\$1)}' /proc/uptime" 2>/dev/null || echo 0
}

disk_cache_path() {
  printf '%s\n' "$STATE_DIR/metrics.disk"
}

# Prints: used_gb app_gb docker_gb
read_disk_fields() {
  local cache
  cache="$(disk_cache_path)"
  if [[ -s "$cache" ]]; then
    python3 - "$cache" <<'PY'
from pathlib import Path
import json
import sys

raw = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace").strip()
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    data = None
if isinstance(data, dict):
    app = float(data.get("disk_app_gb") or 0)
    dock = float(data.get("disk_docker_gb") or 0)
    used = float(data.get("disk_used_gb") or 0)
    if used <= 0:
        used = app + dock
    print(f"{used:.1f} {app:.1f} {dock:.1f}")
    raise SystemExit
try:
    used = float(raw)
except ValueError:
    used = 0.0
print(f"{used:.1f} 0.0 0.0")
PY
    return
  fi
  echo "0.0 0.0 0.0"
}

read_disk_used_gb() {
  local used
  read -r used _ _ < <(read_disk_fields)
  printf '%s\n' "${used:-0}"
}

write_disk_cache() {
  local cache="$1"
  local app_b="${2:-0}"
  local dock_b="${3:-0}"
  python3 - "$cache" "$app_b" "$dock_b" <<'PY'
from pathlib import Path
import sys

cache, app_s, dock_s = sys.argv[1], sys.argv[2], sys.argv[3]
try:
    app = int(float(app_s or 0))
except ValueError:
    app = 0
try:
    dock = int(float(dock_s or 0))
except ValueError:
    dock = 0
g = 1024 ** 3
app_gb = round(app / g, 1)
dock_gb = round(dock / g, 1)
Path(cache).write_text(
    '{"disk_app_gb": %s, "disk_docker_gb": %s, "disk_used_gb": %s}\n'
    % (app_gb, dock_gb, round(app_gb + dock_gb, 1)),
    encoding="utf-8",
)
PY
}

du_bytes() {
  local out
  out="$(awk '{print $1; exit}' 2>/dev/null || true)"
  [[ "$out" =~ ^[0-9]+$ ]] || out=0
  printf '%s\n' "$out"
}

refresh_disk_cache_bg() {
  local cache stamp age now
  cache="$(disk_cache_path)"
  stamp="$STATE_DIR/metrics.disk.pid"
  now="$(date +%s)"
  if [[ -s "$cache" ]]; then
    age=$((now - $(stat -c %Y "$cache" 2>/dev/null || echo 0)))
    if (( age < 60 )); then
      return 0
    fi
  fi
  if [[ -f "$stamp" ]] && kill -0 "$(cat "$stamp" 2>/dev/null)" 2>/dev/null; then
    return 0
  fi
  (
    echo $$ >"$stamp"
    local app_b=0 dock_b=0
    if command -v docker >/dev/null 2>&1 && fast_running; then
      dock_b="$(docker exec -u root "$FAST_NAME" du -sb /var/lib/docker 2>/dev/null | du_bytes)"
      app_b="$(docker exec -u root "$FAST_NAME" du -sb /home/ubuntu/app 2>/dev/null | du_bytes)"
    elif guest_ssh true >/dev/null 2>&1; then
      dock_b="$(guest_ssh du -sb /var/lib/docker 2>/dev/null | du_bytes)"
      app_b="$(guest_ssh du -sb /home/ubuntu/app 2>/dev/null | du_bytes)"
    fi
    write_disk_cache "$cache" "$app_b" "$dock_b"
    rm -f "$stamp"
  ) >/dev/null 2>&1 &
}

fast_sidecar_json() {
  docker exec -i "$FAST_NAME" python3 - <<'PY'
import json
import os
import subprocess

containers = 0
try:
    out = subprocess.check_output(["docker", "ps", "-q"], stderr=subprocess.DEVNULL)
    containers = len([row for row in out.split() if row])
except (OSError, subprocess.CalledProcessError):
    pass

rx = tx = 0
for name in ("eth0", "ens3", "enp0s3", "enp0s1"):
    base = f"/sys/class/net/{name}/statistics"
    try:
        rx = int(open(f"{base}/rx_bytes", encoding="utf-8").read())
        tx = int(open(f"{base}/tx_bytes", encoding="utf-8").read())
        break
    except OSError:
        continue
if rx == 0 and tx == 0:
    try:
        for name in sorted(os.listdir("/sys/class/net")):
            if name == "lo" or name.startswith(("br-", "docker", "veth", "virbr")):
                continue
            base = f"/sys/class/net/{name}/statistics"
            try:
                rx = int(open(f"{base}/rx_bytes", encoding="utf-8").read())
                tx = int(open(f"{base}/tx_bytes", encoding="utf-8").read())
                break
            except OSError:
                continue
    except OSError:
        pass

print(json.dumps({"containers": containers, "rx": rx, "tx": tx}))
PY
}

collect_metrics_json() {
  local be cg sidecar="{}" prev="$STATE_DIR/metrics.prev"
  local mem_cur=0 mem_max=0 mem_cache=0 usage=0 pids=0
  be="$(active_backend 2>/dev/null || echo "$BACKEND")"
  refresh_disk_cache_bg
  if [[ "$be" == "fast" ]] && command -v docker >/dev/null 2>&1 && fast_running; then
    cg="$(fast_cgroup_dir || true)"
    if [[ -n "$cg" ]]; then
      mem_cur="$(read_first_u64 "$cg/memory.current")"
      mem_max="$(read_first_u64 "$cg/memory.max")"
      mem_cache="$(read_first_u64 "$cg/memory.stat" inactive_file)"
      usage="$(read_first_u64 "$cg/cpu.stat" usage_usec)"
      pids="$(read_first_u64 "$cg/pids.current")"
    fi
    sidecar="$(fast_sidecar_json 2>/dev/null || true)"
    [[ "$sidecar" == \{* ]] || sidecar="{}"
    local pending=false disk_used=0 disk_app=0 disk_docker=0
    [[ -s "$(disk_cache_path)" ]] || pending=true
    read -r disk_used disk_app disk_docker < <(read_disk_fields)
    python3 "$FAKEVPS_ROOT/lib/metrics.py" --prev "$prev" <<EOF
{"ram_mb": ${RAM_MB}, "cpus": ${CPUS}, "disk_gb": ${DISK_GB},
 "now": $(date +%s.%N),
 "memory_current": ${mem_cur:-0}, "memory_max": ${mem_max:-0},
 "memory_inactive_file": ${mem_cache:-0},
 "usage_usec": ${usage:-0}, "pids": ${pids:-0},
 "disk_used_gb": ${disk_used:-0},
 "disk_app_gb": ${disk_app:-0},
 "disk_docker_gb": ${disk_docker:-0},
 "disk_pending": ${pending},
 "sidecar": ${sidecar}}
EOF
    return
  fi
  if guest_ssh true >/dev/null 2>&1; then
    local guest disk_used=0 disk_app=0 disk_docker=0
    guest="$(guest_metrics 2>/dev/null || echo '{}')"
    read -r disk_used disk_app disk_docker < <(read_disk_fields)
    python3 "$FAKEVPS_ROOT/lib/metrics.py" --prev "$prev" <<EOF
{"mode": "guest", "now": $(date +%s.%N), "guest": ${guest},
 "disk_used_gb": ${disk_used:-0},
 "disk_app_gb": ${disk_app:-0},
 "disk_docker_gb": ${disk_docker:-0},
 "disk_total_gb": ${DISK_GB}}
EOF
    return
  fi
  echo '{}'
}
