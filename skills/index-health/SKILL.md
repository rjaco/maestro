---
name: index-health
description: "Validate and self-heal all Maestro indexes and cached state. Runs before any skill reads indexed state, on session start, and after git operations."
---

# Index Health

Validates all Maestro indexes and cached state before use, then performs targeted self-healing to repair or regenerate only what is stale or broken. Prevents stale-index bugs where agents read outdated DNA, broken repo maps, or corrupted state.

## Indexed State

Seven files and directories constitute Maestro's indexed state:

| Index | Path | Purpose |
|-------|------|---------|
| DNA | `.maestro/dna.md` | Tech stack, patterns, architecture layers, conventions |
| Repo Map | `.maestro/repo-map.md` | Function and class mapping across the codebase |
| Session State | `.maestro/state.local.md` | Active story, progress counters, current session context |
| Semantic Memory | `.maestro/memory/semantic.md` | Long-term project knowledge with confidence scores |
| Episodic Memory | `.maestro/memory/episodic.md` | Session-scoped event log and short-term context |
| Feature Registry | `.maestro/registry.json` | Shipped feature catalog with status and ownership |
| Stories | `.maestro/stories/` | Story files (scope, criteria, status) |

## Validation Checks

### DNA Validation

1. Read the `**Generated:**` timestamp from `.maestro/dna.md`.
2. Check `git log --since="<timestamp>" -- package.json requirements.txt pyproject.toml Cargo.toml go.mod` — if any manifest was modified after generation, flag **stale**.
3. For each file listed under `## Architecture Layers`, verify it still exists on disk. Missing files are **broken references**.
4. Run `git ls-files --others --directory --exclude-standard` to find new untracked top-level directories. If any aren't mentioned in the DNA, flag **incomplete**.

### Repo Map Validation

1. Read the `**Generated:**` timestamp from `.maestro/repo-map.md`.
2. Run `git diff --name-only HEAD` and `git status --short` to collect changed files since last map generation.
3. Calculate: `changed_files / total_mapped_files`. If ratio exceeds **0.20** (20%), flag **stale**.
4. For each file explicitly listed in the repo map, verify it exists. Missing → **broken reference**.

### State Validation

1. Read `current_story` and `total_stories` from `.maestro/state.local.md`. If `current_story > total_stories`, flag **impossible state**.
2. For the active story path listed in state, verify the file exists under `.maestro/stories/`. Missing → **broken reference**.
3. Check for contradictory status flags:
   - `status: completed` AND `status: active` on the same story → **contradictory state**
   - `progress: 100%` AND `status: blocked` → **contradictory state**

### Semantic Memory Validation

1. Parse each entry in `.maestro/memory/semantic.md` for its `confidence:` field.
2. Entries with `confidence < 0.2` → flag for **archival**.
3. Compare entries with overlapping keywords for direct contradiction (e.g., "always use X" and "never use X"). Flag contradicting pairs.
4. Check `last_reinforced:` date for each entry. Entries older than **30 days** without reinforcement → flag **stale**.

### Episodic Memory Validation

1. Verify the episodic log is append-only (no entries edited mid-session).
2. Flag entries referencing story files that no longer exist as **broken references**.

### Feature Registry Validation

1. Parse `.maestro/registry.json`. Verify it is valid JSON.
2. For each entry with a `"file":` field, verify the file exists. Missing → **broken reference**.
3. Check for duplicate `"id"` fields → flag **duplicate entries**.

### Stories Validation

1. List all files under `.maestro/stories/`.
2. Verify each file has required frontmatter: `title`, `status`, `acceptance_criteria`.
3. Cross-reference: any story referenced in `state.local.md` must exist in `.maestro/stories/`.

## Self-Healing Actions

### Partial Re-index

Triggered when: DNA or Repo Map flagged **stale**.

Action: Do not regenerate the entire index. Instead:
- For DNA: re-run only the sections whose source files changed (e.g., re-detect tech stack if `package.json` changed; skip architecture layer scan if directory structure is unchanged).
- For Repo Map: scan only the changed files identified in the git diff. Merge updated entries into the existing map. Update the `**Generated:**` timestamp.

### Reference Repair

Triggered when: any index has **broken references**.

Action:
- Remove the entry pointing to the deleted file from the index.
- Append a repair note at the bottom of the index file:
  ```
  <!-- repaired: removed reference to src/deleted-file.ts on 2026-03-18 -->
  ```
- Do not attempt to re-create deleted files.

### State Correction

Triggered when: **impossible state** or **contradictory state** detected.

Action:
- `current_story > total_stories` → set `current_story = total_stories`.
- `completed + active` contradiction → set `status: completed`, clear `active` flag.
- `progress: 100% + blocked` contradiction → set `status: completed`, remove `blocked`.
- Log each correction in `.maestro/logs/state-corrections.md`.

### Memory Cleanup

Triggered when: semantic memory entries are below confidence threshold or stale.

Action:
- Move entries with `confidence < 0.2` from `semantic.md` to `.maestro/memory/archive.md` with an `archived_on:` timestamp.
- Flag contradicting pairs in-place with a `# CONFLICT:` comment for human review — do not auto-resolve contradictions.
- Entries older than 30 days without reinforcement are archived (same target file).

## Validation Triggers

| Trigger | Scope |
|---------|-------|
| Session start | Full check across all 7 indexes |
| Pre-read hook (before any skill reads indexed state) | Check only the index(es) that skill will consume |
| Post-git-operation (pull, merge, rebase) | DNA + Repo Map (manifests and file list may have changed) |
| User request (`/maestro index-health`) | Full check, verbose output |

For pre-read hooks, each consuming skill declares which indexes it reads. The health check is scoped to only those indexes to avoid unnecessary overhead.

## Output Format

```
Index Health Check:
  dna.md          valid (2 hours old)
  repo-map.md     stale (15% files changed) -> partial re-index
  state.local.md  valid
  semantic.md     3 entries below threshold -> archived
  episodic.md     valid
  registry.json   valid
  stories/        valid (12 files)

Actions taken:
  repo-map.md     Re-indexed 8 changed files (38 total mapped)
  semantic.md     Archived 3 entries to memory/archive.md
  No broken references found.
```

If all indexes are valid, output is a single line:

```
Index Health Check: all valid. No action taken.
```

## Integration Points

- **`project-dna/SKILL.md`**: Validate `dna.md` before reading. If stale, run partial re-index first, then proceed.
- **`context-engine/SKILL.md`**: Validate `dna.md`, `state.local.md`, and `stories/` before composing any context package.
- **`living-docs/SKILL.md`**: Validate `repo-map.md` and `registry.json` before updating documentation.
- **`health-score/SKILL.md`**: Include index health as a sixth dimension in the health score. All indexes valid = 20 pts; one stale = 14 pts; one broken = 8 pts; multiple broken = 0 pts.

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/logs/index-health.md"
  required_sections:
    - "## Index Health Check"
  required_frontmatter:
    checked_at: datetime
    indexes_valid: integer
    indexes_stale: integer
    indexes_broken: integer
    actions_taken: list
```
