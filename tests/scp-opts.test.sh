#!/usr/bin/env bash
set -euo pipefail
FAKEVPS_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
# shellcheck source=lib/common.sh
source "$FAKEVPS_ROOT/lib/common.sh"
# shellcheck source=lib/ssh.sh
source "$FAKEVPS_ROOT/lib/ssh.sh"
load_config

mapfile -t scp < <(scp_opts)
mapfile -t ssh < <(ssh_opts)

has_line() {
  local needle="$1"
  shift
  local line
  for line in "$@"; do
    if [[ "$line" == "$needle" ]]; then
      return 0
    fi
  done
  return 1
}

has_line -P "${scp[@]}" || { echo "FAIL scp_opts missing -P" >&2; exit 1; }
if has_line -p "${scp[@]}"; then
  echo "FAIL scp_opts must not use -p (preserve times)" >&2
  exit 1
fi
has_line -p "${ssh[@]}" || { echo "FAIL ssh_opts missing -p" >&2; exit 1; }
if has_line -P "${ssh[@]}"; then
  echo "FAIL ssh_opts must not use -P" >&2
  exit 1
fi
echo "scp_opts/ssh_opts port flags ok"
