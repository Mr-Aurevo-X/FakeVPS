#!/usr/bin/env bash
set -euo pipefail
FAKEVPS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$FAKEVPS_ROOT/lib/common.sh"

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
cp "$FAKEVPS_ROOT/config.env.example" "$tmp/config.env"
FAKEVPS_ROOT="$tmp"
write_config_key BOT_DIR "/home/x/Discord Bot/MyBot"
# shellcheck disable=SC1091
source "$tmp/config.env"
if [[ "$BOT_DIR" != "/home/x/Discord Bot/MyBot" ]]; then
  echo "FAIL BOT_DIR not preserved: [$BOT_DIR]" >&2
  exit 1
fi
echo "write_config_key quotes paths with spaces"
