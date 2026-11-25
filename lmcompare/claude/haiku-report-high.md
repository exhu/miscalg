# Security Review: src/staticfiles.pas

**Scope:** `src/staticfiles.pas` (`TStaticFiles.Create`, `Serve`, `MimeTypeFor`, `HandleIndex`, `HandleStatic`). `src/router.pas` and `src/httpsrv.lpr` were read only to trace how requests reach `Serve` and how exceptions are returned.
**Method:** Code reading, plus a dynamic test. I compiled the unmodified source with `fpc -Fusrc` into the session scratchpad (the repo was not changed) and ran it on localhost against a fixture root containing a dotfile, a `.git/` directory, a symlink to `/etc/hostname`, a symlink to `/etc/passwd`, a `chmod 000` file, a FIFO and a symlink to `/dev/zero`.

**Verdict:** Path traversal through the request URL is blocked. Three real issues remain, and two of them depend on who can write to the static root.

## Summary

| # | Finding | Severity | Confirmed |
|---|---------|----------|-----------|
| 1 | Dotfiles and dot-directories are served | Medium (if the root holds dotfiles) | Yes |
| 2 | Symlinks inside the root can point outside it | Medium (if the root is writable by untrusted parties) | Yes |
| 3 | Absolute server path leaked in the 500 response when a file cannot be opened | Low | Yes |
| 4 | Active content served same-origin with no security headers | Low (only if untrusted files can reach the root) | Code reading only |
| 5 | `FileExists` / `TFileStream` race (TOCTOU) | Info | Code reading only |

## Findings

### 1. Dotfiles are served (Medium, conditional)

`Serve` (lines 73–76) rejects `..`, NUL and `\`. It does not reject path segments that start with `.`.

Observed:

```
GET /.env       -> 200  application/octet-stream  "SECRET=1"
GET /.git/config -> 200 application/octet-stream  "x"
```

Impact depends on the root. The default root is `../assets` (`httpsrv.lpr:53`). The current `assets/` contains only `index.html` and `style.css`, so nothing is exposed today. If the root is ever set to a project directory, or someone puts a `.env`, `.git/`, or `.htpasswd` under it, those files are served.

**Fix:** in `Serve`, after the existing checks, reject any segment that begins with `.`:

```pascal
if (Pos('/.', '/' + Rel) > 0) then
  Exit;
```

### 2. Symlinks escape the root (Medium, conditional)

The containment check at line 82 is a string-prefix test on `ExpandFileName(FRoot + Rel)`. `ExpandFileName` normalises text only. It does not resolve symlinks. `FileExists`, `DirectoryExists` and `TFileStream.Create` all follow symlinks.

Observed:

```
GET /link-out -> 200  "tuxlap"                 (link-out -> /etc/hostname)
GET /sub/pw   -> 200  "root:x:0:0:root:/root:/bin/bash ..."  (sub/pw -> /etc/passwd)
```

Precondition: the attacker must be able to create a symlink under the root. That is a real risk if the assets tree is populated from elsewhere (a checkout, an archive, a shared volume, or a deployment step that symlinks in external content).

**Fix:** resolve both `FRoot` and the target to real paths (`realpath(3)` via the C library, or `fpReadlink` in a loop) and run the prefix check on the resolved paths. Alternatively, refuse any target whose resolved path differs from its normalised path.

### 3. Server path leaked on open failure (Low)

If the file exists but cannot be opened, `TFileStream.Create` (line 85) raises. The exception is caught in `TRouter.Dispatch` (`router.pas`), which returns `E.Message` as the body of a 500 response.

Observed (file `chmod 000`, requested as the owning user):

```
GET /locked.txt -> 500  text/plain
Unable to open file "/tmp/claude-1000/.../scratchpad/www/locked.txt" ...
```

The response reveals the absolute filesystem path of the static root and file. The cause is in `router.pas` (returning raw exception text to clients), but this module is where the exception is raised. It is also not logged as a 403 or 404, so a client can tell "exists but unreadable" from "missing".

**Fix:** in `Serve`, wrap the stream creation:

```pascal
try
  Stream := TFileStream.Create(Full, fmOpenRead or fmShareDenyWrite);
except
  on E: EFOpenError do
    Exit;   { treat as not found; the caller sends 404 }
end;
```

In addition, `Dispatch` should not echo `E.Message` to clients. That is outside this file, so it is noted here only.

### 4. Active content served same-origin, no security headers (Low, conditional)

`MimeTypeFor` (lines 35–64) sends `.html`, `.htm`, `.svg` and `.js` under their normal types. Everything else falls back to `/etc/mime.types` through `MimeTypes.GetMimeType` (line 60). That table can map types such as `.xhtml`, `.xml` or `.shtml` to active types as well. `Serve` sets no `X-Content-Type-Options` and no `Content-Security-Policy` (lines 86–91).

If untrusted content (user uploads, third-party files) can reach the root, an uploaded HTML or SVG file runs script in the site's origin. This was not tested dynamically. It follows from the code.

**Fix:** set `X-Content-Type-Options: nosniff` on every static response. Add a restrictive `Content-Security-Policy`. If user content must be served, serve it from a separate origin.

### 5. TOCTOU between existence check and open (Info)

`FileExists` (line 82) and `TFileStream.Create` (line 85) are separate calls. The file can change between them. The practical impact is small here, because `fmShareDenyWrite` and the fallback in finding 3 limit it. Folding the check into the `try` in finding 3 removes the window.

## Ruled out (tested)

Each probe was sent with `curl --path-as-is` against a root containing a known file outside it (the parent directory). All returned 404.

| Request | Result |
|---------|--------|
| `/%2e%2e/server.log` | 404 |
| `/..%2fserver.log` | 404 |
| `/%252e%252e/server.log` (double-encoded) | 404 |
| `/sub/%2e%2e/../server.log` | 404 |
| `/sub/..%2f..%2fserver.log` | 404 |
| `/%5c..%5cserver.log` (backslash) | 404 |
| `/%2e%2e%2fserver.log` | 404 |
| `/index.html%00.txt` (NUL) | 404 |

Other checks:

- **FIFO in the root:** `GET /fifo` returned 404 and the server kept serving. A FIFO does not hang the server.
- **Symlink to `/dev/zero`:** returned 200 with an empty body (`Stream.Size` is 0 for character devices), and the server kept serving. No unbounded stream.
- **Prefix sibling bypass:** `FRoot` has a trailing delimiter, so `/srv/www2` does not match a root of `/srv/www`. Confirmed by code reading.
- **Directories:** rejected by `DirectoryExists`, so there is no listing.

## Notes

- The server is single-threaded (`httpsrv.lpr:65`, `Threaded := False`). Any finding here that causes a long-running response would block all clients. None of the tested inputs did this.
- Default root: `ExtractFilePath(ParamStr(0)) + '../assets'`. As noted in `security-report.md`, that path resolves to `bin/assets` for binaries in `bin/<config>/`, which does not exist. The server returns 404 for everything unless the root is passed as the second argument. This is a functional bug, not a security one.
- The scratch build and fixtures are in `/tmp/claude-1000/-home-yur-agy-projects-miscalg-lmcompare-claude/261ba95c-222a-4a12-a1ce-102e1d863d1c/scratchpad/`. The repository was not modified.
