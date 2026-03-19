---
name: soul
description: "Manage the orchestrator's persistent identity — show current principles, add a learned pattern, or reset to template defaults"
argument-hint: "[show|evolve <pattern>|reset]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - AskUserQuestion
---

# Maestro Soul

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage the orchestrator's persistent identity. The SOUL governs how Maestro reasons, communicates, and enforces quality — across every session, on every project. Unlike DNA (project conventions) and Preferences (your tech choices), SOUL shapes the orchestrator itself.

## File Locations

| Scope | Path |
|-------|------|
| Per-project | `.maestro/soul.md` |
| Global | `~/.claude/maestro-soul.md` |

Resolution order: per-project overrides global. If neither exists, template defaults apply.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments or `show` — Display the current SOUL

Resolve SOUL file:
1. Check `.maestro/soul.md`
2. If absent, check `~/.claude/maestro-soul.md`
3. If neither exists, read `templates/soul.md` and note that no SOUL has been initialized

```
+---------------------------------------------+
| Soul                                        |
+---------------------------------------------+

  Source:           project-local | global | template defaults
  File:             .maestro/soul.md | ~/.claude/maestro-soul.md | (template)
  Last evolved:     <date> | never
  Evolution count:  <N>

  Decision Principles (<N>)
    - <each principle>

  Communication Style (<N>)
    - <each item>

  Quality Bar
    QA confidence threshold:  <N>
    Self-heal max cycles:     <N>
    Minimum test coverage:    <value>

  Autonomy Level
    Mode preference:           <mode>
    Auto-approve simple stories: <true/false>
    Escalate on:               <triggers>

  Learned Patterns (<N>)
    <list — or "(none yet)" if empty>

```

If using template defaults:

```
  (i) No SOUL file found. Showing template defaults.
  (i) Run /maestro soul evolve "<pattern>" to create a SOUL and add your first pattern.
```

After showing the SOUL, offer actions:

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Soul"
- Options:
  1. label: "Add a learned pattern", description: "Teach the orchestrator a new behavioral principle"
  2. label: "Reset to template", description: "Discard learned patterns and start from defaults"
  3. label: "Done", description: "No changes"

---

### `evolve <pattern>` — Add a learned pattern

Add a behavioral pattern to the SOUL's `## Learned Patterns` section.

**Example:** `/maestro soul evolve "Always propose a rollback plan when the story modifies database schema"`

1. Validate the pattern — reject if it is:
   - Vague (e.g., "be better", "try harder", "improve quality")
   - Already present verbatim in the Learned Patterns section

   If invalid:
   ```
   [maestro] Pattern rejected.

     Reason: Too vague — patterns must describe a specific, observable behavior.

     Example of a valid pattern:
       "Ask for human approval before running any migration that drops a column."

     Example of an invalid pattern:
       "Be more careful with databases."
   ```

2. Resolve the SOUL file (per-project first, then global). If neither exists, create `.maestro/soul.md` from `templates/soul.md` first.

3. Append the pattern under `## Learned Patterns`:
   ```
   - [YYYY-MM-DD] <pattern>
   ```

4. Increment `evolution_count` in the frontmatter. Update `last_evolved` to today's date.

5. Write the updated file.

6. Confirm:

   ```
   +---------------------------------------------+
   | Soul Evolved                                |
   +---------------------------------------------+

     Pattern:   <pattern>
     Added to:  .maestro/soul.md | ~/.claude/maestro-soul.md
     Total patterns: <N>
     Evolution count: <N>

     (i) This pattern will be active at the next orchestrator invocation.
     (i) Patterns are injected at T0 priority — they shape all dispatching decisions.
   ```

---

### `reset` — Reset to template defaults

1. Resolve the current SOUL file and read its stats.

2. Display what will be lost:

   ```
   +---------------------------------------------+
   | Reset Soul                                  |
   +---------------------------------------------+

     File:             .maestro/soul.md
     Evolution count:  <N>
     Learned patterns: <N>
     Last evolved:     <date>

     This will remove all learned patterns and custom principles,
     replacing them with the template defaults.
   ```

3. Use AskUserQuestion to confirm:
   - Question: "Reset soul? This removes <N> learned patterns and all customizations."
   - Header: "Confirm Reset"
   - Options:
     1. label: "Yes, reset to template", description: "Overwrite soul.md with a fresh template"
     2. label: "Cancel", description: "Keep the current soul"

4. On confirmation:
   - Copy `templates/soul.md` to `.maestro/soul.md`.
   - Set `created` and `last_evolved` to today's date in the frontmatter.
   - Set `evolution_count` to `0`.
   - Write the file.

5. Confirm:

   ```
   [maestro] Soul reset to template defaults.

     File:    .maestro/soul.md
     Created: <today>

     (i) All learned patterns have been removed.
     (i) Add new patterns with: /maestro soul evolve "<pattern>"
   ```

   Note: `reset` never touches `~/.claude/maestro-soul.md` unless `--global` is passed.

---

## Scope Flag

Append `--global` to any subcommand to operate on `~/.claude/maestro-soul.md` instead of the per-project file:

```
/maestro soul show --global
/maestro soul evolve "..." --global
/maestro soul reset --global
```

When `--global` is used, all file paths in output and confirmation messages reflect the global path.

---

## How SOUL Shapes Orchestration

| SOUL Section | Effect on Dispatch |
|-------------|-------------------|
| Decision Principles | Story prioritization and tradeoff resolution |
| Communication Style | Checkpoint verbosity, status format, question frequency |
| Quality Bar | QA confidence threshold and self-heal cycle limit |
| Autonomy Level | When to pause vs. proceed; what triggers escalation |
| Learned Patterns | Injected as high-priority notes at story planning time |

SOUL is loaded at T0 (orchestrator tier) — before DNA, preferences, or any project context. It is always fully included (relevance score 1.0) and typically consumes 300-600 tokens from the orchestrator budget.

---

## Argument Parsing

| Invocation | Behavior |
|-----------|----------|
| `/maestro soul` | Show current SOUL, then interactive menu |
| `/maestro soul show` | Show current SOUL (same as no args) |
| `/maestro soul evolve "<pattern>"` | Append a learned pattern |
| `/maestro soul reset` | Reset to template defaults (with confirmation) |
| `/maestro soul show --global` | Show the global SOUL file |
| `/maestro soul evolve "..." --global` | Add pattern to global SOUL |
| `/maestro soul reset --global` | Reset global SOUL to template |

The `--global` flag may appear anywhere in `$ARGUMENTS`. Strip it before processing the rest of the argument string.

## Error Handling

| Condition | Action |
|-----------|--------|
| `.maestro/config.yaml` missing | Print "Not initialized" and stop |
| `templates/soul.md` missing | Print `(x) Cannot find soul template. Reinstall the Maestro plugin.` and stop |
| Pattern argument is empty string | Print `[maestro] Pattern cannot be empty.` and stop |
| Pattern is a duplicate | Print `[maestro] Pattern already exists in soul.md` with the existing entry shown |
| Soul file has invalid frontmatter | Warn `(!) soul.md frontmatter is malformed — evolution_count not updated` and proceed with content edit only |
| `~/.claude/` directory does not exist | Create it before writing `~/.claude/maestro-soul.md` |

## SOUL File Format Reference

A valid soul file has this structure:

```markdown
---
created: YYYY-MM-DD
last_evolved: YYYY-MM-DD
evolution_count: N
---

## Decision Principles
- ...

## Communication Style
- ...

## Quality Bar
qa_confidence_threshold: 0.85
self_heal_max_cycles: 3
minimum_test_coverage: 80

## Autonomy Level
mode_preference: checkpoint
auto_approve_simple_stories: false
escalate_on:
  - schema_migration
  - external_api_change
  - security_change

## Learned Patterns
- [YYYY-MM-DD] <pattern>
```

When appending a pattern, locate the `## Learned Patterns` heading and add the new entry on the next available line. If the heading does not exist, append the section at the end of the file.

## Examples

### Example 1: Show soul (no arguments)

```
/maestro soul
```

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
...

+---------------------------------------------+
| Soul                                        |
+---------------------------------------------+

  Source:           project-local
  File:             .maestro/soul.md
  Last evolved:     2026-03-15
  Evolution count:  4

  Decision Principles (3)
    - Prefer incremental, reversible changes
    - Ask before modifying public API surface
    - Treat test coverage as a non-negotiable gate

  Communication Style (2)
    - Concise status updates, no filler phrases
    - Surface blockers immediately, don't buffer them

  Quality Bar
    QA confidence threshold:  0.85
    Self-heal max cycles:     3
    Minimum test coverage:    80%

  Autonomy Level
    Mode preference:           checkpoint
    Auto-approve simple stories: false
    Escalate on:               schema_migration, security_change

  Learned Patterns (1)
    - [2026-03-15] Always propose a rollback plan when the story modifies database schema
```

### Example 2: Add a learned pattern

```
/maestro soul evolve "Run the full test suite before marking any story complete, even for trivial changes"
```

```
+---------------------------------------------+
| Soul Evolved                                |
+---------------------------------------------+

  Pattern:   Run the full test suite before marking any story complete, even for trivial changes
  Added to:  .maestro/soul.md
  Total patterns: 2
  Evolution count: 5

  (i) This pattern will be active at the next orchestrator invocation.
  (i) Patterns are injected at T0 priority — they shape all dispatching decisions.
```

### Example 3: Invalid (vague) pattern rejected

```
/maestro soul evolve "be more careful"
```

```
[maestro] Pattern rejected.

  Reason: Too vague — patterns must describe a specific, observable behavior.

  Example of a valid pattern:
    "Ask for human approval before running any migration that drops a column."

  Example of an invalid pattern:
    "Be more careful with databases."
```
