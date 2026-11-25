# Phase 01 — Scaffold & build

Read `plan-overview.md` first. Work in the project root.

## Steps
1. Create directories: `assets/`, `src/`, `tests/`.
2. Create `.gitignore` with:
   ```
   build/
   bin/
   ```
3. Create `build.sh` (make it executable, `chmod +x`):
   ```bash
   #!/usr/bin/env bash
   set -euo pipefail
   cd "$(dirname "$0")"
   mkdir -p build bin
   fpc -Mobjfpc -Sh -FUbuild -FEbin -obin/httpsrv src/httpsrv.lpr
   ```
4. Create `assets/index.html` (valid HTML5, UTF-8):
   - `<title>FreePascal HTTP server</title>`, `<link rel="stylesheet" href="/style.css">`
   - one paragraph: "A minimal HTTP server written in FreePascal (ObjFPC mode) with simple routing."
   - form:
     ```html
     <form action="/hello" method="get">
       <label for="name">Type your name:</label>
       <input type="text" id="name" name="name" required>
       <button type="submit">Submit</button>
     </form>
     ```
5. Create `assets/style.css` with a few rules (body font/margin, form spacing). Keep it short.
6. Create stub `src/httpsrv.lpr`:
   - `program httpsrv;` `{$mode objfpc}{$H+}`
   - `uses {$ifdef unix}cthreads,{$endif} SysUtils, Classes, fphttpserver;`
   - A small class `TServerApp = class` with method
     `procedure HandleRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
     var AResponse: TFPHTTPConnectionResponse);` that sets `AResponse.Code := 200`,
     `AResponse.ContentType := 'text/plain'`, `AResponse.Content := 'ok'`.
   - Main: port = `StrToIntDef(ParamStr(1), 8080)` if `ParamCount >= 1` else 8080.
     Create `TFPHttpServer.Create(nil)`, set `Port`, `OnRequest := App.HandleRequest`,
     `Threaded := False`; `WriteLn('Listening on http://localhost:', Port)`;
     `Server.Active := True` (blocks). Free objects in `try/finally`.
   - 2-space indentation.

## Verification
```bash
./build.sh
bin/httpsrv 18080 & PID=$!; sleep 1
curl -s http://localhost:18080/     # expect: ok
kill $PID
```
Fix any compile errors before reporting. Report: files created, build output summary, curl result.
