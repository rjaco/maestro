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
```
