# Phase 04 — /hello handler & smoke tests

Read `plan-overview.md` first. Phases 01–03 are done: `src/router.pas`,
`src/staticfiles.pas`, `src/httpsrv.lpr`, `assets/index.html` (form GET → `/hello`,
field `name`). Read `src/httpsrv.lpr` and `src/router.pas` before editing.

## Steps
1. Create `src/handlers.pas` (`unit handlers;` `{$mode objfpc}{$H+}`),
   `uses SysUtils, Classes, fphttpserver;`
   - `function HtmlEscape(const S: string): string;` — replace `&` (first!) → `&amp;`,
     `<` → `&lt;`, `>` → `&gt;`, `"` → `&quot;`, `'` → `&#39;`.
   - `THandlers = class` with
     `procedure HandleHello(var ARequest: TFPHTTPConnectionRequest;
     var AResponse: TFPHTTPConnectionResponse);`
     - name := `ARequest.QueryFields.Values['name']`; if empty, try
       `ARequest.ContentFields.Values['name']` (POST support). `Trim` it.
       (The fields are already URL-decoded by httpdefs; verify `+` → space works.)
     - empty → `'stranger'`.
     - Response: code 200, `text/html; charset=utf-8`, body:
       ```html
       <!DOCTYPE html>
       <html><head><meta charset="utf-8"><title>Hello</title>
       <link rel="stylesheet" href="/style.css"></head>
       <body><h1>hello, NAME!</h1><p><a href="/">Back</a></p></body></html>
       ```
       with `NAME` = `HtmlEscape(name)`.
2. Update `src/httpsrv.lpr`: `uses ... handlers;` create `THandlers`,
   `Router.AddRoute('/hello', Handlers.HandleHello)`; free in `finally`.
   Ensure no handler logic remains in the .lpr (only setup code).
3. Create `tests/smoke.sh` (`chmod +x`), bash, `set -u`:
   - `cd` to project root (`$(dirname "$0")/..`), run `./build.sh`.
   - Start `bin/httpsrv 18080 assets &`, save PID, `trap 'kill $PID 2>/dev/null' EXIT`,
     wait until `curl -s localhost:18080/` succeeds (loop up to ~5 s).
   - Helper `check NAME CONDITION` printing `PASS: NAME` / `FAIL: NAME`, counting failures.
   - Checks:
     - `/` status 200 and body contains `<form`
     - `/style.css` Content-Type contains `text/css`
     - `/hello?name=Yury` body contains `hello, Yury!`
     - `/hello?name=John+Doe` body contains `hello, John Doe!`
     - `/hello?name=%3Cb%3E` body contains `&lt;b&gt;` and not `<b>`
     - `/hello` (no name) body contains `hello, stranger!`
     - POST `-d 'name=Ann'` to `/hello` contains `hello, Ann!`
     - `/missing` status 404
     - `--path-as-is /../src/httpsrv.lpr` status not 200
   - Exit 1 if any failure, else print `ALL PASS`.
4. Code rule check: `wc -l src/*` (all < 1000), `grep -nP '\t' src/*` (no tabs),
   2-space indentation visually consistent.

## Verification
```bash
tests/smoke.sh     # expect ALL PASS
```
Report: files changed, full smoke.sh output, line counts.
