---
name: ci-mode
description: "Non-interactive headless operation for CI/CD pipelines. Auto-resolves all prompts, emits machine-parseable JSON output, writes structured artifacts, and exits with standard exit codes."
---

# CI Mode

Runs Maestro entirely without human interaction. Designed for automated testing pipelines, GitHub Actions workflows, scheduled builds, and any context where a terminal attendant is not present.

## Activation

Set the environment variable before invoking any Maestro skill:

```bash
MAESTRO_CI=true /maestro opus-loop
```

Or export it for the session:

```bash
export MAESTRO_CI=true
```

When `MAESTRO_CI=true`, every behavioral change described in this skill is active. No other configuration is required, though additional options are available (see Configuration).

## Behavioral Changes in CI Mode

### No User Interaction

All `AskUserQuestion` calls are suppressed. Instead:

1. Use the **first option** in the options list (the recommended default).
2. Log the auto-resolution as a JSON event (see Output Format).
3. Continue without pausing.

If a question has no options (free-text prompt), use the empty string `""` as the response and log a `warn` event noting that free-text auto-resolution was attempted.

**Never block waiting for stdin in CI mode.**

### No Visual Chrome

Suppress all of the following:
- Box-drawing characters (`┌`, `─`, `│`, `└`, etc.)
- ANSI color codes
- Progress bars and spinners
- Milestone header banners
- Section dividers
- Emoji in output

Replace all structured display with JSON lines (see Output Format).

### No Desktop or Audio Alerts

Suppress all calls to:
- `osascript` (macOS desktop notifications)
- `notify-send` (Linux desktop notifications)
- `scripts/audio-alert.sh`
- Any sound or bell character (`\a`)

The `notify` skill is also suppressed — no Slack/Discord/Telegram messages unless explicitly configured with `ci_notifications: true`.

## Output Format

All output is **JSON lines** (one JSON object per line, newline-delimited). Each line is a self-contained event.

### Event Schema

```json
{
  "t": "<ISO-8601 timestamp>",
  "level": "info | warn | error | debug",
  "event": "<event_type>",
  "session": "<session_id>",
  "milestone": "<MN-slug or null>",
  "story": "<story-id or null>",
  "phase": "<phase or null>",
  "data": { ... }
}
```

### Event Types

| event | When emitted | Key data fields |
|-------|-------------|-----------------|
| `session.start` | Loop begins | `model`, `milestone_count`, `ci_mode: true` |
| `milestone.start` | Milestone begins | `milestone_id`, `title`, `story_count` |
| `milestone.complete` | Milestone passes eval | `milestone_id`, `duration_ms`, `stories_passed`, `cost_usd` |
| `milestone.failed` | Milestone fails after auto-fix cycles | `milestone_id`, `reason`, `fix_cycles_used` |
| `story.start` | Story dispatched | `story_id`, `title`, `agent`, `model` |
| `story.complete` | Story passes QA | `story_id`, `duration_ms`, `cost_usd` |
| `story.failed` | Story rejected after retries | `story_id`, `reason`, `attempts` |
| `qa.pass` | QA review passes | `story_id`, `reviewer_model` |
| `qa.reject` | QA review rejects | `story_id`, `reasons` |
| `prompt.auto_resolved` | AskUserQuestion auto-answered | `question`, `options`, `selected` |
| `prompt.free_text` | Free-text prompt auto-answered with empty | `question` |
| `timeout.story` | Per-story timeout exceeded | `story_id`, `timeout_ms` |
| `timeout.milestone` | Per-milestone timeout exceeded | `milestone_id`, `timeout_ms` |
| `session.complete` | All milestones done | `exit_code`, `duration_ms`, `total_cost_usd` |
| `session.failed` | Session aborted | `exit_code`, `reason` |

### Example Output

```
{"t":"2024-01-15T14:00:00Z","level":"info","event":"session.start","session":"abc123","milestone":null,"story":null,"phase":null,"data":{"model":"opus","milestone_count":3,"ci_mode":true}}
{"t":"2024-01-15T14:00:01Z","level":"info","event":"milestone.start","session":"abc123","milestone":"M1-auth","story":null,"phase":null,"data":{"title":"Authentication","story_count":4}}
{"t":"2024-01-15T14:00:02Z","level":"info","event":"story.start","session":"abc123","milestone":"M1-auth","story":"01-login-form","phase":"implement","data":{"agent":"implementer","model":"sonnet"}}
{"t":"2024-01-15T14:02:14Z","level":"info","event":"qa.pass","session":"abc123","milestone":"M1-auth","story":"01-login-form","phase":"qa-review","data":{"reviewer_model":"sonnet"}}
{"t":"2024-01-15T14:02:14Z","level":"info","event":"story.complete","session":"abc123","milestone":"M1-auth","story":"01-login-form","phase":null,"data":{"duration_ms":132000,"cost_usd":0.87}}
```

## Exit Codes

| Code | Meaning |
|------|---------|
| `0` | All milestones completed successfully |
| `1` | One or more stories failed (after all retries) |
| `2` | One or more milestones failed (milestone eval did not pass) |
| `3` | Session aborted — unrecoverable error, safety valve triggered, or explicit abort signal |

Exit codes are mutually exclusive. Use the highest applicable code if multiple failures occur (3 > 2 > 1 > 0).

Emit `session.complete` or `session.failed` before exiting to ensure the artifact is flushed.

## Artifact Output

Write `.maestro/ci-output.json` at session end (or on abort). This is the machine-readable session summary.

```json
{
  "schema_version": "1",
  "session_id": "<session_id>",
  "ci_mode": true,
  "started_at": "<ISO-8601>",
  "ended_at": "<ISO-8601>",
  "duration_ms": 14400000,
  "exit_code": 0,
  "milestones": [
    {
      "id": "M1-auth",
      "title": "Authentication",
      "status": "complete",
      "started_at": "<ISO-8601>",
      "ended_at": "<ISO-8601>",
      "duration_ms": 5400000,
      "stories": [
        {
          "id": "01-login-form",
          "title": "Login Form",
          "status": "complete",
          "attempts": 1,
          "duration_ms": 132000,
          "cost_usd": 0.87
        }
      ],
      "cost_usd": 3.21
    }
  ],
  "totals": {
    "milestones_attempted": 3,
    "milestones_complete": 3,
    "milestones_failed": 0,
    "stories_attempted": 11,
    "stories_complete": 11,
    "stories_failed": 0,
    "total_cost_usd": 8.94
  },
  "prompts_auto_resolved": [
    {
      "question": "Which model should handle QA review?",
      "options": ["sonnet", "haiku"],
      "selected": "sonnet"
    }
  ]
}
```

Write this file incrementally — update it after each milestone completes so a crashed run still produces a partial artifact. Use atomic write (write to `.maestro/ci-output.json.tmp`, then rename) to avoid partial reads.

## Timeout Handling

Timeouts prevent a hung agent from stalling a pipeline indefinitely.

### Configuration

```yaml
ci_mode:
  timeouts:
    story_ms: 600000        # 10 minutes per story (default)
    milestone_ms: 3600000   # 60 minutes per milestone (default)
    session_ms: 14400000    # 4 hours total session (default)
```

Override per-milestone in the milestone spec:

```yaml
# .maestro/milestones/M1-auth.md frontmatter
ci_timeout_ms: 7200000   # 2 hours for this milestone specifically
```

### Timeout Behavior

When a story timeout fires:
1. Emit `timeout.story` event
2. Mark story as `failed` with reason `timeout`
3. If `fail_fast: true`, emit `session.failed` and exit with code `3`
4. Otherwise continue to next story

When a milestone timeout fires:
1. Emit `timeout.milestone` event
2. Mark milestone as `failed` with reason `timeout`
3. Continue to next milestone (unless `fail_fast: true`)

When the session timeout fires:
1. Flush `.maestro/ci-output.json` with current state
2. Emit `session.failed` with `reason: session_timeout`
3. Exit with code `3`

## Configuration

Full CI mode config block in `.maestro/config.yaml`:

```yaml
ci_mode:
  enabled: false          # overridden by MAESTRO_CI=true env var

  fail_fast: false        # abort on first story failure

  ci_notifications: false # set true to allow notify skill in CI

  timeouts:
    story_ms: 600000
    milestone_ms: 3600000
    session_ms: 14400000

  output:
    jsonl_file: null      # stream JSON lines to a file (in addition to stdout)
                          # example: .maestro/ci-run.jsonl
    artifact: .maestro/ci-output.json
```

## GitHub Actions Integration

### Basic Workflow

```yaml
# .github/workflows/maestro.yml
name: Maestro Autonomous Build

on:
  push:
    branches: [main]
  workflow_dispatch:
    inputs:
      milestone:
        description: 'Start from milestone (e.g. M2-api). Leave blank for full run.'
        required: false

jobs:
  maestro:
    runs-on: ubuntu-latest
    timeout-minutes: 240

    steps:
      - uses: actions/checkout@v4

      - name: Set up Node.js
        uses: actions/setup-node@v4
        with:
          node-version: '20'
          cache: 'npm'

      - name: Install dependencies
        run: npm ci

      - name: Run Maestro
        env:
          MAESTRO_CI: 'true'
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: npx claude /maestro opus-loop

      - name: Upload CI artifact
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: maestro-ci-output
          path: .maestro/ci-output.json

      - name: Parse exit code
        if: always()
        run: |
          EXIT_CODE=$(cat .maestro/ci-output.json | jq '.exit_code')
          echo "Maestro exit code: $EXIT_CODE"
          case $EXIT_CODE in
            0) echo "All milestones complete" ;;
            1) echo "::warning::One or more stories failed" ;;
            2) echo "::error::One or more milestones failed" ;;
            3) echo "::error::Session aborted" ;;
          esac
          exit $EXIT_CODE
```

### Scheduled Nightly Build

```yaml
# .github/workflows/maestro-nightly.yml
name: Maestro Nightly

on:
  schedule:
    - cron: '0 2 * * *'   # 2am UTC every night

jobs:
  maestro-nightly:
    runs-on: ubuntu-latest
    timeout-minutes: 360

    steps:
      - uses: actions/checkout@v4

      - name: Run Maestro (CI mode)
        env:
          MAESTRO_CI: 'true'
          ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
        run: npx claude /maestro opus-loop

      - name: Upload results
        if: always()
        uses: actions/upload-artifact@v4
        with:
          name: nightly-${{ github.run_id }}
          path: |
            .maestro/ci-output.json
            .maestro/logs/
```

### Posting a Summary to the PR

Add this step after the Maestro run to post a formatted summary as a PR comment:

```yaml
      - name: Post PR summary
        if: github.event_name == 'pull_request' && always()
        uses: actions/github-script@v7
        with:
          script: |
            const fs = require('fs');
            const output = JSON.parse(fs.readFileSync('.maestro/ci-output.json'));
            const icon = output.exit_code === 0 ? '✅' : '❌';
            const lines = output.milestones.map(m =>
              `| ${m.title} | ${m.status} | ${(m.cost_usd ?? 0).toFixed(2)} |`
            ).join('\n');
            const body = `## ${icon} Maestro Build\n\n| Milestone | Status | Cost |\n|-----------|--------|------|\n${lines}\n\nTotal cost: $${output.totals.total_cost_usd.toFixed(2)}`;
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.issue.number,
              body
            });
```

## Suppressed Skills in CI Mode

The following skills are fully suppressed (no-op) when `MAESTRO_CI=true`:

| Skill | Reason |
|-------|--------|
| `notify` | No external notifications unless `ci_notifications: true` |
| `audio` | No sound output |
| `voice` | No speech synthesis |
| `dashboard` | No terminal UI |
| `kanban` | No visual board |
| `desktop-compat` | No desktop integration |

Skills that remain active:
- All implementation, QA, and orchestration skills
- `checkpoint` — still creates checkpoints (useful for CI debugging)
- `audit-log` — still logs decisions
- `token-ledger` — still tracks cost
- `context-autopilot` — still manages context window

## Detecting CI Mode in Skills

Any skill can check for CI mode:

```
if MAESTRO_CI env var is "true":
  # use JSON output, skip prompts, skip visual chrome
else:
  # normal interactive behavior
```

Do not check `.maestro/config.yaml` alone for CI detection — the env var takes precedence and is set per-run by the pipeline, not persisted in config.
