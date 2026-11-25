#!/usr/bin/env bash
# Thin wrapper; see .claude/skills/fpc-dev/SKILL.md. Args: [--mode speed|size|debug] [--clean]
exec "$(dirname "$0")/.claude/skills/fpc-dev/scripts/build.sh" "$@"
