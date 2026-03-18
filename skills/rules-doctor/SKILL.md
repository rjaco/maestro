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
Detection: file does not begin with `---`.
Severity: ERROR.

**S2 — Missing required frontmatter fields**
`name` and `description` are required in all frontmatter blocks.
Detection: frontmatter exists but `name:` or `description:` key is absent or empty.
Severity: ERROR.

**S3 — Placeholder frontmatter values**
Fields left as `null`, `TODO`, `""`, or template strings like `[description here]`.
Detection: value matches placeholder patterns after YAML parse.
Severity: WARN.

**S4 — Broken cross-references**
A file references a path (`skills/*/SKILL.md`, `agents/*.md`, `commands/*.md`) that does not exist on the filesystem.
Detection: extract file paths from body text, resolve relative to repo root, flag missing.
Severity: ERROR.

**S5 — Duplicate names**
Two or more files share the same `name` frontmatter value within the same category.
Detection: collect all `name:` values per category; flag duplicates.
Severity: ERROR.

**S6 — Skills listed in plugin.json but missing from filesystem**
If a `plugin.json` exists, every skill listed under `skills` must have a corresponding `SKILL.md`.
Detection: parse `plugin.json`, resolve each skill path, check existence.
Severity: ERROR.

### Category 2: Content Checks

**C1 — Dead tool references**
A skill references a tool name that does not exist in Claude Code (e.g., `CronCreate` or a misspelled tool).
Detection: scan for tool names in code blocks or bullet lists. Cross-reference against the known tool list: Read, Write, Edit, Bash, Glob, Grep, WebFetch, WebSearch, Skill, mcp__* prefixes.
Severity: WARN.

**C2 — TODO / FIXME markers**
Unfinished work left in skill files signals that the skill is not production-ready.
Detection: case-insensitive search for `TODO`, `FIXME`, `HACK`, `XXX` in file body.
Severity: WARN. Include the line number.

**C3 — Overly long skills**
Skills longer than 300 lines are likely trying to do too much and should be split.
Detection: count lines. Flag if line count > 300.
Severity: WARN. Include actual line count.

**C4 — Missing integration references**
Skills with no cross-references to other skills are islands that reduce composability.
Detection: skill body contains no `skill` keyword, no `skills/*/SKILL.md` paths, and no `## Integration` section.
Severity: INFO. Do not flag intentionally standalone utilities.

**C5 — Unreachable content after unconditional stop**
Content that follows a line containing `stop immediately`, `abort`, or `do nothing` with no conditional qualifier is likely unreachable.
Detection: simple line-by-line pattern match. Flag lines after a match if they contain non-trivial content (not blank lines or headers).
Severity: WARN.

### Category 3: Hook Checks

**H1 — Hook script missing from filesystem**
Every script path listed under any hook event in `hooks/hooks.json` must exist.
Detection: parse `hooks/hooks.json`, resolve each script path, check existence.
Severity: ERROR.

**H2 — Hook script not executable**
Hook scripts that exist but lack the executable bit will fail silently at runtime.
Detection: `test -x <path>` for each resolved script path.
Severity: WARN. Include the chmod command needed to fix.

**H3 — Hook script uses unavailable commands**
Hook scripts invoking tools not in the typical environment may fail on other machines.
Detection: scan for invocations of `jq`, `python`, `python3`, `node`, `ruby`, `perl`. Flag each not confirmed via `command -v`. Do not flag `bash`, `sh`, `echo`, `cat`, `grep`, `sed`, `awk`.
Severity: WARN.

### Category 4: Config Checks

**CF1 — References to undefined providers**
If `integrations.kanban.provider` or `integrations.knowledge_base.provider` is set to a value other than `null`, `asana`, `linear`, `atlassian`, `notion`, or `obsidian`, it is an unknown provider.
Detection: parse `.maestro/config.yml`, validate provider values against the allowed set.
Severity: ERROR.

**CF2 — Placeholder config values**
Config values that are still `null` for fields that require a concrete value to function (e.g., `webhook_url`, `bot_token`, `chat_id` when `enabled: true`).
Detection: for each section where `enabled: true`, check that dependent non-optional fields are not `null`.
Severity: WARN.

**CF3 — Conflicting configuration values**
Mutually exclusive config combinations that produce undefined behavior.
Detection patterns:
- `notifications.enabled: true` but all `triggers.*` are `false`
- `awareness.enabled: true` but `awareness.interval_minutes` is missing or zero
- `quality.max_qa_iterations` is 0 (no QA iterations means QA never runs)
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

Rules:
- Print the scanning header with counts before any findings.
- Print each finding on its own line, prefixed with severity icon.
- Sort findings: ERRORs first, then WARNs, then INFOs.
- Include the file path and a specific description for every finding.
- Include line numbers where applicable.
- Print the summary line last with exact counts.
- If no issues found: print `All clear — no issues detected.`

## Auto-Fix Mode

Run with `--fix` to attempt structural repairs. Never auto-fix content.

**What --fix repairs:**

| Check | Fix Applied |
|-------|-------------|
| S1 (missing frontmatter) | Prepend a minimal frontmatter block using the filename as `name` and a blank `description` |
| S3 (placeholder values) | Replace placeholder description with `"[needs description]"` and emit a WARN to fill it in |
| H2 (not executable) | Run `chmod +x <script>` for each affected hook script |

**What --fix never touches:**
- File body content (C1–C5)
- Cross-references (S4) — instead, suggest the closest match by edit distance and let the user decide
- Config values (CF1–CF3) — structural config errors require human judgment
- Duplicate names (S5) — renaming is a human decision

After applying fixes, re-run all checks and print the updated summary.

## Integration

**doctor/ command** — include rules-doctor after the standard diagnostics block. Print findings inline with the existing doctor output format. Promote any ERROR findings to the Recommendations section.

**awareness/SKILL.md** — in the heartbeat schedule, add a rules-doctor scan as check 6 (after the existing tech debt scan). Flag: any new ERROR findings since the last scan. Do not re-report stable findings that were already known.

**retrospective/SKILL.md** — treat ERROR findings from rules-doctor as a friction signal of type SKILL_SUPPLEMENT. Each broken cross-reference or dead rule reduces composability and should be surfaced as an improvement candidate.

**init/ command** — after Step 4 (Build) completes and before Step 5 (Summary), run rules-doctor on the newly created files. If any ERRORs are found, show them inside the init summary box under a `Warnings:` heading. Do not block init completion.
