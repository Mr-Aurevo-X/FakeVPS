#!/usr/bin/env bash
# Remove user-owned leftovers from a FakeVPS working copy.
# Does not sudo. A root-owned Docker graph must be deleted by the operator.
# Copyright (c) 2026 Mr-Aurevo-X
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

if [[ ! -d .git ]]; then
  printf 'error: refuse to sanitize a non-git tree (would wipe a private copy)\n' >&2
  exit 1
fi
if [[ -f PRIVATE.md ]]; then
  printf 'error: refuse to sanitize a private tree\n' >&2
  exit 1
fi
printf 'This is the git checkout. Removing leftover secrets/state that git ignores.\n'

rm -f config.env secrets/discord.env secrets/vps_ed25519 secrets/vps_ed25519.pub

if [[ -d state ]]; then
  if [[ -d state/fast/docker && ! -w state/fast/docker ]]; then
    printf 'left in place (not writable, often root): state/fast/docker\n' >&2
    printf 'do not zip this folder; use git archive or a clone\n' >&2
  fi
  find state -user "$(id -u)" -writable -delete 2>/dev/null || true
fi

printf 'sanitize done. Public artifact = git repo, not a folder dump.\n'
