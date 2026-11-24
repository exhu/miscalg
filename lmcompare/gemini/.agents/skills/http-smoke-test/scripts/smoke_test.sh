#!/usr/bin/env bash
set -euo pipefail

BINARY="${1:-./httpserver}"
PORT="${2:-18080}"
ASSETS_DIR="${3:-assets}"
BASE_URL="http://127.0.0.1:${PORT}"

if [ ! -x "$BINARY" ]; then
  echo "FAIL: server binary not executable: $BINARY" >&2
  exit 1
fi

TMPDIR_PATH="$(mktemp -d)"
SERVER_PID=""

cleanup() {
  if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
    kill "$SERVER_PID" 2>/dev/null || true
    wait "$SERVER_PID" 2>/dev/null || true
  fi
  rm -rf "$TMPDIR_PATH"
}
trap cleanup EXIT

"$BINARY" --port "$PORT" --assets "$ASSETS_DIR" >"$TMPDIR_PATH/server.log" 2>&1 &
SERVER_PID=$!

ready=0
for _ in $(seq 1 30); do
  if curl -s -o /dev/null "${BASE_URL}/"; then
    ready=1
    break
  fi
  sleep 0.1
done

if [ "$ready" -ne 1 ]; then
  echo "FAIL: server did not become ready within 3s" >&2
  cat "$TMPDIR_PATH/server.log" >&2 || true
  exit 1
fi

HDR="$TMPDIR_PATH/hdr"
BODY="$TMPDIR_PATH/body"
CODE=""

check_req() {
  local label="$1"
  shift
  CODE="$(curl -sS -D "$HDR" -o "$BODY" -w "%{http_code}" "$@")"
  echo "=== ${label} (HTTP ${CODE}) ==="
}

check_req "Test 1: GET /" "${BASE_URL}/"
test "$CODE" = "200"
grep -qi "^Content-Type:.*text/html" "$HDR"
grep -q "<form" "$BODY"
grep -q 'action="/hello"' "$BODY"
grep -q 'name="name"' "$BODY"
grep -qiE 'type="submit"|<button' "$BODY"
grep -qi "FreePascal" "$BODY"
echo "Test 1 PASS"

check_req "Test 2: GET /style.css" "${BASE_URL}/style.css"
test "$CODE" = "200"
grep -qi "^Content-Type:.*text/css" "$HDR"
test -s "$BODY"
echo "Test 2 PASS"

check_req "Test 3: GET /hello?name=Alice" "${BASE_URL}/hello?name=Alice"
test "$CODE" = "200"
grep -qi "^Content-Type:.*text/html" "$HDR"
grep -q "hello, Alice!" "$BODY"
echo "Test 3 PASS"

check_req "Test 4: POST /hello" -X POST -d "name=Bob" "${BASE_URL}/hello"
test "$CODE" = "200"
grep -qi "^Content-Type:.*text/html" "$HDR"
grep -q "hello, Bob!" "$BODY"
echo "Test 4 PASS"

check_req "Test 5: GET /hello?name=Ada+Lovelace" "${BASE_URL}/hello?name=Ada+Lovelace"
test "$CODE" = "200"
grep -q "hello, Ada Lovelace!" "$BODY"
echo "Test 5 PASS"

check_req "Test 6: XSS escaping" "${BASE_URL}/hello?name=%3Cscript%3Ealert(1)%3C/script%3E"
test "$CODE" = "200"
grep -q "&lt;script&gt;" "$BODY"
if grep -q "<script>" "$BODY"; then
  echo "FAIL: unescaped <script> found" >&2
  exit 1
fi
echo "Test 6 PASS"

check_req "Test 7: GET /hello empty name" "${BASE_URL}/hello"
test "$CODE" = "200"
grep -q "hello, World!" "$BODY"
echo "Test 7 PASS"

check_req "Test 8: GET /missing.html" "${BASE_URL}/missing.html"
test "$CODE" = "404"
echo "Test 8 PASS"

check_req "Test 9: Path traversal" --path-as-is "${BASE_URL}/../src/server.pas"
test "$CODE" = "403" -o "$CODE" = "404"
if grep -q "program server" "$BODY"; then
  echo "FAIL: source file leaked via path traversal" >&2
  exit 1
fi
echo "Test 9 PASS"

check_req "Test 10: POST /" -X POST "${BASE_URL}/"
test "$CODE" = "405"
echo "Test 10 PASS"

kill -TERM "$SERVER_PID"
wait "$SERVER_PID"
EXIT_CODE=$?
SERVER_PID=""
test "$EXIT_CODE" -eq 0
echo "Test 11 PASS: clean SIGTERM shutdown (exit 0)"
echo "ALL SMOKE TESTS PASSED"
