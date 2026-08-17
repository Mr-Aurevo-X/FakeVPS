# Docker systemd backend — same SSH/ports as KVM, faster iteration.

FAST_IMAGE="fakevps-ubuntu:24.04"
FAST_NAME="fakevps"

fast_running() {
  command -v docker >/dev/null 2>&1 || return 1
  docker inspect -f '{{.State.Running}}' "$FAST_NAME" 2>/dev/null | grep -q true
}

fast_build() {
  require_cmd docker
  if docker image inspect "$FAST_IMAGE" >/dev/null 2>&1; then
    return 0
  fi
  log "building $FAST_IMAGE"
  docker build -t "$FAST_IMAGE" -f "$FAKEVPS_ROOT/docker/Dockerfile.vps" "$FAKEVPS_ROOT/docker"
}

fast_up() {
  require_cmd docker
  if fast_running; then
    log "fast container already running"
    return 0
  fi
  fast_build
  ensure_ssh_key
  local ports=(-p "127.0.0.1:${SSH_PORT}:22")
  if [[ -n "${BOT_PANEL_PORT}" ]]; then
    ports+=(-p "127.0.0.1:${BOT_PANEL_PORT}:${BOT_PANEL_PORT}")
  fi
  docker rm -f "$FAST_NAME" >/dev/null 2>&1 || true
  log "starting Docker VPS (${RAM_MB} MB, ${CPUS} CPU)"
  docker run -d \
    --name "$FAST_NAME" \
    --privileged \
    --cgroupns=host \
    --memory="${RAM_MB}m" \
    --cpus="$CPUS" \
    --hostname fakevps \
    -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
    "${ports[@]}" \
    "$FAST_IMAGE" >/dev/null
  local i=0
  while (( i < 30 )); do
    if docker exec "$FAST_NAME" systemctl is-system-running >/dev/null 2>&1; then
      break
    fi
    sleep 1
    i=$((i + 1))
  done
  docker exec "$FAST_NAME" mkdir -p /home/ubuntu/.ssh
  docker cp "$SSH_PUB" "${FAST_NAME}:/home/ubuntu/.ssh/authorized_keys"
  docker exec "$FAST_NAME" bash -c 'chown -R ubuntu:ubuntu /home/ubuntu/.ssh && chmod 700 /home/ubuntu/.ssh && chmod 600 /home/ubuntu/.ssh/authorized_keys'
  docker exec "$FAST_NAME" systemctl start ssh || true
  set_backend fast
}

fast_down() {
  if docker inspect "$FAST_NAME" >/dev/null 2>&1; then
    docker stop -t 20 "$FAST_NAME" >/dev/null || true
    # keep the container for persist? Plan: volume state/fast/root.
    # We use the named container as persistence (not --rm).
  fi
}

fast_reset() {
  docker rm -f "$FAST_NAME" >/dev/null 2>&1 || true
}
