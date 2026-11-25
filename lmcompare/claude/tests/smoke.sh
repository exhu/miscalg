#!/usr/bin/env bash
set -u
cd "$(dirname "$0")/.."
./build.sh || exit 1

PORT=18080
URL="localhost:$PORT"
bin/httpsrv $PORT assets >"${SERVER_LOG:-/dev/null}" 2>&1 &
PID=$!
trap 'kill $PID 2>/dev/null' EXIT

for _ in $(seq 1 50); do
  curl -s "$URL/" >/dev/null && break
  sleep 0.1
done

FAILS=0
check() {
  local name=$1; shift
  if "$@"; then echo "PASS: $name"; else echo "FAIL: $name"; FAILS=$((FAILS + 1)); fi
}
status() { curl -s -o /dev/null -w '%{http_code}' "$@"; }
body_has() { local pat=$1; shift; curl -s "$@" | grep -qF -- "$pat"; }
body_lacks() { local pat=$1; shift; ! curl -s "$@" | grep -qF -- "$pat"; }

check "/ status 200" test "$(status "$URL/")" = 200
check "/ contains form" body_has '<form' "$URL/"
check "/style.css content-type" bash -c "curl -sI '$URL/style.css' | grep -i '^content-type:.*text/css'"
check "hello Yury" body_has 'hello, Yury!' "$URL/hello?name=Yury"
check "hello plus decoded" body_has 'hello, John Doe!' "$URL/hello?name=John+Doe"
check "hello escaped" body_has '&lt;b&gt;' "$URL/hello?name=%3Cb%3E"
check "hello not raw" body_lacks '<b>' "$URL/hello?name=%3Cb%3E"
check "hello stranger" body_has 'hello, stranger!' "$URL/hello"
check "hello POST" body_has 'hello, Ann!' -d 'name=Ann' "$URL/hello"
check "/missing 404" test "$(status "$URL/missing")" = 404
check "traversal blocked" test "$(status --path-as-is "$URL/../src/httpsrv.lpr")" != 200

kill -TERM $PID 2>/dev/null && wait $PID 2>/dev/null
check "clean shutdown" test $? = 0

if [ "$FAILS" -ne 0 ]; then echo "$FAILS FAILED"; exit 1; fi
echo "ALL PASS"
