#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p build bin
fpc -Mobjfpc -Sh -FUbuild -FEbin -obin/httpsrv src/httpsrv.lpr
