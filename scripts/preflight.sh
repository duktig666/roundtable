#!/usr/bin/env bash
# scripts/preflight.sh — raw env echo for roundtable orchestrator bootstrap.
#
# Called by hooks/session-start; can also be invoked manually for debugging:
#     bash "${CLAUDE_PLUGIN_ROOT}/scripts/preflight.sh"
#
# Contract: echo raw ROUNDTABLE_AUTO / ROUNDTABLE_DECISION_MODE values plus a
# one-line note deferring resolution (CLI priority / fallback / defaults) to
# the orchestrator LLM per commands/workflow.md Step -0 / Step -1.
#
# Design: docs/design-docs/orchestrator-bootstrap-hardening.md D3
# DEC:    DEC-028 (raw-echo-only; no CLI parsing, no default fallback here)

set -euo pipefail

printf 'PREFLIGHT raw_env ROUNDTABLE_AUTO=%s\n' "${ROUNDTABLE_AUTO:-<unset>}"
printf 'PREFLIGHT raw_env ROUNDTABLE_DECISION_MODE=%s\n' "${ROUNDTABLE_DECISION_MODE:-<unset>}"
printf 'PREFLIGHT note: resolved values computed by orchestrator LLM per commands/workflow.md Step -0 / Step -1 priority (CLI > env > default).\n'
