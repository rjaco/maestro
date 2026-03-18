---
name: universal-output
description: "Universal output adapter that detects the runtime environment and selects the appropriate output format. All commands and skills reference this skill to produce environment-correct output."
effort: low
maxTurns: 2
disallowedTools:
  - Write
  - Edit
---

# Universal Output

All Maestro commands and skills MUST route output through this skill to produce
environment-correct formatting. This skill extends `output-format` with environment
detection and adapts every output decision — boxes, progress bars, AskUserQuestion
options, and line width — to match the runtime context.

## Environment Detection

### Step 1 — Check $CLAUDE_SESSION_TYPE

```
IF $CLAUDE_SESSION_TYPE is set:
  "terminal"  → full output  (same as local Claude Code terminal)
  "desktop"   → compact output
  "remote"    → minimal output
  "sdk"       → structured JSON output
```

### Step 2 — Infer from session hints (fallback)

When `$CLAUDE_SESSION_TYPE` is not set, infer from available signals:

```
IF tty is attached (interactive terminal):
  → terminal (full output)
ELIF $CLAUDE_REMOTE_SESSION == "true" OR $CLAUDE_SESSION_TYPE == "remote":
  → remote (minimal output)
ELIF $CLAUDE_DISPATCH_SESSION == "true" OR $CLAUDE_CLIENT_TYPE IN ["mobile","cowork"]:
  → remote (minimal output)
ELSE:
  → terminal (full output, safe default)
```

### Full decision tree

```
$CLAUDE_SESSION_TYPE set?
  YES → use its value directly
        terminal → TERMINAL mode
        desktop  → DESKTOP mode
        remote   → REMOTE mode
        sdk      → SDK mode
  NO  →
        tty attached?
          YES → TERMINAL mode
          NO  →
                CLAUDE_REMOTE_SESSION=true OR CLAUDE_SESSION_TYPE=remote?
                  YES → REMOTE mode
                  NO  →
                        CLAUDE_DISPATCH_SESSION=true
                        OR CLAUDE_CLIENT_TYPE=mobile/cowork?
                          YES → REMOTE mode
                          NO  → TERMINAL mode (default)
```

Override detection in `.maestro/config.yaml`:

```yaml
output:
  force_environment: terminal   # terminal | desktop | remote | sdk
```

## Environment Profiles

| Feature | Terminal | Desktop | Remote | SDK |
|---------|----------|---------|--------|-----|
| Box-drawing characters | Yes | No | No | No |
| Progress bars | Unicode blocks | Text percentages | None | JSON objects |
| AskUserQuestion options | Up to 4 | 2-3 max | Binary yes/no | Structured response |
| Max line width | 80 chars | 60 chars | 40 chars | N/A |
| Tables | Box-drawing | Stacked key-value | Omit | JSON array |
| Code blocks | Full output | Full output | 10 lines max | Full (in JSON field) |
| Status indicators | `(ok)` `(!)` `(x)` `(i)` | Same | Omit | JSON status field |
| `[maestro]` prefix | Yes | Yes | Yes | No (use JSON wrapper) |
| Phase progress line | Yes | Yes | Omit | JSON field |
| Diagrams / box art | Yes | No | No | No |
| Error details | Full stack trace | Full message | Type + 1 line | JSON error object |

## Output Format per Environment

### Terminal (full)

Follows the `output-format` skill exactly. Box-drawing, Unicode progress,
full AskUserQuestion, 80-char width. This is the default.

```
+---------------------------------------------+
| Story 3/7 complete: API Routes              |
+---------------------------------------------+
  Phase     QA approved (first attempt)
  Files     4 created, 2 modified
  Tests     8 new, all passing
  Commit    feat(api): add user routes
  Tokens    34,200 (story) / 127,800 (total)
  Time      2m 14s (story) / 8m 41s (total)
```

Progress bar:
```
  [======>       ] 4/10 stories
```

### Desktop (compact)

No box-drawing. Plain key-value pairs, stacked. Wrap at 60 chars.
AskUserQuestion: 2-3 options max. No phase progress line.

```
[maestro] Story 3/7 complete: API Routes

  Phase     QA approved (first attempt)
  Files     4 created, 2 modified
  Tests     8 new, all passing

  Continue / Review / Abort
```

Progress indicator (text percentage):
```
  Progress: 40% (4 of 10 stories)
```

### Remote (minimal)

No box-drawing, no tables, no diagrams. Max 40 chars per line.
Max 3 sentences per output block. AskUserQuestion reduced to binary
yes/no or continue/abort. Omit cost breakdowns and file paths
unless critical.

```
[maestro] Story 3/7 done: API Routes.
8 tests passing, 6 files changed.

Continue / Abort
```

No progress indicator — omit entirely.

### SDK (structured)

No conversational text. All output is a JSON object written to stdout.
No `[maestro]` prefix. The consumer parses the result field of the SDK
`result` event.

```json
{
  "event": "story_complete",
  "story": { "index": 3, "total": 7, "title": "API Routes" },
  "phase": "qa",
  "qa": { "passed": true, "attempts": 1 },
  "files": { "created": 4, "modified": 2 },
  "tests": { "added": 8, "passing": 8 },
  "commit": "feat(api): add user routes",
  "tokens": { "story": 34200, "total": 127800 },
  "time_seconds": { "story": 134, "total": 521 },
  "progress": { "completed": 4, "total": 10, "percent": 40 },
  "next_actions": ["continue", "review", "abort"]
}
```

Progress as JSON:
```json
{ "event": "progress", "completed": 4, "total": 10, "percent": 40 }
```

Error as JSON:
```json
{
  "event": "error",
  "type": "self_heal_failed",
  "attempts": 3,
  "last_error": "TypeError: Cannot read property 'id' of undefined",
  "file": "src/routes/users.ts",
  "line": 47,
  "next_actions": ["manual_fix", "skip", "abort"]
}
```

## AskUserQuestion Rules by Environment

| Scenario | Terminal | Desktop | Remote | SDK |
|----------|----------|---------|--------|-----|
| Story checkpoint | 4 options | 3 options | Continue / Abort | JSON `next_actions` |
| Error / pause | 3 options | 2-3 options | Fix / Abort | JSON `next_actions` |
| Ship confirmation | 3 options | 2 options | Ship / Cancel | JSON `next_actions` |
| Config choice | 4 options | 3 options | Accept / Cancel | JSON `next_actions` |

In SDK mode, never call AskUserQuestion. Return `next_actions` in the JSON
output and let the caller handle the decision programmatically.

## Integration Point for Commands and Skills

Every command and skill that produces user-visible output MUST:

1. Detect the environment using the decision tree above (or read the
   `force_environment` config override).
2. Select the matching output profile from this skill.
3. Format output according to that profile before writing to stdout.

Reference this skill at the top of any command or skill that emits output:

```
References: universal-output (environment detection + format selection)
```

Skills that previously referenced only `output-format` should now reference
`universal-output`. The terminal profile of universal-output is identical to
`output-format`, so terminal behavior is unchanged.

### Layered skill chain

```
command or skill
  └─ universal-output        ← this skill (detect env, select profile)
       ├─ terminal profile   ← delegates to output-format skill (full)
       ├─ desktop profile    ← compact formatter (no box-drawing)
       ├─ remote profile     ← minimal formatter (binary options)
       └─ sdk profile        ← JSON formatter (no conversational text)
```

## Configuration

In `.maestro/config.yaml`:

```yaml
output:
  force_environment: ~          # null = auto-detect (default)
  # Options: terminal | desktop | remote | sdk
  sdk:
    pretty_print: false         # true = JSON.stringify with 2-space indent
    include_raw_text: false     # true = add "text" field alongside JSON
  remote:
    max_sentences: 3
    max_line_width: 40
    binary_options_only: true
  desktop:
    max_options: 3
    max_line_width: 60
```

## Environment Variable Reference

| Variable | Values | Effect |
|----------|--------|--------|
| `CLAUDE_SESSION_TYPE` | `terminal`, `desktop`, `remote`, `sdk` | Primary environment selector |
| `CLAUDE_REMOTE_SESSION` | `true` | Forces remote mode (legacy) |
| `CLAUDE_DISPATCH_SESSION` | `true` | Forces remote mode (legacy) |
| `CLAUDE_CLIENT_TYPE` | `mobile`, `cowork` | Forces remote mode (legacy) |

## Rules

1. Never detect environment more than once per command invocation — cache the
   result for the duration of the turn.
2. In SDK mode, never produce conversational prose. All output must be valid JSON.
3. In terminal mode, follow `output-format` exactly — do not diverge.
4. Never add environment labels (e.g., "[desktop mode]") to the output — the
   format itself should be transparent to the user.
5. AskUserQuestion is forbidden in SDK mode. Return `next_actions` instead.
6. When in doubt, default to terminal — it is the richest format and degrades
   gracefully if read as plain text.
