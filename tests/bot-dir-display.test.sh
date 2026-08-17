#!/usr/bin/env bash
set -euo pipefail
FAKEVPS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$FAKEVPS_ROOT/lib/common.sh"

HOME="/home/x"
export HOME

expect() {
  local input="$1" want="$2"
  local got
  got="$(display_bot_dir "$input")"
  if [[ "$got" != "$want" ]]; then
    echo "FAIL display_bot_dir [$input]: got [$got] want [$want]" >&2
    exit 1
  fi
}

expect "" ""
# Literal ~/… display form — tilde must not expand.
# shellcheck disable=SC2088
expect "~" "~"
# shellcheck disable=SC2088
expect "~/Discord Bot/MyBot" "~/Discord Bot/MyBot"
# shellcheck disable=SC2088
expect "/home/x/Discord Bot/MyBot" "~/Discord Bot/MyBot"
expect "/home/x" "~"
expect "/opt/bots/widget" "widget"
echo "display_bot_dir tests passed"
