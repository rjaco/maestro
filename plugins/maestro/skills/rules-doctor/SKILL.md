---
name: rules-doctor
description: "Lint CLAUDE.md files, skill definitions, agent configs, and hooks for dead rules, broken references, and misconfigurations. Supports --fix for structural auto-repair."
---

# Rules Doctor — Maestro Configuration Linter

Scans all Maestro configuration files for dead rules, broken references, unfinished work, and misconfigurations. Inspired by the `claude-rules-doctor` community tool. Run standalone or as part of the health check pipeline.

## What Gets Scanned

| Target | Path Pattern | Description |
|--------|-------------|-------------|
| Project instructions | `CLAUDE.md`, `.claude/CLAUDE.md` | Top-level project rules |
| Skill definitions | `skills/*/SKILL.md` | All registered skills |
| Agent definitions | `agents/*.md` | Orchestrator agent specs |
| Profile definitions | `profiles/*.md` | Specialist role templates |
| Command definitions | `commands/*.md` | Slash command handlers |
| Hook configuration | `hooks/hooks.json` | Stop/pre/post hooks |
| Maestro config | `.maestro/config.yml` | Project-level config |

Count files found in each category before scanning. Report the tally in the opening line.

## Lint Checks

### Category 1: Structural Checks

**S1 — Missing YAML frontmatter**
Skills, agents, profiles, and commands must have a YAML frontmatter block as the first content.
Detection: file does not begin with `---`. Severity: ERROR.

**S2 — Missing required frontmatter fields**
`name` and `description` are required in all frontmatter blocks.
Detection: frontmatter exists but `name:` or `description:` key is absent or empty. Severity: ERROR.

**S3 — Placeholder frontmatter values**
Fields left as `null`, `TODO`, `""`, or template strings like `[description here]`.
Detection: value matches placeholder patterns after YAML parse. Severity: WARN.

**S4 — Broken cross-references**
A file references a path (`skills/*/SKILL.md`, `agents/*.md`, `commands/*.md`) that does not exist on the filesystem.
Detection: extract file paths from body text, resolve relative to repo root, flag missing. Severity: ERROR.

**S5 — Duplicate names**
Two or more files share the same `name` frontmatter value within the same category.
Detection: collect all `name:` values per category; flag duplicates. Severity: ERROR.

**S6 — Skills listed in plugin.json but missing from filesystem**
Every skill listed under `skills` in `plugin.json` must have a corresponding `SKILL.md`.
Detection: parse `plugin.json`, resolve each skill path, check existence. Severity: ERROR.

### Category 2: Content Checks

**C1 — Dead tool references**
A skill references a tool name that does not exist in Claude Code (e.g., `CronCreate` or a misspelled tool).
Detection: scan for tool names in code blocks and bullet lists; cross-reference against Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch, Skill, mcp__* prefixes. Severity: WARN.

**C2 — TODO / FIXME markers**
Unfinished work signals the skill is not production-ready.
Detection: case-insensitive search for `TODO`, `FIXME`, `HACK`, `XXX`. Severity: WARN. Include line number.

**C3 — Overly long skills**
Skills longer than 300 lines likely need splitting.
Detection: flag if line count > 300. Severity: WARN. Include actual line count.

**C4 — Missing integration references**
Skills with no cross-references to other skills are islands that reduce composability.
Detection: skill body contains no `skill` keyword, no `skills/*/SKILL.md` paths, and no `## Integration` section. Severity: INFO. Do not flag intentionally standalone utilities.

**C5 — Unreachable content after unconditional stop**
Non-trivial content following `stop immediately`, `abort`, or `do nothing` (with no conditional qualifier) is unreachable.
Detection: line-by-line pattern match; flag non-blank, non-header lines after a match. Severity: WARN.

### Category 3: Hook Checks

**H1 — Hook script missing from filesystem**
Every script path listed in `hooks/hooks.json` must exist.
Detection: parse JSON, resolve each script path, check existence. Severity: ERROR.

**H2 — Hook script not executable**
Scripts that exist but lack the executable bit will fail silently at runtime.
Detection: `test -x <path>` for each script. Severity: WARN. Include the `chmod +x` command needed.

**H3 — Hook script uses unavailable commands**
Scripts invoking tools not in the typical environment may fail on other machines.
Detection: scan for `jq`, `python`, `python3`, `node`, `ruby`, `perl`; flag each not confirmed via `command -v`. Do not flag `bash`, `sh`, `echo`, `cat`, `grep`, `sed`, `awk`. Severity: WARN.

### Category 4: Config Checks

**CF1 — References to undefined providers**
`integrations.kanban.provider` and `integrations.knowledge_base.provider` must be one of: `null`, `asana`, `linear`, `atlassian`, `notion`, `obsidian`.
Detection: parse `.maestro/config.yml`, validate against the allowed set. Severity: ERROR.

**CF2 — Placeholder config values**
Required fields (`webhook_url`, `bot_token`, `chat_id`) left as `null` when the parent section has `enabled: true`.
Detection: for each `enabled: true` section, flag non-optional `null` fields. Severity: WARN.

**CF3 — Conflicting configuration values**
Mutually exclusive combinations that produce undefined behavior:
- `notifications.enabled: true` but all `triggers.*` are `false`
- `awareness.enabled: true` but `awareness.interval_minutes` is missing or zero
- `quality.max_qa_iterations` is 0
Severity: WARN.

## Output Format

```
Rules Doctor — Maestro Configuration Linter

Scanning 66 skills, 6 agents, 19 commands, 4 hooks...

❌ ERROR: skills/auth/SKILL.md references 'skills/oauth/SKILL.md' but it doesn't exist
⚠️ WARN:  skills/visualize/SKILL.md is 342 lines (consider splitting)
⚠️ WARN:  agents/fixer.md has TODO on line 15
❌ ERROR: hooks/hooks.json references 'hooks/missing.sh' but file not found
ℹ️ INFO:  profiles/designer.md has no integration references

Summary: 2 errors, 2 warnings, 1 info
```

Sort findings ERRORs first, then WARNs, then INFOs. Include file path and line number where applicable. If no issues found, print `All clear — no issues detected.`

## Auto-Fix Mode

Run with `--fix` to attempt structural repairs. Never auto-fix content.

| Check | Fix Applied |
|-------|-------------|
| S1 (missing frontmatter) | Prepend minimal frontmatter using the filename as `name` and an empty `description` |
| S3 (placeholder values) | Replace placeholder with `"[needs description]"` and emit a WARN |
| H2 (not executable) | Run `chmod +x <script>` for each affected hook script |

What `--fix` never touches: file body content (C1-C5), cross-references (S4 — suggest closest match by edit distance instead), config values (CF1-CF3), duplicate names (S5). After applying fixes, re-run all checks and print the updated summary.

## Integration

**doctor/ command** — run rules-doctor after the standard diagnostics block. Print findings inline with the existing doctor output format. Promote ERROR findings to the Recommendations section.

**awareness/SKILL.md** — add a rules-doctor scan as heartbeat check 6 (after the tech debt scan). Flag only new ERROR findings since the last scan; do not re-report stable known issues.

**retrospective/SKILL.md** — treat rules-doctor ERROR findings as a SKILL_SUPPLEMENT friction signal. Each broken cross-reference or dead rule reduces composability and should be surfaced as an improvement candidate.

**init/ command** — after Step 4 (Build) and before Step 5 (Summary), run rules-doctor on the newly created files. Show any ERRORs inside the init summary box under a `Warnings:` heading. Do not block init completion.
