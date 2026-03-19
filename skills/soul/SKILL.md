---
name: soul
description: "Persistent orchestrator identity. Manages Maestro's decision principles, communication style, quality bar, autonomy level, and learned patterns across sessions."
---

# Soul

Manages Maestro's persistent identity — the principles, preferences, and learned patterns that shape how the orchestrator makes decisions, communicates, and enforces quality. The SOUL survives session boundaries and evolves as patterns accumulate.

Unlike DNA (project conventions) and Preferences (developer tech choices), SOUL governs the orchestrator itself: how it reasons, how much it asks, and what it refuses to cut corners on.

## File Locations

| Scope | Path | Purpose |
|-------|------|---------|
| Per-project | `.maestro/soul.md` | Overrides global SOUL for this project |
| Global | `~/.claude/maestro-soul.md` | Applies to all projects on this machine |

Resolution order: per-project SOUL overrides global SOUL. If neither exists, the Context Engine uses the template defaults.

## Operations

### show

Display the current SOUL. If a per-project SOUL exists at `.maestro/soul.md`, show that. If not, fall back to `~/.claude/maestro-soul.md`. If neither exists, show the template defaults from `templates/soul.md` with a notice that no SOUL has been initialized yet.

**Output format:**

```
Soul: [project-local | global | template defaults]
Last evolved: [date or "never"]
Evolution count: [N]

Decision Principles ([N])
  - [each principle]

Communication Style ([N])
  - [each item]

Quality Bar
  - QA confidence threshold: [N]
  - Self-heal max cycles: [N]
  - Minimum test coverage: [value]
  - Lighthouse thresholds: [value]

Autonomy Level
  - Mode preference: [mode]
  - Auto-approve simple stories: [true/false]
  - Escalate on: [triggers]

Learned Patterns ([N])
  [list or "(none yet)"]
```

### evolve

Add a learned pattern to the SOUL's `## Learned Patterns` section.

**Syntax:** `/maestro soul evolve "<pattern>"`

**Process:**

1. Read the current SOUL file (per-project first, then global, then initialize from template if absent).
2. Append the pattern under `## Learned Patterns` with a date stamp:
   ```
   - [YYYY-MM-DD] <pattern>
   ```
3. Increment `evolution_count` in the frontmatter.
4. Update `last_evolved` in the frontmatter to today's date.
5. Write the updated file.
6. Confirm: `Soul evolved. Patterns: [N]. File: [path]`

If no SOUL file exists yet, create `.maestro/soul.md` from `templates/soul.md` first, then add the pattern.

**Validation:** The pattern must be a concrete behavioral statement. Reject patterns that are:
- Vague ("be better", "try harder")
- Already present verbatim in the Learned Patterns section

### reset

Reset the SOUL to template defaults. Requires explicit confirmation.

**Process:**

1. Display current SOUL stats: evolution count, pattern count, last evolved date.
2. Ask: `Reset soul? This removes [N] learned patterns and [N] custom principles. [yes/no]`
3. If confirmed: overwrite the SOUL file with a fresh copy from `templates/soul.md`, with `created` set to today, `last_evolved` set to today, `evolution_count` set to 0.
4. If declined: do nothing.

`reset` never touches the global `~/.claude/maestro-soul.md` unless the `--global` flag is provided.

---

## Retrospective Integration

The retrospective skill calls `soul evolve` automatically when a pattern is detected 3 or more times across stories in a session.

**Pattern promotion criteria:**

- A USER_CORRECTION signal appears 3 or more times addressing the same behavior
- A REPETITION signal identifies the same fix applied 3 or more times
- A TONE_ESCALATION signal recurs 3 or more times around the same orchestrator behavior

When criteria are met, the retrospective generates a pattern candidate and presents it to the user:

```
Soul pattern candidate:
  Pattern: "[inferred pattern statement]"
  Evidence: Detected 3 times — stories [N], [N], [N]
  Add to soul? [yes/no]
```

User approval is required before the pattern is written to SOUL. The retrospective never promotes patterns silently.

---

## Context Engine Integration

The SOUL is loaded at T0 (orchestrator tier) during Step 1 of the Context Engine's composition pipeline.

**Load order:**

1. Check for `.maestro/soul.md` in the project root.
2. If absent, check `~/.claude/maestro-soul.md`.
3. If absent, use the built-in defaults from `templates/soul.md`.

**What the orchestrator uses:**

| SOUL Section | How It Shapes Dispatch |
|-------------|------------------------|
| Decision Principles | Informs story prioritization and tradeoff resolution |
| Communication Style | Controls checkpoint verbosity, status format, question frequency |
| Quality Bar | Sets QA confidence threshold and self-heal cycle limit |
| Autonomy Level | Determines when to pause vs. proceed, what to escalate |
| Learned Patterns | Injected as high-priority notes at story planning time |

**Relevance score:** SOUL content is scored at **1.0** for the orchestrator role — it is always fully included. It is not passed to implementer, QA, or self-heal agents.

**Token budget:** SOUL typically consumes 300-600 tokens. Reserved from the T0 budget before all other context pieces.

---

## Conflict Resolution with Other Layers

| SOUL setting | Competing source | Winner |
|-------------|-----------------|--------|
| Autonomy Level | User command-line flag (`--mode yolo`) | Flag wins for current session only |
| Quality Bar | Project DNA QA thresholds | SOUL wins — orchestrator identity overrides project-level defaults |
| Communication Style | User correction mid-session | Correction wins for session; if 3 recurrences, promote to SOUL via retrospective |
| Learned Patterns | Implementer prompt conventions | Both apply; SOUL patterns surface first in orchestrator reasoning |

---

## Integration Points

- **Loaded by:** `context-engine` skill (T0 orchestrator package, every session start)
- **Evolved by:** `retrospective` skill (pattern promotion after 3+ detections, user approval required)
- **Fed by:** `preferences` skill (developer preferences may inform initial SOUL setup)
- **Mentioned by:** SessionStart hook (reports SOUL status — last evolved date, pattern count)
- **Reads:** `.maestro/soul.md` (per-project), `~/.claude/maestro-soul.md` (global)
- **Writes:** `.maestro/soul.md` (per-project by default), `~/.claude/maestro-soul.md` (with `--global` flag)
- **Template:** `templates/soul.md`
