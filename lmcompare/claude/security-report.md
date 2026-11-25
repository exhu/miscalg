# Security Report: Path Resolution / Traversal

**Scope:** static file serving in `src/staticfiles.pas` (`TStaticFiles.Serve`) and `src/router.pas` (`TRouter.RequestPath`).
**Verdict:** Not vulnerable to path traversal via the request URL. A few hardening items remain.

## Defenses in place

1. The path is URL-decoded (`HTTPDecode`) **before** validation, so encoded payloads (`%2e%2e`, `..%2f`, `%5c`) are caught.
2. Paths containing `..`, NUL (`#0`) or `\` are rejected.
3. Leading `/` characters are stripped, so `//etc/passwd` cannot become an absolute path.
4. Second layer: `ExpandFileName(FRoot + Rel)` must start with `FRoot`. `FRoot` is expanded and has a trailing delimiter, so sibling-prefix bypasses such as `/srv/assets-evil` are not possible.
5. Directories are never served.

## Dynamic testing

The server was started as `bin/debug/httpsrv 18089 assets` and probed with `curl --path-as-is`:

| Request                    | Result |
|----------------------------|--------|
| `/style.css` (control)     | 200    |
| `/../plan-01.md`           | 404    |
| `/%2e%2e/plan-01.md`       | 404    |
| `/%252e%252e/plan-01.md`   | 404    |
| `/..%2fplan-01.md`         | 404    |
| `//etc/passwd`             | 404    |
| `/%2fetc/passwd`           | 404    |
| `/.%2e/build.sh`           | 404    |
| `/%5c..%5cbuild.sh`        | 404    |
| `/style.css%00.html`       | 404    |

## Residual issues

### 1. Symlinks are followed (Low)
`ExpandFileName` normalizes the path text but does not resolve symlinks. A symlink inside `assets/` that points outside it will be served.
*Precondition:* the attacker needs write access to `assets/`.
*Fix:* resolve the real path (e.g. `fpReadLink` / `realpath`) before the prefix check, or reject symlinks.

### 2. Dotfiles are served (Low)
Hidden files inside the assets root (`.git/`, `.env`, `.htpasswd`) are served if they exist.
*Fix:* reject any path segment that starts with `.`.

### 3. Prefix check relies on the trailing delimiter (Info)
`Pos(FRoot, Full) = 1` is safe only because the constructor applies `IncludeTrailingPathDelimiter`. Keep that invariant if the code is refactored.

### 4. Wrong default assets path (Functional, not security)
The default `ExtractFilePath(ParamStr(0)) + '../assets'` resolves to `bin/assets` for binaries in `bin/<config>/`, and that directory does not exist. As a result, every static request returns 404 unless the assets directory is passed as the second argument.
