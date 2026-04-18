---
name: instruction-cleanup
description: Use when CLAUDE.md, AGENTS.md, or instruction files have grown too large (200+ lines, 40k+ chars), when agent performance has degraded due to bloated context, or when the user asks to restructure or clean up their instruction files
---

# Instruction File Cleanup

Restructure bloated instruction files (CLAUDE.md, AGENTS.md, Cursor rules, etc.) to restore agent performance. Follows a three-phase cycle: **Audit** the full instruction surface area, **Plan** where each piece of content should live, **Implement** the restructuring with verification.

## Why This Matters

Instruction files are a **prompt budget**, not documentation. Every line loads into the agent's context window and competes for attention with the actual task. Research shows instruction-following degrades uniformly as instruction count rises — bloated files don't just waste the middle, they degrade adherence everywhere.

## The Three Phases

```dot
digraph cleanup {
  rankdir=LR;
  "AUDIT" -> "PLAN" -> "IMPLEMENT";
  "AUDIT" [shape=box, label="AUDIT\nMeasure everything"];
  "PLAN" [shape=box, label="PLAN\nClassify every section"];
  "IMPLEMENT" [shape=box, label="IMPLEMENT\nRestructure + verify"];
}
```

Work through each phase completely before moving to the next. Do NOT jump to restructuring without measuring first.

---

## Phase 1: Audit

Measure the full instruction surface area — everything that loads into the agent's context.

### What to measure

For each item, count lines and estimate characters:

1. **All CLAUDE.md / AGENTS.md files** — walk the directory tree. Note which are ancestors (load at launch) vs subdirectory (load lazily on demand).
2. **@-imports** — find all `@path/to/file` references in instruction files. These expand at launch and are hidden context cost. Measure what they expand to.
3. **MEMORY.md** — first 200 lines or 25KB load every session. Check current line count. Topic files (in the memory directory) load on demand — note their existence but don't count them as always-loaded.
4. **`.claude/rules/` files** — rules without `paths:` frontmatter load at launch. Path-scoped rules load when matching files are opened.
5. **Skill descriptions** — always in context (budget: ~1% of context window, fallback 8,000 chars). Each skill's frontmatter (name + description) is capped at 1,024 chars; aim for descriptions under ~500 chars.

### Produce the Context Budget Report

```
## Context Budget Report

| Source | Location | Lines | Est. Chars | Loading |
|--------|----------|-------|------------|---------|
| Root CLAUDE.md | ./CLAUDE.md | ??? | ??? | Always |
| Frontend CLAUDE.md | ./frontend/CLAUDE.md | ??? | ??? | Always (ancestor) or Lazy |
| @-import: README | @README.md | ??? | ??? | Always (expands at launch) |
| MEMORY.md | ~/.claude/projects/.../MEMORY.md | ??? | ??? | First 200 lines |
| Rule: testing.md | .claude/rules/testing.md | ??? | ??? | Always (no paths: filter) |
| ...  | ... | ... | ... | ... |
| **TOTAL always-loaded** | | **???** | **???** | |

Target: each file under 200 lines. Combined always-loaded budget: as small as possible.
```

Present this report to the user before proceeding to Phase 2.

---

## Phase 2: Plan

For every section in every instruction file, apply the **litmus test** and route it to the right destination.

### The Litmus Test

For each section, ask: **"Would removing this cause the agent to make mistakes?"**

- **Yes** — it stays in the instruction file (but condensed)
- **No** — it gets extracted, moved, or deleted

### The Content Router

```dot
digraph router {
  "Content to place" [shape=ellipse];
  "Needed EVERY session?" [shape=diamond];
  "Removing it causes mistakes?" [shape=diamond];
  "Multi-step procedure?" [shape=diamond];
  "Reference material?" [shape=diamond];
  "Shared team convention?" [shape=diamond];
  "Personal learned pattern?" [shape=diamond];

  "Keep in instruction file\n(condensed, <3 lines)" [shape=box];
  "Skill\n(.claude/skills/)" [shape=box];
  "Separate doc +\npitch-style reference" [shape=box];
  "Rules file\n(.claude/rules/)" [shape=box];
  "Auto memory" [shape=box];
  "Delete" [shape=box];

  "Content to place" -> "Needed EVERY session?";
  "Needed EVERY session?" -> "Removing it causes mistakes?" [label="yes"];
  "Removing it causes mistakes?" -> "Keep in instruction file\n(condensed, <3 lines)" [label="yes"];
  "Removing it causes mistakes?" -> "Delete" [label="no"];
  "Needed EVERY session?" -> "Multi-step procedure?" [label="no"];
  "Multi-step procedure?" -> "Skill\n(.claude/skills/)" [label="yes"];
  "Multi-step procedure?" -> "Reference material?" [label="no"];
  "Reference material?" -> "Separate doc +\npitch-style reference" [label="yes"];
  "Reference material?" -> "Shared team convention?" [label="no"];
  "Shared team convention?" -> "Rules file\n(.claude/rules/)" [label="yes"];
  "Shared team convention?" -> "Personal learned pattern?" [label="no"];
  "Personal learned pattern?" -> "Auto memory" [label="yes"];
  "Personal learned pattern?" -> "Delete" [label="no"];
}
```

### Destination Guide

| Destination | What goes here | Loading behavior |
|---|---|---|
| **Instruction file (CLAUDE.md)** | Facts the agent needs every session: build commands, critical rules, architectural decisions, key gotchas | Always loaded. Survives compaction (root only). |
| **Skill (.claude/skills/)** | Multi-step procedures: deployment, migration, debugging workflows, testing playbooks | Frontmatter always in context (1,024 chars max; description ~500 chars target). Body loads only when invoked. |
| **Separate doc + reference** | Reference material: route tables, component catalogs, API docs, env var tables, schema docs, code examples | Never loaded automatically. Agent reads on demand. |
| **Rules (.claude/rules/)** | Shared conventions scoped to file types: "when editing *.tsx, follow these patterns" | Unconditional rules load at launch. Path-scoped rules load on file match. |
| **Auto memory** | Personal learned patterns, workflow preferences, feedback corrections | First 200 lines of MEMORY.md load every session. Topic files load on demand. |
| **Delete** | Content the agent can derive from code: file trees, version numbers, standard conventions, self-evident practices | Never existed in context. |

### Reference Technique: Pitch-Style Pointers

When extracting content to a separate doc, leave a **conditional reference** — not a bare path.

```markdown
# BAD — bare path (agent doesn't know WHEN to read it)
- Route table: `docs/routes.md`

# GOOD — pitch-style reference (tells agent when to look)
- Before adding or modifying a route -> `docs/routes.md`
- When creating a React component -> `docs/components.md`
- Before deploying -> `docs/deployment.md`
```

The pitch-style reference tells the agent both WHAT exists and WHEN to read it — a conditional trigger, not a bibliography entry.

### @-Import Warning

**@-imports (`@path/to/file.md`) expand at launch** — they are NOT lazy. Every @-imported file loads into context on every session, even when irrelevant. Use plain pitch-style references instead:

```markdown
# BAD — expands at launch, burns context every session
@docs/api-reference.md

# GOOD — agent reads on demand only when needed
- Before calling a backend endpoint -> `docs/api-reference.md`
```

Reserve @-imports only for short files (<30 lines) that genuinely apply to every session (e.g., importing a shared AGENTS.md).

### Compaction Survival Rule (IMPORTANT for monorepos)

Content in the **root instruction file** survives compaction — it is re-read from disk and re-injected after `/compact`. Content in **subdirectory instruction files** is NOT re-injected — it reloads only when the agent next reads a file in that directory.

**Critical rules must live in the root file, not subdirectory files.** If a rule matters enough that forgetting it mid-session would cause damage, it belongs in the root. When your restructuring plan moves content between files, always ask: "If `/compact` runs and this file doesn't reload, would the agent make a dangerous mistake?" If yes, keep it in root.

### Produce the Restructuring Plan

For each section, state:

| Section | Current | Action | Destination | Condensed Version |
|---|---|---|---|---|
| Route table | 60 lines | Extract | `docs/routes.md` | "Before adding routes -> `docs/routes.md`" |
| Build commands | 15 lines | Keep, condense | Instruction file | (3 essential commands) |
| ... | ... | ... | ... | ... |

**Include a verification section in the plan.** List 5-10 key terms you will grep for after restructuring to confirm nothing was lost. This is part of the plan, not an afterthought.

**Flag compaction-critical content.** In your plan table, mark any rule that must survive compaction with "(root only)" in the Destination column. If a critical rule currently lives in a subdirectory file, the plan must move it to root.

Present this plan to the user and get approval before implementing.

---

## Phase 3: Implement

Execute the approved plan, then verify nothing was lost.

### Composition with `instruction-guardian`

Phase 3 Edits do **not** require per-file `instruction-guardian` invocation — the approved Phase-2 plan IS the guardian pass (same litmus test, same routing flowchart, with explicit user approval). The plugin mechanizes this carve-out via a per-project flag file in the system tmpdir: when the flag is present, the guardian's `PreToolUse` hook suppresses its reminder for matching Edits. Phase 3 owns the flag's lifecycle (create on approval, remove on completion). The flag never lives inside the consumer's repo, so `.gitignore` is not involved.

Run guardian only when a Phase 3 Edit deviates from the approved plan — scope creep, newly discovered sections, ad-hoc additions, or content you decide to handle differently. A deviating Edit should disarm the flag (see "Final step" below) before running, or accept that the hook will not fire for it.

### Step 0 — Arm the carve-out (immediately after Phase-2 approval)

Before any Edits, create the flag so the guardian hook stays silent for the rest of Phase 3:

```sh
flag="${TMPDIR:-/tmp}/instruction-health-cleanup-$(printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}" | cksum | awk '{print $1}').flag"
touch "$flag"
```

The flag lives in the system tmpdir, keyed by a `cksum` of `CLAUDE_PROJECT_DIR` so it scopes per-project and never enters the repo.

### Implementation Order

1. **Create extracted docs first** — write the files that content is moving to
2. **Create skills** — write SKILL.md files for procedures being extracted
3. **Rewrite the instruction file** — condense kept content, add pitch-style references, remove extracted content
4. **Clean up memory** — if MEMORY.md was flagged in audit, move misplaced content to instruction files or rules

### Verification: The Needle Grep

After restructuring, verify that key concepts are still reachable. Pick 5-10 important terms from the original file and grep for them:

```bash
# Can the agent still find routing info?
grep -r "route" docs/ CLAUDE.md .claude/

# Can it find the deployment procedure?
grep -r "deploy" .claude/skills/ docs/

# Is the critical pitfall still inline?
grep "getSession" CLAUDE.md
```

If a key term is unreachable (not in any instruction file, doc, skill, or code), something was lost. Fix it before committing.

### Final step — Disarm the carve-out

Once the verification grep is clean, remove the flag so guardian reminders re-enable for any subsequent edits:

```sh
flag="${TMPDIR:-/tmp}/instruction-health-cleanup-$(printf '%s' "${CLAUDE_PROJECT_DIR:-$PWD}" | cksum | awk '{print $1}').flag"
rm -f "$flag"
```

Skip-or-forget this step and the next session would silently bypass the guardian for instruction-file edits in this project — `SessionStart` cleans up stale flags as a safety net (and the OS clears `$TMPDIR` on reboot), but Phase 3 should not rely on either.

### Target Metrics

| Metric | Target |
|---|---|
| Lines per instruction file | Under 200 |
| Code blocks in instruction files | 0 (extract to docs or skills) |
| Large tables (10+ rows) | 0 (extract to docs) |
| @-imports of large files | 0 (convert to pitch-style references) |
| MEMORY.md line count | Well under 200, with headroom for growth |

---

## Common Mistakes

1. **Skipping the audit** — Restructuring without measuring leads to "feels smaller" but no actual context reduction. Measure first.
2. **Leaving all pitfalls in docs** — Critical gotchas (ones that cause CI failures or data loss) MUST stay inline. Only extract the less severe ones.
3. **Not considering skills** — Deployment procedures, testing workflows, and debugging playbooks are verbs, not nouns. They belong in skills, not docs.
4. **One-shot restructuring** — This should be a conversation: audit -> present -> plan -> approve -> implement -> verify. Not a single commit.
