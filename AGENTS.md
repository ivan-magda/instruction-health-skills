# Agent Guidelines for Instruction Health Skills

This document provides guidance for AI agents working with this plugin to ensure consistency and avoid common pitfalls.

## Core Principles

### 1. Routing First, Content Second

**This plugin is about where content belongs, not what it says.** Every decision flows through the same question: "What is the correct destination for this content?" Not: "How should this content be phrased?"

- `instruction-guardian` routes *before* a write happens.
- `instruction-cleanup` re-routes content that was misplaced in the past.

Do not include:

- Opinions about what *should* be in a project's CLAUDE.md
- Content-generation templates ("here's what a good CLAUDE.md looks like")
- Domain-specific guidance (security, testing, deployment rules) — those belong in their own skills

### 2. No Project-Specific Opinions

**Stick to generic, cross-project routing principles.** Avoid:

- Prescribing a required file structure ("every project must have `.claude/rules/testing.md`")
- Mandating specific section names in CLAUDE.md
- Enforcing whether a repo should even have a CLAUDE.md
- Dictating team workflow (code review, PR templates, branch naming)

**Exception**: The line-budget thresholds (200 lines, 40k chars, 1,536-char skill descriptions) are not opinions — they are drawn from published Anthropic guidance and are treated as facts.

### 3. The Litmus Test Applies to Everything Added

**Before the skill persists or recommends persisting any content, apply the litmus test:** "Would removing this cause the agent to make mistakes?"

- **Yes** → it belongs somewhere in the instruction surface area (instruction file / skill / rule / memory). Route it.
- **No** → do not persist it. The agent will read the code.

This is the single fact-driven gate. Everything else in the skill flows from it.

### 4. Guardian Pushes Back; Cleanup Audits First

Behavioral rules for the two skills:

- **`instruction-guardian`** — when the user asks "add this to CLAUDE.md" and the content doesn't belong, politely push back and suggest the right destination. Do not silently comply. If the user insists after hearing the tradeoff, comply — but condense and note the line-count impact.
- **`instruction-cleanup`** — never jump to restructuring. Always produce the Context Budget Report (Phase 1) first, then the Restructuring Plan with verification list (Phase 2), then wait for user approval before implementing (Phase 3).

## Content Guidelines

### Suggestions vs Requirements

**Use "route to X" or "consider X" for destination recommendations:**

- ✅ "Consider routing this deployment procedure to a skill — it's a multi-step verb."
- ✅ "This API table belongs in a separate doc, not CLAUDE.md."
- ❌ "All deployment procedures must be in `.claude/skills/deploy/`."

**Reserve "never" or "always" for destructive anti-patterns:**

- ✅ "Never paste full code blocks (over 5 lines) into CLAUDE.md — burns context every session."
- ✅ "Never create an `@`-import for files over 30 lines — they expand at launch unconditionally."
- ✅ "Always apply the litmus test before persisting."

### Language and Tone

**Factual, direct, and helpful:**

- "This belongs in a skill because it's a multi-step procedure."
- "At [N] lines, CLAUDE.md is [near / over] the 200-line target — extract something before adding."
- "Removing this wouldn't cause mistakes, so the agent can read the code directly."

**Avoid prescriptive or judgmental language:**

- ❌ "Your CLAUDE.md is bad."
- ❌ "You must organize your skills under `.claude/skills/<domain>/`."
- ❌ "Your team needs a CONTRIBUTING.md."

## What to Include

### ✅ Include These Topics:

- Context-budget measurement (lines, chars, `@`-import expansion cost, skill description size)
- Destination routing — instruction file / skill / rule / doc / memory / delete
- The litmus test and its application to real content
- Compaction survival rules (root vs subdirectory instruction files)
- `@`-import guidance (when they're safe, when they silently balloon context)
- Pitch-style references for conditional lookups
- Condensation patterns for content that does belong inline
- Line-budget thresholds (200-line soft target, 1,536-char skill description cap, MEMORY.md first-200-line rule)

### ❌ Exclude These Topics:

- What to put in CLAUDE.md for a specific domain (security, testing, deployment) — those are separate skills
- Content templates or boilerplate ("here's what a good CLAUDE.md looks like")
- File naming opinions
- Git / PR / review workflow guidance
- Whether to use CLAUDE.md vs AGENTS.md — this is a tool choice, not a routing question
- Advice on writing skills themselves (use `superpowers:writing-skills` for that)
- Project structure mandates

## Common AI Generator Mistakes to Correct

When routing or reviewing instruction-file content, watch for these frequent AI mistakes:

- Pasting full code blocks into CLAUDE.md instead of extracting to a doc or source file
- Creating `@`-imports for large reference files (the imports expand at launch every session)
- Duplicating content between CLAUDE.md and MEMORY.md — creates conflicting sources of truth
- Stuffing multi-step procedures inline instead of extracting to a skill
- Skipping the litmus test — adding content "just in case"
- Writing prescriptive style rules ("use tabs not spaces") that the tooling / linter already enforces
- Storing project-specific context in a skill description instead of an instruction file
- Leaving critical rules in subdirectory instruction files (they don't survive `/compact`)
- Using bare path references ("see `docs/routes.md`") instead of pitch-style triggers ("before adding a route → `docs/routes.md`")
- Restructuring without an audit — "it feels smaller" is not the same as measurably smaller

## Updating the Skills

When adding new content to either skill, ask:

1. **Is this about routing or an opinion?** Opinions don't belong.
2. **Does it survive the litmus test?** If the skill itself doesn't apply the litmus test to its own content, it fails its own rules.
3. **Is it generic across projects, or project-specific?** Project-specific belongs in memory, not the skill.
4. **Can an agent actually act on this?** Vague prose ("consider thinking carefully") isn't actionable — concrete thresholds and routing trees are.

If unsure, err on the side of excluding content. It's better to have a focused, actionable skill than a comprehensive but vague one.

## Summary

**Focus**: routing content to the correct destination, preventing context-budget bloat
**Avoid**: project-specific opinions, content templates, team workflow guidance
**Tone**: factual, direct, non-prescriptive
**Goal**: give agents a fact-driven framework for keeping instruction files lean, without enforcing what those files should say
