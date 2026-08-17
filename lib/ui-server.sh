# Cockpit HTTP server on 127.0.0.1:$UI_PORT

ui_pidfile() {
  printf '%s\n' "$STATE_DIR/ui.pid"
}

ui_running() {
  local pf
  pf="$(ui_pidfile)"
  [[ -f "$pf" ]] || return 1
  kill -0 "$(cat "$pf")" 2>/dev/null
}

ui_start() {
  if ui_running; then
    return 0
  fi
  require_cmd python3
  mkdir -p "$STATE_DIR/logs"
  FAKEVPS_ROOT="$FAKEVPS_ROOT" UI_PORT="$UI_PORT" python3 "$FAKEVPS_ROOT/lib/ui_server.py" \
    >>"$STATE_DIR/logs/ui.log" 2>&1 &
  echo $! >"$(ui_pidfile)"
  sleep 0.3
  log "cockpit http://127.0.0.1:${UI_PORT}"
}

ui_stop() {
  if ui_running; then
    kill "$(cat "$(ui_pidfile)")" 2>/dev/null || true
    rm -f "$(ui_pidfile)"
  fi
}
