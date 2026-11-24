# Phase 05: End-to-End Integration Testing & Verification

## Objective

Perform a clean rebuild, verify Pascal coding rules across all source files, and run live `curl` integration tests against `./httpserver`, fixing any defects found and re-testing until all checks pass.

## Step-by-Step Instructions

1. **Clean rebuild**:
   ```bash
   rm -rf build httpserver && mkdir -p build && fpc -Mobjfpc -Sh -O2 -FUbuild -Fusrc -FE. -ohttpserver src/server.pas
   ```

2. **Static code checks on `src/*.pas`**:
   - Confirm every `.pas` file contains `{$mode objfpc}`.
   - Confirm `wc -l src/*.pas` shows every file strictly under 1000 lines.
   - Confirm zero tab characters (`! grep -P '\t' src/*.pas`) and 2-space indentation.

3. **Live integration tests** (in a single shell script that starts `./httpserver --port 18080 --assets assets` in the background with `trap 'kill $PID 2>/dev/null || true' EXIT`, waits up to 3s for port readiness, runs all checks, and verifies clean `SIGTERM` exit):
   - **Test 1 (`GET /`)**: HTTP `200`, `Content-Type` contains `text/html`, body contains `<form`, `action="/hello"`, `name="name"`, submit button, and program description text.
   - **Test 2 (`GET /style.css`)**: HTTP `200`, `Content-Type` contains `text/css`, non-empty body.
   - **Test 3 (`GET /hello?name=Alice`)**: HTTP `200`, `Content-Type` contains `text/html`, body contains `hello, Alice!`.
   - **Test 4 (`POST /hello` with `-d "name=Bob"`)**: HTTP `200`, `Content-Type` contains `text/html`, body contains `hello, Bob!`.
   - **Test 5 (`GET /hello?name=Ada+Lovelace`)**: HTTP `200`, body contains `hello, Ada Lovelace!`.
   - **Test 6 (XSS escaping `GET /hello?name=%3Cscript%3Ealert(1)%3C/script%3E`)**: HTTP `200`, body contains `&lt;script&gt;` and does NOT contain `<script>`.
   - **Test 7 (`GET /hello` with empty name)**: HTTP `200`, body contains `hello, World!`.
   - **Test 8 (`GET /missing.html`)**: HTTP `404`.
   - **Test 9 (path traversal `curl --path-as-is http://127.0.0.1:18080/../src/server.pas`)**: HTTP `403` or `404`, body does NOT contain `program server`.
   - **Test 10 (`POST /`)**: HTTP `405`.
   - **Test 11 (clean shutdown)**: `kill -TERM $PID`, `wait $PID`, verify exit code `0`.

4. **Handle failures (if any)**:
   - If any check fails, diagnose and fix the root cause in the relevant `src/*.pas` or `assets/*` file, rebuild cleanly, and re-run all checks until 100% pass.
   - Ensure no background `./httpserver` process remains running after tests finish.
