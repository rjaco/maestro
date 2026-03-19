---
name: squad
description: "Manage squads — list, activate, deactivate, create, and inspect agent teams"
argument-hint: "[list|activate <name>|deactivate|create <name>|info <name>]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - AskUserQuestion
---

# Maestro Squad

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage agent squads. A squad is a named team of specialized agents stored in `squads/<name>/squad.md`. Activating a squad changes how the delegation skill selects models and agent types for the current session.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show squad status

Read `.maestro/state.local.md` to check `active_squad`. Glob `squads/*/squad.md` to count available squads.

```
+---------------------------------------------+
| Squads                                      |
+---------------------------------------------+

  Available: <N> squad(s) in squads/
  Active:    <name> | none

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Squad"
- Options:
  1. label: "List squads", description: "Show all available squads"
  2. label: "Activate a squad", description: "Load a squad for the current session"
  3. label: "Deactivate", description: "Unload the active squad, revert to default delegation"
  4. label: "Create a squad", description: "Define a new squad interactively"

### `list` — Show available squads

Invoke the squad skill's `list` operation.

Glob `squads/*/squad.md`. For each match, read the frontmatter to extract `name`, `description`, and `agents` count. Read `.maestro/state.local.md` for `active_squad`.

```
+---------------------------------------------+
| Available Squads                            |
+---------------------------------------------+

  full-stack-dev     Full-stack web development team       (4 agents)
  content-creator    Content creation and marketing team   (3 agents)
  devops-sre         DevOps and reliability engineering     (3 agents)

  Active: none
```

If `squads/` contains no valid squad files:

```
[maestro] No squads found.

  Create your first squad with:
    /maestro squad create <name>
```

### `activate <name>` — Activate a squad

Invoke the squad skill's `activate` operation with the given name.

1. Verify `squads/<name>/squad.md` exists. If not:
   ```
   [maestro] Squad "<name>" not found.

     Run /maestro squad list to see available squads.
   ```

2. If another squad is already active, confirm the switch:
   Use AskUserQuestion:
   - Question: "Squad \"<current>\" is already active. Switch to \"<name>\"?"
   - Header: "Confirm Switch"
   - Options:
     1. label: "Yes, switch squads", description: "Deactivate <current> and activate <name>"
     2. label: "Cancel", description: "Keep <current> active"

3. Write `active_squad: <name>` to `.maestro/state.local.md`.

4. Confirm:
   ```
   +---------------------------------------------+
   | Squad Activated                             |
   +---------------------------------------------+

     Squad:    <name>
     Agents:   <N> (<roles>)
     Mode:     <orchestration_mode>

     (i) Agent dispatch will now use this squad's role mapping.
     (i) Deactivate with: /maestro squad deactivate
   ```

### `deactivate` — Deactivate the active squad

Invoke the squad skill's `deactivate` operation.

1. Read `.maestro/state.local.md`. If `active_squad` is absent or null:
   ```
   [maestro] No squad is currently active.
   ```

2. Remove `active_squad` from `.maestro/state.local.md`.

3. Confirm:
   ```
   [maestro] Squad "<name>" deactivated.

     (i) Delegation reverts to default model selection.
   ```

### `create <name>` — Create a new squad

Invoke the squad skill's `create` operation with the given name.

Check if `squads/<name>/squad.md` already exists. If it does:

Use AskUserQuestion:
- Question: "Squad \"<name>\" already exists. What would you like to do?"
- Header: "Squad Exists"
- Options:
  1. label: "Overwrite", description: "Replace the existing squad definition"
  2. label: "Cancel", description: "Keep the existing squad"

If creating (or confirmed overwrite), run the interactive wizard defined in `skills/squad/SKILL.md` under the `create` operation. After saving, offer to activate the new squad immediately:

Use AskUserQuestion:
- Question: "Squad \"<name>\" created. Activate it now?"
- Header: "Activate"
- Options:
  1. label: "Yes, activate", description: "Start using this squad for agent dispatch"
  2. label: "Not now", description: "Activate later with /maestro squad activate <name>"

### `info <name>` — Show squad details

Invoke the squad skill's `info` operation with the given name.

Read `squads/<name>/squad.md`. If not found:

```
[maestro] Squad "<name>" not found.

  Run /maestro squad list to see available squads.
```

Parse the squad file frontmatter and body. Display in this format:

```
+---------------------------------------------+
| Squad: full-stack-dev                       |
+---------------------------------------------+

  Description:  Full-stack web development team
  File:         squads/full-stack-dev/squad.md
  Active:       yes  (currently loaded)

  Agents (4):
    Role            Model    Responsibilities
    ─────────────────────────────────────────────
    orchestrator    opus     planning, decomposition, QA review
    implementer     sonnet   story execution, code writing
    reviewer        opus     code review, security checks
    researcher      haiku    web lookup, documentation

  Quality Gates:
    min_test_coverage:  80%
    require_types:      true
    max_qa_iterations:  3

  Shared Context:
    [content of squad's shared_context section, if any]

  Orchestration Mode:  standard
```

If a required field (e.g., `agents`) is missing from the squad file, show:
```
  (!) Squad file is missing the "agents" section — squad may not function correctly.
```

---

## Argument Parsing

| Invocation | Behavior |
|-----------|----------|
| `/maestro squad` | Show status overview + interactive menu |
| `/maestro squad list` | List all available squads |
| `/maestro squad activate <name>` | Activate the named squad |
| `/maestro squad deactivate` | Deactivate the currently active squad |
| `/maestro squad create <name>` | Create a new squad interactively |
| `/maestro squad info <name>` | Show full details for a squad |

`<name>` must be a single token matching a directory name under `squads/`. Names with spaces are not supported — use hyphens (e.g., `full-stack-dev`).

## Squad File Format Reference

A valid squad file lives at `squads/<name>/squad.md` and has this structure:

```markdown
---
name: full-stack-dev
description: Full-stack web development team
orchestration_mode: standard
agents:
  - role: orchestrator
    model: opus
  - role: implementer
    model: sonnet
  - role: reviewer
    model: opus
  - role: researcher
    model: haiku
quality_gates:
  min_test_coverage: 80
  require_types: true
  max_qa_iterations: 3
---

## Shared Context

Any shared context injected into all agents in this squad.
```

When creating a new squad via `create`, use this template. The wizard (defined in `skills/squad/SKILL.md`) will prompt for each field interactively.

## Error Handling

| Condition | Action |
|-----------|--------|
| `squads/` directory does not exist | Treat as empty (no squads found) |
| Squad file has invalid YAML frontmatter | Show `(x) squads/<name>/squad.md has invalid frontmatter — cannot parse` |
| `active_squad` in state references a deleted squad | Warn `(!) Active squad "<name>" no longer exists. Run /maestro squad list.` and clear `active_squad` |
| `create` name contains spaces | Reject: `[maestro] Squad names cannot contain spaces. Use hyphens, e.g. "full-stack-dev".` |
| `create` name contains special characters | Reject: `[maestro] Squad name must be alphanumeric with hyphens only.` |

## Examples

### Example 1: List squads

```
/maestro squad list
```

```
+---------------------------------------------+
| Available Squads                            |
+---------------------------------------------+

  full-stack-dev     Full-stack web development team       (4 agents)
  content-creator    Content creation and marketing team   (3 agents)
  devops-sre         DevOps and reliability engineering     (3 agents)

  Active: full-stack-dev
```

### Example 2: Activate a squad

```
/maestro squad activate devops-sre
```

```
+---------------------------------------------+
| Squad Activated                             |
+---------------------------------------------+

  Squad:    devops-sre
  Agents:   3 (orchestrator, implementer, reviewer)
  Mode:     standard

  (i) Agent dispatch will now use this squad's role mapping.
  (i) Deactivate with: /maestro squad deactivate
```

### Example 3: Squad not found

```
/maestro squad activate frontend-team
```

```
[maestro] Squad "frontend-team" not found.

  Run /maestro squad list to see available squads.
```
