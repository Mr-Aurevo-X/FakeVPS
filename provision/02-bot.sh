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

yaml_nested_get() {
  local manifest="$1" parent="$2" child="$3"
  awk -v parent="$parent" -v child="$child" '
    $0 ~ "^" parent ":" { inb=1; next }
    inb && /^[^[:space:]#]/ { inb=0 }
    inb {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      if (line ~ "^" child ":") {
        sub("^" child ":[[:space:]]*", "", line)
        sub(/[[:space:]]+#.*$/, "", line)
        gsub(/"/, "", line)
        gsub(/\047/, "", line)
        print line
        exit
      }
    }
  ' "$manifest"
}

yaml_get() {
  local key="$1"
  local manifest="$APP/fakevps.bot.yml"
  [[ -f "$manifest" ]] || return 0
  if [[ "$key" == *.* ]]; then
    yaml_nested_get "$manifest" "${key%%.*}" "${key#*.}"
    return 0
  fi
  sed -n "s/^${key}:[[:space:]]*//p" "$manifest" | sed 's/[[:space:]]*#.*//' | tr -d '"' | tr -d "'" | head -1
}

panel_wanted() {
  [[ -n "${BOT_PANEL_PORT:-}" && "${BOT_PANEL_PORT}" =~ ^[0-9]+$ ]] || return 1
  local cmd
  cmd="$(yaml_get panel.start || true)"
  [[ -n "$cmd" ]]
}

write_panel_unit() {
  local dest="$1"
  local exec_start="$2"
  cat >"$dest" <<EOF
[Unit]
Description=Bot web panel (FakeVPS)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=${APP}
EnvironmentFile=-${APP}/.env
Environment=CI=true
Environment=npm_config_update_notifier=false
Environment=PATH=/usr/local/bin:/usr/bin:/bin
Environment=PORT=${BOT_PANEL_PORT}
ExecStart=${exec_start}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
}

maybe_install_panel() {
  local unit_dir dest panel_cmd exec_start
  unit_dir="${SYSTEMD_UNIT_DIR:-/etc/systemd/system}"
  dest="${unit_dir}/bot-panel.service"
  panel_cmd="$(yaml_get panel.start || true)"
  if ! panel_wanted; then
    if [[ -f "$dest" ]]; then
      if [[ "${SYSTEMD_SKIP_CTL:-}" != "1" ]]; then
        systemctl disable --now bot-panel.service >/dev/null 2>&1 || true
      fi
      rm -f "$dest"
      if [[ "${SYSTEMD_SKIP_CTL:-}" != "1" ]]; then
        systemctl daemon-reload || true
      fi
    fi
    return 0
  fi
  mkdir -p "$unit_dir"
  exec_start="/bin/bash -lc 'cd ${APP} && ${panel_cmd}'"
  write_panel_unit "$dest" "$exec_start"
  log "installing bot-panel.service"
  if [[ "${SYSTEMD_SKIP_CTL:-}" == "1" ]]; then
    return 0
  fi
  case "$panel_cmd" in
    *pnpm*|*npm*|*npx*|*yarn*|*node*)
      ensure_node || { log "panel start needs Node — install failed"; return 1; }
      ;;
  esac
  systemctl daemon-reload
  systemctl enable bot-panel.service
  # enable --now does not bounce an already-active unit (stale ExecStart).
  systemctl restart bot-panel.service
}

# If this attach does not want a panel, drop a leftover unit even when we
# exit early (no token, unknown runtime, failed compose/build).
trap 'panel_wanted || maybe_install_panel || true' EXIT

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
fallback="$(yaml_get fallback || true)"
case "${fallback:-none}" in
  node) fallback_node=true ;;
  *) fallback_node=false ;;
esac

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
Environment=CI=true
Environment=npm_config_update_notifier=false
ExecStart=${exec_start}
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
  systemctl daemon-reload
  systemctl enable --now discord-bot.service
}

# Ubuntu 24.04 ships Node 18. Current pnpm needs >= 22.13.
# Official tarball + sha256 — do not pipe NodeSource into a shell.
NODE_MIN_MAJOR=22
NODE_MIN_MINOR=13
NODE_DIST_VER=22.23.2

node_meets_min() {
  command -v node >/dev/null 2>&1 && command -v npm >/dev/null 2>&1 || return 1
  node -e '
const [maj, min] = process.versions.node.split(".").map(Number);
const needMaj = Number(process.env.NODE_MIN_MAJOR || 22);
const needMin = Number(process.env.NODE_MIN_MINOR || 13);
process.exit((maj > needMaj || (maj === needMaj && min >= needMin)) ? 0 : 1);
' 2>/dev/null
}

ensure_node() {
  export NODE_MIN_MAJOR NODE_MIN_MINOR
  if node_meets_min; then
    return 0
  fi
  local arch file sha url tmp
  case "$(uname -m)" in
    x86_64)
      arch=linux-x64
      sha=b294a556e639d64338823920e5866c21c02741742d2e1529ee1a225c1ec9252a
      ;;
    aarch64)
      arch=linux-arm64
      sha=013b59cfd2819703a6f4a14ab891fc46fc2a4e3f5bf92de3fb4929b43e35b30
      ;;
    *)
      log "unsupported arch $(uname -m) for Node.js"
      return 1
      ;;
  esac
  file="node-v${NODE_DIST_VER}-${arch}.tar.gz"
  url="https://nodejs.org/dist/v${NODE_DIST_VER}/${file}"
  log "installing Node.js ${NODE_DIST_VER} from nodejs.org (checksum verified)"
  tmp="$(mktemp -d)"
  curl -fsSL "$url" -o "${tmp}/${file}"
  echo "${sha}  ${tmp}/${file}" | sha256sum -c -
  tar -C /usr/local --strip-components=1 -xzf "${tmp}/${file}"
  rm -rf "$tmp"
  hash -r
  export PATH="/usr/local/bin:${PATH}"
  node_meets_min
}

start_node_bot() {
  cd "$APP"
  ensure_node
  local exec_start=""
  if [[ -f pnpm-lock.yaml ]]; then
    export PATH="/usr/local/bin:${PATH}"
    export CI=true
    export npm_config_update_notifier=false
    if [[ ! -f /home/ubuntu/.npmrc ]] || ! grep -q '^update-notifier=' /home/ubuntu/.npmrc; then
      printf 'update-notifier=false\n' >>/home/ubuntu/.npmrc
      chown ubuntu:ubuntu /home/ubuntu/.npmrc
    fi
    local pnpm_spec
    pnpm_spec="$(python3 - <<'PY'
import json
from pathlib import Path
raw = ""
p = Path("package.json")
if p.is_file():
    raw = str(json.loads(p.read_text(encoding="utf-8")).get("packageManager") or "")
print(raw if raw.startswith("pnpm@") else "pnpm@9.15.0")
PY
)"
    corepack enable >/dev/null 2>&1 || true
    corepack prepare "$pnpm_spec" --activate >/dev/null 2>&1 \
      || corepack prepare pnpm@9.15.0 --activate
    sudo -u ubuntu env CI=true npm_config_update_notifier=false PATH="$PATH" pnpm install
    if grep -q '"db:migrate"' package.json; then
      if grep -qE '^DATABASE_URL=.+' "$APP/.env" 2>/dev/null; then
        sudo -u ubuntu env CI=true PATH="$PATH" pnpm db:migrate || sudo -u ubuntu env CI=true PATH="$PATH" pnpm db:push || true
      else
        log "DATABASE_URL missing from .env — skipping db:migrate (add it to secrets/discord.env, then attach again)"
      fi
    fi
    # Without a generated Prisma client the query results type as `any` and
    # strict builds explode with TS7006. Generate from the package that owns
    # the schema — from the workspace root, pnpm writes the client into the
    # wrong node_modules and the build still sees the stub.
    local schema pkg_dir
    while IFS= read -r schema; do
      pkg_dir="$(dirname "$(dirname "$schema")")"
      log "prisma generate ($(basename "$pkg_dir"))"
      (cd "$pkg_dir" && sudo -u ubuntu env CI=true PATH="$PATH" \
        pnpm exec prisma generate --schema "$schema") || true
    done < <(find "$APP" -maxdepth 4 -name schema.prisma -not -path '*/node_modules/*' 2>/dev/null)
    # Monorepo: root build scripts compile workspace packages in dependency
    # order; a bare --filter build leaves @scope/* deps without dist.
    local build_ok=true
    if grep -qE '"build:ci"[[:space:]]*:' package.json; then
      sudo -u ubuntu env CI=true PATH="$PATH" pnpm run build:ci || build_ok=false
    elif grep -qE '"build"[[:space:]]*:' package.json; then
      sudo -u ubuntu env CI=true PATH="$PATH" pnpm run build || build_ok=false
    elif [[ -f apps/bot/package.json ]]; then
      sudo -u ubuntu env CI=true PATH="$PATH" pnpm --filter "./apps/bot..." build || build_ok=false
    fi
    if [[ "$build_ok" != true ]]; then
      log "build failed — service NOT installed (fix the errors above, then ./fakevps attach again)"
      return 1
    fi
    if [[ -f apps/bot/package.json ]]; then
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

# List ${VAR} references of a compose file that have no default value and are
# absent (or empty) in $APP/.env — the ones compose will refuse or blank out.
missing_compose_env() {
  local file="$1"
  python3 - "$APP/$file" "$APP/.env" <<'PY'
import re
import sys
from pathlib import Path

compose = Path(sys.argv[1]).read_text(encoding="utf-8", errors="replace")
have = set()
env_path = Path(sys.argv[2])
if env_path.is_file():
    for raw in env_path.read_text(encoding="utf-8", errors="replace").splitlines():
        line = raw.strip()
        if line and not line.startswith("#") and "=" in line:
            key, value = line.split("=", 1)
            if value.strip():
                have.add(key.strip())
missing = []
for m in re.finditer(r"\$\{([A-Za-z_][A-Za-z0-9_]*)(:?[-?][^}]*)?\}", compose):
    name, op = m.group(1), m.group(2) or ""
    has_default = op.startswith("-") or op.startswith(":-")
    if not has_default and name not in have and name not in missing:
        missing.append(name)
print(" ".join(missing))
PY
}

# Fail fast with an actionable message instead of letting `up` abort halfway.
compose_env_preflight() {
  local file="$1"
  local missing
  missing="$(missing_compose_env "$file" 2>/dev/null || true)"
  if [[ -n "$missing" ]]; then
    log "missing env keys for $file: $missing"
    log "add them to secrets/discord.env (or BOT_DIR/.env), then ./fakevps attach again"
  fi
  if ! docker compose -f "$file" --env-file .env config -q >/dev/null 2>&1; then
    return 1
  fi
  return 0
}

# Older nodes were provisioned before the compose plugin was part of first boot.
ensure_compose() {
  if docker compose version >/dev/null 2>&1; then
    return 0
  fi
  log "installing docker compose plugin"
  DEBIAN_FRONTEND=noninteractive apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-compose-v2
  DEBIAN_FRONTEND=noninteractive apt-get install -y docker-buildx || true
  docker compose version >/dev/null 2>&1
}

case "$rt" in
  compose)
    ensure_compose || { log "docker compose unavailable — cannot deploy this bot"; exit 1; }
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
    # Idempotent redeploys: stale containers from a previous run (same names,
    # different labels) make `up` fail with "name already in use".
    docker compose -f "$compose_file" --env-file .env down --remove-orphans >/dev/null 2>&1 || true
    docker ps -a --format '{{.Names}}' | grep -E '^app-' | xargs -r docker rm -f >/dev/null 2>&1 || true
    prod_ok=false
    if compose_env_preflight "$compose_file"; then
      log "docker compose -f $compose_file ${extra[*]:-} up -d --build"
      if docker compose -f "$compose_file" --env-file .env "${extra[@]}" up -d --build --remove-orphans; then
        prod_ok=true
      fi
    else
      log "compose $compose_file config invalid (missing env)"
    fi
    if [[ "$prod_ok" != true ]]; then
      if [[ "$fallback_node" == true ]]; then
        log "compose $compose_file not deployed — fallback: node — trying infra compose + Node"
        docker compose -f "$compose_file" down >/dev/null 2>&1 || true
        if [[ -f "$APP/docker-compose.yml" && "$compose_file" != "docker-compose.yml" ]]; then
          docker compose -f docker-compose.yml --env-file .env up -d --build || true
        fi
      else
        log "compose $compose_file failed — not falling back (add fallback: node or runtime: node to fakevps.bot.yml)"
        exit 1
      fi
    fi
    if ! compose_has_bot_container && ! systemctl is-active --quiet discord-bot.service && [[ -f "$APP/package.json" ]]; then
      if [[ "$fallback_node" == true ]]; then
        log "compose has no bot process — starting Node service"
        if [[ -f "$APP/docker-compose.yml" ]]; then
          docker compose -f docker-compose.yml --env-file .env up -d || true
        fi
        start_node_bot
      else
        log "compose has no bot process — add fallback: node (or runtime: node) to fakevps.bot.yml"
        exit 1
      fi
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

# Post-deploy healthcheck: a deploy only counts when a bot process survives
# its first seconds. Catches bad tokens and crash-loops right away.
bot_process_up() {
  systemctl is-active --quiet discord-bot.service 2>/dev/null || compose_has_bot_container
}

panel_process_up() {
  systemctl is-active --quiet bot-panel.service 2>/dev/null
}

panel_healthcheck() {
  local tries=0
  if ! panel_wanted; then
    return 0
  fi
  log "healthcheck: waiting for the panel process"
  sleep 6
  while (( tries < 8 )); do
    if panel_process_up; then
      sleep 4
      if panel_process_up; then
        log "healthcheck OK — the panel process is up and stayed up"
        return 0
      fi
      log "healthcheck: the panel started then died — likely a crash-loop"
    fi
    sleep 2
    tries=$((tries + 1))
  done
  log "healthcheck FAILED — no stable panel process; last logs:"
  journalctl -u bot-panel -n 25 --no-pager 2>/dev/null || true
  log "panel deploy failed the healthcheck — fix the errors above, then ./fakevps attach again"
  return 1
}

healthcheck() {
  local tries=0
  log "healthcheck: waiting for the bot process"
  sleep 6
  while (( tries < 8 )); do
    if bot_process_up; then
      sleep 4
      if bot_process_up; then
        log "healthcheck OK — the bot process is up and stayed up"
        panel_healthcheck
        return $?
      fi
      log "healthcheck: the bot started then died — likely a crash-loop"
    fi
    sleep 2
    tries=$((tries + 1))
  done
  log "healthcheck FAILED — no stable bot process; last logs:"
  journalctl -u discord-bot -n 25 --no-pager 2>/dev/null || true
  docker ps -a --format '{{.Names}}  {{.Status}}' 2>/dev/null || true
  log "bot deploy failed the healthcheck — fix the errors above, then ./fakevps attach again"
  return 1
}

maybe_install_panel || exit 1
healthcheck || exit 1
log "pruning dangling docker images and build cache"
docker builder prune -af >/dev/null 2>&1 || true
docker image prune -f >/dev/null 2>&1 || true
log "bot deploy complete"
