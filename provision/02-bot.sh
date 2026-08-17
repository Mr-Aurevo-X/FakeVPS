#!/usr/bin/env bash
# Detect and start a generic Discord bot in /home/ubuntu/app.
set -euo pipefail

APP="${APP_DIR:-/home/ubuntu/app}"
RUNTIME="${BOT_RUNTIME:-auto}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

log() { printf '[bot] %s\n' "$*"; }

if [[ ! -d "$APP" ]]; then
  log "no app directory — VPS stays empty"
  exit 0
fi

has_token() {
  [[ -f "$APP/.env" ]] && grep -qE '^DISCORD_TOKEN=.+' "$APP/.env"
}

yaml_get() {
  local key="$1"
  local manifest="$APP/fakevps.bot.yml"
  [[ -f "$manifest" ]] || return 0
  sed -n "s/^${key}:[[:space:]]*//p" "$manifest" | sed 's/[[:space:]]*#.*//' | tr -d '"' | tr -d "'" | head -1
}

rt="$("$SCRIPT_DIR/detect-runtime.sh" "$APP" "$RUNTIME")"
log "runtime=$rt"

if [[ "$rt" == "none" ]]; then
  log "no known bot layout — SSH in and start it yourself"
  exit 0
fi

if ! has_token; then
  log "DISCORD_TOKEN missing — synced only, not started"
  exit 0
fi

start_cmd="$(yaml_get start || true)"
compose_file="$(yaml_get compose_file || true)"

install_node_unit() {
  local exec_start="$1"
  cat >/etc/systemd/system/discord-bot.service <<EOF
[Unit]
Description=Discord bot (FakeVPS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=${APP}
EnvironmentFile=-${APP}/.env
ExecStart=${exec_start}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now discord-bot.service
}

case "$rt" in
  compose)
    if [[ -z "$compose_file" ]]; then
      for f in docker-compose.yml compose.yaml docker-compose.prod.yml docker-compose.yaml; do
        if [[ -f "$APP/$f" ]]; then
          compose_file="$f"
          break
        fi
      done
    fi
    log "docker compose -f $compose_file up -d --build"
    cd "$APP"
    docker compose -f "$compose_file" --env-file .env up -d --build
    ;;
  docker)
    log "docker build + run"
    cd "$APP"
    docker build -t fakevps-bot .
    docker rm -f fakevps-bot >/dev/null 2>&1 || true
    docker run -d --name fakevps-bot --restart unless-stopped --env-file .env fakevps-bot
    ;;
  node)
    cd "$APP"
    if [[ -f pnpm-lock.yaml ]] && command -v pnpm >/dev/null 2>&1; then
      sudo -u ubuntu pnpm install
      exec_start="${start_cmd:-$(command -v pnpm) start}"
    elif [[ -f yarn.lock ]] && command -v yarn >/dev/null 2>&1; then
      sudo -u ubuntu yarn install
      exec_start="${start_cmd:-$(command -v yarn) start}"
    else
      if ! command -v npm >/dev/null 2>&1; then
        curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
        DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
      fi
      sudo -u ubuntu npm install
      exec_start="${start_cmd:-$(command -v npm) start}"
    fi
    if [[ "$exec_start" != /* ]]; then
      exec_start="/bin/bash -lc 'cd ${APP} && ${exec_start}'"
    fi
    install_node_unit "$exec_start"
    ;;
  python)
    cd "$APP"
    if ! command -v python3 >/dev/null 2>&1; then
      DEBIAN_FRONTEND=noninteractive apt-get install -y python3 python3-venv python3-pip
    fi
    sudo -u ubuntu python3 -m venv "$APP/.venv"
    if [[ -f requirements.txt ]]; then
      sudo -u ubuntu "$APP/.venv/bin/pip" install -r requirements.txt
    elif [[ -f pyproject.toml ]]; then
      sudo -u ubuntu "$APP/.venv/bin/pip" install -e .
    fi
    if [[ -n "$start_cmd" ]]; then
      exec_start="/bin/bash -lc 'cd ${APP} && ${start_cmd}'"
    elif [[ -f "$APP/bot.py" ]]; then
      exec_start="$APP/.venv/bin/python $APP/bot.py"
    else
      exec_start="$APP/.venv/bin/python $APP/main.py"
    fi
    install_node_unit "$exec_start"
    ;;
  *)
    log "unknown runtime $rt"
    exit 1
    ;;
esac

log "bot start requested"
