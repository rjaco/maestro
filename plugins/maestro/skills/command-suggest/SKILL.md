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

## Integration Points

This skill is invoked by the orchestrator at the end of major command handlers. It does not require user input — it fires automatically after the primary operation completes and displays its output below the completion summary.

Commands that should trigger this skill:
- `init`, `connect`, `disconnect`, `spec`, `retro`, `security-scan`
- dev-loop completion (feature complete checkpoint)
- opus-loop milestone checkpoint
