---
name: http-smoke-test
description: >-
  Runs end-to-end HTTP smoke tests against a local web server binary using curl.
  Use when verifying routes, form submissions, XSS escaping, static assets,
  path traversal protection, HTTP status codes, and clean SIGTERM shutdown.
---

# HTTP Smoke Test Runner

Execute the reviewed test script instead of generating an inline `bash -c`
server-and-curl harness:

```bash
.agents/skills/http-smoke-test/scripts/smoke_test.sh ./httpserver 18080 assets
```

## What It Verifies

- Port readiness polling and guaranteed `trap` cleanup.
- `GET /` (`200`, `text/html`, form markup), `GET /style.css` (`200`, `text/css`).
- `GET /hello` and `POST /hello` parameter decoding, empty fallback, and HTML escaping.
- `404` missing asset, `403` path traversal (`--path-as-is`), `405` disallowed method.
- Clean `SIGTERM` shutdown (`exit 0`) and no stray process left running.
