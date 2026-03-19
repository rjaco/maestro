---
name: dispatch-compat
description: "Compatibility layer for Claude Code Dispatch (Cowork mobile control) and Remote Control. Adapts Maestro output for mobile/remote contexts."
---

# Dispatch Compatibility

Adapts Maestro output for remote and mobile contexts. When Maestro is invoked via Claude Code Remote Control (desktop remote) or Dispatch/Cowork (mobile remote), output must be shorter, simpler, and focused on actionable status. This skill detects the remote context and adjusts all Maestro output accordingly.

## Context Detection

### Remote Control Detection

Check session metadata to determine if running via Remote Control:

```bash
# Check environment variables set by Remote Control
echo $CLAUDE_REMOTE_SESSION
echo $CLAUDE_SESSION_TYPE
```

Indicators of a remote session:
- `CLAUDE_REMOTE_SESSION=true` — Explicit remote flag
- `CLAUDE_SESSION_TYPE=remote` — Session type indicator
- Absence of a local TTY (`[ -t 0 ]` returns false)
- Session metadata in `.claude/session.json` contains `remote: true`

### Dispatch (Cowork Mobile) Detection

Dispatch sessions have additional constraints:

```bash
echo $CLAUDE_DISPATCH_SESSION
echo $CLAUDE_CLIENT_TYPE
```

Indicators of a Dispatch session:
- `CLAUDE_DISPATCH_SESSION=true` — Explicit Dispatch flag
- `CLAUDE_CLIENT_TYPE=mobile` — Client type is mobile
- `CLAUDE_CLIENT_TYPE=cowork` — Cowork app specifically

### Auto-Detection Logic

```
if CLAUDE_DISPATCH_SESSION == true OR CLAUDE_CLIENT_TYPE == mobile:
    mode = "dispatch"
elif CLAUDE_REMOTE_SESSION == true OR CLAUDE_SESSION_TYPE == remote:
    mode = "remote"
else:
    mode = "local"
```

Override via config:

```yaml
remote:
  auto_detect: true
  mobile_mode: false      # Force mobile mode on/off
  compact_output: false   # Force compact mode on/off
```

## Output Adaptation: Remote Mode

When running in remote mode, adapt all Maestro output for a user who may be viewing on a smaller screen or through a remote interface with limited rendering.

### Rules for Remote Output

| Aspect | Local Mode | Remote Mode |
|--------|-----------|-------------|
| Message length | Full detail | Max 3 sentences per block |
| Tables | Wide box-drawing tables | Stacked key-value pairs |
| AskUserQuestion options | Up to 5 options | Max 3 options |
| Code blocks | Full output | Truncated to 10 lines |
| Progress updates | Detailed phase-by-phase | Summary only |
| Diagrams | Full box-drawing art | Skip entirely |
| Error output | Full stack trace | Error type + 1-line message |

### Example: Story Checkpoint

**Local mode:**
```
┌─────────────────────────────────────────────────────────┐
│  Story 3/7 complete: Frontend Dashboard UI              │
├─────────────────────────────────────────────────────────┤
│                                                         │
│  Files changed: 4 created, 2 modified                   │
│  Tests: 8 added, all passing                            │
│  Tokens used: 34,200 (this story) / 127,800 (total)    │
│  Time: 2m14s                                            │
│  Commit score: 92/100                                   │
│                                                         │
│  [GO] Continue to next story                            │
│  [PAUSE] I want to review before continuing             │
│  [SKIP] Skip next story                                 │
│  [ABORT] Stop execution, keep what we have              │
│  [MODE] Change mode for remaining stories               │
│                                                         │
└─────────────────────────────────────────────────────────┘
```

**Remote mode:**
```
Story 3/7 done: Frontend Dashboard UI
8 tests passing, 6 files changed, $0.95 cost.

Continue / Pause / Abort
```

### Example: Ship Summary

**Local mode:**
```
┌──────────────────────────────────────────────┐
│  Shipped: Dashboard Feature                  │
├──────────────────────────────────────────────┤
│  PR: #142                                    │
│  Stories: 7                                  │
│  Commits: 7                                  │
│  Tests: 34 passing                           │
│  Total cost: ~$12.40                         │
│  Living docs updated.                        │
│  Ready for review and merge.                 │
└──────────────────────────────────────────────┘
```

**Remote mode:**
```
Shipped: Dashboard Feature
PR #142 — 7 stories, 34 tests passing, $12.40 total.
Ready for review.
```

### Example: Error Report

**Local mode:**
```
┌─────────────────────────────────────────────────────────────┐
│  CI Failure Analysis — Run #4827                            │
├─────────────────────────────────────────────────────────────┤
│  Type: Test failure                                         │
│  Job:  test-unit                                            │
│  File: src/utils/pricing.test.ts:47                         │
│  Error:                                                     │
│    Expected: 29.99                                          │
│    Received: 30.00                                          │
│  Suggestion:                                                │
│    Use toBeCloseTo() instead of toBe() for prices.          │
└─────────────────────────────────────────────────────────────┘
```

**Remote mode:**
```
CI failed: test failure in pricing.test.ts:47.
Fix: use toBeCloseTo() for price assertions.

Fix and push / Re-run / Ignore
```

## Output Adaptation: Dispatch (Mobile) Mode

Dispatch mode is even more constrained than remote. The user is on a phone, likely glancing at notifications, not reading detailed output.

### Rules for Dispatch Output

| Aspect | Remote Mode | Dispatch Mode |
|--------|-------------|---------------|
| Message length | Max 3 sentences | Max 2 sentences |
| AskUserQuestion options | Max 3 | Max 2 (approve/reject pattern) |
| Tables | Stacked key-value | Skip entirely |
| Status updates | Summary | Status emoji + 1 line |
| Suggestions | Included | Omit (just state the issue) |
| Diagrams | Skipped | Skipped |
| File paths | Shortened | Omitted unless critical |

### Example: Story Checkpoint

**Dispatch mode:**
```
Story 3/7 done. 8 tests passing.

Continue / Abort
```

### Example: CI Failure

**Dispatch mode:**
```
CI failed: test error in pricing.test.ts.

Fix / Ignore
```

### Example: Ship Complete

**Dispatch mode:**
```
Shipped PR #142. 7 stories, all tests pass.
```

No options needed — ship is a terminal action.

### Focus: Status + Next Action

In Dispatch mode, every message follows the pattern:

```
[What happened]. [Key metric].

[Action 1] / [Action 2]
```

Never include:
- Multi-line tables or box-drawing
- Code snippets longer than 1 line
- Explanations or suggestions
- File paths (unless the user needs to look at a specific file)
- Cost breakdowns (just total)

## Integration with Notify Skill

When running in remote or dispatch mode, push notifications become critical. The user may not be watching the terminal — they rely on notifications to know what is happening.

### Enhanced Notification Behavior

| Context | Notification Behavior |
|---------|----------------------|
| Local | Notifications are supplementary (user sees terminal) |
| Remote | Notifications are important (user may switch tabs) |
| Dispatch | Notifications are primary (user relies on phone alerts) |

In dispatch mode:
- Send notifications for ALL events, not just configured triggers
- Include the action options in the notification message
- Mark high-urgency notifications (self-heal failure, CI failure) as priority

### Notify Integration Config

```yaml
remote:
  notify_all_events: false     # true in dispatch mode
  priority_events:
    - self_heal_failure
    - ci_failure
    - session_paused
    - qa_rejection
```

## Adaptation Layer Architecture

All Maestro skills call the output formatting layer. The dispatch-compat skill modifies this layer based on context:

```
Skill Output → dispatch-compat check → Format Selection → User

if mode == "local":
    use output-format skill (full box-drawing)
elif mode == "remote":
    use compact formatter (3-sentence max, stacked tables)
elif mode == "dispatch":
    use minimal formatter (2-sentence max, no tables, binary options)
```

### Format Function

When any skill produces output, dispatch-compat provides:

**compact(message, options):**
- Truncate message to 3 sentences
- Reduce options to top 3 most relevant
- Replace box-drawing tables with plain key-value lines

**minimal(message, options):**
- Truncate message to 2 sentences
- Reduce options to 2 (approve/reject or continue/abort)
- Strip all formatting, tables, diagrams

## Best Practices for Remote Maestro Usage

1. **Start in checkpoint mode** — Get confirmation at each story instead of yolo
2. **Enable notifications** — Configure Slack/Discord/Telegram before going remote
3. **Link workspaces to branches** — So you know which workspace maps to which work
4. **Use `/maestro status`** — Quick summary of where things stand
5. **Avoid careful mode remotely** — Too much output for remote consumption
6. **Set cost limits** — Prevent runaway spend when not actively watching

## Configuration

In `.maestro/config.yaml`:

```yaml
remote:
  auto_detect: true          # Detect remote/dispatch automatically
  mobile_mode: false          # Force mobile mode (override auto-detect)
  compact_output: false       # Force compact output (override auto-detect)
  notify_all_events: false    # Send notifications for all events in remote
  max_options: 3              # Max AskUserQuestion options in remote
  max_sentences: 3            # Max sentences per output block in remote
  dispatch:
    max_options: 2            # Max options in dispatch mode
    max_sentences: 2          # Max sentences in dispatch mode
    skip_diagrams: true       # Always skip box-drawing in dispatch
    skip_tables: true         # Always skip tables in dispatch
```

## Mobile-Friendly Status Format

When in a Dispatch or remote context, Maestro emits a compact single-block status header on every checkpoint. This format is optimised for a phone notification or a narrow terminal pane.

### Status Line Format

```
Maestro M2/7 S3/5 ▶ IMPLEMENT
✓✓✓○○ | $2.40 | 45m elapsed
QA: 80% first-pass | ETA: ~1h
```

**Line 1** — Session snapshot:
- `M2/7` — current milestone / total milestones
- `S3/5` — current story / stories in this milestone
- `▶ IMPLEMENT` — active phase (PLAN | IMPLEMENT | QA | SHIP)

**Line 2** — Progress bar + cost + time:
- `✓` filled story completed, `○` story pending
- `$2.40` cumulative session cost
- `45m elapsed` wall-clock time since session start

**Line 3** — Quality signal + estimate:
- `QA: 80% first-pass` — percentage of stories that passed QA without rework
- `ETA: ~1h` — rough estimate to milestone completion (omit if unknown)

Emit this header before any question or action prompt in dispatch/remote mode.

### Status Header Examples

Mid-session, all well:
```
Maestro M1/3 S4/6 ▶ QA
✓✓✓✓○○ | $1.10 | 22m elapsed
QA: 100% first-pass | ETA: ~30m
```

Mid-session, one rework:
```
Maestro M2/4 S2/5 ▶ IMPLEMENT
✓○○○○ | $0.80 | 18m elapsed
QA: 75% first-pass | ETA: ~2h
```

Session complete:
```
Maestro M3/3 S5/5 ▶ SHIP
✓✓✓✓✓ | $8.20 | 3h 12m elapsed
QA: 90% first-pass
```

## Remote Commands

When Maestro is running unattended, an operator can send commands to control the session without interrupting the current Claude turn. Commands are processed at the next safe checkpoint.

### Command Reference

| Command | Action |
|---------|--------|
| `PAUSE` | Graceful stop after the current story completes. State is saved. |
| `RESUME` | Continue from the last saved position after a PAUSE. |
| `STATUS` | Emit the current mobile-friendly status block immediately. |
| `ABORT` | Immediate halt at the next checkpoint. Full state saved to `.maestro/state.json`. |
| `DETAIL` | Emit detailed progress with per-story status list. |

### Command Delivery

Commands can be sent through any of the following channels:

1. **Webhook** — POST to the session's webhook endpoint (see Webhook JSON Format below)
2. **File trigger** — Write the command word to `.maestro/command` (Maestro polls this file)
3. **Signal** — Send SIGUSR1 to the session process to trigger a STATUS dump
4. **Remote Control skill** — Use the remote-control skill integration (see `skills/remote-control`)

### File Trigger Usage

```bash
# Pause after current story
echo "PAUSE" > .maestro/command

# Request immediate status
echo "STATUS" > .maestro/command

# Abort and save
echo "ABORT" > .maestro/command
```

Maestro reads and deletes `.maestro/command` at the start of each checkpoint. The command is acknowledged by writing a timestamped entry to `.maestro/command-log`.

### DETAIL Command Output

When DETAIL is received, Maestro emits a per-story breakdown suitable for a mobile scroll view:

```
Maestro M2/7 S3/5 ▶ IMPLEMENT
✓✓✓○○ | $2.40 | 45m elapsed

Stories this milestone:
  ✓ S1: Setup auth service (SHIP)
  ✓ S2: User model + migrations (SHIP)
  ✓ S3: Login endpoint (QA - in progress)
  ○ S4: Refresh token flow (pending)
  ○ S5: Logout + session cleanup (pending)
```

## Webhook JSON Format

Maestro exposes a lightweight webhook interface for CI/CD systems and remote-control bots.

### Request Format

```json
{"command": "STATUS", "session_id": "optional"}
```

All fields:

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `command` | string | yes | One of: STATUS, PAUSE, RESUME, ABORT, DETAIL |
| `session_id` | string | no | Session identifier for multi-session hosts |
| `auth_token` | string | no | Bearer token if webhook auth is enabled |

### Response Format

```json
{
  "milestone": {"current": 2, "total": 7, "name": "Advanced Orchestration"},
  "story": {"current": 3, "total": 5, "name": "Knowledge Graph"},
  "phase": "IMPLEMENT",
  "cost": {"spent": 2.40, "remaining": 3.60},
  "elapsed_minutes": 45,
  "qa_first_pass_rate": 0.80
}
```

Full response schema:

| Field | Type | Description |
|-------|------|-------------|
| `milestone.current` | int | Current milestone index (1-based) |
| `milestone.total` | int | Total milestones in the plan |
| `milestone.name` | string | Human-readable milestone name |
| `story.current` | int | Current story index within milestone (1-based) |
| `story.total` | int | Total stories in current milestone |
| `story.name` | string | Current story name |
| `phase` | string | Active phase: PLAN, IMPLEMENT, QA, SHIP |
| `cost.spent` | float | Cumulative USD spent this session |
| `cost.remaining` | float | Estimated remaining spend (null if no budget set) |
| `elapsed_minutes` | int | Wall-clock minutes since session start |
| `qa_first_pass_rate` | float | 0.0–1.0, fraction of stories passing QA first try |

### Error Response

```json
{"error": "unknown_command", "message": "Valid commands: STATUS PAUSE RESUME ABORT DETAIL"}
```

### Webhook Configuration

```yaml
remote:
  webhook:
    enabled: false
    port: 7474
    path: /maestro/command
    auth_token: ""          # Leave empty to disable auth
    cors_origin: ""         # Leave empty to restrict to localhost
```

## Output Contract

```yaml
output_contract:
  modes:
    local:
      format: full
      tables: box-drawing
      options: unlimited
    remote:
      format: compact
      tables: stacked-kv
      options: 3
      max_sentences: 3
    dispatch:
      format: minimal
      tables: none
      options: 2
      max_sentences: 2
  detection:
    env_vars: [CLAUDE_REMOTE_SESSION, CLAUDE_DISPATCH_SESSION, CLAUDE_CLIENT_TYPE, CLAUDE_SESSION_TYPE]
    fallback: local
  mobile_status_header:
    emit_on: [checkpoint, question, error, ship]
    format: "M{m}/{M} S{s}/{S} ▶ {phase} | {progress_bar} | ${cost} | {elapsed}"
  remote_commands:
    poll_file: .maestro/command
    poll_interval_seconds: 30
    ack_log: .maestro/command-log
    valid: [PAUSE, RESUME, STATUS, ABORT, DETAIL]
```
