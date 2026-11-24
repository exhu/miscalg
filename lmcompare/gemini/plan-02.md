# Phase 02: HTTP Utilities & Static File Serving (`src/uhttpfiles.pas`)

## Objective

Implement `src/uhttpfiles.pas` providing HTML escaping, MIME type detection, path traversal protection, safe asset path resolution, HTML/error response helpers, and static file streaming.

## Coding Rules

- Must begin with `unit uhttpfiles;` and `{$mode objfpc}{$H+}`.
- Strictly 2-space indentation, zero tab characters (`\t`).
- Strictly under 1000 lines.

## Step-by-Step Instructions

1. **Create `src/uhttpfiles.pas`** using `Classes, SysUtils, httpdefs, fpmimetypes`.

2. **Declare and implement the following routines in `interface` and `implementation`**:
   - `function EscapeHtml(const AText: string): string;`
     - Escapes `&` -> `&amp;`, `<` -> `&lt;`, `>` -> `&gt;`, `"` -> `&quot;`, `'` -> `&#39;`.
   - `function GetMimeTypeForFile(const AFileName: string): string;`
     - Extracts lowercase extension via `LowerCase(ExtractFileExt(AFileName))`.
     - Built-in map:
       - `.html`, `.htm` -> `'text/html; charset=utf-8'`
       - `.css` -> `'text/css; charset=utf-8'`
       - `.js` -> `'application/javascript; charset=utf-8'`
       - `.txt` -> `'text/plain; charset=utf-8'`
       - `.json` -> `'application/json; charset=utf-8'`
       - `.svg` -> `'image/svg+xml'`
       - `.png` -> `'image/png'`
       - `.jpg`, `.jpeg` -> `'image/jpeg'`
       - `.gif` -> `'image/gif'`
       - `.ico` -> `'image/x-icon'`
     - If not matched in the built-in map, lazily load `fpmimetypes.MimeTypes` once (calling `MimeTypes.LoadKnownTypes` if `FileExists('/etc/mime.types')`) and query `MimeTypes.GetMimeType(Ext)`.
     - Fall back to `'application/octet-stream'` if still empty.
   - `function IsPathTraversalAttempt(const AUrlPath: string): Boolean;`
     - Returns `True` if `AUrlPath` contains `#0`, `'\'`, or a `'..'` path segment (e.g., exact `'..'`, starts with `'../'`, ends with `'/..'`, or contains `'..'` as any `'/'`-delimited segment).
   - `function ResolveSafeAssetPath(const AAssetsDir, AUrlPath: string; out AFullPath: string): Boolean;`
     - Rejects empty `AUrlPath`, rejects `IsPathTraversalAttempt(AUrlPath)`.
     - Expands `AAssetsDir` via `IncludeTrailingPathDelimiter(ExpandFileName(AAssetsDir))`.
     - Strips leading `'/'` characters from `AUrlPath` (returning `False` if nothing remains).
     - Combines expanded root with relative path and calls `ExpandFileName(...)`.
     - Verifies the resolved path starts with the expanded root directory (using `Copy(Candidate, 1, Length(RootDir)) = RootDir`) and checks `FileExists(Candidate) and (not DirectoryExists(Candidate))`.
   - `procedure SendHtmlResponse(AResponse: TResponse; AStatusCode: Integer; const AHtml: string);`
     - Sets `AResponse.Code := AStatusCode`, `AResponse.ContentType := 'text/html; charset=utf-8'`, `AResponse.Content := AHtml`.
   - `procedure SendErrorResponse(AResponse: TResponse; AStatusCode: Integer; const AMessage: string);`
     - Renders a minimal HTML5 error page with HTML-escaped status code and message via `SendHtmlResponse`.
   - `function ServeStaticFile(const AAssetsDir, AUrlPath: string; AResponse: TResponse): Boolean;`
     - First checks `IsPathTraversalAttempt(AUrlPath)`: if `True`, sends `403` via `SendErrorResponse(AResponse, 403, '403 Forbidden')` and returns `True`.
     - Otherwise calls `ResolveSafeAssetPath(AAssetsDir, AUrlPath, FullPath)`. If `False`, returns `False`.
     - Opens `FileStream := TFileStream.Create(FullPath, fmOpenRead or fmShareDenyWrite)`.
     - Sets `AResponse.Code := 200`, `AResponse.ContentType := GetMimeTypeForFile(FullPath)`, `AResponse.ContentStream := FileStream`, `AResponse.FreeContentStream := True` (setting `ContentStream` automatically sets `ContentLength` in `httpdefs`).
     - Returns `True`.

3. **Verify compilation and style**:
   - Run `fpc -Mobjfpc -Sh -FUbuild -Fusrc src/uhttpfiles.pas`
   - Run `wc -l src/uhttpfiles.pas` (must be `< 1000`) and `! grep -P '\t' src/uhttpfiles.pas` (must have zero tabs).
