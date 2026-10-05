#!/bin/sh

PROJECT_DIR=$(pwd -P) || exit 0
PROJECT_KEY=$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')
FLAG="${TMPDIR:-/tmp}/instruction-health-codex-cleanup-${PROJECT_KEY}.flag"
[ -e "$FLAG" ] && exit 0

SCRIPT_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd) || exit 0
paths=$(python3 "$SCRIPT_DIR/codex-patch-paths.py" 2>/dev/null) || exit 0

if ! printf '%s\n' "$paths" \
  | grep -qE '(^|/)(CLAUDE|AGENTS|MEMORY)\.md$|(^|/)\.claude/rules/|(^|/)\.claude/(.+/)?memory/'; then
  exit 0
fi

cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"Before this apply_patch, invoke the `instruction-guardian` skill and run its six-step checklist for the instruction files touched by the patch, regardless of edit size. The Codex instruction-cleanup Phase-3 flag is not active. If this edit belongs to a Phase-2 plan already approved in this conversation, re-arm the Codex flag as described in instruction-cleanup before continuing."}}
JSON
exit 0
