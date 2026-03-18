---
name: retro
description: "Weekly retrospective — shipping stats, quality trends, friction patterns, and improvement proposals"
argument-hint: "[--week N|--all|--improvements]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

# Maestro Retro

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Generate a weekly retrospective with shipping stats, quality trends, and actionable improvement proposals. Inspired by gstack's `/retro` skill.

## Flags

| Flag | Effect |
|------|--------|
| `--week N` | Show retro for N weeks ago (default: current week) |
| `--all` | Show all-time stats |
| `--improvements` | Show only improvement proposals |

## Data Sources

Gather data from:

1. **Git history** — `git log --since="1 week ago" --format="%H|%s|%ai|%an"` for commits
2. **Maestro state** — `.maestro/state.md` for session history
3. **Token ledger** — `.maestro/token-ledger.md` for cost data
4. **Trust metrics** — `.maestro/trust.yaml` for QA rates
5. **Build logs** — `.maestro/logs/` for session events
6. **Memory** — `.maestro/memory/semantic.md` for learned patterns

## Output Format

```
+---------------------------------------------+
| Maestro Retro — Week of [date]              |
+---------------------------------------------+

  Shipping
    Commits       [N] this week ([+/-N] vs last week)
    Stories       [N] completed
    Features      [N] shipped
    Streak        [N] consecutive days with commits

  Quality
    QA first-pass [N]% ([+/-N]% vs last week)
    Self-heal     [N] avg attempts per story
    Doom-loops    [N] detected, [N] auto-resolved
    Trust level   [level] ([N] total stories)

  Cost
    Tokens        [N]K this week
    Spend         ~$[N.NN] this week
    Avg per story ~$[N.NN]
    Model mix     [N]% Sonnet / [N]% Opus / [N]% Haiku

  Friction Signals
    [signal type] — [description] (seen [N] times)
    [signal type] — [description] (seen [N] times)

  Improvements Applied
    [date] [improvement description]
    [date] [improvement description]
```

## Shipping Streak

Track consecutive days with at least one Maestro commit:

```bash
git log --format="%ad" --date=short | sort -ur | awk '
  BEGIN { streak = 0; prev = "" }
  {
    split($1, d, "-")
    cur = mktime(d[1] " " d[2] " " d[3] " 0 0 0")
    if (prev != "" && (prev - cur) == 86400) streak++
    else if (prev != "") { print streak + 1; streak = 0 }
    prev = cur
  }
  END { print streak + 1 }
' | head -1
```

## Improvement Proposals

After presenting stats, invoke the `retrospective` skill to analyze friction patterns and generate improvement proposals:

1. Run friction signal detection from the retrospective skill
2. For each signal, propose a concrete improvement
3. Present proposals to the user for approval

```
+---------------------------------------------+
| Improvement Proposals                       |
+---------------------------------------------+

  [1] Add "Read before Edit" to implementer prompt
      Signal: exact-repeat doom-loop on Edit (3 occurrences)
      Impact: Reduce self-heal attempts by ~30%

  [2] Update decompose template to require file lists
      Signal: context-chase (2 NEEDS_CONTEXT chains)
      Impact: Fewer re-dispatches, faster story completion

  [3] Switch forecast model from Haiku to Sonnet
      Signal: forecast accuracy was 45% (below 60% target)
      Impact: Better cost estimates for user
```

Use AskUserQuestion:
- Question: "Apply these improvements?"
- Header: "Improvements"
- Options:
  1. label: "Apply all", description: "Update skills and DNA with all proposals"
  2. label: "Select individually", description: "Choose which to apply"
  3. label: "Skip", description: "Review only, no changes"

## Integration

Add `retro` to the router in `commands/maestro.md` (Step 2.5):

```
| `retro` | `/maestro retro` |
```

This command is a user-facing wrapper around the existing `retrospective` skill, adding weekly stats, shipping streaks, and a formatted dashboard that the retrospective skill doesn't provide on its own.
