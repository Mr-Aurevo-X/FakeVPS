# Copy guest scripts and optionally deploy a bot.

push_provision_scripts() {
  guest_ssh "mkdir -p /home/ubuntu/fakevps-provision"
  # shellcheck disable=SC2046
  scp $(ssh_opts) \
    "$FAKEVPS_ROOT/provision/01-packages.sh" \
    "$FAKEVPS_ROOT/provision/02-bot.sh" \
    "$FAKEVPS_ROOT/provision/detect-runtime.sh" \
    "${SSH_USER}@127.0.0.1:/home/ubuntu/fakevps-provision/"
  guest_ssh "chmod +x /home/ubuntu/fakevps-provision/*.sh"
}

provision_packages() {
  log "guest packages (Docker, swap, ufw)"
  guest_ssh "sudo BOT_PANEL_PORT='${BOT_PANEL_PORT}' bash /home/ubuntu/fakevps-provision/01-packages.sh"
}

provision_bot() {
  if [[ -z "${BOT_DIR}" ]]; then
    log "BOT_DIR empty — fresh VPS, no bot"
    return 0
  fi
  sync_bot_tree "$BOT_DIR"
  inject_bot_env
  log "auto-deploy bot"
  guest_ssh "sudo BOT_RUNTIME='${BOT_RUNTIME}' APP_DIR=/home/ubuntu/app bash /home/ubuntu/fakevps-provision/02-bot.sh"
}

provision_all() {
  push_provision_scripts
  provision_packages
  provision_bot
}

marker_path() {
  printf '%s\n' "$STATE_DIR/provisioned"
}

first_boot_provision() {
  if [[ -f "$(marker_path)" ]]; then
    if [[ -n "${BOT_DIR}" ]]; then
      provision_bot
    fi
    return 0
  fi
  provision_all
  date -Iseconds >"$(marker_path)"
}
