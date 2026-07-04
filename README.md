# Instruction Health Skills

> Agent skills that keep AI assistant instruction files (AGENTS.md, CLAUDE.md, MEMORY.md) lean.

Two skills work together: a **guardian** that runs before an instruction file is edited to prevent bloat, and a three-phase **cleanup** for files that have already grown too large. They work with Claude, Cursor, Windsurf, Copilot, Codex, and other AI coding assistants that support the Agent Skills / AGENTS.md format.

## Table of Contents

- [Background](#background)
- [Philosophy](#philosophy)
- [Features](#features)
- [Installation](#installation)
- [Usage](#usage)
- [Project Structure](#project-structure)
- [Contributing](#contributing)
- [License](#license)

## Background

My team's `CLAUDE.md` hit Claude Code's 40k-character warning at 519 lines, grown over three months. The cost wasn't token count. Instruction-following degrades as the file grows, so a bloated instruction file makes the agent worse at every rule it holds, not only the ones it skips. I cleaned ours up by hand and cut always-loaded context by 73% ([writeup](https://ivanmagda.dev/posts/fixing-40k-claude-md-warning-monorepo/)). These two skills codify that routine: one prevents the bloat, one fixes it once it lands.

Treat the instruction file as a prompt budget. Spend it on rules the agent needs in front of it every turn.

## Philosophy

These skills handle context-budget hygiene as a set of facts, leaving opinions about what belongs in your instruction file to you.

**Covered:**

- Routing: every piece of content has one correct destination (instruction file, skill, rule, doc, memory, or delete).
- Context budget: measuring, condensing, and preventing re-bloat of always-loaded context.
- Compaction survival: which content survives `/compact` and which disappears.

**Intentionally excluded:**

- Team workflow opinions. No mandate on what goes in CLAUDE.md vs AGENTS.md vs team docs.
- Naming conventions. No rules about skill names, doc paths, or file structure.
- Prescriptive style. The litmus test ("would removing this cause mistakes?") drives every call.

## Features

| Skill                  | When to use it                                                                                                                                                              | What it does                                                                                                                                                                                |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `instruction-guardian` | Day-to-day gate. Runs before every edit to CLAUDE.md / AGENTS.md / MEMORY.md / `.claude/rules/`, keeping files from re-bloating.                                            | Runs a six-step checklist: line budget, dedup check, litmus test, destination routing, format rules, `@`-import prevention. Pushes back when content doesn't belong in an instruction file. |
| `instruction-cleanup`  | One-time fix. Run when files have grown past ~200 lines or ~40k chars and agent performance has degraded. Produces a written plan you approve before anything is rewritten. | Three-phase audit, plan, and implement procedure. Measures the full context-budget surface area, classifies every section, and restructures with a needle-grep verification step.           |

Cleanup fixes the past, guardian prevents the future.

## Installation

### Option A: skills.sh (recommended)

Run one command and pick both skills in the wizard (space to toggle, enter to confirm):

```bash
npx skills add https://github.com/ivan-magda/instruction-health-skills
```

Or install both non-interactively in one shot:

```bash
npx skills add https://github.com/ivan-magda/instruction-health-skills --skill instruction-cleanup instruction-guardian
```

For an unattended setup that also picks every agent, use `--all`.

Per-skill platform pages:

- [instruction-cleanup](https://skills.sh/ivan-magda/instruction-health-skills/instruction-cleanup)
- [instruction-guardian](https://skills.sh/ivan-magda/instruction-health-skills/instruction-guardian)

### Option B: Claude Code plugin

Both skills ship in a single plugin: one marketplace add, one install, and you get both.

Add the marketplace:

```bash
/plugin marketplace add ivan-magda/instruction-health-skills
```

Install the plugin:

```bash
/plugin install instruction-health@instruction-health-skills
```

The plugin ships a `PreToolUse` hook that reminds the agent to invoke `instruction-guardian` before any `Edit` or `Write` against an instruction file (CLAUDE.md / AGENTS.md / MEMORY.md / `.claude/rules/` / memory topic files), and a `SessionStart` hook that clears any leftover `instruction-cleanup` carve-out flag. Both activate when the plugin is installed, with no extra configuration.

To provide both skills to everyone working in a repository, configure the repository's `.claude/settings.json`:

```json
{
  "enabledPlugins": {
    "instruction-health@instruction-health-skills": true
  },
  "extraKnownMarketplaces": {
    "instruction-health-skills": {
      "source": {
        "source": "github",
        "repo": "ivan-magda/instruction-health-skills"
      }
    }
  }
}
```

When team members open the project, Claude Code prompts them to install the plugin.

### Option C: Manual install

1. **Clone** this repository.
2. **Symlink both skill folders** into your tool's skills directory. For Claude Code:

   ```bash
   ln -s /path/to/clone/instruction-cleanup ~/.claude/skills/instruction-cleanup
   ln -s /path/to/clone/instruction-guardian ~/.claude/skills/instruction-guardian
   ```

3. **Use your AI tool** as usual and ask it to use either skill when touching instruction files.

For where to save skills, follow your tool's documentation:

- **Codex:** [Where to save skills](https://developers.openai.com/codex/skills/#where-to-save-skills)
- **Claude:** [Using Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#using-skills)
- **Cursor:** [Enabling Skills](https://cursor.com/docs/context/skills#enabling-skills)

## Usage

Ask your agent to run the guardian before adding to an instruction file:

> Use the instruction-guardian skill to check whether this new section belongs in CLAUDE.md

Run the cleanup once files have already bloated:

> Use the instruction-cleanup skill to audit this repo's instruction files and propose a restructuring plan

To confirm a skill is active, watch for your agent referencing the checklist or workflow in the relevant `SKILL.md` on instruction-file edits: the guardian before a write, the cleanup when files are already bloated.

## Project Structure

```
instruction-health-skills/
├── .claude-plugin/
│   ├── plugin.json                      # Claude Code plugin manifest
│   └── marketplace.json                 # Claude Code marketplace catalog
├── hooks/
│   ├── hooks.json                       # PreToolUse + SessionStart hook wiring
│   ├── guardian-reminder.sh             # Reminds the agent to invoke instruction-guardian pre-edit
│   └── clear-cleanup-flag.sh            # Clears a stale cleanup carve-out flag at session start
├── instruction-cleanup/
│   └── SKILL.md                         # Three-phase restructuring procedure
├── instruction-guardian/
│   └── SKILL.md                         # Six-step pre-write checklist
└── tests/
    └── hook-unit-tests.sh               # Unit tests for both hook scripts
```

## Contributing

Issues and pull requests are welcome. Open an issue to discuss a change before sending a larger pull request.

## License

MIT
