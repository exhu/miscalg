#!/usr/bin/env bash
set -u

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT" || exit 1

PORT=18080
BASE="http://localhost:$PORT"
FAILURES=0

./build.sh || { echo "BUILD FAILED"; exit 1; }

bin/httpsrv "$PORT" assets &
PID=$!
trap 'kill $PID 2>/dev/null' EXIT

ready=0
for _ in $(seq 1 50); do
  if curl -s "$BASE/" >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 0.1
done
if [ "$ready" -ne 1 ]; then
  echo "FAIL: server did not start on port $PORT"
  exit 1
fi

check() {
  local name="$1" cond="$2"
  if eval "$cond"; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    FAILURES=$((FAILURES + 1))
  fi
}

# Fetch helpers: body and status / content type into variables.
BODY=$(curl -s "$BASE/")
STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/")
check "/ status 200" '[ "$STATUS" = 200 ]'
check "/ body contains <form" 'grep -q "<form" <<<"$BODY"'

CTYPE=$(curl -s -o /dev/null -w '%{content_type}' "$BASE/style.css")
check "/style.css Content-Type contains text/css" 'grep -q "text/css" <<<"$CTYPE"'

BODY=$(curl -s "$BASE/hello?name=Yury")
check "/hello?name=Yury contains 'hello, Yury!'" 'grep -q "hello, Yury!" <<<"$BODY"'

BODY=$(curl -s "$BASE/hello?name=John+Doe")
check "/hello?name=John+Doe contains 'hello, John Doe!'" 'grep -q "hello, John Doe!" <<<"$BODY"'

BODY=$(curl -s "$BASE/hello?name=%3Cb%3E")
check "/hello?name=%3Cb%3E contains &lt;b&gt;" 'grep -q "&lt;b&gt;" <<<"$BODY"'
check "/hello?name=%3Cb%3E does not contain <b>" '! grep -q "<b>" <<<"$BODY"'

BODY=$(curl -s "$BASE/hello")
check "/hello (no name) contains 'hello, stranger!'" 'grep -q "hello, stranger!" <<<"$BODY"'

BODY=$(curl -s -d 'name=Ann' "$BASE/hello")
check "POST /hello name=Ann contains 'hello, Ann!'" 'grep -q "hello, Ann!" <<<"$BODY"'

STATUS=$(curl -s -o /dev/null -w '%{http_code}' "$BASE/missing")
check "/missing status 404" '[ "$STATUS" = 404 ]'

STATUS=$(curl -s -o /dev/null -w '%{http_code}' --path-as-is "$BASE/../src/httpsrv.lpr")
check "--path-as-is /../src/httpsrv.lpr status not 200" '[ "$STATUS" != 200 ]'

if [ "$FAILURES" -eq 0 ]; then
  echo "ALL PASS"
  exit 0
else
  echo "$FAILURES FAILURE(S)"
  exit 1
fi
