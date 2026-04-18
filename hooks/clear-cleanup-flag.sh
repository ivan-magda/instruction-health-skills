#!/bin/sh
# clear-cleanup-flag.sh — SessionStart hook for instruction-health.
#
# Removes a stale Phase-3 carve-out flag at session start so an aborted
# instruction-cleanup run (which left the flag behind) does not silently
# suppress guardian reminders in the next session. Idempotent and fail-open.
#
# Same flag-path convention as guardian-reminder.sh:
#   ${TMPDIR:-/tmp}/instruction-health-cleanup-<cksum>.flag

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_KEY=$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')
rm -f "${TMPDIR:-/tmp}/instruction-health-cleanup-${PROJECT_KEY}.flag"
exit 0
