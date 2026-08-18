# Copy guest scripts and optionally deploy a bot.
# Copyright (c) 2026 Mr-Aurevo-X

push_provision_scripts() {
  guest_ssh "mkdir -p /home/ubuntu/fakevps-provision"
  # shellcheck disable=SC2046
  scp $(scp_opts) \
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
    log "BOT_DIR empty — no bot (token in secrets/discord.env, then ./fakevps attach ~/bot)"
    return 0
  fi
  sync_bot_tree "$BOT_DIR"
  inject_bot_env
  log "auto-deploy bot"
  guest_ssh "sudo BOT_RUNTIME='${BOT_RUNTIME}' BOT_PANEL_PORT='${BOT_PANEL_PORT}' APP_DIR=/home/ubuntu/app bash /home/ubuntu/fakevps-provision/02-bot.sh"
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
  # Never abort `up` here: a failed scp/bot must not kill the cockpit (set -e parent).
  # Host marker can be stale after the fast container is recreated.
  if guest_ssh "command -v docker >/dev/null 2>&1"; then
    if [[ -n "${BOT_DIR}" ]]; then
      if auto_deploy_enabled; then
        provision_bot || log "bot deploy failed — node stays up; retry ./fakevps attach <dir>"
      else
        log "AUTO_DEPLOY=false — bot not started (./fakevps attach <dir> when you want it)"
      fi
    fi
    return 0
  fi
  if ! push_provision_scripts; then
    log "could not copy provision scripts — node is up; cockpit still available"
    return 0
  fi
  if ! provision_packages; then
    log "guest package install failed — node is up; cockpit still available"
    return 0
  fi
  if [[ -z "${BOT_DIR}" ]]; then
    log "no bot attached — put token in secrets/discord.env then ./fakevps attach ~/bot"
  elif auto_deploy_enabled; then
    provision_bot || log "bot deploy failed — packages are installed; retry ./fakevps attach <dir>"
  else
    log "AUTO_DEPLOY=false — bot not started (./fakevps attach <dir> when you want it)"
  fi
  date -Iseconds >"$(marker_path)"
  return 0
}
