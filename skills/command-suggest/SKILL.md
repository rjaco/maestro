---
name: command-suggest
description: "Context-aware next-step suggestions. After major Maestro operations, suggest the most logical follow-on command to guide users forward."
---

# Context-Aware Command Suggestions

After completing a major operation, suggest the most logical next step to guide the user forward. This skill prevents the "what now?" moment that follows a successful action.

## When to Invoke This Skill

Call this skill after:
- `/maestro init` completes
- `/maestro connect` completes
- A feature build completes (dev-loop finished)
- A Magnum Opus milestone completes
- A service error or health failure is detected
- The very first time a user interacts with Maestro on a project
- An unrecognized command is typed (suggest closest matches)

## Suggestion Algorithm

When a user types an unrecognized command, run the following procedure to produce suggestions:

```
Algorithm: SuggestClosestCommands(query, all_commands)

1. For each command_name in all_commands (51 total):
     distance[command_name] = LevenshteinDistance(query, command_name)

2. threshold = max(1, floor(len(query) / 4))

3. candidates = [c for c in all_commands if distance[c] <= threshold]

4. Sort candidates by distance[c] ascending.

5. top3 = candidates[0:3]

6. If len(top3) > 0:
     Display top3 as "Did you mean?" suggestions.
   Else:
     Fall back to intent mapping (see command-search skill).

LevenshteinDistance(Q, C):
  - Build matrix M of size (len(Q)+1) x (len(C)+1).
  - M[0][j] = j, M[i][0] = i.
  - For i in 1..len(Q), j in 1..len(C):
      If Q[i-1] == C[j-1]: M[i][j] = M[i-1][j-1]
      Else: M[i][j] = 1 + min(M[i-1][j], M[i][j-1], M[i-1][j-1])
  - Return M[len(Q)][len(C)].
```

### Example Unrecognized Command Suggestions

User types `/maestro deplyo` (typo):
```
[maestro] Command "deplyo" not found. Did you mean:
  /maestro deploy      — ship built features
  /maestro demo        — run a feature demo
  /maestro deps        — view dependency graph

Type /maestro help commands for the full list.
```

User types `/maestro bord` (typo of "board"):
```
[maestro] Command "bord" not found. Did you mean:
  /maestro board       — view kanban board

Type /maestro help commands for the full list.
```

## Trigger-to-Suggestion Mapping

| Trigger | Suggestions to show |
|---------|---------------------|
| `/maestro init` completed | Build a feature, run doctor |
| `/maestro connect` completed | Check services, configure autonomy |
| Feature build complete | Ship or view board |
| Opus milestone complete | Check dashboard, view next milestone |
| Service error detected | Run services health, check doctor |
| First-ever run on project | Run init to set up the project |
| `/maestro spec` completed | Build the spec with `/maestro "feature"` |
| `/maestro retro` completed | Plan next sprint with `/maestro plan` |
| `/maestro security-scan` completed | Review findings with `/maestro config` |
| `/maestro brain` completed | Sync with `/maestro sync-ide` or query again |
| `/maestro notify` completed | Configure channels with `/maestro preferences` |
| `/maestro schedule` completed | Monitor with `/maestro heartbeat` |

## Context-Aware Suggestion Rules

Use the current session state to select the most relevant suggestions:

| Session State Signal | Adjust Suggestions By |
|----------------------|-----------------------|
| No services connected yet | Prioritize `/maestro connect` and `/maestro services` |
| Autonomy mode is off | Offer `/maestro autonomy` to enable it |
| No opus plan exists | Suggest `/maestro plan` before building |
| Errors or warnings in last output | Promote `/maestro doctor` to top slot |
| User is mid-opus milestone | Prefer opus-related commands (dashboard, opus) |
| Worker daemons are running | Include `/maestro workers` in suggestions |
| Last command was a search/browse | Suggest an action command to act on findings |

Context is inferred from what the orchestrator passes when invoking this skill. If no context signal is available, fall back to the static trigger-to-suggestion mapping above.

## Output Format

Always show at most 3 suggestions. Use the `(i)` indicator. Keep each line under 60 characters.

```
[maestro] (i) Next steps:
  /maestro services    — check which services are connected
  /maestro autonomy    — configure how autonomous Maestro should be
```

For first-run:
```
[maestro] (i) First run detected. Get started:
  /maestro init        — set up Maestro for this project
  /maestro help        — browse help topics
```

For post-init:
```
[maestro] (i) Project initialized. Try:
  /maestro "your first feature"   — build something
  /maestro doctor                 — verify installation
```

For post-connect:
```
[maestro] (i) Service connected. Next:
  /maestro services    — view all connected services
  /maestro autonomy    — configure autonomy level
```

For feature complete:
```
[maestro] (i) Feature complete. What next?
  /maestro board       — view kanban board
  /maestro status      — see overall project progress
```

For opus milestone complete:
```
[maestro] (i) Milestone complete. Continue:
  /maestro dashboard   — live progress dashboard
  /maestro opus        — view full opus roadmap
```

For service error:
```
[maestro] (i) Service issue detected. Try:
  /maestro services    — list services with status
  /maestro doctor      — run full health diagnostics
```

## Behavior Rules

- Show at most 3 suggestions. Never more.
- Each suggestion must be actionable — a real command the user can run immediately.
- Do not repeat the command that just completed.
- Use `[maestro] (i)` prefix. No box required.
- Keep the entire block under 6 lines total.
- If no suggestion is relevant, do not output anything. Silence is better than noise.
- When suggesting after an unrecognized command, use the Levenshtein algorithm first, then intent mapping as fallback.

## Integration Points

This skill is invoked by the orchestrator at the end of major command handlers. It does not require user input — it fires automatically after the primary operation completes and displays its output below the completion summary.

Commands that should trigger this skill:
- `init`, `connect`, `disconnect`, `spec`, `retro`, `security-scan`
- `brain`, `notify`, `schedule`, `workers`
- dev-loop completion (feature complete checkpoint)
- opus-loop milestone checkpoint
- any unrecognized command input (for typo/fuzzy suggestions)
