#!/usr/bin/env bash
# Usage: test.sh [speed|size|debug]  (default debug) — builds then runs tests/smoke.sh
set -euo pipefail
cd "$(dirname "$0")/../../../.."
LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT
RC=0
BUILD_MODE=${1:-debug} SERVER_LOG=$LOG tests/smoke.sh || RC=$?
if grep -q 'unfreed memory blocks' "$LOG"; then
  echo "--- heaptrc ---"; sed -n '/^Heap dump/,$p' "$LOG" | head -40
  grep -q '^0 unfreed memory blocks' "$LOG" || { echo "LEAKS DETECTED"; RC=1; }
fi
exit $RC
