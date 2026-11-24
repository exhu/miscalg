# Project Instructions

## Shell & Automation Preferences
- Prefer reviewed scripts in `.agents/skills/*/scripts/` over multi-line inline `bash -c` or `python3 -c` commands.
- Keep `run_command` calls short and single-purpose; avoid ad-hoc `rm -rf` chains when `.agents/skills/fpc-dev/scripts/build.sh --clean` suffices.

## FreePascal Coding Standards
- Every `.pas` unit/program must include `{$mode objfpc}{$H+}`.
- Use strictly 2-space indentation with zero tab characters.
- Keep every unit under 1000 lines.
- Compile the server binary to the project root with `.agents/skills/fpc-dev/scripts/build.sh` (or `fpc -Mobjfpc -Sh -O2 -FUbuild -Fusrc -FE. -ohttpserver src/server.pas`).
