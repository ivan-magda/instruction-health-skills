#!/bin/sh
# Unit tests for hooks/guardian-reminder.sh and hooks/clear-cleanup-flag.sh.
#
# Contract under test:
#   guardian-reminder.sh reads PreToolUse JSON on stdin. If the flag file
#   `${TMPDIR:-/tmp}/instruction-health-cleanup-<cksum>.flag` (where <cksum>
#   is the POSIX cksum of CLAUDE_PROJECT_DIR) exists, exit silently.
#   Otherwise, if .tool_input.file_path matches one of the instruction-file
#   globs (CLAUDE.md / AGENTS.md / MEMORY.md at any depth, anything under
#   .claude/rules/, anything under .claude/**/memory/), emit a single
#   PreToolUse JSON object with additionalContext reminding the agent to
#   invoke instruction-guardian. Otherwise (non-match, parse error, anything
#   unexpected) exit 0 silently. Hook must never block edits.
#
#   clear-cleanup-flag.sh removes the flag (no-op if absent) and exits 0.
#
# Flag location is intentionally outside the consumer's repo so the plugin
# never has to touch their .gitignore.
#
# Run: sh tests/hook-unit-tests.sh

set -u

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
GUARD="$REPO_ROOT/hooks/guardian-reminder.sh"
CLEAR="$REPO_ROOT/hooks/clear-cleanup-flag.sh"

# Sandbox both CLAUDE_PROJECT_DIR and TMPDIR so the flag lands in a scratch
# location and we don't touch the real repo or the system tmpdir.
SCRATCH="$(mktemp -d)"
trap 'rm -rf "$SCRATCH"' EXIT INT TERM
export CLAUDE_PROJECT_DIR="$SCRATCH/project"
export TMPDIR="$SCRATCH/tmp"
mkdir -p "$CLAUDE_PROJECT_DIR" "$TMPDIR"

# Compute the same flag path the hooks compute. Test failures here indicate
# the cksum convention drifted between the test and the hook scripts.
flag_path() {
  printf '%s/instruction-health-cleanup-%s.flag\n' \
    "$TMPDIR" \
    "$(printf '%s' "$CLAUDE_PROJECT_DIR" | cksum | awk '{print $1}')"
}
FLAG=$(flag_path)

PASS=0
FAIL=0

# ---- helpers ---------------------------------------------------------------

run_guard() {
  # $1 = stdin payload
  printf '%s' "$1" | sh "$GUARD" 2>/dev/null
}

assert_empty() {
  # $1 = test name, $2 = output
  if [ -z "$2" ]; then
    PASS=$((PASS + 1))
    printf '  PASS  %s\n' "$1"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %s\n        got: %s\n' "$1" "$2"
  fi
}

assert_has_reminder() {
  # $1 = test name, $2 = output
  case "$2" in
    *additionalContext*instruction-guardian*)
      PASS=$((PASS + 1))
      printf '  PASS  %s\n' "$1"
      ;;
    *)
      FAIL=$((FAIL + 1))
      printf '  FAIL  %s\n        got: %s\n' "$1" "$2"
      ;;
  esac
}

assert_file_absent() {
  if [ ! -e "$1" ]; then
    PASS=$((PASS + 1))
    printf '  PASS  %s\n' "$2"
  else
    FAIL=$((FAIL + 1))
    printf '  FAIL  %s\n        file still present: %s\n' "$2" "$1"
  fi
}

clear_flag() { rm -f "$FLAG"; }
set_flag()   { touch "$FLAG"; }

# ---- guardian-reminder.sh: flag absent (should fire on matches) ------------

echo
echo "guardian-reminder.sh: flag absent"
clear_flag

out=$(run_guard '{"tool_input":{"file_path":"/x/.claude/projects/foo/memory/feedback_x.md"}}')
assert_has_reminder "memory topic file fires reminder (issue #2)" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/apps/mobile/CLAUDE.md"}}')
assert_has_reminder "subdir CLAUDE.md fires reminder" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/CLAUDE.md"}}')
assert_has_reminder "root CLAUDE.md fires reminder" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/packages/api/AGENTS.md"}}')
assert_has_reminder "subdir AGENTS.md fires reminder" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/MEMORY.md"}}')
assert_has_reminder "MEMORY.md fires reminder" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/.claude/rules/testing.md"}}')
assert_has_reminder ".claude/rules/* fires reminder" "$out"

# ---- guardian-reminder.sh: flag absent, non-matching paths -----------------

out=$(run_guard '{"tool_input":{"file_path":"/x/src/Foo.tsx"}}')
assert_empty "non-matching source file silent" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/README.md"}}')
assert_empty "README.md silent (regression guard)" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/docs/CLAUDE-md-guide.md"}}')
assert_empty "filename containing CLAUDE substring but not CLAUDE.md silent" "$out"

# ---- guardian-reminder.sh: malformed input must exit silently --------------

out=$(run_guard 'not json at all')
assert_empty "non-JSON stdin silent" "$out"

out=$(run_guard '{"tool_input":{}}')
assert_empty "JSON without file_path silent" "$out"

out=$(run_guard '')
assert_empty "empty stdin silent" "$out"

# ---- guardian-reminder.sh: flag present (suppression) ----------------------

echo
echo "guardian-reminder.sh: flag present (Phase-3 carve-out)"
set_flag

out=$(run_guard '{"tool_input":{"file_path":"/x/apps/mobile/CLAUDE.md"}}')
assert_empty "subdir CLAUDE.md suppressed by flag" "$out"

out=$(run_guard '{"tool_input":{"file_path":"/x/.claude/projects/foo/memory/feedback_x.md"}}')
assert_empty "memory topic file suppressed by flag" "$out"

clear_flag

# ---- clear-cleanup-flag.sh -------------------------------------------------

echo
echo "clear-cleanup-flag.sh"

set_flag
sh "$CLEAR"
assert_file_absent "$FLAG" "removes flag when present"

# Idempotent: running again with no flag must still exit 0.
if sh "$CLEAR"; then
  PASS=$((PASS + 1))
  printf '  PASS  %s\n' "no-op when flag already absent"
else
  FAIL=$((FAIL + 1))
  printf '  FAIL  %s\n' "no-op when flag already absent (non-zero exit)"
fi

# ---- summary ---------------------------------------------------------------

echo
printf 'PASS: %d  FAIL: %d\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
