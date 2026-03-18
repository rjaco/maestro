# Conversation Channel — Live Message Classification and Routing

Classifies user messages received while Opus agents work in the background. Routes each message to the appropriate handler without disrupting execution unless the user explicitly requests it.

## Classification Table

When a user message arrives during an active Opus session, classify its intent:

| Intent | Examples | Interrupting | Action |
|--------|----------|--------------|--------|
| `status-check` | "How's it going?", "Progress?", "Where are we?" | No | Show current milestone, story, phase, token spend |
| `information` | "The API uses OAuth2, not API keys", "The database is Postgres 16" | No | Save to `.maestro/notes.md` with timestamp and current milestone tag |
| `context` | "Here is the design mockup: [link]", "The schema looks like this..." | No | Save to notes, flag for next story's context package |
| `complement` | "Looking good!", "Nice work on that component" | No | Acknowledge briefly, save to notes |
| `redirect` | "Actually, let's build X instead of Y", "Change the approach to..." | Yes | Invoke divergence-handler. Graceful pause after current story |
| `reprioritize` | "Move M4 before M3", "Skip the auth milestone" | Yes | Update roadmap, reorder milestones. Resume after adjustment |
| `feedback` | "The button should be blue, not green", "The copy is too formal" | No | Save to notes. If feedback applies to current story, flag for QA |
| `pause` | "Pause", "Hold on", "Wait" | Yes | Graceful stop after current story completes. Save state |
| `urgent-fix` | "STOP", "URGENT", "BUG", "BROKEN" | Yes | Immediate halt. Save state. Show what was interrupted |
| `question` | "Why did you choose X?", "What does milestone 3 include?" | No | Answer from vision/research/roadmap context |
| `chat` | "What time is it?", unrelated conversation | No | Respond naturally. Do not save to notes |
| `resume` | "Continue", "Go", "Resume" | No | Resume from saved position |

## Classification Rules

1. **Default to non-interrupting.** If intent is ambiguous, treat the message as information and save it to notes. The user will explicitly say PAUSE or STOP if they want to interrupt.
2. **Case-insensitive matching.** "STOP", "stop", and "Stop" all trigger urgent-fix.
3. **Multi-intent messages.** If a message contains both information and a redirect, treat it as a redirect (the more disruptive intent wins).
4. **Keyword shortcuts.** These single words always map to their intent regardless of context:
   - PAUSE, HOLD, WAIT -> pause
   - STOP, ABORT, HALT -> urgent-fix
   - GO, CONTINUE, RESUME -> resume
   - STATUS, PROGRESS -> status-check

## Notes Format

When saving to `.maestro/notes.md`, use this format:

```markdown
## [ISO timestamp] — During M[N] Story [X]

**Intent:** [classified intent]
**Message:** [user's original message]
**Action taken:** [what the orchestrator did with this message]
```

Notes accumulate during a milestone. Between milestones, the opus-loop processes all notes and archives them to `.maestro/archive/notes-MN.md`.

## Interrupting Message Protocol

When an interrupting message is received:

1. **Do not kill running background agents immediately** (unless intent is urgent-fix).
2. For `pause`: Let the current story's current phase complete, then save state and stop.
3. For `redirect` / `reprioritize`: Let the current story complete if possible, then pause to process the change.
4. For `urgent-fix`: Attempt to cancel running agents. Save state immediately. Show what was in progress and what was interrupted.

After any interruption, the session must be resumable via `/maestro magnum-opus --resume` or the `resume` keyword.

## Status Response Format

When the user asks for status:

```
Opus Session Status

  Milestone: [current]/[total] — [name]
  Story:     [current]/[total] — [name]
  Phase:     [phase name]
  Spend:     ~[N]K tokens (~$[cost])
  Budget:    [spend]/[budget or "unlimited"]
  Elapsed:   [N]h [N]m

  Last completed: [story name] ([time ago])
  Next up:        [story name]
```
