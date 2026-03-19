---
name: skill-loader
description: "Skill loading engine with declarative dependency gating and three-tier precedence resolution. Skills declare OS, binary, and env requirements in frontmatter. Higher-tier workspace skills shadow bundled skills."
---

# Skill Loader

Discovers, validates, and loads SKILL.md files at session start. Applies dependency gates so skills that lack required binaries, env vars, or OS support are skipped cleanly. Resolves name conflicts using a three-tier precedence hierarchy.

## Frontmatter-Based Dependency Gating

Skills can declare requirements in their YAML frontmatter. If any requirement is unmet at load time the skill is skipped and the reason is logged.

### Supported Gate Fields

```yaml
---
name: my-skill
description: "Does something"
requires_os: linux          # Only load on Linux (values: linux, darwin, win32)
requires_bins: [jq, curl]   # All must be available (checked via `command -v`)
requires_env: [MY_API_KEY]  # All env vars must be set and non-empty
---
```

All gate fields are optional. A skill with no `requires_*` fields loads unconditionally (backwards compatible with all existing skills).

### Gate Evaluation Order

At skill load time, evaluate gates in this order:

1. **OS gate** — If `requires_os` is set, compare against the current platform (`linux`, `darwin`, `win32`). If it does not match, skip the skill.
2. **Binary gate** — If `requires_bins` is set, run `command -v <bin>` for each entry. If any binary is missing, skip the skill.
3. **Env gate** — If `requires_env` is set, check that each named env var is set and non-empty. If any is missing or empty, skip the skill.

Stop at the first failing gate — do not evaluate subsequent gates for a skipped skill.

### Skip Logging

Append a line to `.maestro/logs/skill-loader.log` whenever a skill is skipped:

```
[2026-03-18T14:00:00Z] SKIP my-skill: requires_bins 'ffmpeg' not found
[2026-03-18T14:00:00Z] SKIP video-encoder: requires_os 'darwin' but current OS is 'linux'
[2026-03-18T14:00:00Z] SKIP cloud-deploy: requires_env 'AWS_ACCESS_KEY_ID' not set
```

Format: `[<ISO8601 timestamp>] SKIP <skill-name>: <gate-type> '<value>' <reason>`

Create `.maestro/logs/` if it does not exist.

### Examples

**Audio processing skill (macOS only, needs ffmpeg):**

```yaml
---
name: audio-encode
description: "Encode audio clips for the project"
requires_os: darwin
requires_bins: [ffmpeg, ffprobe]
---
```

**Cloud deployment skill (needs AWS credentials):**

```yaml
---
name: cloud-deploy
description: "Deploy to AWS"
requires_bins: [aws]
requires_env: [AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_DEFAULT_REGION]
---
```

**Plain skill (no gates, always loads):**

```yaml
---
name: git-craft
description: "Git workflow automation"
---
```

## Three-Tier Skill Precedence

When the same skill name appears in multiple locations, a clear precedence order determines which version wins.

### Precedence Tiers

| Priority | Tier | Location | Purpose |
|----------|------|----------|---------|
| 1 (highest) | Workspace | `./skills/` | Project-local skills, committed to the repo |
| 2 | Global | `~/.maestro/skills/` | User-wide skills shared across all projects |
| 3 (lowest) | Bundled | `plugins/maestro/skills/` | Shipped with Maestro, updated via plugin upgrades |

### Resolution Rules

- Skill identity is determined by the `name` field in the YAML frontmatter, not the directory name.
- When two skills share the same `name`, the skill from the higher-tier location wins. The lower-tier skill is not loaded.
- Workspace skills shadow global skills. Global skills shadow bundled skills.
- This enables per-project skill customization: copy a bundled skill into `./skills/`, modify it, and it will take effect for that project without touching the plugin.

### Shadow Logging

Append a line to `.maestro/logs/skill-loader.log` whenever a higher-tier skill shadows a lower-tier one:

```
[2026-03-18T14:00:00Z] SHADOW dev-loop: workspace ./skills/dev-loop/SKILL.md shadows bundled
[2026-03-18T14:00:00Z] SHADOW context-engine: global ~/.maestro/skills/context-engine/SKILL.md shadows bundled
```

Format: `[<ISO8601 timestamp>] SHADOW <skill-name>: <winning-tier> <winning-path> shadows <losing-tier>`

### Discovery Order

Scan skill directories in this order to build the candidate list:

1. `plugins/maestro/skills/*/SKILL.md` (bundled — lowest priority, processed first)
2. `~/.maestro/skills/*/SKILL.md` (global — overrides bundled)
3. `./skills/*/SKILL.md` (workspace — overrides both)

For each candidate:
- Parse the YAML frontmatter to extract `name`.
- If a skill with that `name` is already registered, log a SHADOW entry and skip the new candidate — keeping the higher-tier version that was registered later in the scan order.

Wait: the scan processes lower-priority tiers first, so each subsequent tier can replace the existing registration. Use a map keyed by `name`; later writes win (workspace > global > bundled).

### Practical Example

```
Candidate order (processed first to last, last write wins):
  1. plugins/maestro/skills/dev-loop/SKILL.md    name: dev-loop  (bundled)
  2. ~/.maestro/skills/dev-loop/SKILL.md          name: dev-loop  (global — shadows bundled)
  3. ./skills/dev-loop/SKILL.md                   name: dev-loop  (workspace — shadows global)

Result: ./skills/dev-loop/SKILL.md is loaded. Bundled and global versions are skipped.
Log:
  SHADOW dev-loop: global ~/.maestro/skills/dev-loop/SKILL.md shadows bundled
  SHADOW dev-loop: workspace ./skills/dev-loop/SKILL.md shadows global
```

## Load Sequence

At session start, the skill loader runs the following steps:

1. **Discover** — Scan all three tier directories, build candidate list (bundled → global → workspace).
2. **Resolve precedence** — Apply three-tier precedence, build the active skill map, log SHADOW events.
3. **Evaluate gates** — For each active skill, evaluate `requires_os`, `requires_bins`, `requires_env`. Remove skipped skills from the active map, log SKIP events.
4. **Report** — Log a summary line to `.maestro/logs/skill-loader.log`:
   ```
   [2026-03-18T14:00:01Z] LOADED 42 skills (3 skipped, 2 shadowed)
   ```

## Doctor Integration

`/maestro doctor` performs a skill gate audit as part of its diagnostic run. For each skill in the active skill map, re-evaluate its gates and report any that are unsatisfied.

### Doctor Output Section

```
  Skills:
    (ok) skill-loader      loaded (42 active, 3 skipped, 2 shadowed)
    (!)  audio-encode       SKIPPED — requires_bins 'ffmpeg' not found
    (!)  cloud-deploy       SKIPPED — requires_env 'AWS_ACCESS_KEY_ID' not set
    (!)  video-encoder      SKIPPED — requires_os 'darwin' (current: linux)
```

- `(ok)` — skill loaded successfully
- `(!)` — skill skipped; show the gate that failed and the missing value

The doctor section is titled **Skills** and appears after the **Hooks** section in the diagnostic output. Include a count line in the Summary:

```
  ---- Summary: 8 passed, 0 warnings, 3 skills skipped ----
```

### Doctor Recommendations

| Condition | Recommendation |
|-----------|----------------|
| Skill skipped due to missing binary | `brew install <bin>` or `apt install <bin>` based on OS |
| Skill skipped due to missing env var | Set `<VAR>` in your shell profile or `.env` |
| Skill skipped due to OS mismatch | Informational only — no action needed |

## Integration Points

- **Invoked by:** session start (dev-loop, auto-init)
- **Reads from:** `./skills/*/SKILL.md`, `~/.maestro/skills/*/SKILL.md`, `plugins/maestro/skills/*/SKILL.md`
- **Writes to:** `.maestro/logs/skill-loader.log` (append-only)
- **Used by:** `skill-watcher` (provides the initial snapshot), `/maestro doctor` (gate audit)
