# Docker systemd backend — same SSH/ports as KVM, faster iteration.
# Copyright (c) 2026 Mr-Aurevo-X

FAST_IMAGE="fakevps-ubuntu:24.04"
FAST_NAME="fakevps"

fast_running() {
  command -v docker >/dev/null 2>&1 || return 1
  docker inspect -f '{{.State.Running}}' "$FAST_NAME" 2>/dev/null | grep -q true
}

fast_docker_graph_mounted() {
  docker inspect -f '{{range .Mounts}}{{if eq .Destination "/var/lib/docker"}}yes{{end}}{{end}}' \
    "$FAST_NAME" 2>/dev/null | grep -q yes
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
  if fast_running && fast_docker_graph_mounted; then
    log "fast container already running"
    return 0
  fi
  if fast_running; then
    log "recreating fast node with a host-backed Docker graph"
    docker rm -f "$FAST_NAME" >/dev/null 2>&1 || true
  fi
  fast_build
  ensure_ssh_key
  mkdir -p "$STATE_DIR/fast/docker" "$STATE_DIR/fast/containerd"
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
    -v "$STATE_DIR/fast/docker:/var/lib/docker" \
    -v "$STATE_DIR/fast/containerd:/var/lib/containerd" \
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
  command -v docker >/dev/null 2>&1 || return 0
  docker rm -f "$FAST_NAME" >/dev/null 2>&1 || true
  rm -rf "$STATE_DIR/fast/docker" "$STATE_DIR/fast/containerd" 2>/dev/null || true
  # The inner Docker graph is written by root inside the node — if plain rm
  # left anything behind, delete it through a short-lived container instead.
  if [[ -n "$(ls -A "$STATE_DIR/fast/docker" 2>/dev/null)" || -n "$(ls -A "$STATE_DIR/fast/containerd" 2>/dev/null)" ]]; then
    docker run --rm -v "$STATE_DIR/fast:/wipe" "$FAST_IMAGE" \
      bash -c 'rm -rf /wipe/docker /wipe/containerd' >/dev/null 2>&1 || true
  fi
  mkdir -p "$STATE_DIR/fast/docker" "$STATE_DIR/fast/containerd"
}
