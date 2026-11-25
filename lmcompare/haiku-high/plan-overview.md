# Minimal FreePascal HTTP Server — Plan Overview

## Goal
A minimal HTTP server written in FreePascal (`{$mode objfpc}{$H+}`) with its own
simple router. It serves static files from `assets/` and handles a form submission.

Routes:
- `/` — serves `assets/index.html`: one line describing the program and a form with
  a text input (`name`) and a submit button. The form submits to `/hello`.
- `/hello` — responds with an HTML page `hello, <name>!`.
- anything else — tries a static file under `assets/`, otherwise 404.

## Environment
- FPC 3.2.2, fcl-web available. Sources at `/usr/share/fpcsrc/3.2.2/packages/fcl-web/src/base/`
  (see `fphttpserver.pp`, `httpdefs.pp`, `fpmimetypes.pp` when an API detail is unclear).
- `TFPHttpServer` (unit `fphttpserver`) is used ONLY as transport. Routing is our own unit.
  Do not use `httproute`, `fphttpapp`, `custhttpapp`.
- Request handler signature from `fphttpserver`:
  ```pascal
  THTTPServerRequestHandler = procedure(Sender: TObject;
    var ARequest: TFPHTTPConnectionRequest;
    var AResponse: TFPHTTPConnectionResponse) of object;
  ```

## Directory layout (project root = directory containing this file)
```
assets/              static content (index.html, style.css)
src/                 Pascal sources
  httpsrv.lpr        main program
  router.pas         TRouter (phase 02)
  staticfiles.pas    TStaticFiles (phase 03)
  handlers.pas       route handlers, HtmlEscape (phase 04)
tests/smoke.sh       curl end-to-end tests (phase 04)
build.sh             build script
build/, bin/         build output (git-ignored)
```

## Shared code rules (apply to every phase)
- Every Pascal file starts with `{$mode objfpc}{$H+}`.
- 2-space indentation, no tabs.
- Every unit / program file is under 1000 lines.
- Keep it minimal; no extra dependencies beyond FPC RTL/FCL.
- Build with `./build.sh`, which runs:
  `fpc -Mobjfpc -Sh -FUbuild -FEbin -obin/httpsrv src/httpsrv.lpr` (creating `build/` and `bin/`).
- CLI: `bin/httpsrv [port] [assets-dir]` — default port 8080, default assets dir
  `<exe dir>/../assets`.
- When testing a running server, always start it in the background and kill it
  afterwards (`kill $PID`); never leave it running.
- Do not make git commits.

## Phases
Run phases in order. Each phase is executed by a NEW subagent with the prompt:
"Implement `plan-NN.md` in this project directory. Read
`plan-overview.md` first for shared rules. Report what you did and the verification results."
Do not start a phase until the previous one reports success.

| Phase | Doc | Goal | Done when |
|-------|-----|------|-----------|
| 01 | [plan-01.md](plan-01.md) | Scaffold dirs, assets, build script, stub server | `curl /` returns `ok` |
| 02 | [plan-02.md](plan-02.md) | Router unit and wiring | `/` hits a route, `/nope` → 404 |
| 03 | [plan-03.md](plan-03.md) | Static file serving from `assets/` | `/` returns index.html, traversal blocked |
| 04 | [plan-04.md](plan-04.md) | `/hello` handler + smoke tests | `tests/smoke.sh` all PASS |
