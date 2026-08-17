# SSH helpers for the guest.

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
  die "SSH did not become ready within ${timeout}s"
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
  if guest_ssh "test -f $dest_env"; then
    log "guest .env already present — leaving it"
    return 0
  fi
  if [[ -f "$SECRETS_DIR/discord.env" ]]; then
    guest_ssh "mkdir -p /home/ubuntu/app"
    # shellcheck disable=SC2046
    scp $(ssh_opts) "$SECRETS_DIR/discord.env" "${SSH_USER}@127.0.0.1:${dest_env}"
    guest_ssh "chmod 600 $dest_env"
    log "injected secrets/discord.env → $dest_env"
  else
    log "no secrets/discord.env — bot will not auto-start"
  fi
}
