# Security Review Report: `src/uhttpfiles.pas`

**Target:** [src/uhttpfiles.pas](src/uhttpfiles.pas)  
**Context Reviewed:** [src/uhandlers.pas](src/uhandlers.pas), [src/urouter.pas](src/urouter.pas), [src/server.pas](src/server.pas)  
**Date:** 2026-11-25

---

## 1. Executive Summary

`src/uhttpfiles.pas` implements static file serving, path traversal validation, MIME type resolution, HTML escaping, and HTTP response helpers for the FreePascal `TFPHttpServer` application. While the unit includes baseline defenses—such as rejecting `..`, `\`, and `#0` in `IsPathTraversalAttempt`, enforcing a trailing path delimiter on `RootDir` in `ResolveSafeAssetPath`, and escaping five HTML characters in `EscapeHtml`—several security weaknesses remain.

The most significant issue is **symlink traversal** in `ResolveSafeAssetPath` due to `SysUtils.ExpandFileName` performing only lexical normalization rather than resolving symbolic links. Additional medium- and low-severity issues include potential **Denial of Service** via special files (FIFOs/devices) or quadratic string concatenation in `EscapeHtml`, **dotfile exposure**, **XSS risk from `image/svg+xml`** combined with missing `X-Content-Type-Options: nosniff`, **unhandled stream exceptions / TOCTOU**, and a **thread-safety race** in MIME initialization.

### Findings Summary

| ID | Severity | Title | Location | CWE |
| :--- | :--- | :--- | :--- | :--- |
| **F-01** | **High** | Symlink Traversal / Arbitrary File Read via Lexical Path Check | `ResolveSafeAssetPath` (L131–137) | CWE-59 / CWE-22 |
| **F-02** | **Medium** | Denial of Service via Special Files (FIFOs / Device Nodes) | `ResolveSafeAssetPath` (L136), `ServeStaticFile` (L181) | CWE-400 |
| **F-03** | **Medium** | Hidden File / Dotfile Exposure | `ResolveSafeAssetPath` (L113–141) | CWE-538 / CWE-200 |
| **F-04** | **Medium** | Inline Script Execution Risk via SVG & Missing `nosniff` Header | `GetMimeTypeForFile` (L66–67), `ServeStaticFile` (L181–186) | CWE-79 / CWE-16 |
| **F-05** | **Low** | Quadratic String Concatenation (CPU/Memory DoS) in `EscapeHtml` | `EscapeHtml` (L32–49) | CWE-407 |
| **F-06** | **Low** | Unhandled `TFileStream` Exceptions & TOCTOU Race | `ResolveSafeAssetPath` (L136), `ServeStaticFile` (L181) | CWE-367 / CWE-755 |
| **F-07** | **Low** | Thread-Safety Race Condition in `EnsureMimeTypesLoaded` | `EnsureMimeTypesLoaded` (L20–30) | CWE-362 |
| **F-08** | **Info** | Raw-Character Validation & Escaping Context Assumptions | `IsPathTraversalAttempt` (L87–111), `EscapeHtml` (L32–49) | CWE-20 / CWE-79 |

---

## 2. Detailed Findings

### F-01: Symlink Traversal / Arbitrary File Read via Lexical Path Check
- **Severity:** High
- **Location:** [uhttpfiles.pas#L131-L137](src/uhttpfiles.pas#L131-L137) (`ResolveSafeAssetPath`)
- **CWE:** CWE-59 (Improper Link Resolution Before File Access), CWE-22 (Path Traversal)

#### Description
`ResolveSafeAssetPath` normalizes both the assets root directory and the requested file path using `SysUtils.ExpandFileName`:

```pascal
RootDir := IncludeTrailingPathDelimiter(ExpandFileName(AAssetsDir));
Candidate := ExpandFileName(RootDir + RelPath);

if Copy(Candidate, 1, Length(RootDir)) <> RootDir then
  Exit(False);
if (not FileExists(Candidate)) or DirectoryExists(Candidate) then
  Exit(False);
```

In FreePascal, `ExpandFileName` performs **lexical** path resolution only (prepending the current working directory and collapsing `.` and `..` segments); it does **not** resolve symbolic links on the filesystem.

#### Impact
If any symbolic link exists inside `AAssetsDir` pointing outside the assets directory (either to a file or to a parent/system directory), `Candidate` will still lexically begin with `RootDir`. `FileExists(Candidate)` follows symlinks via `stat`, returns `True`, and `ServeStaticFile` will open and serve the target file from outside `AAssetsDir`.

#### Remediation
Canonicalize both `AAssetsDir` and `Candidate` using `realpath` (via `BaseUnix` / `libc` or `FpReadLink` segment resolution) before performing the `RootDir` prefix check, or verify with `FpLstat` that no path component is a symlink (`S_ISLNK`).

```pascal
// Example approach on Linux using libc realpath (or a helper wrapping it):
// 1. Canonicalize AAssetsDir -> RealRoot (with trailing '/')
// 2. Canonicalize Candidate -> RealCandidate
// 3. Verify Copy(RealCandidate, 1, Length(RealRoot)) = RealRoot
```

---

### F-02: Denial of Service via Special Files (FIFOs / Device Nodes)
- **Severity:** Medium
- **Location:** [uhttpfiles.pas#L136](src/uhttpfiles.pas#L136) (`ResolveSafeAssetPath`), [uhttpfiles.pas#L181](src/uhttpfiles.pas#L181) (`ServeStaticFile`)
- **CWE:** CWE-400 (Uncontrolled Resource Consumption)

#### Description
`ResolveSafeAssetPath` only checks `(not FileExists(Candidate)) or DirectoryExists(Candidate)`. On Linux, `FileExists` returns `True` for non-regular files such as named pipes (FIFOs), character/block devices, and Unix domain sockets, while `DirectoryExists` returns `False`.

#### Impact
If a named pipe or blocking device exists within `AAssetsDir`, `TFileStream.Create(FullPath, fmOpenRead or fmShareDenyWrite)` or reading `AResponse.ContentStream` can block indefinitely or stream unbounded data. Because [server.pas#L54](src/server.pas#L54) configures `FServer.Threaded := False`, a single blocking request stalls the entire HTTP server for all clients.

#### Remediation
Use `FpStat` (from `BaseUnix`) on the canonicalized path and verify `fpS_ISREG(StatBuf.st_mode)` so that only regular files are served.

---

### F-03: Hidden File / Dotfile Exposure
- **Severity:** Medium
- **Location:** [uhttpfiles.pas#L113-L141](src/uhttpfiles.pas#L113-L141) (`ResolveSafeAssetPath`)
- **CWE:** CWE-538 (Insertion of Sensitive Information into Externally-Accessible File or Directory), CWE-200 (Exposure of Sensitive Information)

#### Description
`IsPathTraversalAttempt` only rejects segments equal to `..`. Neither `IsPathTraversalAttempt` nor `ResolveSafeAssetPath` restricts path segments starting with `.` (such as `.git`, `.env`, `.htaccess`, or `.DS_Store`).

#### Impact
If the assets directory contains version-control metadata, environment/config files, or editor backup/dot files, any client can retrieve them directly over HTTP.

#### Remediation
Reject any path segment in `AUrlPath` that is `.` or begins with `.` (e.g., `(Segment = '.') or ((Length(Segment) > 0) and (Segment[1] = '.'))`), unless an explicit allowlist (such as `.well-known`) is required.

---

### F-04: Inline Script Execution Risk via SVG & Missing `nosniff` Header
- **Severity:** Medium
- **Location:** [uhttpfiles.pas#L66-L67](src/uhttpfiles.pas#L66-L67) (`GetMimeTypeForFile`), [uhttpfiles.pas#L181-L186](src/uhttpfiles.pas#L181-L186) (`ServeStaticFile`)
- **CWE:** CWE-79 (Cross-site Scripting), CWE-16 (Configuration)

#### Description
1. `GetMimeTypeForFile` maps `.svg` to `image/svg+xml`. SVG documents can contain embedded `<script>` elements and event handlers that execute in the origin of the server when opened directly in a browser.
2. `ServeStaticFile` and `SendHtmlResponse` do not set `X-Content-Type-Options: nosniff`.

#### Impact
If untrusted or user-supplied `.svg` (or `.html`) files are ever placed in `AAssetsDir`, navigating to them executes arbitrary JavaScript in the application's origin. Without `X-Content-Type-Options: nosniff`, browsers may also MIME-sniff `application/octet-stream` or `text/plain` responses as HTML/JS.

#### Remediation
- Set `AResponse.SetCustomHeader('X-Content-Type-Options', 'nosniff');` in `ServeStaticFile` and `SendHtmlResponse`.
- If untrusted assets may be served, either serve `.svg` with `Content-Disposition: attachment` or apply a restrictive `Content-Security-Policy` (e.g., `sandbox; default-src 'none'`).

---

### F-05: Quadratic String Concatenation (CPU/Memory DoS) in `EscapeHtml`
- **Severity:** Low
- **Location:** [uhttpfiles.pas#L32-L49](src/uhttpfiles.pas#L32-L49) (`EscapeHtml`)
- **CWE:** CWE-407 (Inefficient Algorithmic Complexity)

#### Description
`EscapeHtml` builds `Result` character-by-character using `Result := Result + ...` inside a loop over `AText`. In FreePascal `AnsiString` (`{$H+}`), repeated single-character concatenation reallocates and copies the string on each iteration, resulting in $O(N^2)$ time and allocation overhead.

#### Impact
In [uhandlers.pas#L42-L48](src/uhandlers.pas#L42-L48), `EscapeHtml` is called directly on user-controlled `name` parameters from query strings or POST bodies. A large input causes disproportionate CPU and memory consumption, which is amplified by the single-threaded server loop in `server.pas`.

#### Remediation
Pre-allocate or write in chunks using a `TStringBuilder` (from `SysUtils`) or a single-pass buffer copy (counting escaped length first, `SetLength(Result, OutLen)`, then filling by index).

---

### F-06: Unhandled `TFileStream` Exceptions & TOCTOU Race
- **Severity:** Low
- **Location:** [uhttpfiles.pas#L136](src/uhttpfiles.pas#L136), [uhttpfiles.pas#L181](src/uhttpfiles.pas#L181) (`ServeStaticFile`)
- **CWE:** CWE-367 (Time-of-Check Time-of-Use Race Condition), CWE-755 (Improper Handling of Exceptional Conditions)

#### Description
`ResolveSafeAssetPath` checks file existence and type, and `ServeStaticFile` subsequently opens `FullPath` with `TFileStream.Create(FullPath, fmOpenRead or fmShareDenyWrite)`. There is no `try..except` handling around `TFileStream.Create`.

#### Impact
If a file is unreadable (permission error `EACCES`), locked against `fmShareDenyWrite`, or removed/modified between `ResolveSafeAssetPath` and `TFileStream.Create`, an unhandled `EFOpenError` propagates out of `ServeStaticFile`. While `TMinimalHttpApp.HandleHttpRequest` in `server.pas` catches `Exception` and returns a `500`, other callers of `ServeStaticFile` may crash, and `ServeStaticFile` returns a generic `500` instead of an appropriate `403`/`404` or clean `False`.

#### Remediation
Wrap `TFileStream.Create` in `try..except` (handling `EFOpenError` / `EStreamError`) and return `403`/`404` or `False` cleanly. Where possible on Unix, open with `FpOpen(..., O_RDONLY or O_NOFOLLOW)` and inspect `FpFStat` on the open file descriptor to eliminate both TOCTOU and symlink races atomically.

---

### F-07: Thread-Safety Race Condition in `EnsureMimeTypesLoaded`
- **Severity:** Low
- **Location:** [uhttpfiles.pas#L20-L30](src/uhttpfiles.pas#L20-L30) (`EnsureMimeTypesLoaded`)
- **CWE:** CWE-362 (Concurrent Execution using Shared Resource with Improper Synchronization)

#### Description
`GMimeTypesLoaded` is a module-level boolean checked and mutated without locking before calling `MimeTypes.LoadKnownTypes` on the global `MimeTypes` singleton.

#### Impact
Although `server.pas` currently sets `FServer.Threaded := False`, `uhttpfiles.pas` is a general-purpose unit. If `Threaded` is enabled or `GetMimeTypeForFile` is called concurrently, one thread can observe `GMimeTypesLoaded = True` before `LoadKnownTypes` completes, or multiple threads can mutate `MimeTypes` simultaneously.

#### Remediation
Initialize `MimeTypes.LoadKnownTypes` once in the unit `initialization` section (or guard `EnsureMimeTypesLoaded` with a `TCriticalSection`).

---

### F-08: Raw-Character Validation & Escaping Context Assumptions
- **Severity:** Informational
- **Location:** [uhttpfiles.pas#L87-L111](src/uhttpfiles.pas#L87-L111) (`IsPathTraversalAttempt`), [uhttpfiles.pas#L32-L49](src/uhttpfiles.pas#L32-L49) (`EscapeHtml`)
- **CWE:** CWE-20 (Improper Input Validation), CWE-79 (Cross-site Scripting)

#### Description
1. **`IsPathTraversalAttempt` assumes prior URL decoding and rejects only `#0`, `\`, and `..`:** It does not reject ASCII control characters (`#1`–`#31`, `#127`) or percent-encoded sequences (`%2e%2e`, `%2f`, `%00`). While `ServeStaticFile` does not URL-decode `RelPath` itself (preventing double-decoding bypasses in the current call chain), any future caller that decodes after calling `IsPathTraversalAttempt` would bypass the check.
2. **`EscapeHtml` context scope:** `EscapeHtml` escapes `&`, `<`, `>`, `"`, and `'`. This is safe for HTML element bodies and quoted attributes (as used in `SendErrorResponse` and `HandleHello`), but **not** safe for unquoted HTML attributes, `<script>`/`<style>` contexts, or `href`/`src` URL attributes (where `javascript:` URIs are not blocked).

#### Remediation
- Document that `AUrlPath` must already be URL-decoded before calling `IsPathTraversalAttempt` / `ResolveSafeAssetPath`, and reject control characters (`Ord(C) < 32` or `Ord(C) = 127`).
- Document `EscapeHtml`'s safe contexts (HTML body and quoted attributes only).

---

## 3. Prioritized Remediation Checklist

1. **High:** Replace lexical `ExpandFileName` validation in `ResolveSafeAssetPath` with `realpath` canonicalization (or `O_NOFOLLOW` + `FpFStat`) to prevent symlink traversal.
2. **Medium:** Verify `fpS_ISREG` via `FpStat`/`FpFStat` to block FIFOs, sockets, and device nodes.
3. **Medium:** Reject `.`-prefixed path segments in `IsPathTraversalAttempt` / `ResolveSafeAssetPath` to prevent dotfile disclosure.
4. **Medium:** Add `X-Content-Type-Options: nosniff` to `ServeStaticFile` and `SendHtmlResponse`, and consider `Content-Disposition: attachment` or CSP for `.svg` if untrusted assets are ever served.
5. **Low:** Rewrite `EscapeHtml` using `TStringBuilder` or single-pass buffer allocation; wrap `TFileStream.Create` in `try..except`; move `MimeTypes.LoadKnownTypes` to unit `initialization` (or guard with a critical section).
