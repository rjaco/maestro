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

---

## Flags

| Flag | Effect |
|------|--------|
| `--week N` | Show retro for N weeks ago (default: current week) |
| `--all` | Show all-time stats |
| `--improvements` | Show only improvement proposals, skip stats |

---

## Date Handling

All date calculations MUST use UTC to avoid timezone-induced off-by-one errors.

```bash
# Get the start of the current ISO week (Monday 00:00:00 UTC)
python3 -c "
from datetime import datetime, timezone, timedelta
now = datetime.now(timezone.utc)
monday = now - timedelta(days=now.weekday())
print(monday.strftime('%Y-%m-%d'))
"
```

For `--week N`, subtract N×7 days from today (UTC) to get the start of that week.

Never use local time for git log date filters. Always pass `--date=iso-strict` and filter on UTC values.

Git log command for weekly data:

```bash
git log \
  --format="%H|%s|%ai|%an" \
  --after="${WEEK_START}T00:00:00+0000" \
  --before="${WEEK_END}T23:59:59+0000" \
  --no-merges
```

---

## Data Sources

Gather data from:

1. **Git history** — scoped to the target week using UTC boundaries (see above)
2. **Maestro state** — `.maestro/state.md` for session history
3. **Token ledger** — `.maestro/token-ledger.md` for cost data
4. **Trust metrics** — `.maestro/trust.yaml` for QA rates
5. **Build logs** — `.maestro/logs/` for session events
6. **Memory** — `.maestro/memory/semantic.md` for learned patterns
7. **Previous retro baseline** — `.maestro/retro/baseline.md` for week-over-week comparisons

---

## First-Time Retro Handling

Check whether `.maestro/retro/baseline.md` exists.

**If it does not exist** (first retro ever):

```
+---------------------------------------------+
| Maestro Retro — First Run                   |
+---------------------------------------------+

  (i) No baseline found — this is your first retro.
  (i) Week-over-week comparisons are not available yet.
  (i) A baseline will be saved after this retro so future runs can show trends.

  Showing absolute stats only (no deltas).
```

Do NOT show `[+/-N]` delta columns. Show raw numbers only. After generating the retro report, save the current week's stats as the new baseline (see "Baseline Persistence" below).

**If baseline exists:**
Load it and compute deltas for each metric. Show `[+N]` (green arrow `^`) or `[-N]` (red arrow `v`) next to each number.

---

## Output Format

```
+---------------------------------------------+
| Maestro Retro — Week of [YYYY-MM-DD] (UTC)  |
+---------------------------------------------+

  Shipping
    Commits       [N] this week  ([+/-N] vs last week)
    Stories       [N] completed  ([+/-N])
    Features      [N] shipped    ([+/-N])
    Streak        [N] consecutive days with commits

  Quality
    QA first-pass [N]%  ([+/-N]% vs last week)
    Self-heal     [N] avg attempts per story
    Doom-loops    [N] detected, [N] auto-resolved
    Trust level   [level]  ([N] total stories)

  Cost
    Tokens        [N]K this week
    Spend         ~$[N.NN] this week  ([+/-$N.NN])
    Avg per story ~$[N.NN]
    Model mix     [N]% Sonnet / [N]% Opus / [N]% Haiku

  Friction Signals
    [signal type] — [description]  (seen [N] times)
    [signal type] — [description]  (seen [N] times)

  Improvements Applied This Week
    [YYYY-MM-DD] [improvement description]
```

The "Week of" date is always the Monday of the target week, formatted as `YYYY-MM-DD (UTC)`.

---

## Shipping Streak

Track consecutive days with at least one Maestro commit. Use UTC dates from git log:

```bash
git log --format="%ad" --date=format:"%Y-%m-%d" | sort -ur | awk '
  BEGIN { streak = 0; prev = "" }
  {
    if (prev == "") { streak = 1; prev = $1; next }
    # Parse dates as YYYY-MM-DD and compare
    cmd = "date -d \"" prev "\" +%s"; cmd | getline prev_epoch; close(cmd)
    cmd = "date -d \"" $1  "\" +%s"; cmd | getline cur_epoch;  close(cmd)
    diff = prev_epoch - cur_epoch
    if (diff == 86400) { streak++; prev = $1 }
    else { exit }
  }
  END { print streak }
'
```

If `date -d` is not available (macOS), use `date -j -f "%Y-%m-%d"` instead. If neither works, fall back to counting unique commit dates in the target week as a proxy.

---

## Improvement Proposals

After presenting stats, invoke the `retrospective` skill to analyze friction patterns and generate improvement proposals:

1. Run friction signal detection from the retrospective skill
2. For each signal, propose a concrete improvement with an estimated impact
3. For each proposal, include the **target file(s)** that would need to change

```
+---------------------------------------------+
| Improvement Proposals                       |
+---------------------------------------------+

  [1] Add "Read before Edit" to implementer prompt
      Signal:  exact-repeat doom-loop on Edit (3 occurrences)
      Impact:  Reduce self-heal attempts by ~30%
      Target:  skills/implementer/SKILL.md
      Risk:    Low — additive instruction, no behavior removed

  [2] Update decompose template to require file lists
      Signal:  context-chase (2 NEEDS_CONTEXT chains)
      Impact:  Fewer re-dispatches, faster story completion
      Target:  skills/decompose/SKILL.md
      Risk:    Low — adds a required field, existing stories unaffected

  [3] Switch forecast model from Haiku to Sonnet
      Signal:  forecast accuracy was 45% (below 60% target)
      Impact:  Better cost estimates for user
      Target:  .maestro/config.yaml (models.forecast)
      Risk:    Medium — increases forecast cost by ~$0.05/session
```

Use AskUserQuestion:
- Question: "Apply these improvements?"
- Header: "Improvements"
- Options:
  1. label: "Apply all", description: "Update skills and DNA with all proposals"
  2. label: "Select individually", description: "Choose which to apply"
  3. label: "Skip", description: "Review only, no changes"

---

## Improvement Validation Before Applying

Before applying ANY improvement, run validation to ensure it does not break existing behavior.

**Step 1 — Dry-run read.**
For each target file, read its current content and identify the exact section that will change.

**Step 2 — Semantic conflict check.**
Before writing, verify the proposed change does not contradict any existing instruction in the same file. Look for direct negations (e.g., proposing to add "always X" when the file already says "never X"). If a conflict is found:
```
[maestro] Conflict detected in skills/implementer/SKILL.md:
  Proposed: "Always read files before editing"
  Existing: "Skip reading large files to save tokens" (line 47)
  Resolution needed before applying.
```
Ask the user how to resolve before proceeding.

**Step 3 — Apply the change.**
Write only the minimum diff required. Do not reformat or restructure content beyond the targeted change.

**Step 4 — Post-apply verification.**
After writing, re-read the file and confirm the target instruction is present. If the file cannot be re-read or the instruction is absent, report:
```
[maestro] Verification failed for improvement [1]. File may not have saved correctly.
```

---

## Rollback Strategy

Before applying any improvement, save a snapshot:

```bash
cp "${TARGET_FILE}" "${TARGET_FILE}.retro-backup-$(date -u +%Y%m%d)"
```

After all improvements are applied, report:

```
[maestro] Improvements applied. Backups saved:
  skills/implementer/SKILL.md.retro-backup-20260318
  skills/decompose/SKILL.md.retro-backup-20260318

To roll back all changes:
  cp skills/implementer/SKILL.md.retro-backup-20260318 skills/implementer/SKILL.md
  cp skills/decompose/SKILL.md.retro-backup-20260318 skills/decompose/SKILL.md
```

If the user requests a rollback at any point during this session, restore from the `.retro-backup-*` file and confirm.

---

## Baseline Persistence

After every retro run that completes successfully, save the current week's key metrics to `.maestro/retro/baseline.md`. Create the directory if it does not exist.

**Baseline file format:**

```markdown
---
week: 2026-03-16        # Monday of the week, UTC
generated: 2026-03-18   # Date this baseline was written
---

commits: 12
stories: 8
features: 2
streak: 5
qa_first_pass_pct: 80
self_heal_avg: 1.2
doom_loops: 1
spend_usd: 4.20
avg_per_story_usd: 0.53
model_mix_sonnet_pct: 66
model_mix_opus_pct: 34
model_mix_haiku_pct: 0
```

If a baseline already exists for the same week (same `week:` value), overwrite it. Never accumulate multiple baseline entries for the same week.

---

## Integration

Add `retro` to the router in `commands/maestro.md` (Step 2.5):

```
| `retro` | `/maestro retro` |
```

This command is a user-facing wrapper around the existing `retrospective` skill, adding weekly stats, shipping streaks, timezone-safe date handling, improvement validation, rollback snapshots, and a formatted dashboard that the retrospective skill does not provide on its own.
