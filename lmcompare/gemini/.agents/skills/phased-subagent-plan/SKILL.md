---
name: phased-subagent-plan
description: >-
  Structures multi-phase plans (plan-overview.md plus plan-NN.md files) for
  sequential subagent execution while minimizing shell command approvals.
  Use when decomposing a task into small subagent phases.
---

# Phased Subagent Execution Guidelines

1. Write `plan-overview.md` plus small, focused `plan-NN.md` files so each
   subagent stays well within its context budget.
2. Before writing phase verification commands, check `.agents/skills/` and
   `~/.gemini/config/skills/` for existing build, lint, or test scripts.
3. Instruct phase subagents to call those reviewed scripts directly rather than
   composing inline `bash -c`, `python3 -c`, or `rm -rf` one-liners.
4. Keep each phase's verification to a single short command.
