---
name: squad
description: "Manage squad lifecycle — list available squads, activate or deactivate a squad for the current session, create new squad definitions, and inspect squad details. Reads from squads/ directory and writes activation state to .maestro/state.local.md."
---

# Squad

Manages the lifecycle of Maestro squads. A squad is a named team of specialized agents stored in `squads/<name>/squad.md`. This skill handles discovery, activation, deactivation, creation, and inspection of squads.

When a squad is active, the delegation skill uses its role→agent mapping to select models and agent types. Activating a squad is scoped to the current session — it persists in `.maestro/state.local.md` and is cleared on deactivation or session end.

## Operations

### list

Scan the `squads/` directory for available squads. For each subdirectory that contains a `squad.md` file, read its frontmatter to extract `name`, `description`, and `agents` count.

Read `.maestro/state.local.md` to check if `active_squad` is set.

Display:

```
+---------------------------------------------+
| Available Squads                            |
+---------------------------------------------+

  full-stack-dev     Full-stack web development team       (4 agents)
  content-creator    Content creation and marketing team   (3 agents)
  devops-sre         DevOps and reliability engineering     (3 agents)

  Active: none
```

If a squad is active, highlight it:

```
  Active: full-stack-dev
```

If `squads/` is empty or contains no valid `squad.md` files:

```
[maestro] No squads found in squads/.

  Create your first squad with:
    /maestro squad create <name>

  Or explore the built-in templates in squads/CONTRIBUTING.md
```

### activate `<name>`

Load a squad for the current session.

1. Verify `squads/<name>/squad.md` exists. If not:
   ```
   [maestro] Squad "<name>" not found.

     Available squads:
       /maestro squad list
   ```

2. Read `squads/<name>/squad.md`. Parse frontmatter fields: `name`, `description`, `agents`, `orchestration_mode`, `shared_context`, `quality_gates`.

3. Read `.maestro/state.local.md`. If another squad is already active, warn:
   ```
   [maestro] Squad "<current>" is already active.

     Deactivating it and activating "<name>"...
   ```

4. Write `active_squad: <name>` to `.maestro/state.local.md`.

5. Confirm:
   ```
   +---------------------------------------------+
   | Squad Activated                             |
   +---------------------------------------------+

     Squad:    full-stack-dev
     Agents:   4 (frontend, backend, devops, qa)
     Mode:     parallel

     (i) Agent dispatch will now use this squad's role mapping.
     (i) Deactivate with: /maestro squad deactivate
   ```

**Integration with delegation:** Once activated, the delegation skill checks `active_squad` in `.maestro/state.local.md` before running its default model selection. If the story's agent type matches a role in the squad's `agents` list, that squad member's `model` field is used. Story-level `model` fields still take highest priority.

### deactivate

Unload the active squad and restore default delegation behavior.

1. Read `.maestro/state.local.md`. If no squad is active:
   ```
   [maestro] No squad is currently active.
   ```

2. Remove `active_squad` from `.maestro/state.local.md` (set to `null` or delete the key).

3. Confirm:
   ```
   [maestro] Squad deactivated. Delegation reverts to default model selection.
   ```

### create `<name>`

Interactive squad creation wizard. Guides the user through defining a new squad and saves it to `squads/<name>/squad.md`.

**Step 1: Describe the squad**

Use AskUserQuestion:
- Question: "What is this squad for? Describe its purpose in one sentence."
- Header: "Create Squad: <name>"

**Step 2: How many agents**

Use AskUserQuestion:
- Question: "How many agents will be on this squad?"
- Header: "Agents"
- Options:
  1. label: "2 agents", description: "Lean team — implementer + reviewer"
  2. label: "3 agents", description: "Standard team — implementer, reviewer, specialist"
  3. label: "4 agents", description: "Full team — multiple specialties"
  4. label: "Custom", description: "I'll specify the exact number"

**Step 3: Define each agent**

For each agent slot, use AskUserQuestion to collect:
- Role name (e.g., `frontend`, `backend`, `qa`, `security`)
- Subagent type (from the valid list: implementer, qa-reviewer, security-reviewer, architect, strategist)
- Model preference: haiku / sonnet / opus
- Focus area (a short description, e.g., "React components and state management")

**Step 4: Orchestration mode**

Use AskUserQuestion:
- Question: "How should agents be coordinated?"
- Header: "Orchestration"
- Options:
  1. label: "parallel", description: "Dispatch independent agents concurrently — faster, higher cost"
  2. label: "sequential", description: "Run agents one at a time — slower, easier to debug"

**Step 5: Generate and save**

Generate the squad file from the collected inputs:

```yaml
---
name: "<name>"
description: "<user's description>"
version: "1.0.0"
author: "user"
orchestration_mode: parallel  # or sequential
shared_context:
  - .maestro/config.yaml
  - .maestro/state.local.md
quality_gates:
  - all_tests_pass
  - no_lint_errors
agents:
  - role: frontend
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
    focus: "React components and state management"
  - role: qa
    subagent_type: "maestro:maestro-qa-reviewer"
    model: sonnet
    focus: "Integration tests and coverage"
---

# <name> Squad

<user's description>

## Agents

| Role | Subagent | Model | Focus |
|------|---------|-------|-------|
| frontend | implementer | sonnet | React components and state management |
| qa | qa-reviewer | sonnet | Integration tests and coverage |

## Workflow

Dispatched by the delegation skill when `active_squad` matches this squad's name. Agent selection follows the role→subagent mapping above. Story-level `model` fields override squad model assignments.

## Quality Gates

- all_tests_pass — CI must be green before QA review
- no_lint_errors — Zero lint warnings on changed files
```

Save to `squads/<name>/squad.md`. Create the directory if it does not exist.

Confirm:

```
+---------------------------------------------+
| Squad Created                               |
+---------------------------------------------+

  Name:     <name>
  Agents:   <N>
  Saved to: squads/<name>/squad.md

  Activate it now with:
    /maestro squad activate <name>
```

### info `<name>`

Show detailed information about a squad.

1. Read `squads/<name>/squad.md`. If not found:
   ```
   [maestro] Squad "<name>" not found.
   ```

2. Display full squad details:

```
+---------------------------------------------+
| Squad: full-stack-dev                       |
+---------------------------------------------+

  Description:  Full-stack web development team
  Version:      1.0.0
  Author:       user
  Mode:         parallel

  Agents (4):
  +---------+------------------+--------+--------------------------------+
  | Role    | Subagent         | Model  | Focus                          |
  +---------+------------------+--------+--------------------------------+
  | frontend| implementer      | sonnet | React components               |
  | backend | implementer      | sonnet | API routes and database        |
  | devops  | implementer      | haiku  | CI/CD and infrastructure       |
  | qa      | qa-reviewer      | opus   | End-to-end coverage            |
  +---------+------------------+--------+--------------------------------+

  Quality Gates:
    (ok) all_tests_pass
    (ok) no_lint_errors

  Shared Context:
    - .maestro/config.yaml
    - .maestro/state.local.md

  Status: [Active | Inactive]
```

## Squad File Format

Squads live in `squads/<name>/squad.md` (one directory per squad). The file uses YAML frontmatter followed by a markdown body:

```yaml
---
name: "full-stack-dev"
description: "Full-stack web development team"
version: "1.0.0"
author: "user"
orchestration_mode: parallel          # parallel | sequential
shared_context:
  - .maestro/config.yaml
  - .maestro/state.local.md
quality_gates:
  - all_tests_pass
  - no_lint_errors
agents:
  - role: frontend
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
    focus: "React components and state management"
  - role: backend
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
    focus: "API routes and database layer"
  - role: devops
    subagent_type: "maestro:maestro-implementer"
    model: haiku
    focus: "CI/CD configuration and infrastructure"
  - role: qa
    subagent_type: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "End-to-end coverage and regression"
---
```

### Frontmatter Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Machine-readable squad identifier (matches directory name) |
| `description` | Yes | One-sentence description of the squad's purpose |
| `version` | No | Semver string, defaults to `1.0.0` |
| `author` | No | Who created the squad |
| `orchestration_mode` | Yes | `parallel` or `sequential` |
| `shared_context` | No | Files included in every agent's context package |
| `quality_gates` | No | Checks that must pass before QA review |
| `agents` | Yes | List of agent definitions (see below) |

### Agent Fields

| Field | Required | Description |
|-------|----------|-------------|
| `role` | Yes | Short identifier used in dispatch logs and state |
| `subagent_type` | Yes | Must be a registered Maestro subagent (e.g., `maestro:maestro-implementer`) |
| `model` | Yes | `haiku`, `sonnet`, or `opus` |
| `focus` | No | Description of what this agent handles — shown in info output |

## State Integration

Squad activation state is stored in `.maestro/state.local.md`:

```yaml
active_squad: full-stack-dev   # null or absent when no squad is active
```

The delegation skill reads `active_squad` on every dispatch. If the value is set:
1. Load `squads/<active_squad>/squad.md`
2. Match the dispatched agent type against the squad's `agents[].subagent_type`
3. Use the matched agent's `model` field instead of the delegation default
4. If no match found, fall back to delegation's default model selection

Story-level `model` field always overrides squad assignments.
