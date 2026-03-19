---
name: instance-registry
description: "Manage concurrent Maestro instance lifecycle. Register instances, claim stories, detect stale instances, prevent parallel work conflicts."
---

# Instance Registry

Enables multiple Maestro instances to work simultaneously on the same repository without conflicts. Each instance registers itself, claims stories, and coordinates with other instances.

## Instance Lifecycle

### Registration (on session start)

When a Maestro session begins, create an instance registration file at `.maestro/instances/{session_id}.json`:

```json
{
  "session_id": "opus-wave6-20260318",
  "pid": 12345,
  "hostname": "dev-laptop",
  "started_at": "2026-03-18T14:00:00Z",
  "last_heartbeat": "2026-03-18T14:32:00Z",
  "current_story": null,
  "branch": "development",
  "feature": "Wave 6: The Grand Ultimate Tool",
  "phase": "opus_executing",
  "opus_mode": "full_auto"
}
```

Create the `.maestro/instances/` directory if it doesn't exist.

### Heartbeat Updates

Every time a heartbeat is written to `.maestro/logs/heartbeat.json`, also update the instance file's `last_heartbeat` timestamp and `current_story` field.

### Story Claiming

Before starting work on a story:

1. Read all instance files in `.maestro/instances/`
2. For each instance file:
   - Parse the JSON
   - Check if `last_heartbeat` is within the last 10 minutes
   - If so, the instance is **active** — its `current_story` is claimed
3. If the target story is claimed by another active instance, skip to the next unclaimed story
4. Claim the story by updating this instance's file with `current_story: "M1-02"`

### Stale Instance Cleanup

Before claiming a story, clean up stale instances:

1. Read all instance files in `.maestro/instances/`
2. For each instance, check `last_heartbeat`
3. If `last_heartbeat` is older than 10 minutes:
   - Consider the instance **stale** (crashed, disconnected, or abandoned)
   - Log: `[WARN] Stale instance {session_id} (last heartbeat: {timestamp}). Releasing claims.`
   - Delete the instance file
   - Any stories that were claimed by this instance are now available

### Deregistration

Remove the instance file when:
- Session ends normally (phase: completed)
- User pauses (phase: paused)
- Session aborts (phase: aborted)
- Daemon stops (`--stop` flag)

## Story Claim Verification

When the orchestrator selects the next story to execute:

```
1. List all .maestro/instances/*.json files
2. Parse each — build a set of claimed stories from active instances
3. List all .maestro/stories/M{current_milestone}-*.md files
4. For each story in dependency order:
   a. If story status is "completed" → skip
   b. If story ID is in the claimed set → skip (another instance working on it)
   c. Otherwise → claim this story and begin work
5. If no unclaimed stories remain → milestone is complete (or all in-flight)
```

## Conflict Prevention Rules

1. **One story per instance**: An instance works on exactly one story at a time
2. **File-level locking**: Before modifying any shared file (state, roadmap, config), check `.maestro/locks/{filename}.lock`
3. **State isolation**: Each instance updates its own instance file; the central `state.local.md` is updated only by the primary instance (lowest session_id)
4. **Branch isolation**: Each instance's agents work in their own worktrees — no two instances modify the same branch

## Integration Points

| System | Integration |
|--------|------------|
| session-start-hook | Auto-register instance on session start |
| stop-hook | Auto-deregister on session end |
| opus-daemon.sh | Update heartbeat in instance file |
| heartbeat skill | Update `last_heartbeat` and `current_story` in instance file |
| dev-loop | Check claims before starting a story |
| opus-loop | Check claims at milestone decomposition |

## Monitoring

Run `/maestro instances` to see all registered instances:

```
Active Maestro Instances
========================
  SESSION_ID              PID    STORY   HEARTBEAT        STATUS
  opus-wave6-20260318     12345  M1-01   2 min ago        active
  opus-wave6-20260318b    12346  M1-03   45 sec ago       active
  opus-wave6-old          11111  M1-02   15 min ago       STALE (cleaning up)
```
