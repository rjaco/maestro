---
name: auto-docs
description: "Auto-generate documentation from code changes. Creates/updates README sections, API docs, and changelog entries after each story."
---

# Auto-Docs

Automatically generate and update documentation based on code changes. After each story completes in the dev-loop, auto-docs analyzes what changed and produces the appropriate documentation artifacts: CHANGELOG entries, README updates, API documentation, and inline code comments.

## When to Use

- **After dev-loop Phase 6 (GIT CRAFT):** Automatically invoked to generate docs for the completed story
- **Before ship skill:** Generate a cumulative documentation update for the entire feature
- **Manual invocation:** `/maestro auto-docs` to regenerate docs from recent changes
- **On demand:** `/maestro auto-docs changelog` or `/maestro auto-docs readme` for specific doc types

## Detection: What Docs to Generate

Analyze the files changed by the story to determine which documentation types are relevant:

### File Type Analysis

| Files Changed | Docs to Generate |
|--------------|------------------|
| `src/**/*.ts`, `src/**/*.js` | CHANGELOG, possibly README |
| `src/app/api/**`, `src/routes/**` | CHANGELOG, API docs |
| `src/components/**`, `src/pages/**` | CHANGELOG, possibly README (if new pages) |
| `*.config.*`, `package.json` | CHANGELOG (config section) |
| `README.md` | Skip README generation (user-maintained) |
| CLI commands, new subcommands | CHANGELOG, README (usage section) |
| New dependencies added | CHANGELOG (dependencies section) |

### Feature Detection

Determine if a story introduced:

1. **New user-facing feature** — New route, component, CLI command, API endpoint
2. **Modified behavior** — Changed existing functionality
3. **Bug fix** — Fixed broken behavior
4. **Internal refactor** — No user-visible change
5. **New dependency** — Added a package or service
6. **Configuration change** — New config options or env vars

Map to documentation priority:

```
New feature       → CHANGELOG (Added) + README update
Modified behavior → CHANGELOG (Changed)
Bug fix           → CHANGELOG (Fixed)
Internal refactor → CHANGELOG (Changed) — brief, if at all
New dependency    → CHANGELOG (Added) — note the dependency
Config change     → CHANGELOG (Changed) + README (config section)
```

## 1. CHANGELOG Generation

### Format: Keep a Changelog

Follow the [Keep a Changelog](https://keepachangelog.com/) format:

```markdown
## [Unreleased]

### Added
- New dashboard page with budget tracking widgets (`/dashboard`)
- Price comparison API endpoint (`GET /api/compare`)
- CSV export for transaction history

### Changed
- Updated navigation to include dashboard link
- Improved error messages for invalid API requests

### Fixed
- Currency formatting now handles zero-decimal currencies correctly

### Dependencies
- Added `recharts@2.12.0` for dashboard charts
- Upgraded `next` from 14.1.0 to 14.2.0
```

### Generation Rules

1. Read the story spec (acceptance criteria, description) for context
2. Read the git diff for the story's commit
3. For each changed file, classify the change (added, changed, fixed)
4. Write human-readable descriptions (not file names or technical diffs)
5. Group entries under the correct section header
6. Use present tense, active voice: "Add dashboard" not "Added dashboard" or "Adds dashboard"

### Conflict Handling

If `CHANGELOG.md` already has an `[Unreleased]` section:
- Append new entries under the existing section headers
- Do not duplicate existing entries
- Preserve existing entries written by humans

If `CHANGELOG.md` does not exist:
- Do NOT create one unless the user explicitly requests it
- Log a note: "No CHANGELOG.md found — skipping changelog generation"

### Per-Story vs. Per-Feature

| Context | Behavior |
|---------|----------|
| dev-loop (per story) | Accumulate entries in memory, do not write yet |
| ship (per feature) | Write all accumulated entries to CHANGELOG.md |
| Manual invocation | Write immediately |

This prevents noisy intermediate changelog entries for individual stories that are part of a larger feature.

## 2. README Updates

### Section Detection

Scan the existing README.md for sections that may need updating:

| README Section | Update Trigger |
|---------------|----------------|
| `## Features` or `## What it does` | New user-facing feature added |
| `## Installation` | New dependency or setup step required |
| `## Usage` or `## Getting Started` | New command, route, or API endpoint |
| `## Configuration` or `## Environment Variables` | New config option or env var |
| `## API` or `## Endpoints` | New API route added |
| `## Commands` or `## CLI` | New CLI command or subcommand |
| `## Architecture` | Significant structural change |

### Update Strategy

1. Read the current README.md
2. Identify the section that needs updating
3. Generate the new content for that section
4. Present the proposed change to the user via AskUserQuestion:

- Question: "Auto-docs wants to update the README. Review the proposed change?"
- Header: "Auto-Docs"
- Options:
  - "Apply update" — Write the change
  - "Show diff" — Display the proposed diff before applying
  - "Skip" — Do not update README

### README Guard Rails

- Never overwrite the entire README — only update specific sections
- Never remove existing content — only add or modify
- If a section does not exist, suggest adding it but do not auto-create
- Preserve all formatting, badges, images, and links in untouched sections
- Maximum addition per story: 10 lines (prevent bloat)

## 3. API Documentation

### When to Generate

Generate API docs when the story creates or modifies:
- REST endpoints (`src/app/api/**`, `src/routes/**`, `routes/**`)
- GraphQL resolvers or schema definitions
- RPC handlers or WebSocket events
- CLI commands with arguments and options

### API Doc Format

For each new or modified endpoint:

```markdown
### `GET /api/compare`

Compare prices across multiple vehicles.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| `ids` | string | Yes | Comma-separated vehicle IDs |
| `currency` | string | No | ISO currency code (default: USD) |

**Response:**

```json
{
  "vehicles": [
    {
      "id": "abc123",
      "name": "Model Y",
      "price": 44990,
      "currency": "USD"
    }
  ],
  "compared_at": "2026-03-18T10:00:00Z"
}
```

**Status Codes:**

| Code | Description |
|------|-------------|
| 200 | Success |
| 400 | Invalid vehicle IDs |
| 404 | Vehicle not found |
```

### API Doc Location

| Project Type | Doc Location |
|-------------|-------------|
| Next.js / Express | `docs/api.md` or README API section |
| CLI tool | README Commands section |
| Library | README API section or `docs/api.md` |

If no existing API docs location is found, accumulate in memory and include in the ship PR description.

## 4. Inline Code Comments

### When to Generate

Add inline comments for:
- Functions with cyclomatic complexity > 5
- Non-obvious algorithms or business logic
- Workarounds with external references (GitHub issues, Stack Overflow)
- Configuration values that need explanation
- Regular expressions

### Comment Style

Follow the project's existing comment conventions (detected from DNA):

```typescript
/**
 * Calculate the discounted price applying tiered volume discounts.
 *
 * Discount tiers:
 *   1-9 units:   0% discount
 *   10-49 units: 5% discount
 *   50+ units:   12% discount
 *
 * Prices are rounded to 2 decimal places using banker's rounding
 * to avoid systematic bias in financial calculations.
 */
function calculateDiscountedPrice(unitPrice: number, quantity: number): number {
```

### Comment Guard Rails

- Never add comments to self-explanatory code (`// increment counter` on `i++`)
- Never add comments that restate the function name
- Only add comments when the code's intent is non-obvious
- Match the project's existing comment density (some projects prefer minimal comments)
- Default: inline comments are **disabled** (opt-in via config)

## Integration: Dev-Loop (Phase 6)

After the GIT CRAFT phase commits the story's changes:

1. Read the committed diff: `git diff HEAD~1`
2. Classify the changes (feature, fix, refactor, etc.)
3. Generate CHANGELOG entries (accumulate in `.maestro/state.local.md`)
4. Check if README needs updating
5. If API endpoints changed, generate API doc fragments
6. If inline comments enabled, scan for complex functions

**Do not write docs during dev-loop** — accumulate them. The ship skill writes them all at once to avoid noisy intermediate commits.

### Accumulated State

Store pending doc updates in `.maestro/state.local.md`:

```yaml
auto_docs:
  pending_changelog:
    added:
      - "Dashboard page with budget tracking widgets (`/dashboard`)"
      - "Price comparison API endpoint (`GET /api/compare`)"
    changed:
      - "Navigation updated to include dashboard link"
    fixed:
      - "Currency formatting for zero-decimal currencies"
  pending_readme_sections:
    - section: "## Features"
      action: "append"
      content: "- **Dashboard**: Real-time budget tracking with charts"
  pending_api_docs:
    - endpoint: "GET /api/compare"
      method: "GET"
      description: "Compare prices across vehicles"
```

## Integration: Ship Skill

Before the ship skill creates the PR:

1. Read accumulated doc updates from `.maestro/state.local.md`
2. Write CHANGELOG entries to `CHANGELOG.md` (if it exists)
3. Apply README section updates (with user confirmation)
4. Write API docs (if applicable)
5. Commit the doc updates as a separate commit:
   ```
   docs: auto-generate documentation for [feature name]
   ```
6. Clear the accumulated state

### Ship PR Description

Include a "Documentation" section in the PR description:

```markdown
## Documentation

- CHANGELOG: [N] entries added (Added: [N], Changed: [N], Fixed: [N])
- README: Updated [section names]
- API docs: [N] endpoints documented
```

## Manual Invocation

### `/maestro auto-docs`

Generate docs from all uncommitted or recent changes:

```bash
# Analyze changes since last tag or last 10 commits
git diff HEAD~10 --name-only
```

Show what would be generated:

```
┌─────────────────────────────────────────────────────────────┐
│  Auto-Docs Analysis                                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Changes analyzed: 14 files across 5 commits                │
│                                                             │
│  CHANGELOG entries:                                         │
│    Added:   3 entries                                       │
│    Changed: 1 entry                                         │
│    Fixed:   2 entries                                       │
│                                                             │
│  README updates:                                            │
│    ## Features — 1 new bullet                               │
│    ## API      — 2 new endpoints                            │
│                                                             │
│  API docs:                                                  │
│    GET /api/compare    (new)                                 │
│    POST /api/export    (new)                                 │
│                                                             │
│  Inline comments:                                           │
│    Disabled (enable in config)                               │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

Then ask via AskUserQuestion:
- Question: "Auto-docs found documentation updates to generate. Apply them?"
- Header: "Auto-Docs"
- Options:
  - "Apply all" — Write all doc updates
  - "Review each" — Show diffs one by one for approval
  - "Skip" — Do not generate docs

### `/maestro auto-docs changelog`

Generate only CHANGELOG entries.

### `/maestro auto-docs readme`

Generate only README updates.

### `/maestro auto-docs api`

Generate only API documentation.

## Configuration

In `.maestro/config.yaml`:

```yaml
auto_docs:
  enabled: true
  changelog: true           # Generate CHANGELOG entries
  readme: true              # Update README sections
  api_docs: false            # Generate API documentation
  inline_comments: false     # Add inline code comments
  write_on_story: false      # Write docs per story (default: accumulate)
  write_on_ship: true        # Write docs when shipping (default: true)
  changelog_format: keepachangelog   # keepachangelog | conventional
  readme_max_lines: 10       # Max lines added per story
  api_doc_location: auto     # auto | docs/api.md | README
  confirm_readme: true       # Ask before updating README
  confirm_changelog: false   # Ask before updating CHANGELOG
```

## Output Contract

```yaml
output_contract:
  changelog_entry:
    format: keepachangelog
    sections: [Added, Changed, Fixed, Deprecated, Removed, Security, Dependencies]
    required_fields: [section, description]
  readme_update:
    required_fields: [section, action, content]
    actions: [append, replace, insert_after]
  api_doc:
    required_fields: [endpoint, method, description]
    optional_fields: [parameters, response, status_codes]
  inline_comment:
    required_fields: [file, line, comment]
    style: project_convention
```

## Error Handling

| Situation | Action |
|-----------|--------|
| No CHANGELOG.md exists | Skip changelog, log note |
| No README.md exists | Skip readme updates, log note |
| README section not found | Suggest creating section, do not auto-create |
| Changelog conflict (concurrent edits) | Show conflict, ask user to resolve |
| API doc location ambiguous | Ask user via AskUserQuestion |
| Inline comments disabled | Skip silently |
| No changes detected | Report "nothing to document" |
| Story type is `knowledge_work` | Skip code analysis, document the output artifacts instead |

## Subcommand Patterns

| Command | Description |
|---------|-------------|
| `/maestro auto-docs` | Analyze and generate all applicable docs |
| `/maestro auto-docs changelog` | Generate CHANGELOG entries only |
| `/maestro auto-docs readme` | Generate README updates only |
| `/maestro auto-docs api` | Generate API documentation only |
| `/maestro auto-docs status` | Show pending accumulated doc updates |
| `/maestro auto-docs clear` | Clear accumulated doc updates |
| `/maestro auto-docs config` | Show current auto-docs configuration |
