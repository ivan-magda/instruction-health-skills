#!/bin/sh
# guardian-reminder.sh — PreToolUse hook for instruction-health.
#
# Reads PreToolUse JSON on stdin. Emits an additionalContext reminder telling
# the agent to invoke instruction-guardian before Edit/Write proceeds against
# instruction files (CLAUDE.md / AGENTS.md / MEMORY.md at any depth, anything
# under .claude/rules/, anything under .claude/**/memory/). Suppresses the
# reminder when the Phase-3 carve-out flag is present.
#
# Flag location: ${TMPDIR:-/tmp}/instruction-health-cleanup-<cksum>.flag
# where <cksum> is the POSIX cksum of CLAUDE_PROJECT_DIR. The flag lives in
# the system tmpdir on purpose — the plugin must never write into the
# consumer's repo, where it would risk leaking into commits.
#
# Fail-open: any unexpected condition (parse error, missing field, no match)
# exits 0 silently. Hook must never block edits.

set -u

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-$PWD}"
PROJECT_KEY=$(printf '%s' "$PROJECT_DIR" | cksum | awk '{print $1}')
FLAG="${TMPDIR:-/tmp}/instruction-health-cleanup-${PROJECT_KEY}.flag"

# Phase-3 carve-out: instruction-cleanup signalled an approved cleanup is in
# progress. Suppress reminders for ALL matching edits until Phase-3 clears it.
[ -e "$FLAG" ] && exit 0

input=$(cat)

# Extract the first "file_path": "<value>" string from the PreToolUse payload.
# No jq dependency — sed handles a single string field. If the path contains
# escaped quotes (rare for file paths), extraction fails and we exit silently.
file_path=$(printf '%s' "$input" \
  | sed -n 's/.*"file_path"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' \
  | head -n 1)

[ -z "$file_path" ] && exit 0

# Match the instruction-file glob set:
#   - CLAUDE.md / AGENTS.md / MEMORY.md at any path depth (or as basename)
#   - any path under .claude/rules/
#   - any path under .claude/**/memory/  (closes issue #2: memory topic files)
if ! printf '%s\n' "$file_path" \
  | grep -qE '(^|/)(CLAUDE|AGENTS|MEMORY)\.md$|/\.claude/rules/|/\.claude/(.+/)?memory/'; then
  exit 0
fi

# permissionDecision=allow keeps the normal permission flow; additionalContext
# carries the reminder. Single-line JSON to stdout — Claude Code parses it.
cat <<'JSON'
{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"allow","additionalContext":"Before this Edit/Write, invoke the `instruction-guardian` skill and run the six-step checklist. The checklist is mandatory regardless of edit size (1-line tweak, typo, appended list item all trigger it). You are seeing this reminder because the `instruction-cleanup` Phase-3 carve-out flag is not active — this Edit is therefore a routine edit, not part of an approved cleanup plan."}}
JSON
exit 0
