# Phase 02 — Router unit

Read `plan-overview.md` first. Phase 01 is done: `build.sh`, `assets/`, stub
`src/httpsrv.lpr` with `TServerApp.HandleRequest` exist. Read `src/httpsrv.lpr` before editing.

## Steps
1. Create `src/router.pas` (`unit router;` `{$mode objfpc}{$H+}`), `uses SysUtils, Classes, fphttpserver;`
   - Handler type (same shape as fphttpserver's handler, without Sender):
     ```pascal
     TRouteHandler = procedure(var ARequest: TFPHTTPConnectionRequest;
       var AResponse: TFPHTTPConnectionResponse) of object;
     ```
   - Route record: `TRoute = record Path: string; Handler: TRouteHandler; end;`
   - `TRouter = class` with private `FRoutes: array of TRoute; FFallback: TRouteHandler;`
     - `procedure AddRoute(const APath: string; AHandler: TRouteHandler);`
     - `procedure SetFallback(AHandler: TRouteHandler);`
     - `procedure Dispatch(Sender: TObject; var ARequest: TFPHTTPConnectionRequest;
       var AResponse: TFPHTTPConnectionResponse);` — signature matches
       `THTTPServerRequestHandler`, so it can be assigned to `Server.OnRequest` directly.
     - `class function RequestPath(ARequest: TFPHTTPConnectionRequest): string;` —
       take `ARequest.URI`, cut everything from the first `?`; if empty return `/`.
       (Use `URI`, not `PathInfo`, since `PathInfo` may be empty for TFPHttpServer.
       Check `httpdefs.pp` if unsure.)
     - `class procedure SendNotFound(var AResponse: TFPHTTPConnectionResponse);` —
       code 404, `CodeText 'Not Found'`, `text/html; charset=utf-8`, small HTML body
       `<h1>404 Not Found</h1>`.
   - Dispatch: exact, case-sensitive match of the path against routes in order; call the
     handler. No match → `FFallback` if assigned, else `SendNotFound`.
     Wrap handler call in `try/except on E: Exception` → code 500, text body with
     `E.Message`; also `WriteLn` the error to stderr.
   - Log each request: `WriteLn(ARequest.Method, ' ', ARequest.URI, ' -> ', AResponse.Code)`
     after the handler runs.
2. Update `src/httpsrv.lpr`:
   - `uses ... router;`
   - Replace `TServerApp.HandleRequest` with a temporary route handler method
     `HandleRoot(var ARequest; var AResponse)` (typed params) returning `text/plain`
     body `root`.
   - Create `TRouter`, `Router.AddRoute('/', App.HandleRoot)`,
     `Server.OnRequest := Router.Dispatch`. Free router in `finally`.
3. Keep 2-space indentation; unit < 1000 lines.

## Verification
```bash
./build.sh
bin/httpsrv 18080 & PID=$!; sleep 1
curl -s http://localhost:18080/                                   # expect: root
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18080/nope    # expect: 404
curl -s 'http://localhost:18080/?x=1'                             # expect: root
kill $PID
```
Report: files changed, verification output.
