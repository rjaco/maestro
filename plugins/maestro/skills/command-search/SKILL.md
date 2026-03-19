---
name: command-search
description: "Fuzzy command matching and intent routing. When user input doesn't match any known command, suggest the closest alternatives and handle common alias patterns."
---

# Command Search & Fuzzy Matching

When a user types a command that does not match any of the 51 known Maestro commands, apply fuzzy matching to suggest the closest alternatives and handle common intent aliases.

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

## Command Category Index

Browse commands by domain to help users discover what is available.

| Category | Commands |
|----------|----------|
| Getting Started | init, doctor, help, demo, quick-start |
| Building | maestro, opus, plan, spec, pair |
| Monitoring | status, dashboard, heartbeat, observe, watch, aware |
| Configuration | config, model, preferences, profile, soul |
| Operations | board, deps, viz, rollback, history |
| Integrations | brain, notify, remote, services, webhooks, schedule |
| Analysis | retro, cost-estimate, security-scan |
| Content | content, marketing, readme |

When a user asks "what commands are there for X?", match their topic to the appropriate category row and list its commands.

## Step 0 — Intent Mapping

Before fuzzy matching, check if the input word or phrase maps to a known intent. If it does, route directly without performing edit-distance calculations.

| User Says | Maps To | Reason |
|-----------|---------|--------|
| deploy | /maestro ship | Ship is the deployment command |
| email | /maestro notify | Notify handles email |
| run tests | /maestro watch | Watch monitors tests |
| costs | /maestro cost-estimate | Cost tracking |
| fix | /maestro doctor | Doctor diagnoses issues |
| kanban | /maestro board | Board is the kanban view |
| research | /maestro plan | Plan includes research phase |
| brain | /maestro brain | Second brain operations |
| monitor | /maestro aware | Awareness checks |
| automate | /maestro workers | Background workers |
| deploy, ship, release, launch | /maestro chain | Multi-service deployment chains |
| email, sendgrid, smtp | /maestro connect sendgrid | Email service integration |
| domain, namecheap, dns | /maestro connect namecheap | Domain management |
| cost, spend, budget, price | /maestro cost-estimate | Pre-build cost forecast |
| settings, prefs, configure | /maestro config | Configuration editor |
| login, auth, sign in | /maestro browser login | Browser-based auth flow |
| cron, job, schedule, recurring | /maestro schedule | Scheduled task runner |
| test, tests, testing | /maestro aware | Proactive quality checks |
| docs, documentation, readme | /maestro readme | Auto-generate README |

### Intent Mapping Output Format

```
[maestro] Routing "deploy" to /maestro chain — multi-service task chains.

  Run /maestro chain to continue, or:
  /maestro help commands    — see all 51 commands
```

## Step 1 — Fuzzy Match via Levenshtein Distance

If no intent alias matched, compute Levenshtein distance between the unknown input and every command name to find the closest matches.

### Levenshtein Distance Algorithm

Execute the following mentally for each candidate command name:

```
Given query Q and candidate C:

1. Create a matrix M of size (len(Q)+1) x (len(C)+1).
2. Initialize: M[0][j] = j for all j (cost of deleting all of C's prefix).
              M[i][0] = i for all i (cost of inserting all of Q's prefix).
3. For each i from 1..len(Q), for each j from 1..len(C):
     If Q[i-1] == C[j-1]:
       M[i][j] = M[i-1][j-1]          (no operation needed)
     Else:
       M[i][j] = 1 + min(
         M[i-1][j],    // deletion  — remove char from Q
         M[i][j-1],    // insertion — add char from C into Q
         M[i-1][j-1]   // substitution — swap Q[i] for C[j]
       )
4. Distance = M[len(Q)][len(C)].

Example — query "deplyo", candidate "deploy":
  Matrix row by row produces distance = 2 (two transpositions).
  Threshold = max(1, len("deplyo") / 4) = max(1, 1.5) = 2  → MATCH.

Example — query "statis", candidate "status":
  Distance = 1 (one substitution). Threshold = max(1, 6/4) = 2 → MATCH.

Example — query "xyz", candidate "status":
  Distance = 5. Threshold = max(1, 3/4) = 1  → NO MATCH.
```

### Fuzzy Match Procedure

1. Compute Levenshtein distance from the query to all 51 command names.
2. Calculate threshold = max(1, floor(len(query) / 4)).
3. Retain only candidates where distance <= threshold.
4. Sort retained candidates by distance ascending (closest first).
5. Return the top 3 matches.
6. If fewer than 3 candidates pass the threshold, show only those that do.
7. If zero candidates pass, proceed to Step 2 (no-match fallback).

### Output Format

```
[maestro] Command "servces" not found. Did you mean:
  /maestro services    List services with status
  /maestro connect     Connect an external service
  /maestro status      View progress

Type /maestro help commands for the full list.
```

Rules:
- Show at most 3 suggestions (or fewer if fewer than 3 pass the threshold)
- Show command name and a one-line description beside each
- End with the pointer to `help commands`
- Use `[maestro]` prefix, no box required for this message

## Step 2 — No Match Found

If no fuzzy match scored within the threshold and no alias matched:

```
[maestro] Command "xyz" not recognized.

  Type /maestro help commands for the full list.
  Type /maestro help for quick-start topics.
```

## Behavior Rules

- Always check intent mapping first (Step 0), then fuzzy match (Step 1), then no-match fallback (Step 2).
- Never silently fail. Always respond with a suggestion or pointer.
- Do not guess if confidence is low — show the full command list link instead.
- Keep the response to 5 lines maximum. Do not explain fuzzy matching to the user.
- Use plain `[maestro]` prefix, not a box, for these messages.
