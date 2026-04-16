# Instruction Health Skills

Agent skills to keep AI assistant instruction files (AGENTS.md, CLAUDE.md, MEMORY.md) lean and healthy. Two complementary skills: a reactive **guardian** that runs before an instruction file is edited to prevent bloat, and a three-phase **cleanup** for files that have already grown too large. Designed to work with Claude, Cursor, Windsurf, Copilot, and other AI coding assistants that support the Agent Skills / AGENTS.md format.

## Why These Skills Exist

I built these after my team's `CLAUDE.md` hit Claude Code's 40k-character warning — 519 lines that had grown organically over three months. The cost wasn't tokens: instruction-following degrades uniformly as the file grows, so a fat instruction file makes the agent worse at *every* rule in it, not just the ones it skips. Cleaning that up by hand got our always-loaded context down 73% ([writeup](https://ivanmagda.dev/posts/fixing-40k-claude-md-warning-monorepo/)). These two skills are the codified version of that routine — one to prevent the bloat, one to fix it once it's there.

The instruction file is a prompt budget, not documentation.

## Philosophy

These skills focus on **facts about context-budget hygiene**, not opinions about what belongs in your instruction file.

**Covered:**

- Routing — every piece of content has exactly one correct destination (instruction file, skill, rule, doc, memory, or delete)
- Context budget — measuring, condensing, and preventing re-bloat of always-loaded context
- Compaction survival — which content survives `/compact` and which silently disappears

**Intentionally excluded:**

- No team workflow opinions — no mandate on what goes in CLAUDE.md vs AGENTS.md vs team docs
- No naming conventions — no rules about skill names, doc paths, or file structure
- No prescriptive style — the litmus test ("would removing this cause mistakes?") drives every call

## Structure

```
instruction-health-skills/
├── .claude-plugin/
│   ├── plugin.json                      # Claude Code plugin manifest
│   └── marketplace.json                 # Claude Code marketplace catalog
├── instruction-cleanup/
│   └── SKILL.md                         # Three-phase restructuring procedure
└── instruction-guardian/
    └── SKILL.md                         # Six-step pre-write checklist
```

## Coverage

| Skill | When it triggers | What it does |
| ----- | ---------------- | ------------ |
| `instruction-guardian` | Before any edit to CLAUDE.md / AGENTS.md / MEMORY.md / `.claude/rules/` | Runs a six-step checklist: line budget, dedup check, litmus test, destination routing, format rules, `@`-import prevention. Politely pushes back when content doesn't belong in an instruction file. |
| `instruction-cleanup` | After files have already grown past ~200 lines or ~40k chars (agent performance has degraded) | Three-phase audit → plan → implement procedure. Measures the full context-budget surface area, classifies every section, restructures with a needle-grep verification step. |

## When to Use Which

- Use **`instruction-guardian`** as a day-to-day gate — on *every* edit to an instruction file. Keeps files from re-bloating.
- Use **`instruction-cleanup`** once, when you realize the files are already too large. It produces a written plan you approve before anything is rewritten.

The two are designed to be used together: cleanup fixes the past, guardian prevents the future.

## How to Use These Skills

### Option A: Using skills.sh (recommended)

Run a single command and pick both skills in the wizard (space to toggle, enter to confirm):

```bash
npx skills add https://github.com/ivan-magda/instruction-health-skills
```

Or install both non-interactively in one shot:

```bash
npx skills add https://github.com/ivan-magda/instruction-health-skills --skill instruction-cleanup instruction-guardian
```

For an unattended setup that also picks every agent, use `--all`.

For more information, visit the per-skill platform pages:

- [instruction-cleanup](https://skills.sh/ivan-magda/instruction-health-skills/instruction-cleanup)
- [instruction-guardian](https://skills.sh/ivan-magda/instruction-health-skills/instruction-guardian)

Then use the skill in your AI agent, for example:

> Use the instruction-guardian skill to check whether this new section belongs in CLAUDE.md

### Option B: Claude Code Plugin

#### Personal Usage

Both skills are bundled into a single plugin — one marketplace add, one install, and you get both.

Add the marketplace:

```bash
/plugin marketplace add ivan-magda/instruction-health-skills
```

Install the plugin:

```bash
/plugin install instruction-health@instruction-health-skills
```

#### Project Configuration

To automatically provide both skills to everyone working in a repository, configure the repository's `.claude/settings.json`:

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

When team members open the project, Claude Code will prompt them to install the plugin.

### Option C: Manual install

1. **Clone** this repository.
2. **Symlink both skill folders** into your tool's skills directory. For Claude Code:

   ```bash
   ln -s /path/to/clone/instruction-cleanup ~/.claude/skills/instruction-cleanup
   ln -s /path/to/clone/instruction-guardian ~/.claude/skills/instruction-guardian
   ```

3. **Use your AI tool** as usual and ask it to use either skill when touching instruction files.

#### Where to Save Skills

Follow your tool's official documentation, here are a few popular ones:

- **Codex:** [Where to save skills](https://developers.openai.com/codex/skills/#where-to-save-skills)
- **Claude:** [Using Skills](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/overview#using-skills)
- **Cursor:** [Enabling Skills](https://cursor.com/docs/context/skills#enabling-skills)

**How to verify:**

Your agent should reference the checklist/workflow in the relevant `SKILL.md` on instruction-file edits — the guardian before a write, the cleanup when files are already bloated.

## License

MIT
