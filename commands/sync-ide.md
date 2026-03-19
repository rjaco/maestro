---
name: sync-ide
description: "Generate and maintain IDE-specific instruction files (.cursorrules, GEMINI.md, agents.md, copilot-instructions) from Maestro's canonical markdown source. Detects drift and regenerates on demand."
argument-hint: "[--target <cursorrules|gemini|agents|copilot>|--check]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
---

# /maestro sync-ide

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███████╗██╗   ██╗███╗   ██╗ ██████╗    ██╗██████╗ ███████╗
██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝    ██║██╔══██╗██╔════╝
███████╗ ╚████╔╝ ██╔██╗ ██║██║         ██║██║  ██║█████╗
╚════██║  ╚██╔╝  ██║╚██╗██║██║         ██║██║  ██║██╔══╝
███████║   ██║   ██║ ╚████║╚██████╗    ██║██████╔╝███████╗
╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝   ╚═╝╚═════╝ ╚══════╝
```

Sync Maestro's canonical configuration to IDE-specific instruction files. Keeps Cursor, Gemini CLI, GitHub Copilot, and other tools in sync with your project's conventions and squad assignments — from a single source of truth.

---

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

---

## Step 2: Handle Arguments

### No arguments — Run full sync (default)

Invoke the `ide-sync` skill from `skills/ide-sync/SKILL.md` to regenerate all IDE-specific files from canonical sources.

**Canonical sources read:**
- `CLAUDE.md` — project conventions, tech stack, workflow rules
- `skills/*/SKILL.md` — relevant skill behaviors
- Active squad definition from `.maestro/state.local.md`
- `.maestro/dna.md` — project DNA (language, framework, architecture)
- `.maestro/config.yaml` — active feature flags and preferences

**Targets generated:**
- `.cursorrules` — always-on Cursor prompt injection
- `GEMINI.md` — Gemini CLI session instructions
- `agents.md` — cross-tool agent discovery (via `agents-md` skill)
- `.github/copilot-instructions.md` — GitHub Copilot repository instructions

**Format translation applied per target:**

| Canonical Feature | `.cursorrules` | `GEMINI.md` | `copilot-instructions.md` |
|-------------------|---------------|-------------|--------------------------|
| Skill invocation (`/maestro X`) | Omit | Omit | Omit |
| `AskUserQuestion` checkpoint | Replace with CHECKPOINT pattern | Replace with CHECKPOINT pattern | Omit |
| Hook-based branch guard | Convert to explicit prohibition | Convert to explicit prohibition | Single-line rule |
| Parallel agent dispatch | Omit | Sequential phases workaround | Omit |
| Model selection rules | Omit | Omit | Omit |

Before overwriting, check each target for manual edits. A file is considered manually edited if its `Updated:` header line is missing or removed. If manual edits are detected, warn:

```
[ide-sync] Warning: .cursorrules appears to have been manually edited.

  Regenerating will overwrite your changes.
  To preserve them, move them to CLAUDE.md and run /maestro sync-ide.

  Proceed? [yes / no]
```

On completion, display:

```
+---------------------------------------------+
| IDE Sync Complete                           |
+---------------------------------------------+

  .cursorrules                     regenerated
  GEMINI.md                        regenerated
  agents.md                        regenerated (via agents-md skill)
  .github/copilot-instructions.md  regenerated

  Source: CLAUDE.md + .maestro/dna.md + squad: <active squad or "none">
  Updated: <ISO-8601 timestamp>

  (i) Never edit generated files manually — they will be overwritten on next sync.
  (i) Edit CLAUDE.md or skill files, then run /maestro sync-ide to propagate changes.
```

---

### `--target <name>` — Regenerate a single target

Valid values: `cursorrules`, `gemini`, `agents`, `copilot`

Regenerates only the specified file. All other targets are left unchanged.

Examples:
- `/maestro sync-ide --target gemini` — regenerates `GEMINI.md` only
- `/maestro sync-ide --target copilot` — regenerates `.github/copilot-instructions.md` only
- `/maestro sync-ide --target agents` — regenerates `agents.md` via `agents-md` skill

Output:

```
+---------------------------------------------+
| IDE Sync — GEMINI.md                        |
+---------------------------------------------+

  GEMINI.md  regenerated

  Source: CLAUDE.md + .maestro/dna.md + squad: <active squad or "none">
  Updated: <ISO-8601 timestamp>
```

If an invalid target name is provided:

```
[maestro] Unknown target: "<name>"

  Valid targets:
    cursorrules  →  .cursorrules
    gemini       →  GEMINI.md
    agents       →  agents.md
    copilot      →  .github/copilot-instructions.md
```

---

### `--check` — Drift detection only

Run drift detection without regenerating any files. Print the drift report and exit.

**Drift detection algorithm:**
1. Read the `Updated:` timestamp from the header of each generated file.
2. Compare against the modification time (`mtime`) of each canonical source that contributed to it.
3. If any canonical source is newer than the generated file's `Updated:` timestamp, mark the target as drifted.

If any targets have drifted:

```
+---------------------------------------------+
| IDE Sync — Drift Check                      |
+---------------------------------------------+

  Drifted targets:
    .cursorrules                (CLAUDE.md modified 2026-03-18, synced 2026-03-15)
    GEMINI.md                   (squads/full-stack-dev/squad.md modified 2026-03-17, synced 2026-03-15)

  Unchanged:
    .github/copilot-instructions.md
    agents.md

  Run /maestro sync-ide to regenerate all drifted targets.
  Run /maestro sync-ide --target <name> to regenerate a specific target.
```

If no drift is detected:

```
+---------------------------------------------+
| IDE Sync — Drift Check                      |
+---------------------------------------------+

  All targets are up to date.

  Last synced: <timestamp from most recent Updated: header>
```

If a target file does not exist yet (never been synced):

```
  .cursorrules                NOT FOUND — run /maestro sync-ide to generate
```

---

## Drift Check Triggers

| Trigger | Action |
|---------|--------|
| Session start | Silent drift check. Warn if any target is drifted. |
| After `/maestro init` | Auto-sync all targets (full regeneration). |
| After `squad activate` / `squad deactivate` | Regenerate `.cursorrules` and `GEMINI.md`. |
| After `squad create` | Regenerate all targets. |
| Manual `/maestro sync-ide` | Full regeneration of all targets. |

---

## Error Handling

| Error | Action |
|-------|--------|
| `CLAUDE.md` does not exist | Skip sync, print: `[ide-sync] CLAUDE.md not found — run /maestro init first.` |
| `.maestro/dna.md` does not exist | Use sensible defaults; note missing DNA in output |
| `.github/` directory does not exist | Create it before writing `copilot-instructions.md` |
| `agents-md` skill not available | Write a static `agents.md` placeholder; note in output |
| Target file is read-only | Print error with the offending path; skip that target and continue |

---

## Integration

- **ide-sync skill**: `skills/ide-sync/SKILL.md` — implements the full sync and drift logic
- **agents-md skill**: `skills/agents-md/SKILL.md` — generates `agents.md` from squad definitions
- **init**: auto-runs a full sync after project initialization
- **squad**: triggers re-sync of affected targets when squad configuration changes
