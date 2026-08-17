#!/usr/bin/env bash
# --version, doctor, audit: exist, run, and stay honest.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "FAIL $*" >&2; exit 1; }

ver="$("$ROOT/fakevps" --version)"
printf '%s\n' "$ver" | grep -qE '^FakeVPS [0-9]+\.[0-9]+\.[0-9]+' || fail "--version has no semver"
printf '%s\n' "$ver" | grep -q 'https://github.com/Mr-Aurevo-X/FakeVPS' || fail "--version missing origin URL"

help_out="$("$ROOT/fakevps" --help)"
printf '%s\n' "$help_out" | grep -q 'doctor' || fail "help missing doctor"
printf '%s\n' "$help_out" | grep -q 'audit' || fail "help missing audit"

# doctor and audit must run to completion on any host (exit 0 or 1, never crash).
doc_out="$("$ROOT/fakevps" doctor 2>&1)" || true
printf '%s\n' "$doc_out" | grep -q 'FakeVPS doctor' || fail "doctor did not run"
printf '%s\n' "$doc_out" | grep -qE '[0-9]+ fail, [0-9]+ warn' || fail "doctor has no summary"

aud_out="$("$ROOT/fakevps" audit 2>&1)" || true
printf '%s\n' "$aud_out" | grep -q 'FakeVPS audit' || fail "audit did not run"

# The changelog exists and matches the CLI version.
[[ -f "$ROOT/CHANGELOG.md" ]] || fail "CHANGELOG.md missing"
cli_ver="$(printf '%s\n' "$ver" | head -1 | awk '{print $2}')"
grep -q "## ${cli_ver}" "$ROOT/CHANGELOG.md" || fail "CHANGELOG.md has no entry for ${cli_ver}"

# attach must expand a literal quoted "~" itself (copy-pasted commands).
if out="$("$ROOT/fakevps" attach '~/fakevps-missing-dir-xyz' 2>&1)"; then
  fail "attach on a missing dir did not fail"
else
  printf '%s\n' "$out" | grep -q "not a directory: $HOME/fakevps-missing-dir-xyz" \
    || fail "attach did not expand ~ (got: $out)"
fi

# Suggested cockpit commands must never contain a quoted, unexpandable tilde.
grep -q '\\"~/' "$ROOT/ui/app.js" && fail "quoted tilde back in app.js fix commands"
grep -q 'diag.empty-app.t' "$ROOT/ui/app.js" || fail "empty-app diagnostic missing"
grep -q 'lastStatus.force_diag = false' "$ROOT/ui/app.js" || fail "force_diag one-shot reset missing"

echo "cli-basics tests passed"
