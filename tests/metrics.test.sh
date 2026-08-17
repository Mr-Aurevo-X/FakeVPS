#!/usr/bin/env bash
set -euo pipefail
FAKEVPS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export PYTHONPATH="$FAKEVPS_ROOT/lib"

python3 - <<'PY'
import metrics as m

assert m.parse_u64("max", 99) == 99
assert m.parse_u64("6442450944") == 6442450944
assert m.bytes_to_mb(6442450944) == 6144
used, total = m.ram_pair(3221225472, 6442450944, 6144)
assert used == 3072 and total == 6144, (used, total)
# Host leak must not win: missing max falls back to envelope.
used, total = m.ram_pair(16_000 * 1024 * 1024, 0, 6144)
assert total == 6144 and used == 6144, (used, total)
# Docker working set: drop inactive page cache (host file cache on bind mounts).
# Live bug: current ~5.04 GiB, docker stats ~2.98 GiB.
current = 5413789696
inactive = current - 3204445962
assert m.working_set_bytes(current, inactive) == 3204445962
used, total = m.ram_pair(current, 6442450944, 6144, inactive)
assert total == 6144
assert used == m.bytes_to_mb(3204445962)
assert used < 3500, used

pct = m.cpu_percent(1_000_000, 100.0, 1_000_000 + 2_000_000, 102.0, 4)
# 2.0 cpu-sec over 2.0 wall-sec on 4 CPUs = 25%
assert pct == 25.0, pct
assert m.cpu_percent(1, 0, 9, 1, 4) == 0.0

assert m.net_bps(1000, 10.0, 5000, 12.0) == 2000
assert m.net_bps(5000, 10.0, 1000, 12.0) == 0

out, nxt = m.build({
    "ram_mb": 6144,
    "cpus": 4,
    "disk_gb": 40,
    "now": 200.0,
    "memory_current": 5413789696,
    "memory_inactive_file": 5413789696 - 3204445962,
    "memory_max": 6442450944,
    "usage_usec": 3_000_000,
    "disk_used_gb": 12.34,
    "containers": 3,
    "pids": 80,
    "rx": 9000,
    "tx": 3000,
    "prev": {"t": 198.0, "usage_usec": 1_000_000, "rx": 1000, "tx": 1000},
})
assert out["ram_used_mb"] == m.bytes_to_mb(3204445962)
assert out["ram_total_mb"] == 6144
assert out["ram_used_mb"] < 3500
assert out["cpu_pct"] == 25.0
assert out["disk_used_gb"] == 12.3
assert out["disk_total_gb"] == 40.0
assert out["containers"] == 3
assert out["net_rx_bps"] == 4000
assert out["net_tx_bps"] == 1000
assert out["disk_pending"] is False
assert nxt["rx"] == 9000

guest, _ = m.build({
    "mode": "guest",
    "now": 12.0,
    "guest": {
        "ram_used_mb": 1800,
        "ram_total_mb": 6144,
        "load1": 0.4,
        "cpu_pct": 10.0,
        "disk_used_gb": 8.0,
        "disk_total_gb": 40.0,
        "containers": 1,
        "pids": 90,
        "rx": 2000,
        "tx": 500,
    },
    "prev": {"t": 10.0, "rx": 0, "tx": 100},
})
assert guest["ram_total_mb"] == 6144
assert guest["net_rx_bps"] == 1000
assert guest["net_tx_bps"] == 200
print("metrics.py envelope math ok")
PY
