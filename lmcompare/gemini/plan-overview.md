# Minimal FreePascal HTTP Server — Plan Overview

## Description

A minimal HTTP server implemented in FreePascal (`{$mode objfpc}{$H+}`) with simple routing support to serve HTML pages and static files from disk.

## Directory Layout

- `assets/` — Static content served by the HTTP server (`index.html`, `style.css`)
- `src/` — FreePascal source files (`uhttpfiles.pas`, `urouter.pas`, `uhandlers.pas`, `server.pas`)
- `build/` — Compiler intermediate artifacts (`.o`, `.ppu`)
- `httpserver` — Compiled server binary

## Request Routes

- `GET /` — Serves `assets/index.html` containing a line of text describing the program and an HTML form with a text input (`name`) and a submit button targeting `/hello`.
- `GET /hello` and `POST /hello` — Reads the submitted `name` parameter, HTML-escapes it, and responds with an HTML page displaying `hello, <name>!`.
- Fallback `GET /<path>` — Safely serves static files from `assets/` (such as `/style.css`), returning `404 Not Found` if missing and `403 Forbidden` on path traversal attempts.

## Pascal Coding Rules

Every `.pas` file in `src/` MUST follow these rules:
1. Compile in ObjFPC mode with `{$mode objfpc}{$H+}` at the top of every unit/program.
2. Use strictly **2 spaces** for indentation (zero tab characters).
3. Keep every unit strictly under **1000 lines**.

## Build Command

```bash
mkdir -p build && fpc -Mobjfpc -Sh -O2 -FUbuild -Fusrc -FE. -ohttpserver src/server.pas
```

## Sequential Execution Phases

| Phase | Plan Document | Scope |
| --- | --- | --- |
| Phase 01 | [plan-01.md](./plan-01.md) | Project scaffolding (`assets/`, `src/`, `build/`) and static assets (`index.html`, `style.css`) |
| Phase 02 | [plan-02.md](./plan-02.md) | HTTP utilities and static file serving unit (`src/uhttpfiles.pas`) |
| Phase 03 | [plan-03.md](./plan-03.md) | Simple HTTP router unit (`src/urouter.pas`) |
| Phase 04 | [plan-04.md](./plan-04.md) | Route handlers (`src/uhandlers.pas`) and server entrypoint (`src/server.pas`) |
| Phase 05 | [plan-05.md](./plan-05.md) | Clean rebuild, Pascal style verification, and end-to-end `curl` integration testing |
