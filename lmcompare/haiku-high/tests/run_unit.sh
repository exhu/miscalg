#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/unit bin
fpc -Mobjfpc -Sh -Fusrc -FUbuild/unit -FEbin -obin/unittests tests/unit/testrunner.lpr
bin/unittests --all --format=plain
