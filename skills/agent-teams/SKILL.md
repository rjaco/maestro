---
name: agent-teams
description: "Coordinate multiple agents as a team on a shared task list. Supports lead/worker/reviewer roles, TeammateIdle and TaskCompleted hooks, conflict resolution on shared files, and team topologies from pairs to squads."
---

# Agent Teams

Extends beyond sequential and parallel dispatch to coordinate multiple agents as a persistent team working toward a shared milestone. Agents share a task list, have defined roles, and hand off work to each other through Claude Code's `TeammateIdle` and `TaskCompleted` hooks.

## When to Use Agent Teams

Use agent teams when:
- Multiple agents need to work on interdependent tasks, not just isolated parallel stories
- A milestone has more work than one agent can complete in a single context window
- You need a reviewer agent to continuously monitor and unblock workers
- You want dynamic task assignment as agents finish rather than static pre-assignment

Use standard parallel dispatch (via the delegation skill) when tasks are fully independent and do not need coordination.

## Team Roles

### Lead

The lead agent coordinates the team. It does not implement — it plans, assigns, tracks, and unblocks.

Responsibilities:
- Decompose the milestone into the initial task list
- Assign tasks to workers at team start
- Monitor `.maestro/team-state.md` for idle agents and completed tasks
- Assign the next unblocked task when a `TeammateIdle` hook fires
- Declare milestone complete when all tasks reach `done` status
- Resolve conflicts when two workers modify the same file

One lead per team. The lead uses the `strategist` or `architect` subagent type depending on whether the work is strategic or technical.

### Worker

Workers implement assigned tasks. Each worker pulls one task at a time from the task list, executes it, marks it complete, and signals idle.

Responsibilities:
- Execute the assigned task and report STATUS (DONE, BLOCKED, DONE_WITH_CONCERNS)
- Write `## Chain Output` summarizing changes made (file paths, functions added, decisions taken)
- Update `.maestro/team-state.md` to mark their task complete
- Signal idle so the lead can assign the next task

Workers use `implementer` subagent type. A team may have 1-4 workers.

### Reviewer

The reviewer monitors completed tasks and provides continuous QA. Unlike the standard QA pass at the end of a story, the reviewer in a team checks work incrementally as workers complete tasks.

Responsibilities:
- Review completed task output before the next dependent task begins
- Flag defects back to the lead (do not reassign directly)
- Verify final milestone output against acceptance criteria
- Run output contract validation if applicable

One reviewer per team (optional for pair topology). Uses `qa-reviewer` subagent type.

## Shared State

All team coordination is mediated through `.maestro/team-state.md`. This file is the single source of truth for task assignments and status.

### Format

```markdown
---
milestone: "Implement pricing feature"
team: full-stack-dev
started: 2026-03-18T14:00:00Z
status: in_progress   # in_progress | milestone_complete | blocked
---

# Team State

## Task List

| ID  | Task                        | Assigned To | Status      | Blocked By |
|-----|-----------------------------|-------------|-------------|------------|
| T01 | Add sortByPrice function    | worker-1    | done        |            |
| T02 | Add PriceTable component    | worker-2    | in_progress |            |
| T03 | Write unit tests            | worker-1    | pending     | T01        |
| T04 | Write integration tests     | unassigned  | pending     | T02, T03   |
| T05 | QA review                   | reviewer    | pending     | T04        |

## Agent Status

| Agent      | Role     | Current Task | State  |
|------------|----------|--------------|--------|
| worker-1   | worker   | T03          | active |
| worker-2   | worker   | T02          | active |
| reviewer   | reviewer | T05          | idle   |
| lead       | lead     | —            | active |

## Completed Tasks

- T01 — sortByPrice(direction) added to src/pricing.ts — worker-1 — 2026-03-18T14:12:00Z

## Blocking Issues

(none)
```

### Status Values

| Status | Meaning |
|--------|---------|
| `pending` | Not yet started; dependencies may not be met |
| `in_progress` | Assigned and being worked on |
| `done` | Completed and reviewed (if reviewer is present) |
| `blocked` | Cannot proceed; blocking issue logged |
| `skipped` | Lead decided this task is no longer needed |

## TeammateIdle Hook

Fires via the `SubagentStop` hook when a worker or reviewer completes a task and has no further assignment.

The lead responds to `TeammateIdle` by:

1. Reading `.maestro/team-state.md`
2. Finding the next unblocked task:
   - Status is `pending`
   - All tasks in `Blocked By` are `done`
   - No other agent is currently assigned to it
3. Assigning that task to the idle agent (update `Assigned To` and `Status → in_progress`)
4. Writing the updated state to `.maestro/team-state.md`
5. Dispatching the idle agent with the assigned task context

If no unblocked task exists and all active agents are still working, the lead waits. If all agents are idle and no unblocked task exists, the lead checks whether all tasks are `done` and triggers the `TaskCompleted` milestone check.

## TaskCompleted Hook

Fires when a worker marks a task as `done` in `.maestro/team-state.md`.

The lead responds to `TaskCompleted` by:

1. Checking whether any pending tasks were blocked on the now-completed task
2. If yes: unblock those tasks (clear their `Blocked By` entries, set to `pending`)
3. If a reviewer is on the team: assign the completed task to the reviewer before marking it `done`
4. If all tasks are `done`: set `status: milestone_complete` in frontmatter and notify the user

## Team Topologies

### Pair (2 agents)

Minimal team for focused tasks. One implementer, one reviewer.

```yaml
team_topology: pair
agents:
  - role: worker-1
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
  - role: reviewer
    subagent_type: "maestro:maestro-qa-reviewer"
    model: sonnet
```

Best for: single-feature stories where parallel implementation and review is valuable.

### Trio (3 agents)

Standard team for most feature work. Two workers plus a reviewer; no dedicated lead (worker-1 acts as de-facto coordinator for simple sequences).

```yaml
team_topology: trio
agents:
  - role: worker-1
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
  - role: worker-2
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
  - role: reviewer
    subagent_type: "maestro:maestro-qa-reviewer"
    model: sonnet
```

Best for: milestones with 3-6 independent-to-mildly-dependent tasks.

### Squad (4-5 agents)

Full team with a dedicated lead. Lead coordinates 2-3 workers and one reviewer across a larger milestone.

```yaml
team_topology: squad
agents:
  - role: lead
    subagent_type: "maestro:maestro-architect"
    model: opus
  - role: worker-1
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
  - role: worker-2
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
  - role: worker-3
    subagent_type: "maestro:maestro-implementer"
    model: haiku
  - role: reviewer
    subagent_type: "maestro:maestro-qa-reviewer"
    model: sonnet
```

Best for: large milestones (7+ tasks), refactors touching multiple modules, or work that needs architectural oversight during execution.

## Conflict Resolution

When two workers are assigned tasks that modify the same file, conflicts may arise. The lead detects this by scanning task descriptions and prior chain outputs for overlapping file paths.

### Detection

Before assigning a task, the lead checks:
- Does the task's expected scope include a file currently being modified by another active worker?
- Does the completed task's `## Chain Output` mention files that overlap with pending tasks?

If overlap is detected, the lead applies one of these strategies:

### Strategy 1: Serialize (default)

Add a dependency link. The second task blocks on the first completing.

```
T07 — Blocked By: T05
```

The lead waits for T05 to complete before dispatching T07. No merge needed.

### Strategy 2: Partition

If both tasks can be scoped to non-overlapping sections of the file (e.g., different functions or different modules within the same file), the lead splits the scope and assigns non-overlapping ranges explicitly in each task description.

### Strategy 3: Merge

If two workers independently modified the same file and both changes are valid, the lead:

1. Reviews both `## Chain Output` sections to understand what each changed
2. Asks the reviewer to produce a merged version
3. The reviewer writes the merged file and marks both original tasks `done`
4. The merge is logged in `## Completed Tasks` with both source task IDs

Merge is a last resort. The lead should prefer serialization or partitioning at task-assignment time.

## Orchestrator Setup Protocol

When a story spec includes a `team:` block, the orchestrator:

1. **Initialize state.** Write `.maestro/team-state.md` with the task list and initial agent assignments.

2. **Dispatch the lead** (if `team_topology: squad`). The lead reads the task list, validates it, and confirms initial assignments.

3. **Dispatch initial workers.** Assign the first wave of unblocked tasks to available workers. For `pair` and `trio`, the orchestrator handles initial assignment directly (no lead agent needed for first dispatch).

4. **Listen for SubagentStop.** Each time a subagent completes, the orchestrator fires `TeammateIdle` logic:
   - Read updated `.maestro/team-state.md`
   - Determine next assignment
   - Dispatch the idle agent with its new task

5. **Check milestone completion.** After each `TaskCompleted`, check if all tasks are `done`. If yes, mark milestone complete and run final reviewer pass.

6. **Report.** Emit a team summary:

```
+---------------------------------------------+
| Team Milestone Complete                     |
+---------------------------------------------+

  Milestone:  Implement pricing feature
  Team:       full-stack-dev
  Topology:   squad (5 agents)
  Duration:   18m 42s

  Tasks:
    (done) T01 — sortByPrice function          worker-1   2m 14s
    (done) T02 — PriceTable component          worker-2   4m 33s
    (done) T03 — Unit tests                    worker-1   3m 07s
    (done) T04 — Integration tests             worker-3   5m 20s
    (done) T05 — QA review                     reviewer   3m 28s

  Tokens:     82,400 total (28,100 lead | 41,200 workers | 13,100 reviewer)
  Conflicts:  0 detected
```

## Story Spec Format

```yaml
milestone: "Implement pricing feature"
team_topology: squad

team:
  - role: lead
    subagent_type: "maestro:maestro-architect"
    model: opus
  - role: worker-1
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
  - role: worker-2
    subagent_type: "maestro:maestro-implementer"
    model: sonnet
  - role: reviewer
    subagent_type: "maestro:maestro-qa-reviewer"
    model: sonnet

tasks:
  - id: T01
    description: "Add sortByPrice(direction) to src/pricing.ts"
    assigned_to: worker-1
  - id: T02
    description: "Build PriceTable component in src/components/PriceTable.tsx"
    assigned_to: worker-2
  - id: T03
    description: "Write unit tests for sortByPrice"
    blocked_by: [T01]
  - id: T04
    description: "Write integration tests for PriceTable"
    blocked_by: [T02, T03]
  - id: T05
    description: "QA review: run output contract validation and acceptance criteria check"
    assigned_to: reviewer
    blocked_by: [T04]
```

## Integration with Other Skills

- **squad:** Agent team members are typically drawn from an active squad. If a squad is active in `.maestro/state.local.md`, the team topology uses that squad's model and subagent assignments rather than the story spec defaults.
- **delegation:** Each team member dispatch goes through the delegation skill. Normal model selection, token budget, and audit logging apply.
- **stream-chain:** Tasks within a team can use stream-chain to pass outputs between steps without writing intermediary files. The chain log and team state log are maintained separately.
- **hooks-integration:** `SubagentStop` fires after each team member completes, giving the orchestrator the signal to update `.maestro/team-state.md` and dispatch the next assignment.
- **audit-log:** Each task assignment, completion, and conflict resolution is logged as a standard audit entry.
- **checkpoint:** At milestone completion, the final `.maestro/team-state.md` is preserved as a checkpoint for post-mortem review.
