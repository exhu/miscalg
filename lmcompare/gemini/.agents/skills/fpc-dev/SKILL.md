---
name: fpc-dev
description: >-
  Builds, lints, and references FreePascal (ObjFPC) applications and fcl-web
  HTTP servers on Linux. Use when compiling Pascal units or binaries, checking
  Pascal formatting rules, or working with fphttpserver, httpdefs, and BaseUnix.
---

# FreePascal Development Workflow

Use the bundled scripts instead of writing inline `python3 -c`, `rm -rf`, or
multi-command `fpc` shell chains.

## Steps

1. **Check Pascal style rules** (`{$mode objfpc}`, `< 1000` lines, zero tabs,
   2-space indentation):
   `.agents/skills/fpc-dev/scripts/check_style.sh src/*.pas`
2. **Build a single unit or full binary** (`-FE.` ensures root output):
   - Full build (default `speed` mode, `-O2`): `.agents/skills/fpc-dev/scripts/build.sh`
   - Select optimization mode (`speed`, `size`, or `debug`):
     - Speed (`-O2`): `.agents/skills/fpc-dev/scripts/build.sh --mode speed` (or `--speed`)
     - Size (`-Os -CX -XX -Xs`): `.agents/skills/fpc-dev/scripts/build.sh --mode size` (or `--size`)
     - Debug (`-O- -g -gl -Cr -Co -Ct`): `.agents/skills/fpc-dev/scripts/build.sh --mode debug` (or `--debug`)
   - Clean rebuild: `.agents/skills/fpc-dev/scripts/build.sh --clean`
   - Single unit check: `.agents/skills/fpc-dev/scripts/build.sh --unit src/urouter.pas`
3. **Consult verified FPC 3.2.2 quirks** when working with `fcl-web` or signals:
   Read [fpc-3.2.2-fcl-web.md](./references/fpc-3.2.2-fcl-web.md).
