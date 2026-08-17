#!/usr/bin/env bash
# Session token, bot-logs endpoint, streaming and i18n wiring.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

fail() { echo "FAIL $*" >&2; exit 1; }

PORT=8799
TOKEN_FILE="$ROOT/state/ui.token"
saved_token=""
[[ -f "$TOKEN_FILE" ]] && saved_token="$(cat "$TOKEN_FILE")"

cleanup() {
  [[ -n "${SRV_PID:-}" ]] && kill "$SRV_PID" 2>/dev/null || true
  if [[ -n "$saved_token" ]]; then printf '%s\n' "$saved_token" >"$TOKEN_FILE"; fi
}
trap cleanup EXIT

FAKEVPS_ROOT="$ROOT" UI_PORT="$PORT" python3 "$ROOT/lib/ui_server.py" >/dev/null 2>&1 &
SRV_PID=$!
for _ in $(seq 1 50); do
  curl -fsS "http://127.0.0.1:$PORT/api/status" >/dev/null 2>&1 && break
  sleep 0.1
done

# Token file exists and is private.
[[ -f "$TOKEN_FILE" ]] || fail "state/ui.token not created"
[[ "$(stat -c '%a' "$TOKEN_FILE")" == "600" ]] || fail "ui.token is not 600"
token="$(tr -d '[:space:]' <"$TOKEN_FILE")"
[[ -n "$token" ]] || fail "ui.token empty"

# POSTs without the token are refused; with it they reach dispatch.
ORIGIN="Origin: http://127.0.0.1:$PORT"
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$ORIGIN" "http://127.0.0.1:$PORT/api/nope")"
[[ "$code" == "403" ]] || fail "POST without token returned $code (want 403)"
code="$(curl -s -o /dev/null -w '%{http_code}' -X POST -H "$ORIGIN" -H "X-FakeVPS-Token: $token" "http://127.0.0.1:$PORT/api/nope")"
[[ "$code" != "403" ]] || fail "POST with token still 403"

# Browse requires the token too (it lists the home tree).
code="$(curl -s -o /dev/null -w '%{http_code}' "http://127.0.0.1:$PORT/api/browse?path=~")"
[[ "$code" == "403" ]] || fail "browse without token returned $code (want 403)"
curl -fsS -H "X-FakeVPS-Token: $token" "http://127.0.0.1:$PORT/api/browse?path=~" | grep -q '"dirs"' \
  || fail "browse with token failed"

# Status stays open (redacted, read-only).
curl -fsS "http://127.0.0.1:$PORT/api/status" | grep -q '"running"' || fail "status broken"

kill "$SRV_PID" 2>/dev/null || true
wait "$SRV_PID" 2>/dev/null || true
SRV_PID=""

# Static wiring: client token header, streaming attach, bot logs, i18n.
grep -q 'X-FakeVPS-Token' "$ROOT/ui/app.js" || fail "app.js does not send the token"
grep -q '/api/attach?stream=1' "$ROOT/ui/app.js" || fail "attach is not streamed"
grep -q '/api/bot-logs' "$ROOT/ui/app.js" || fail "app.js missing bot-logs"
grep -q '_stream_fakevps' "$ROOT/lib/ui_server.py" || fail "server missing stream helper"
grep -q 'BOT_LOGS_SCRIPT' "$ROOT/lib/ui_server.py" || fail "server missing bot logs script"
grep -q 'lang-toggle' "$ROOT/ui/index.html" || fail "index.html missing language toggle"
grep -qE '^\s*en: \{' "$ROOT/ui/app.js" || fail "app.js missing english dictionary"
grep -q 'data-i18n' "$ROOT/ui/index.html" || fail "index.html missing i18n attributes"
grep -q 'ui_url()' "$ROOT/lib/ui-server.sh" || fail "ui-server.sh missing ui_url"

echo "cockpit-session tests passed"
