#!/usr/bin/env python3
"""Envelope telemetry for FakeVPS (VPS limits, not the host).

Copyright (c) 2026 Mr-Aurevo-X
"""

from __future__ import annotations

import json
import sys
from typing import Any


def parse_u64(text: object, default: int = 0) -> int:
    raw = str(text if text is not None else "").strip()
    if not raw or raw == "max":
        return default
    try:
        return int(raw, 10)
    except ValueError:
        return default


def bytes_to_mb(n: int) -> int:
    return max(int(n) // (1024 * 1024), 0)


def cpu_percent(
    prev_usec: int,
    prev_t: float,
    cur_usec: int,
    cur_t: float,
    cpus: int,
) -> float:
    ncpu = max(int(cpus or 1), 1)
    if prev_t <= 0 or cur_t <= prev_t:
        return 0.0
    dt = cur_t - prev_t
    du = max(int(cur_usec) - int(prev_usec), 0)
    pct = (du / 1_000_000.0) / dt / ncpu * 100.0
    return min(100.0, round(pct, 1))


def net_bps(prev_bytes: int, prev_t: float, cur_bytes: int, cur_t: float) -> int:
    if prev_t <= 0 or cur_t <= prev_t:
        return 0
    delta = int(cur_bytes) - int(prev_bytes)
    if delta < 0:
        return 0
    return int(delta / (cur_t - prev_t))


def ram_pair(current_bytes: int, max_bytes: int, ram_mb: int) -> tuple[int, int]:
    total = bytes_to_mb(max_bytes) if max_bytes > 0 else int(ram_mb)
    if total <= 0:
        total = int(ram_mb)
    used = min(bytes_to_mb(current_bytes), total)
    return used, total


def build(sample: dict[str, Any]) -> tuple[dict[str, Any], dict[str, Any]]:
    for key in ("sidecar", "guest"):
        extra = sample.get(key)
        if isinstance(extra, dict):
            merged = dict(extra)
            merged.update(sample)
            sample = merged
    now = float(sample.get("now") or 0)
    prev = sample.get("prev") if isinstance(sample.get("prev"), dict) else {}
    prev_t = float(prev.get("t") or 0)
    rx = parse_u64(sample.get("rx"))
    tx = parse_u64(sample.get("tx"))
    usage_usec = parse_u64(sample.get("usage_usec"))
    nxt = {"t": now, "usage_usec": usage_usec, "rx": rx, "tx": tx}
    if sample.get("mode") == "guest":
        metrics = {
            "ram_used_mb": int(sample.get("ram_used_mb") or 0),
            "ram_total_mb": int(sample.get("ram_total_mb") or 0),
            "load1": round(float(sample.get("load1") or 0), 2),
            "cpu_pct": min(100.0, float(sample.get("cpu_pct") or 0)),
            "disk_used_gb": round(float(sample.get("disk_used_gb") or 0), 1),
            "disk_total_gb": round(float(sample.get("disk_total_gb") or 0), 1),
            "containers": int(sample.get("containers") or 0),
            "pids": int(sample.get("pids") or 0),
            "net_rx_bps": net_bps(parse_u64(prev.get("rx")), prev_t, rx, now),
            "net_tx_bps": net_bps(parse_u64(prev.get("tx")), prev_t, tx, now),
            "disk_pending": False,
        }
        return metrics, nxt
    ram_mb = int(sample.get("ram_mb") or 6144)
    cpus = int(sample.get("cpus") or 4)
    disk_gb = float(sample.get("disk_gb") or 40)
    cpu_pct = cpu_percent(
        parse_u64(prev.get("usage_usec")),
        prev_t,
        usage_usec,
        now,
        cpus,
    )
    load1 = sample.get("load1")
    if load1 is None:
        load1 = round(cpu_pct / 100.0 * cpus, 2)
    else:
        load1 = round(float(load1), 2)
    used_mb, total_mb = ram_pair(
        parse_u64(sample.get("memory_current")),
        parse_u64(sample.get("memory_max")),
        ram_mb,
    )
    disk_used = float(sample.get("disk_used_gb") or 0)
    metrics = {
        "ram_used_mb": used_mb,
        "ram_total_mb": total_mb,
        "load1": load1,
        "cpu_pct": cpu_pct,
        "disk_used_gb": round(disk_used, 1),
        "disk_total_gb": round(disk_gb, 1),
        "containers": int(sample.get("containers") or 0),
        "pids": int(sample.get("pids") or 0),
        "net_rx_bps": net_bps(parse_u64(prev.get("rx")), prev_t, rx, now),
        "net_tx_bps": net_bps(parse_u64(prev.get("tx")), prev_t, tx, now),
        "disk_pending": bool(sample.get("disk_pending")),
    }
    return metrics, nxt


def main() -> None:
    raw = sys.stdin.read()
    try:
        sample = json.loads(raw or "{}")
    except json.JSONDecodeError:
        sample = {}
    if not isinstance(sample, dict):
        sample = {}
    prev_path = ""
    args = sys.argv[1:]
    if args[:1] == ["--prev"] and len(args) >= 2:
        prev_path = args[1]
    if prev_path:
        try:
            with open(prev_path, encoding="utf-8") as fh:
                sample["prev"] = json.load(fh)
        except (OSError, json.JSONDecodeError):
            sample.setdefault("prev", {})
    metrics, nxt = build(sample)
    if prev_path:
        try:
            with open(prev_path, "w", encoding="utf-8") as fh:
                json.dump(nxt, fh)
        except OSError:
            pass
    json.dump(metrics, sys.stdout)
    sys.stdout.write("\n")


if __name__ == "__main__":
    main()
