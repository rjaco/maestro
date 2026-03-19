---
name: command-search
description: "Fuzzy command matching and intent routing. When user input doesn't match any known command, suggest the closest alternatives and handle common alias patterns."
---

# Command Search & Fuzzy Matching

When a user types a command that does not match any of the 50 known Maestro commands, apply fuzzy matching to suggest the closest alternatives and handle common intent aliases.

## When to Apply This Skill

Invoke this skill when:
- The user runs `/maestro <unknown>` where `<unknown>` does not match any command name
- The user describes intent using non-command language (e.g., "deploy", "email", "settings")
- A command is partially typed or visibly misspelled

## All Known Commands

```
maestro, plan, spec, pair, status, board, deps, viz, retro, rollback, history,
magnum-opus, opus, dashboard, cost-estimate, quick-start,
connect, disconnect, services, autonomy, notifications, browser, chain,
init, config, doctor, help, demo, preferences, profile, soul, squad, model,
aware, heartbeat, watch, workers, schedule, observe, ci,
brain, remote, webhooks, sync-ide, readme, content, marketing,
security-scan, notify, btw
```

## Step 1 — Fuzzy Match

Compare the unknown input against all 50 command names using:
1. Exact substring match (e.g., "servce" matches "service" partially)
2. Character overlap (count shared characters in order)
3. Edit distance (how many single-character changes are needed)

Select the top 3 closest matches and display them.

### Output Format

```
[maestro] Command "servces" not found. Did you mean:
  /maestro services    List services with status
  /maestro connect     Connect an external service
  /maestro status      View progress

Type /maestro help commands for the full list.
```

Rules:
- Always show exactly 3 suggestions (or fewer if fewer than 3 are plausible)
- Show command name and a one-line description beside each
- End with the pointer to `help commands`
- Use `[maestro]` prefix, no box required for this message

## Step 2 — Intent Alias Routing

Before fuzzy matching, check if the input matches a known intent alias. If it does, route directly.

| User input contains | Route to | Note |
|---------------------|----------|------|
| deploy, ship, release, launch | `/maestro chain` | Multi-service deployment chains |
| email, sendgrid, smtp | `/maestro connect sendgrid` | Email service integration |
| domain, namecheap, dns | `/maestro connect namecheap` | Domain management |
| cost, spend, budget, price | `/maestro cost-estimate` | Pre-build cost forecast |
| settings, prefs, configure | `/maestro config` | Configuration editor |
| login, auth, sign in | `/maestro browser login` | Browser-based auth flow |
| monitor, watch, observe | `/maestro watch` | File/service monitoring |
| cron, job, schedule, recurring | `/maestro schedule` | Scheduled task runner |
| test, tests, testing | `/maestro aware` | Proactive quality checks |
| docs, documentation, readme | `/maestro readme` | Auto-generate README |

### Intent Alias Output Format

```
[maestro] Routing "deploy" to /maestro chain — multi-service task chains.

  Run /maestro chain to continue, or:
  /maestro help commands    — see all 50 commands
```

## Step 3 — No Match Found

If no fuzzy match scores above the minimum threshold and no alias matches:

```
[maestro] Command "xyz" not recognized.

  Type /maestro help commands for the full list.
  Type /maestro help for quick-start topics.
```

## Behavior Rules

- Never silently fail. Always respond with a suggestion or pointer.
- Do not guess if confidence is low — show the full command list link instead.
- Keep the response to 5 lines maximum. Do not explain fuzzy matching to the user.
- Use plain `[maestro]` prefix, not a box, for these messages.
