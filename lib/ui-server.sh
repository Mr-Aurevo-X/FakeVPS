# Cockpit HTTP server on 127.0.0.1:$UI_PORT
# Copyright (c) 2026 Mr-Aurevo-X

ui_pidfile() {
  printf '%s\n' "$STATE_DIR/ui.pid"
}

ui_port_listening() {
  host_bind_ok "$UI_PORT"
}

# Port on 127.0.0.1 is the source of truth. A leftover pid in another netns
# must not count as "already running".
ui_running() {
  ui_port_listening
}

ui_start() {
  if ui_running; then
    return 0
  fi
  require_cmd python3
  mkdir -p "$STATE_DIR/logs"
  rm -f "$(ui_pidfile)"
  nohup env FAKEVPS_ROOT="$FAKEVPS_ROOT" UI_PORT="$UI_PORT" \
    SSH_PORT="$SSH_PORT" SSH_USER="$SSH_USER" \
    python3 "$FAKEVPS_ROOT/lib/ui_server.py" \
    >>"$STATE_DIR/logs/ui.log" 2>&1 &
  local pid=$!
  echo "$pid" >"$(ui_pidfile)"
  disown "$pid" 2>/dev/null || true
  local n=0
  while (( n < 20 )); do
    if ui_running; then
      log "cockpit http://127.0.0.1:${UI_PORT}"
      return 0
    fi
    sleep 0.1
    n=$((n + 1))
  done
  log "cockpit did not bind 127.0.0.1:${UI_PORT} — see state/logs/ui.log"
  return 1
}

ui_stop() {
  local pf pid
  pf="$(ui_pidfile)"
  if [[ -f "$pf" ]]; then
    pid="$(cat "$pf" 2>/dev/null || true)"
    if [[ -n "$pid" ]]; then
      kill "$pid" 2>/dev/null || true
    fi
    rm -f "$pf"
  fi
  # Leftover cockpit from this tree or a sibling checkout (Python only).
  local p comm
  while read -r p; do
    [[ -n "$p" ]] || continue
    comm="$(ps -o comm= -p "$p" 2>/dev/null || true)"
    comm="${comm// /}"
    case "$comm" in
      python3|python) kill "$p" 2>/dev/null || true ;;
    esac
  done < <(pgrep -f 'lib/ui_server.py' || true)
}
