# SSH helpers for the guest.
# Copyright (c) 2026 Mr-Aurevo-X

ensure_ssh_key() {
  if [[ ! -f "$SSH_KEY" ]]; then
    require_cmd ssh-keygen
    ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -C "fakevps" >/dev/null
    chmod 600 "$SSH_KEY"
    log "generated $SSH_KEY"
  fi
}

ssh_opts() {
  printf '%s\n' \
    -i "$SSH_KEY" \
    -p "$SSH_PORT" \
    -o "StrictHostKeyChecking=accept-new" \
    -o "UserKnownHostsFile=$KNOWN_HOSTS" \
    -o "ConnectTimeout=5" \
    -o "LogLevel=ERROR"
}

# scp uses -P for port; -p means "preserve times" and would try to stat the port.
scp_opts() {
  printf '%s\n' \
    -i "$SSH_KEY" \
    -P "$SSH_PORT" \
    -o "StrictHostKeyChecking=accept-new" \
    -o "UserKnownHostsFile=$KNOWN_HOSTS" \
    -o "ConnectTimeout=5" \
    -o "LogLevel=ERROR"
}

guest_ssh() {
  # shellcheck disable=SC2046
  ssh $(ssh_opts) "${SSH_USER}@127.0.0.1" "$@"
}

guest_metrics() {
  guest_ssh env \
    FAKEVPS_RAM_MB="$RAM_MB" \
    FAKEVPS_CPUS="$CPUS" \
    FAKEVPS_DISK_GB="$DISK_GB" \
    python3 - <<'PY'
import json
import os
import shutil
import subprocess

ram_cap = int(os.environ.get("FAKEVPS_RAM_MB") or 6144)
cpus = max(int(os.environ.get("FAKEVPS_CPUS") or 4), 1)
disk_cap = float(os.environ.get("FAKEVPS_DISK_GB") or 40)
mem = {}
with open("/proc/meminfo", encoding="utf-8") as fh:
    for line in fh:
        parts = line.split()
        if len(parts) >= 2:
            mem[parts[0].rstrip(":")] = int(parts[1])
total = mem.get("MemTotal", 0) // 1024
avail = mem.get("MemAvailable", mem.get("MemFree", 0)) // 1024
used = max(total - avail, 0)
# Privileged fast node sees the host /proc. Never publish that as VPS RAM.
if total > int(ram_cap * 1.15):
    print(json.dumps({
        "ram_used_mb": 0,
        "ram_total_mb": ram_cap,
        "load1": 0.0,
        "cpu_pct": 0.0,
        "disk_used_gb": 0.0,
        "disk_total_gb": disk_cap,
        "containers": 0,
        "pids": 0,
        "rx": 0,
        "tx": 0,
        "host_proc": True,
    }))
    raise SystemExit
load1 = 0.0
try:
    with open("/proc/loadavg", encoding="utf-8") as fh:
        load1 = float(fh.read().split()[0])
except OSError:
    pass
du = shutil.disk_usage("/")
containers = 0
try:
    out = subprocess.check_output(["docker", "ps", "-q"], stderr=subprocess.DEVNULL)
    containers = len([row for row in out.split() if row])
except (OSError, subprocess.CalledProcessError):
    pass
pids = 0
try:
    pids = sum(1 for name in os.listdir("/proc") if name.isdigit())
except OSError:
    pass
rx = tx = 0
for name in ("ens3", "enp0s3", "eth0", "enp0s1"):
    base = f"/sys/class/net/{name}/statistics"
    try:
        rx = int(open(f"{base}/rx_bytes", encoding="utf-8").read())
        tx = int(open(f"{base}/tx_bytes", encoding="utf-8").read())
        break
    except OSError:
        continue
print(json.dumps({
    "ram_used_mb": used,
    "ram_total_mb": total,
    "load1": round(load1, 2),
    "cpu_pct": min(100.0, round(100.0 * load1 / cpus, 1)),
    "disk_used_gb": round(min(du.used / (1024 ** 3), disk_cap), 1),
    "disk_total_gb": round(disk_cap, 1),
    "containers": containers,
    "pids": pids,
    "net_rx_bps": 0,
    "net_tx_bps": 0,
    "rx": rx,
    "tx": tx,
}))
PY
}

# Guest probe for cockpit status. Prints JSON only — never token values.
guest_status_probe() {
  guest_ssh python3 - <<'PY'
import json
import os
import re
import shutil
import subprocess

def run(cmd):
    try:
        return subprocess.check_output(cmd, stderr=subprocess.DEVNULL, text=True)
    except (OSError, subprocess.CalledProcessError):
        return ""

docker_ok = shutil.which("docker") is not None
services = []
if docker_ok:
    for line in run(["docker", "ps", "--format", "{{.Names}} {{.Status}}"]).splitlines():
        line = line.strip()
        if not line:
            continue
        name, _, state = line.partition(" ")
        if name:
            services.append({"name": name, "state": state or "unknown"})

bot_ok = False
try:
    if subprocess.run(
        ["systemctl", "is-active", "--quiet", "discord-bot.service"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    ).returncode == 0:
        bot_ok = True
        if not any(row.get("name") == "discord-bot" for row in services):
            services.append({"name": "discord-bot", "state": "active"})
except OSError:
    pass
if not bot_ok:
    names = " ".join(row.get("name", "") for row in services)
    if re.search(r"bot|worker|discord", names, re.I):
        bot_ok = True

token_present = False
try:
    with open("/home/ubuntu/app/.env", encoding="utf-8", errors="replace") as fh:
        for line in fh:
            if line.startswith("DISCORD_TOKEN=") and len(line.strip()) > len("DISCORD_TOKEN="):
                token_present = True
                break
except OSError:
    pass

runtime = "none"
script = "/home/ubuntu/fakevps-provision/detect-runtime.sh"
if os.path.isfile(script):
    runtime = (run(["bash", script, "/home/ubuntu/app"]) or "none").strip() or "none"

print(json.dumps({
    "docker": docker_ok,
    "bot": bot_ok,
    "services": services,
    "token_present": token_present,
    "runtime": runtime,
}))
PY
}

wait_ssh() {
  local timeout="${1:-180}"
  local i=0
  log "waiting for SSH on 127.0.0.1:${SSH_PORT}"
  while (( i < timeout )); do
    if guest_ssh true >/dev/null 2>&1; then
      log "SSH ready"
      return 0
    fi
    sleep 2
    i=$((i + 2))
  done
  log "SSH did not become ready within ${timeout}s"
  return 1
}

sync_bot_tree() {
  local src="$1"
  [[ -d "$src" ]] || die "BOT_DIR is not a directory: $src"
  require_cmd rsync
  log "rsync bot → guest:/home/ubuntu/app"
  guest_ssh "mkdir -p /home/ubuntu/app"
  rsync -az --delete \
    --exclude node_modules \
    --exclude .venv \
    --exclude __pycache__ \
    --exclude .env \
    --exclude .git \
    -e "ssh -i ${SSH_KEY} -p ${SSH_PORT} -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${KNOWN_HOSTS} -o LogLevel=ERROR" \
    "${src%/}/" "${SSH_USER}@127.0.0.1:/home/ubuntu/app/"
}

inject_bot_env() {
  local dest_env="/home/ubuntu/app/.env"
  local bot_env=""
  local secrets_env=""
  local tmp
  if [[ -n "${BOT_DIR}" && -f "${BOT_DIR}/.env" ]]; then
    bot_env="${BOT_DIR}/.env"
  fi
  if [[ -f "$SECRETS_DIR/discord.env" ]]; then
    secrets_env="$SECRETS_DIR/discord.env"
  fi
  if [[ -z "$bot_env" && -z "$secrets_env" ]]; then
    log "no .env in BOT_DIR or secrets/discord.env — bot will not auto-start"
    return 0
  fi
  tmp="$(mktemp "$STATE_DIR/.env.inject.XXXXXX")"
  python3 - "$tmp" "$bot_env" "$secrets_env" <<'PY'
from pathlib import Path
import re
import sys

def parse(path: str) -> dict[str, str]:
    data: dict[str, str] = {}
    if not path:
        return data
    for raw in Path(path).read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        key = key.strip()
        if key.startswith("export "):
            key = key[7:].strip()
        if key:
            data[key] = value
    return data

dest, bot_env, secrets_env = sys.argv[1], sys.argv[2], sys.argv[3]
merged = parse(bot_env)
for key, value in parse(secrets_env).items():
    if value.strip():
        merged[key] = value
if not str(merged.get("POSTGRES_PASSWORD", "")).strip():
    match = re.match(r"postgres(?:ql)?://[^:]+:([^@]+)@", merged.get("DATABASE_URL", ""))
    if match:
        merged["POSTGRES_PASSWORD"] = match.group(1)
if not str(merged.get("DISCORD_CLIENT_SECRET", "")).strip():
    merged["DISCORD_CLIENT_SECRET"] = "fakevps-rehearsal"
lines = [f"{key}={value}" for key, value in merged.items()]
Path(dest).write_text("\n".join(lines) + ("\n" if lines else ""), encoding="utf-8")
PY
  guest_ssh "mkdir -p /home/ubuntu/app"
  # shellcheck disable=SC2046
  scp $(scp_opts) "$tmp" "${SSH_USER}@127.0.0.1:${dest_env}"
  rm -f "$tmp"
  guest_ssh "chmod 600 $dest_env"
  if [[ -n "$bot_env" && -n "$secrets_env" ]]; then
    log "injected BOT_DIR/.env + secrets/discord.env → $dest_env"
  elif [[ -n "$bot_env" ]]; then
    log "injected BOT_DIR/.env → $dest_env"
  else
    log "injected secrets/discord.env → $dest_env"
  fi
}
