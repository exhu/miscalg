#!/usr/bin/env bash
# Usage: build.sh [--mode speed|size|debug | --speed|--size|--debug] [--clean] [--unit FILE]
set -euo pipefail
cd "$(dirname "$0")/../../../.."
MODE=${BUILD_MODE:-speed}; CLEAN=0; UNIT=""
while [ $# -gt 0 ]; do
  case $1 in
    --mode) MODE=$2; shift ;;
    --speed|--size|--debug) MODE=${1#--} ;;
    --clean) CLEAN=1 ;;
    --unit) UNIT=$2; shift ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
  shift
done
case $MODE in
  speed) FLAGS="-O3 -CX -XX" ;;
  size)  FLAGS="-Os -CX -XX -Xs" ;;
  debug) FLAGS="-O- -g -gl -gh -Cr -Co -Ct -Sa" ;;
  *) echo "bad mode: $MODE" >&2; exit 2 ;;
esac
OBJ=build/$MODE; OUT=bin/$MODE
[ $CLEAN = 1 ] && rm -rf "$OBJ" "$OUT"
mkdir -p "$OBJ" "$OUT"
BASE="-Mobjfpc -Sh -vewn -Fusrc -FU$OBJ"
if [ -n "$UNIT" ]; then
  fpc $BASE $FLAGS -Cn "$UNIT"
  echo "unit OK: $UNIT ($MODE)"; exit 0
fi
fpc $BASE $FLAGS -FE"$OUT" -o"$OUT/httpsrv" src/httpsrv.lpr
ln -sf "$MODE/httpsrv" bin/httpsrv
echo "built $OUT/httpsrv ($MODE, $(stat -c %s "$OUT/httpsrv") bytes); bin/httpsrv -> $MODE"
