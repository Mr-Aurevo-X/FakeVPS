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
