#!/usr/bin/env bash
# Detect and start a generic Discord bot in /home/ubuntu/app.
# Copyright (c) 2026 Mr-Aurevo-X
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

ensure_node() {
  if command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
    return 0
  fi
  curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
  DEBIAN_FRONTEND=noninteractive apt-get install -y nodejs
}

start_node_bot() {
  cd "$APP"
  ensure_node
  local exec_start=""
  if [[ -f pnpm-lock.yaml ]]; then
    corepack enable >/dev/null 2>&1 || true
    corepack prepare pnpm@9.15.0 --activate >/dev/null 2>&1 || npm install -g pnpm
    sudo -u ubuntu pnpm install
    if grep -q '"db:migrate"' package.json; then
      sudo -u ubuntu pnpm db:migrate || sudo -u ubuntu pnpm db:push || true
    fi
    if [[ -f apps/bot/package.json ]]; then
      sudo -u ubuntu pnpm --filter "./apps/bot..." build || true
      exec_start="$(command -v pnpm) --filter ./apps/bot start"
    else
      exec_start="${start_cmd:-$(command -v pnpm) start}"
    fi
  elif [[ -f yarn.lock ]] && command -v yarn >/dev/null 2>&1; then
    sudo -u ubuntu yarn install
    exec_start="${start_cmd:-$(command -v yarn) start}"
  else
    sudo -u ubuntu npm install
    exec_start="${start_cmd:-$(command -v npm) start}"
  fi
  if [[ -n "$start_cmd" ]]; then
    exec_start="/bin/bash -lc 'cd ${APP} && ${start_cmd}'"
  elif [[ "$exec_start" != /* ]]; then
    exec_start="/bin/bash -lc 'cd ${APP} && ${exec_start}'"
  fi
  install_node_unit "$exec_start"
}

compose_has_bot_container() {
  docker ps --format '{{.Names}}' | grep -qiE 'bot|worker|discord'
}

case "$rt" in
  compose)
    if [[ -z "$compose_file" ]]; then
      for f in docker-compose.prod.yml docker-compose.yml compose.yaml docker-compose.yaml; do
        if [[ -f "$APP/$f" ]]; then
          compose_file="$f"
          break
        fi
      done
    fi
    cd "$APP"
    for other in docker-compose.prod.yml docker-compose.yml compose.yaml docker-compose.yaml; do
      if [[ -n "$compose_file" && "$other" != "$compose_file" && -f "$APP/$other" ]]; then
        docker compose -f "$other" down >/dev/null 2>&1 || true
      fi
    done
    extra=()
    if grep -qE '^[[:space:]]*profiles:' "$APP/$compose_file"; then
      extra+=(--profile music)
    fi
    log "docker compose -f $compose_file ${extra[*]:-} up -d --build"
    if ! docker compose -f "$compose_file" --env-file .env "${extra[@]}" up -d --build; then
      log "compose $compose_file failed — trying infra compose + Node"
      docker compose -f "$compose_file" down >/dev/null 2>&1 || true
      if [[ -f "$APP/docker-compose.yml" && "$compose_file" != "docker-compose.yml" ]]; then
        docker compose -f docker-compose.yml --env-file .env up -d --build || true
      fi
    fi
    if ! compose_has_bot_container && ! systemctl is-active --quiet discord-bot.service && [[ -f "$APP/package.json" ]]; then
      log "compose has no bot process — starting Node service"
      if [[ -f "$APP/docker-compose.yml" ]]; then
        docker compose -f docker-compose.yml --env-file .env up -d || true
      fi
      start_node_bot
    fi
    ;;
  docker)
    log "docker build + run"
    cd "$APP"
    docker build -t fakevps-bot .
    docker rm -f fakevps-bot >/dev/null 2>&1 || true
    docker run -d --name fakevps-bot --restart unless-stopped --env-file .env fakevps-bot
    ;;
  node)
    start_node_bot
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
