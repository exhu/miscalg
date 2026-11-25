#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT_DIR"

CLEAN=0
MODE="speed"
UNIT_FILE=""
ENTRY_FILE="src/server.pas"
OUTPUT_BIN="httpserver"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --clean)
      CLEAN=1
      shift
      ;;
    --mode)
      if [ "$#" -lt 2 ]; then
        echo "Missing argument for --mode" >&2
        exit 2
      fi
      MODE="$2"
      shift 2
      ;;
    --speed|--size|--debug)
      MODE="${1#--}"
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
      echo "Usage: $0 [--clean] [--mode speed|size|debug | --speed | --size | --debug] [--unit <file.pas>]"
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  speed)
    COMPILE_FLAGS=(-O2)
    LINK_FLAGS=()
    ;;
  size)
    COMPILE_FLAGS=(-Os -CX)
    LINK_FLAGS=(-XX -Xs)
    ;;
  debug)
    COMPILE_FLAGS=(-O- -g -gl -Cr -Co -Ct)
    LINK_FLAGS=()
    ;;
  *)
    echo "Unknown mode: $MODE (expected speed, size, or debug)" >&2
    exit 2
    ;;
esac

mkdir -p build

if [ "$CLEAN" -eq 1 ]; then
  rm -f build/*.o build/*.ppu "$OUTPUT_BIN"
fi

if [ -n "$UNIT_FILE" ]; then
  fpc -Mobjfpc -Sh "${COMPILE_FLAGS[@]}" -FUbuild -Fusrc "$UNIT_FILE"
else
  fpc -Mobjfpc -Sh -B "${COMPILE_FLAGS[@]}" "${LINK_FLAGS[@]}" -FUbuild -Fusrc -FE. -o"$OUTPUT_BIN" "$ENTRY_FILE"
fi
