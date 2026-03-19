---
name: context-autopilot
description: "Autonomous context lifecycle management. Monitors usage thresholds, archives session state before compaction, and re-injects critical context after compaction so long opus-loop runs survive transparently."
---

# Context Autopilot

Monitors Claude Code context usage and takes graduated protective action as thresholds are crossed. The goal is zero information loss across context compaction events during long autonomous runs.

## Why This Exists

Claude Code's context window is finite. During a long opus-loop run, context fills up and compaction discards non-essential conversation history. Without intervention, this wipes the current story spec, active phase, and accumulated state, causing the loop to lose its place.

Context Autopilot solves this by taking defensive action before compaction hits and restoring exactly what was lost immediately after.

## Threshold Ladder

| Threshold | Level | Action |
|-----------|-------|--------|
| 80% | Warning | Proactive summary — compress conversation history |
| 90% | Caution | Archive state — write full session to disk |
| 95% | Emergency | Emergency compact — save only critical state |
| PostCompact | Recovery | Re-inject critical state into new context window |

Claude Code exposes current context usage as `context_window_usage` in the session. Read it before every major loop iteration in opus-loop.

## 80% — Proactive Summary

At 80% usage, compress non-essential conversation history without losing active state.

**What to compress:**
- Completed story summaries: collapse to one-line entries (story ID, outcome, commit)
- Resolved QA feedback: discard — it is in git history
- Milestone eval outputs from completed milestones: collapse to pass/fail/commit
- Research summaries already written to `.maestro/research/`: discard the in-context copy

**What to preserve in full:**
- Current story spec and acceptance criteria
- Active milestone spec
- North Star (`.maestro/vision.md` content or a verbatim excerpt)
- Current phase and loop state
- Any unresolved QA feedback for the current story
- Decisions made this loop iteration that have not yet been acted on

**Output format:**

```
[Context Autopilot] 80% threshold — compressing history
  Collapsed: 4 completed stories → 4 one-liners
  Collapsed: 2 milestone evals → 2 pass entries
  Freed: ~3,200 tokens
  Current story: preserved in full
  North Star: preserved in full
```

## 90% — Archive State

At 90% usage, write a full session archive to disk before anything is lost.

### Archive File Location

```
.maestro/archive/session-<session_id>.md
```

Read `session_id` from `.maestro/state.local.md`. If absent, generate a slug from current timestamp: `YYYYMMDD-HHMMSS`.

### Archive File Format

```markdown
---
session_id: <session_id>
archived_at: <ISO-8601 timestamp>
context_usage_pct: 90
---

# Session Archive

## North Star

<verbatim content of .maestro/vision.md>

## Active Milestone

milestone_id: <MN slug>
milestone_title: <title>
milestone_file: .maestro/milestones/<MN-slug>.md

## Current Story

story_id: <story ID>
story_title: <title>
story_file: .maestro/stories/<story-file>.md
phase: <research | decompose | implement | qa-review | fix | checkpoint>
attempt: <N>

## Acceptance Criteria Status

- [ ] AC1: <text>        ← pending
- [x] AC2: <text>        ← confirmed done
- [ ] AC3: <text>        ← pending

## Active Agent State

<If an implementer or qa-reviewer agent is mid-run, note its dispatch parameters here>

## Loop Counters

consecutive_failures: <N>
fix_cycle: <N of max 3>
stories_completed_this_milestone: <N>

## Completed Stories This Milestone

| Story ID | Outcome | Commit |
|----------|---------|--------|
| <id>     | DONE    | <sha>  |

## Unresolved QA Feedback

<Any QA rejection reasons not yet addressed>

## Open Decisions

<Any decisions flagged for human review that have not been resolved>
```

**Output format:**

```
[Context Autopilot] 90% threshold — archiving session state
  Archive: .maestro/archive/session-<id>.md
  Captured: milestone, story, phase, AC status, loop counters
```

## 95% — Emergency Compact

At 95% usage, compaction is imminent. Save only the minimum required to resume.

### Emergency State File

```
.maestro/archive/emergency-<session_id>.md
```

```markdown
---
session_id: <session_id>
archived_at: <ISO-8601 timestamp>
context_usage_pct: 95
type: emergency
---

# Emergency State

## North Star (one-paragraph summary)

<Distilled to the core goal, 2-3 sentences maximum>

## Resume Point

milestone: <MN slug>
story: <story ID>
phase: <phase>
fix_cycle: <N>

## Must-Do Next

<Single most important action to take after resuming>
```

**Output format:**

```
[Context Autopilot] 95% threshold — emergency state saved
  File: .maestro/archive/emergency-<id>.md
  Compaction imminent — PostCompact hook will restore state
```

Do NOT attempt further compression at 95%. Let compaction proceed. The PostCompact hook handles recovery.

## PostCompact — State Recovery

The PostCompact hook fires immediately after Claude Code compacts the context. At this point the conversation history is gone but the file system is intact.

### Recovery Protocol

Execute these reads in order, injecting each into the new context window:

1. **Emergency or full archive** — Check for `.maestro/archive/emergency-<session_id>.md` first. If present, use it. Otherwise load `.maestro/archive/session-<session_id>.md`.

2. **North Star** — Read `.maestro/vision.md` verbatim. Prepend to context.

3. **Active milestone** — Read `.maestro/milestones/<MN-slug>.md`. Focus on scope and acceptance criteria.

4. **Active story** — Read `.maestro/stories/<story-file>.md`. Restore all acceptance criteria and status.

5. **Current state** — Read `.maestro/state.local.md` for session counters (consecutive_failures, fix_cycle).

6. **HANDOFF.md** — If `.maestro/HANDOFF.md` exists, read it. It may contain recovery instructions left by a prior compaction.

### Recovery Announcement

After re-injection, emit this block so the opus-loop knows it survived:

```
[Context Autopilot] PostCompact recovery complete
  Session: <session_id>
  North Star: re-injected
  Milestone: <MN slug> — re-injected
  Story: <story ID> — re-injected
  Phase: <phase>
  Loop counters: restored
  Ready to continue from: <phase description>
```

### Resume the Loop

After recovery, the opus-loop MUST resume exactly where it left off — same story, same phase, same fix cycle count. The loop treats compaction as a transparent pause, not a restart.

If the archived phase was `implement` with an agent mid-dispatch, re-dispatch the same agent with the same context package. Do not increment attempt counters for compaction-induced re-dispatches.

## Integration with opus-loop

The opus-loop checks context usage at the start of each story and at each phase transition.

Add this check at the top of every phase transition in the loop:

```
1. Read context_window_usage
2. If >= 95%: run emergency compact (context-autopilot at 95%)
3. If >= 90%: run archive (context-autopilot at 90%)
4. If >= 80%: run proactive summary (context-autopilot at 80%)
5. Continue with phase
```

This means the archive always happens before agent dispatches, ensuring the disk state is current before any new context is consumed.

## Archive Index

Maintain `.maestro/archive/index.md` as a running log:

```markdown
| session_id | archived_at | type | milestone | story | phase |
|------------|-------------|------|-----------|-------|-------|
| abc123     | 2024-01-15T14:22:00Z | full | M2-auth | 03-login-form | implement |
| abc123     | 2024-01-15T14:45:00Z | emergency | M2-auth | 03-login-form | qa-review |
```

This lets you reconstruct the full session timeline even if the session ended mid-story.

## Configuration

In `.maestro/config.yaml`:

```yaml
context_autopilot:
  enabled: true
  thresholds:
    summary: 80       # % at which to compress history
    archive: 90       # % at which to write full archive
    emergency: 95     # % at which to write emergency state
  archive_dir: .maestro/archive
  keep_archives: 10   # max archived sessions to retain (oldest pruned)
```

Disable for short sessions where compaction is unlikely:

```yaml
context_autopilot:
  enabled: false
```

## Manual Invocation

Archive on demand without waiting for a threshold:

```
/maestro context-autopilot archive
```

Force a recovery read (useful after manual context clear):

```
/maestro context-autopilot recover
```

Show current usage and threshold status:

```
/maestro context-autopilot status
```
