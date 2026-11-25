# Security Review: src/staticfiles.pas

Scope: `src/staticfiles.pas` only. `router.pas` was not reviewed, so what `TRouter.RequestPath` returns (decoded or not, query string stripped or not) is unconfirmed.

## Findings

### 1. Hidden files are served (medium)

`Serve` (lines 73–84) blocks `..`, NUL and backslash, but not path segments that begin with `.`. A request for `/.env`, `/.git/config` or `/.htaccess` returns the file if it exists under `FRoot`. This matters most if the static root is the project directory or contains dotfiles.

### 2. Symlinks escape the root (medium, depends on who controls the root)

The containment check at line 82 is a string-prefix test on `ExpandFileName` output. `ExpandFileName` does not resolve symlinks, so a symlink such as `static/link -> /etc` passes the check, and `FileExists` and `TFileStream` then follow it. Anyone who can create a symlink in the root, or a deployment that links in external assets, can read arbitrary files.

### 3. Active content served same-origin (low, only if untrusted files can land in the root)

`MimeTypeFor` (lines 35–64) serves `.html`, `.svg` and `.js` under their normal types. `Serve` sets no security headers (lines 88–90): no `X-Content-Type-Options: nosniff`, no `Content-Security-Policy`. Any user-uploaded HTML or SVG in the root would run script in the site's origin.

### 4. Unhandled open error (low)

`TFileStream.Create` at line 85 can raise if the file exists but is unreadable, for example because of permissions. The exception then reaches the server's request handling, which may return a 500 or leak the exception text. The `FileExists` followed by `Create` sequence is also a small TOCTOU window.

### 5. Overbroad `..` check (informational)

Line 74 rejects any name containing `..`, such as `notes..md`. This fails closed and is not a vulnerability.

## What holds up

- Percent-decoding happens before the `..`, NUL and backslash checks, so `%2e%2e` and `%252e%252e` are caught after decoding.
- `FRoot` has a trailing delimiter, so `/srv/www2/` does not match a root of `/srv/www/`.
- Directories are rejected, so there is no directory listing.

## Suggested fixes

- Reject any path segment that begins with `.` in `Serve`.
- Resolve the real path of the target (for example with `realpath` through the C library, or by walking `fpReadlink`) and run the prefix check on the resolved path. Resolve `FRoot` the same way at construction.
- Add `X-Content-Type-Options: nosniff` and a restrictive `Content-Security-Policy` to served responses, or serve untrusted uploads from a separate origin.
- Wrap the `TFileStream` creation in a `try`/`except` that returns 404 or 403.

## Open questions

- Is `FRoot` ever the project directory, or is the root only populated from controlled build output?
- Does `TRouter.RequestPath` decode the path and strip the query string? If not, `Serve` must handle a query string.
