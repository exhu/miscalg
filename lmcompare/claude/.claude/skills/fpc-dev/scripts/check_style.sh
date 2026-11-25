#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -eq 0 ]; then
  shopt -s nullglob
  FILES=(src/*.pas)
  shopt -u nullglob
else
  FILES=("$@")
fi

if [ "${#FILES[@]}" -eq 0 ]; then
  echo "No Pascal files found to check." >&2
  exit 1
fi

python3 - "${FILES[@]}" <<'PY'
import sys

ok = True
for path in sys.argv[1:]:
    with open(path, "r", encoding="utf-8") as fh:
        content = fh.read()
    lines = content.splitlines()
    if len(lines) >= 1000:
        print(f"FAIL {path}: {len(lines)} lines (must be < 1000)")
        ok = False
    if "{$mode objfpc}" not in content.lower():
        print(f"FAIL {path}: missing {{$mode objfpc}}")
        ok = False
    for idx, line in enumerate(lines, 1):
        if "\t" in line:
            print(f"FAIL {path}:{idx}: contains tab character")
            ok = False
        if not line:
            continue
        lead = len(line) - len(line.lstrip(" "))
        if lead % 2 != 0:
            print(f"FAIL {path}:{idx}: odd indentation ({lead} spaces)")
            ok = False
    print(f"OK   {path}: {len(lines)} lines")

if not ok:
    sys.exit(1)
print("Style check: PASS")
PY
