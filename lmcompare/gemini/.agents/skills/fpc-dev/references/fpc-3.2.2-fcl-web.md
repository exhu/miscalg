# FPC 3.2.2 (`fcl-web` & Linux RTL) Reference

## Local Paths (Verified)
- Compiler: `/usr/bin/fpc` (`3.2.2`)
- `fcl-web` units: `/usr/lib/fpc/3.2.2/units/x86_64-linux/fcl-web/`
- `fcl-web` sources: `/usr/share/fpcsrc/3.2.2/packages/fcl-web/src/base/`
  - `fphttpserver.pp`
  - `httpdefs.pp`
  - `fpmimetypes.pp`
- System MIME types: `/etc/mime.types`

## Verified Quirks & Signatures
1. **Output path with `-o`**: When compiling `src/server.pas`, pass `-FE. -ohttpserver`. Without `-FE.`, FPC places the binary in `src/httpserver`.
2. **Root `PathInfo` in `TFPHttpServer`**: `fphttpserver.pp` (`ParseStartLine`) converts `/` into `ARequest.PathInfo := ''`. Routers must normalize `''` to `'/'`.
3. **`TFPHttpServer.Address` visibility**: `Address` is `protected` on `TFPCustomHttpServer` and not published on `TFPHttpServer`; omit assigning it to bind `TInetServer.Create(FPort)`.
4. **`TResponse.ContentStream`**: Assigning `AResponse.ContentStream := Stream` in `httpdefs.pp` sets `ContentLength := Stream.Size` automatically; set `FreeContentStream := True` so the stream is freed after sending.
5. **Unix signal handling**: Use `BaseUnix` (`{$IFDEF UNIX}`) with `procedure HandleUnixSignal(ASig: cint); cdecl;` and register via `FpSignal(SIGINT, SignalHandler(@HandleUnixSignal))`.
