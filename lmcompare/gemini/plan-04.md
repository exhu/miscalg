# Phase 04: Route Handlers & Server Application (`src/uhandlers.pas`, `src/server.pas`)

## Objective

Implement the application route handlers in `src/uhandlers.pas` and the main HTTP server program in `src/server.pas`, then compile the `./httpserver` executable.

## Coding Rules

- Every unit/program must use `{$mode objfpc}{$H+}`.
- Strictly 2-space indentation, zero tab characters (`\t`).
- Strictly under 1000 lines per file.

## Step-by-Step Instructions

1. **Create `src/uhandlers.pas`** (`unit uhandlers; {$mode objfpc}{$H+}`), using `SysUtils, httpdefs, uhttpfiles`:
   - Define `TAppHandlers = class(TObject)`:
     - `private FAssetsDir: string;`
     - `public constructor Create(const AAssetsDir: string);`
     - `procedure HandleIndex(ARequest: TRequest; AResponse: TResponse);`
       - Calls `if not ServeStaticFile(FAssetsDir, '/index.html', AResponse) then SendErrorResponse(AResponse, 404, '404 index.html not found');`
     - `procedure HandleHello(ARequest: TRequest; AResponse: TResponse);`
       - Reads `RawName := Trim(ARequest.ContentFields.Values['name']);`
       - If `RawName = ''` then `RawName := Trim(ARequest.QueryFields.Values['name']);`
       - If `RawName = ''` then `RawName := 'World';`
       - Escapes with `SafeName := EscapeHtml(RawName);`
       - Builds a clean HTML5 page (linking `/style.css`, displaying `<h1>hello, ` + `SafeName` + `!</h1>`, and a `<p><a href="/">Back</a></p>` link) and calls `SendHtmlResponse(AResponse, 200, Html);`.
     - `procedure HandleStaticFallback(ARequest: TRequest; AResponse: TResponse);`
       - Checks `UpperCase(Trim(ARequest.Method))` is `'GET'` or `'HEAD'`; if not, calls `SendErrorResponse(AResponse, 405, '405 Method Not Allowed')` and exits.
       - Calls `if not ServeStaticFile(FAssetsDir, ARequest.PathInfo, AResponse) then SendErrorResponse(AResponse, 404, '404 Not Found');`

2. **Create `src/server.pas`** (`program server; {$mode objfpc}{$H+}`), using `SysUtils, Classes, {$IFDEF UNIX}BaseUnix,{$ENDIF} fphttpserver, httpdefs, uhttpfiles, urouter, uhandlers`:
   - Declare module-level `GStopRequested: Boolean = False;` and Unix signal handler:
     ```pascal
     {$IFDEF UNIX}
     procedure HandleUnixSignal(ASig: cint); cdecl;
     begin
       if (ASig = SIGINT) or (ASig = SIGTERM) then
         GStopRequested := True;
     end;
     {$ENDIF}
     ```
   - Define `TMinimalHttpApp = class(TObject)`:
     - Fields: `FServer: TFPHttpServer`, `FRouter: THttpRouter`, `FHandlers: TAppHandlers`, `FPort: Word`, `FAssetsDir: string`.
     - `HandleHttpRequest(Sender: TObject; var ARequest: TFPHTTPConnectionRequest; var AResponse: TFPHTTPConnectionResponse);`
       - Calls `FRouter.Dispatch(ARequest, AResponse)` inside `try ... except on E: Exception do SendErrorResponse(AResponse, 500, '500 Internal Server Error'); end;`.
     - `HandleAcceptIdle(Sender: TObject);`
       - If `GStopRequested` then `FServer.Active := False;`.
     - Register routes in `Create`:
       - `FRouter.AddRoute('GET', '/', @FHandlers.HandleIndex);`
       - `FRouter.AddRoute('GET', '/hello', @FHandlers.HandleHello);`
       - `FRouter.AddRoute('POST', '/hello', @FHandlers.HandleHello);`
       - `FRouter.SetFallbackHandler(@FHandlers.HandleStaticFallback);`
     - Configure `FServer`:
       - `FServer.Port := FPort;` (note: do NOT assign `FServer.Address`, as `Address` is protected in FPC 3.2.2 `TFPHttpServer`)
       - `FServer.Threaded := False;`
       - `FServer.AcceptIdleTimeout := 250;`
       - `FServer.OnRequest := @HandleHttpRequest;`
       - `FServer.OnAcceptIdle := @HandleAcceptIdle;`
     - `Run`: prints startup message (`WriteLn('HTTP server listening on http://127.0.0.1:', FPort, ' (assets: ', FAssetsDir, ')'); Flush(Output);`) and sets `FServer.Active := True;`.
   - Main program block:
     - Default `Port := 8080`, `AssetsDir := 'assets'`.
     - Parse CLI options `-p <port>` / `--port <port>`, `-a <dir>` / `--assets <dir>`, `-h` / `--help`.
     - Install signal handlers: `FpSignal(SIGINT, SignalHandler(@HandleUnixSignal));` and `FpSignal(SIGTERM, SignalHandler(@HandleUnixSignal));`.
     - Instantiate `TMinimalHttpApp.Create(Port, AssetsDir)` and run inside `try ... finally App.Free; end;`.

3. **Compile and verify**:
   - Run `mkdir -p build && fpc -Mobjfpc -Sh -O2 -FUbuild -Fusrc -FE. -ohttpserver src/server.pas`
   - Verify `./httpserver` exists, zero compiler errors, `wc -l src/*.pas` all `< 1000`, and `! grep -P '\t' src/*.pas`.
