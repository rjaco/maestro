---
name: history
description: "View session history and build logs"
argument-hint: "[list|detail SESSION_ID|cost|compare SESSION_A SESSION_B]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro History

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

View past sessions, build logs, and cost analysis. Reads from `.maestro/logs/`, `.maestro/state.md`, and `.maestro/token-ledger.md`.

---

## Data Discovery

Before rendering any subcommand, gather data from all available sources in this priority order:

1. **Primary** — Glob `.maestro/logs/*.md`; read each log file for structured session data
2. **Secondary** — Read `.maestro/state.md` for the "Features Completed" and "History" sections
3. **Tertiary (fallback)** — If neither source has records, run:
   ```bash
   git log --format="%H|%s|%ai|%an" --no-merges | head -50
   ```
   and synthesize approximate session records from commit groups (commits on the same calendar day = one session)

Never fail silently when a data source is missing — always try the next fallback and note which source was used at the bottom of the output with `(source: git log fallback)`.

---

## No Arguments or `list` — Session List

Read all sources. Present a table:

```
+---------------------------------------------+
| Session History                             |
+---------------------------------------------+
  Date        Feature                  Stories  Cost    Time
  ----------  ---------------------    -------  ------  ------
  2026-03-15  User authentication      5/5      $4.20   14m
  2026-03-12  Dark mode toggle         2/2      $1.10   6m
  2026-03-10  API rate limiting        3/3      $2.85   11m

  Total  3 sessions, 10 stories, $8.15, 31m
```

Use AskUserQuestion:
- Question: "What would you like to see?"
- Header: "History"
- Options:
  1. label: "Session details", description: "View full build log for a specific session"
  2. label: "Cost analysis", description: "Aggregated cost data across all sessions"
  3. label: "Compare two sessions", description: "Side-by-side quality and cost comparison"

### Graceful Fallback — No Maestro Logs

If `.maestro/logs/` does not exist or is empty, and `.maestro/state.md` has no session entries, fall back to git log and display:

```
+---------------------------------------------+
| Session History  (source: git log fallback) |
+---------------------------------------------+
  (i) No .maestro/logs found — showing approximate sessions from git history.
  (i) Full history is recorded after completing features with /maestro.

  Date        Commits   Message sample
  ----------  -------   ------------------------------
  2026-03-15  5         feat: user authentication
  2026-03-12  2         feat: dark mode toggle
  2026-03-10  3         feat: API rate limiting
```

The git fallback groups commits by calendar date using the committer date in UTC. Commits whose subject does not start with `feat:` or `fix:` are still shown but marked `(chore)`.

---

## `detail SESSION_ID` — Session Details

The SESSION_ID can be a date (`2026-03-15`), a feature name (`user-auth`), or a session UUID. Search through all logs to find the matching session.

```
+---------------------------------------------+
| Session: User authentication                |
+---------------------------------------------+
  Date      2026-03-15
  Mode      checkpoint
  Duration  14m 32s
  Stories   5/5 completed, 0 skipped

  Story Breakdown
    01  Database schema    (ok)  QA pass 1st    $0.65   2m 10s   estimated $0.50
    02  API routes         (ok)  QA pass 1st    $0.95   3m 05s   estimated $0.80
    03  Auth middleware    (ok)  QA pass 2nd    $1.10   4m 20s   estimated $0.70
    04  Login page         (ok)  QA pass 1st    $0.80   3m 02s   estimated $0.80
    05  Tests              (ok)  QA pass 1st    $0.70   2m 15s   estimated $0.60

  Estimates vs Actual
    Estimated total   $3.40
    Actual total      $4.20
    Variance          +$0.80  (+24%)  — Auth middleware ran 2 QA cycles

  QA first-pass rate  80%  (4/5 stories)
  Self-heal cycles    2 total  (story 03)
  Commits             5
```

**Estimated vs Actual column:** Read the `estimated_cost` field from the story frontmatter (set by `/maestro decompose`). If not present, show `—`. Compute variance as `actual - estimated` and express as both dollar delta and percent. Highlight in the summary if variance exceeds +30%.

Use AskUserQuestion:
- Question: "What next?"
- Header: "Detail"
- Options:
  1. label: "Show git log", description: "View commits from this session"
  2. label: "Compare with another session", description: "Side-by-side quality and cost"
  3. label: "Back to list", description: "Return to session overview"

---

## `cost` — Cost Analysis

Aggregate cost data across all sessions from `.maestro/token-ledger.md`.

```
+---------------------------------------------+
| Cost Analysis                               |
+---------------------------------------------+
  Total spend       $8.15
  Total stories     10
  Total sessions    3
  Avg per story     $0.82
  Avg per session   $2.72

  Model Breakdown
    Model           Spend    Share   Stories   Avg/Story
    -----------     ------   -----   -------   ---------
    Sonnet 3.5      $5.40    66%     8         $0.68
    Opus 3          $2.75    34%     5 (QA)    $0.55

  Cost Trend  (per session, chronological)
    Mar 10    $2.85   ███████████████████████████
    Mar 12    $1.10   ██████████
    Mar 15    $4.20   ████████████████████████████████████████

  Trend direction   UP (+47% vs 2-session avg)
  Most expensive    Auth Middleware ($1.10, session 2026-03-15)
  Cheapest story    Dark mode toggle ($0.55, session 2026-03-12)

  Estimated vs Actual (all sessions)
    Sessions with estimates   3/3
    Total estimated           $6.90
    Total actual              $8.15
    Overall variance          +$1.25 (+18%)

  Tips
    (i) Lower costs: use --yolo for well-understood tasks
    (i) Cheaper model: /maestro model set execution haiku
    (i) Stories with QA retries drive most variance — check friction patterns with /maestro retro
```

**Model Breakdown calculation:**

Read `.maestro/token-ledger.md`. For each entry, the `model` field identifies which model ran that task. Sum `cost_usd` per model. If `model` field is absent, attribute to the model set in `.maestro/config.yaml` at `models.execution`.

If the token ledger records token counts but not dollar amounts, apply these default rates to calculate cost:
- claude-opus-4: $0.015 per 1K input tokens, $0.075 per 1K output tokens
- claude-sonnet-4: $0.003 per 1K input tokens, $0.015 per 1K output tokens
- claude-haiku-3-5: $0.0008 per 1K input tokens, $0.004 per 1K output tokens

Show which rate table was applied with `(i) Costs calculated from token counts using published rates.`

If `.maestro/token-ledger.md` does not exist:

```
+---------------------------------------------+
| Cost Analysis                               |
+---------------------------------------------+
  (i) No cost data found.
  (i) Cost tracking starts automatically when you build features.
  (i) Disable with: /maestro config set cost_tracking.enabled false
```

---

## `compare SESSION_A SESSION_B` — Session Comparison

Look up both sessions by ID (date, name, or UUID) and render a side-by-side comparison.

```
+------------------------------------------------------------------+
| Session Comparison                                               |
+------------------------------------------------------------------+

                          User Auth (Mar 15)    API Endpoints (Mar 12)
                          ------------------    ----------------------
  Stories                 5/5                   2/2
  Duration                14m 32s               6m 05s
  Total cost              $4.20                 $1.10
  Avg cost/story          $0.84                 $0.55
  QA first-pass rate      80%                   100%
  Self-heal cycles        2                     0
  Commits                 5                     2

  Model mix
    Sonnet                $2.80  (67%)           $0.90  (82%)
    Opus (QA)             $1.40  (33%)           $0.20  (18%)

  Winner (by cost/story)  ← API Endpoints ($0.55 vs $0.84)
  Winner (by QA rate)     ← API Endpoints (100% vs 80%)
```

If either session ID is not found, display:
```
[maestro] Session not found: "2026-03-09"
Available sessions: 2026-03-15, 2026-03-12, 2026-03-10
```

---

## Output Contract

Every `history` invocation emits output in this order:

1. ASCII banner (mandatory)
2. Primary data table or detail block
3. Data source note (if git fallback was used): `(source: git log fallback)`
4. Estimated vs Actual summary (in `detail` and `cost` views)
5. AskUserQuestion prompt (in `list` and `detail` views)

**Never omit the Estimated vs Actual section** when forecast data exists in story frontmatter — this is the primary signal for improving decompose quality over time.
