# Phase 03 — Static files

Read `plan-overview.md` first. Phases 01–02 are done: `src/router.pas` (`TRouter`,
`TRouteHandler`, `RequestPath`, `SendNotFound`) and `src/httpsrv.lpr` exist. Read both
before editing.

## Steps
1. Create `src/staticfiles.pas` (`unit staticfiles;` `{$mode objfpc}{$H+}`),
   `uses SysUtils, Classes, fphttpserver, fpmimetypes, router;`
   - `TStaticFiles = class`
     - `constructor Create(const ARoot: string);` — store
       `IncludeTrailingPathDelimiter(ExpandFileName(ARoot))`. Load MIME types:
       `if FileExists('/etc/mime.types') then MimeTypes.LoadFromFile('/etc/mime.types');`
     - `function MimeTypeFor(const AFileName: string): string;` — built-in table first for
       `.html/.htm` → `text/html; charset=utf-8`, `.css` → `text/css`, `.js` →
       `application/javascript`, `.png` `image/png`, `.jpg/.jpeg` `image/jpeg`,
       `.svg` `image/svg+xml`, `.txt` `text/plain; charset=utf-8`, `.ico` `image/x-icon`;
       otherwise `MimeTypes.GetMimeType(ext without dot)`; empty → `application/octet-stream`.
     - `function Serve(const ARelPath: string; var AResponse: TFPHTTPConnectionResponse): Boolean;`
       Returns True if a file was sent.
       - Decode percent-escapes first (`HTTPDecode` from `httpdefs`, or a small local decoder).
       - Reject (return False) if the decoded path contains `..`, `#0`, `\`, or is empty.
       - Strip leading `/`; full := `ExpandFileName(FRoot + rel)`; require
         `Pos(FRoot, full) = 1` and `FileExists(full)` and not a directory.
       - Read the file into `AResponse.ContentStream` via `TFileStream.Create(full,
         fmOpenRead or fmShareDenyWrite)`, set `AResponse.FreeContentStream := True`,
         `Code := 200`, `ContentType := MimeTypeFor(full)`,
         `ContentLength := stream.Size`.
     - `procedure HandleIndex(var ARequest; var AResponse)` (TRouteHandler shape) —
       `Serve('/index.html', ...)`, else `TRouter.SendNotFound`.
     - `procedure HandleStatic(var ARequest; var AResponse)` (TRouteHandler shape) —
       `Serve(TRouter.RequestPath(ARequest), ...)`, else `TRouter.SendNotFound`.
2. Update `src/httpsrv.lpr`:
   - Assets dir: `ParamStr(2)` if `ParamCount >= 2`, else
     `ExtractFilePath(ParamStr(0)) + '../assets'`. Print it at startup.
   - Create `TStaticFiles`; `Router.AddRoute('/', Static.HandleIndex)`;
     `Router.SetFallback(Static.HandleStatic)`. Remove the temporary `HandleRoot`
     (and `TServerApp` if now unused). Free in `finally`.
3. 2-space indentation; units < 1000 lines.

## Verification
```bash
./build.sh
bin/httpsrv 18080 & PID=$!; sleep 1
curl -s -i http://localhost:18080/ | head -5               # 200, text/html, then contains <form
curl -s -i http://localhost:18080/style.css | head -5      # 200, text/css
curl -s -o /dev/null -w '%{http_code}\n' http://localhost:18080/missing.txt      # 404
curl -s -o /dev/null -w '%{http_code}\n' --path-as-is http://localhost:18080/../src/httpsrv.lpr   # not 200
curl -s -o /dev/null -w '%{http_code}\n' --path-as-is http://localhost:18080/%2e%2e/src/httpsrv.lpr # not 200
kill $PID
```
Report: files changed, verification output.
