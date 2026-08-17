#!/usr/bin/env bash
# Print compose|docker|node|python|none for a bot directory.
set -euo pipefail

APP="${1:-.}"
RUNTIME_OVERRIDE="${2:-auto}"
MANIFEST="$APP/fakevps.bot.yml"

yaml_get() {
  local key="$1"
  [[ -f "$MANIFEST" ]] || return 0
  sed -n "s/^${key}:[[:space:]]*//p" "$MANIFEST" | sed 's/[[:space:]]*#.*//' | tr -d '"' | tr -d "'" | head -1
}

if [[ "$RUNTIME_OVERRIDE" != "auto" && -n "$RUNTIME_OVERRIDE" ]]; then
  printf '%s\n' "$RUNTIME_OVERRIDE"
  exit 0
fi

if [[ -f "$MANIFEST" ]]; then
  local_rt="$(yaml_get runtime || true)"
  if [[ -n "${local_rt}" && "$local_rt" != "auto" ]]; then
    printf '%s\n' "$local_rt"
    exit 0
  fi
fi

compose_file="$(yaml_get compose_file || true)"
if [[ -n "$compose_file" && -f "$APP/$compose_file" ]]; then
  printf 'compose\n'
  exit 0
fi

for f in docker-compose.yml compose.yaml docker-compose.prod.yml docker-compose.yaml; do
  if [[ -f "$APP/$f" ]]; then
    printf 'compose\n'
    exit 0
  fi
done

if [[ -f "$APP/Dockerfile" ]]; then
  printf 'docker\n'
  exit 0
fi

if [[ -f "$APP/package.json" ]]; then
  printf 'node\n'
  exit 0
fi

if [[ -f "$APP/pyproject.toml" || -f "$APP/requirements.txt" || -f "$APP/bot.py" || -f "$APP/main.py" ]]; then
  printf 'python\n'
  exit 0
fi

printf 'none\n'
