---
name: fpc-dev
description: >-
  Build (speed/size/debug optimized), style-check and smoke-test this FreePascal
  (ObjFPC, fcl-web) HTTP server. Use when compiling, testing, checking Pascal
  style, or working with fphttpserver/httpdefs quirks in FPC 3.2.2.
---

# FreePascal dev workflow (httpsrv)

Use these scripts instead of ad-hoc `fpc` command lines. Run from the project root.

## Build
`.claude/skills/fpc-dev/scripts/build.sh [--mode speed|size|debug] [--clean] [--unit FILE]`
- `speed` (default): `-O3 -CX -XX`
- `size`: `-Os -CX -XX -Xs` (prints binary size)
- `debug`: `-O- -g -gl -gh -Cr -Co -Ct -Sa` (line info, heaptrc, range/overflow/stack checks, assertions)
- Objects go to `build/<mode>/`, binary to `bin/<mode>/httpsrv`; `bin/httpsrv` symlinks the last build.
- `--unit src/router.pas` compiles a single unit without linking (quick check).
- `BUILD_MODE` env var sets the default mode; root `./build.sh` forwards to this script.

## Test
`.claude/skills/fpc-dev/scripts/test.sh [mode]` — builds (default `debug`) and runs `tests/smoke.sh`.
Prints PASS/FAIL per check. The server is stopped with SIGTERM (handled: clean shutdown),
so in debug mode the heaptrc summary is printed and any unfreed blocks fail the run.

## Style
`.claude/skills/fpc-dev/scripts/check_style.sh [files...]` (default `src/*.pas`):
`{$mode objfpc}` present, < 1000 lines, no tabs, even (2-space) indentation.
Run before finishing any Pascal edit.

## Reference
FPC 3.2.2 fcl-web quirks (PathInfo `''` for `/`, `-FE` output paths, ContentStream,
signals): [references/fpc-3.2.2-fcl-web.md](references/fpc-3.2.2-fcl-web.md).
Shutdown pattern used here: signal handler only sets a flag; `AcceptIdleTimeout` +
`OnAcceptIdle` polls it and sets `Server.Active := False`. In `OnAcceptIdle`, `Sender` is
the internal `TInetServer`, not the `TFPHttpServer` — keep a direct server reference.
