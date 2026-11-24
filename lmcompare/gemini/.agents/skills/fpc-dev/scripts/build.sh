#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT_DIR"

CLEAN=0
UNIT_FILE=""
ENTRY_FILE="src/server.pas"
OUTPUT_BIN="httpserver"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --clean)
      CLEAN=1
      shift
      ;;
    --unit)
      if [ "$#" -lt 2 ]; then
        echo "Missing argument for --unit" >&2
        exit 2
      fi
      UNIT_FILE="$2"
      shift 2
      ;;
    -h|--help)
      echo "Usage: $0 [--clean] [--unit <file.pas>]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

mkdir -p build

if [ "$CLEAN" -eq 1 ]; then
  rm -f build/*.o build/*.ppu "$OUTPUT_BIN"
fi

if [ -n "$UNIT_FILE" ]; then
  fpc -Mobjfpc -Sh -FUbuild -Fusrc "$UNIT_FILE"
else
  fpc -Mobjfpc -Sh -O2 -FUbuild -Fusrc -FE. -o"$OUTPUT_BIN" "$ENTRY_FILE"
fi
