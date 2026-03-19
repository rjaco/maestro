---
name: team-hooks
description: "Agent-team lifecycle hooks for Maestro. Documents TeammateIdle and TaskCompleted hook handlers, how they integrate with the dev-loop and agent-teams skill, and the team-state.md file format they consume."
---

# Team Hooks

Maestro's agent-team hooks fire during parallel dev-loop execution when Claude Code v2.1.32+ agent-team support is active. There are two handlers:

| Hook | Handler | Fires when | Effect |
|------|---------|-----------|--------|
| `TeammateIdle` | `hooks/teammate-idle-hook.sh` | A teammate agent is about to go idle | Assigns next unblocked task (exit 2) or allows idle (exit 0) |
| `TaskCompleted` | `hooks/task-completed-hook.sh` | A task is being marked complete | Validates output against acceptance criteria; blocks (exit 2) or allows (exit 0) |

Both hooks log decisions to `.maestro/logs/workers/team-lifecycle.md`.

---

## TeammateIdle Hook

**File:** `hooks/teammate-idle-hook.sh`

**Purpose:** Keeps teammate agents busy during parallel execution. When an agent finishes its current task and would otherwise go idle, this hook checks whether any unblocked work remains. If yes, it injects the next task assignment and exits 2 (re-prompts the agent). If no unblocked tasks remain, it exits 0 and the agent idles normally.

### Input (stdin JSON)

```json
{
  "agent_id": "implementer-2"
}
```

`agent_id` is optional. If absent, the hook still assigns the next available task.

### Decision Logic

1. Read `.maestro/team-state.md`.
2. If the file is missing or `active: false`, exit 0 (allow idle).
3. Scan the file body for the first task line with status `[todo]`.
4. If found: exit 2 with a message assigning that task to the agent.
5. If none found: exit 0 (allow idle).

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Allow idle — no work available or team not active |
| 2 | Keep working — outputs task assignment message for the agent |

---

## TaskCompleted Hook

**File:** `hooks/task-completed-hook.sh`

**Purpose:** Guards against premature task completion. Before a task transitions to `done`, this hook validates that the agent's output addresses all acceptance criteria defined in `team-state.md`. Lightweight keyword matching is used — the implementer's STATUS report is the primary source of truth.

### Input (stdin JSON)

```json
{
  "task_id": "TASK-003",
  "task_output": "STATUS: DONE\nTests: 4 passing\nAC1: ...\nAC2: ...",
  "agent_id": "implementer-1"
}
```

`task_id` falls back to `current_task` in the team-state frontmatter if absent.

### Decision Logic

1. Read `.maestro/team-state.md`.
2. Find the `### TASK-ID` section in the file body.
3. Extract acceptance criteria lines from the `#### Acceptance Criteria` subsection.
4. For each criterion, check whether its keyword phrase appears in `task_output` (case-insensitive).
5. If all criteria match: exit 0 (allow completion).
6. If any criterion is missing: exit 2 with a feedback message listing the gaps.

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Allow completion — all criteria verified (or no criteria to check) |
| 2 | Block completion — outputs list of missing criteria for the agent to address |

---

## team-state.md Format

Both hooks consume `.maestro/team-state.md`. This file uses YAML frontmatter followed by a task list in the body.

### Frontmatter

```yaml
---
active: true
current_task: TASK-002
team_size: 3
---
```

| Field | Required | Description |
|-------|----------|-------------|
| `active` | Yes | `true` while the agent team is running |
| `current_task` | No | Fallback task ID used by TaskCompleted when none is provided in hook input |
| `team_size` | No | Number of agents in the team (informational) |

### Body — Task List

```markdown
## Tasks

- [done] TASK-001: Set up project scaffolding
- [in_progress] TASK-002: Implement authentication endpoints
- [todo] TASK-003: Write integration tests
- [todo] TASK-004: Add rate limiting middleware
- [blocked] TASK-005: Deploy to staging (depends on TASK-004)

### TASK-003

Implement integration tests for the auth endpoints introduced in TASK-002.

#### Acceptance Criteria

- POST /auth/login returns 200 with valid credentials
- POST /auth/login returns 401 with invalid credentials
- JWT token is included in successful response
- Tests run with npm test without errors

### TASK-004

Add rate limiting middleware to all API routes.

#### Acceptance Criteria

- Rate limiter rejects requests above 100/min per IP with 429
- Configuration is environment-variable-driven
- Existing tests still pass
```

### Task Status Values

| Status | Meaning |
|--------|---------|
| `todo` | Available for assignment — no blockers |
| `in_progress` | Currently assigned to an agent |
| `done` | Completed and validated |
| `blocked` | Cannot start — has unresolved dependencies |

The `TeammateIdle` hook only assigns tasks with status `[todo]`. Blocked and in-progress tasks are skipped.

---

## Integration with the Dev Loop

The team-hooks integrate at the edges of parallel execution in the dev-loop skill:

```
Parallel dispatch (stories S2, S3, S4):
  Each agent executes its story.
  When an agent finishes → TaskCompleted fires → validates output.
  If output passes → agent idles → TeammateIdle fires → assigns next todo task.
  If no tasks remain → agent stays idle → orchestrator collects results.
```

This creates a work-stealing pattern: agents pull from the todo queue as they finish, keeping all available agents busy without the orchestrator having to manually re-dispatch.

### Enabling Team Hooks

Team hooks are registered in `hooks/hooks.json` and activate automatically when Claude Code v2.1.32+ fires the `TeammateIdle` or `TaskCompleted` events. No additional configuration is required.

```json
"TeammateIdle": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/teammate-idle-hook.sh"}]}],
"TaskCompleted": [{"hooks": [{"type": "command", "command": "${CLAUDE_PLUGIN_ROOT}/hooks/task-completed-hook.sh"}]}]
```

### Logging

Both hooks append to `.maestro/logs/workers/team-lifecycle.md`. The directory is created on first write. Log entries use this format:

```markdown
## TeammateIdle — 2026-03-18T21:57:00Z
- Event: assign_task
- Detail: agent=implementer-2 task=TASK-003: Write integration tests

## TaskCompleted — 2026-03-18T21:58:30Z
- Event: allow_completion
- Detail: All acceptance criteria verified for TASK-003 (agent=implementer-2)
```

---

## Adding New Team Hook Handlers

1. Create the handler script in `hooks/` following the `yaml_val()` parser pattern from `hooks/stop-hook.sh`.
2. Register it in `hooks/hooks.json` under the appropriate event name.
3. Document it in this SKILL.md.
4. Test with: `echo '{"task_id":"TASK-001","task_output":"..."}' | hooks/your-hook.sh`
