---
name: preferences
description: "Global developer preferences profile. Loads ~/.claude/maestro-preferences.md and injects it into agent context as a high-priority constraint. Developer intent always beats project convention."
---

# Developer Preferences

Manages the developer's global preferences file (`~/.claude/maestro-preferences.md`) and injects
its contents into every implementer agent context package as a high-priority constraint.

Preferences are cross-project: they live outside any repository and apply to every project Maestro
runs on this machine. When a preference conflicts with `.maestro/dna.md`, the preference wins —
developer intent beats detected project convention.

## Preferences File

**Location:** `~/.claude/maestro-preferences.md`

**Template:** `templates/preferences.md` (in the Maestro plugin directory)

**Structure:**

```yaml
---
name: "Developer Preferences"
created: "YYYY-MM-DD"
last_updated: "YYYY-MM-DD"
---

## Tech Stack Preferences
- Framework: Next.js (App Router)
- Language: TypeScript (strict mode)
- Styling: Tailwind CSS + shadcn/ui
- Database: Supabase (PostgreSQL)
- Testing: Vitest
- Package manager: npm

## Coding Patterns
- Named exports only (no default exports)
- Server Components by default, 'use client' only when needed
- Zod for all validation
- Error handling: explicit try/catch, no silent failures

## Anti-Patterns (Never Do)
- No class components
- No CSS modules
- No any types
- No console.log in production code

## Conventions
- File naming: kebab-case
- Component naming: PascalCase
- Import aliases: @/ for src/
- Commit style: conventional commits
```

---

## Operations

### load()

Read the preferences file and return its contents as a structured block.

1. Check if `~/.claude/maestro-preferences.md` exists.
2. If it does not exist, return `null` — do not create or default silently.
3. If it exists, read the full file and return its contents.

### exists()

Return `true` if `~/.claude/maestro-preferences.md` exists, `false` otherwise.

### build_context()

Format the preferences file contents as a context block suitable for injection into agent prompts.

```
[Developer Preferences]
Priority: HIGH — these preferences override project conventions.

## Tech Stack Preferences
- Framework: Next.js (App Router)
- Language: TypeScript (strict mode)
- Styling: Tailwind CSS + shadcn/ui
- Database: Supabase (PostgreSQL)
- Testing: Vitest
- Package manager: npm

## Coding Patterns
- Named exports only (no default exports)
- Server Components by default, 'use client' only when needed
- Zod for all validation
- Error handling: explicit try/catch, no silent failures

## Anti-Patterns (Never Do)
- No class components
- No CSS modules
- No any types
- No console.log in production code

## Conventions
- File naming: kebab-case
- Component naming: PascalCase
- Import aliases: @/ for src/
- Commit style: conventional commits

[End Developer Preferences]
```

The `Priority: HIGH` header signals to every agent that these rules are non-negotiable and should
be treated identically to `NEVER` / `ALWAYS` rules in CLAUDE.md.

### create_from_template()

Create `~/.claude/maestro-preferences.md` from `templates/preferences.md`.

1. Read `templates/preferences.md` from the Maestro plugin directory.
2. Fill in `created` and `last_updated` with today's date.
3. Write to `~/.claude/maestro-preferences.md`.

### update_field(key, value)

Update a single field in the preferences file using dot-notation keys.

Map dot-notation keys to markdown sections:

| Key prefix | Section heading |
|------------|----------------|
| `stack.*` | `## Tech Stack Preferences` |
| `patterns.*` | `## Coding Patterns` |
| `anti_patterns.*` | `## Anti-Patterns (Never Do)` |
| `conventions.*` | `## Conventions` |

Edit the matching line within the section. Update the `last_updated` frontmatter field to today's date.

---

## Context Engine Integration

The preferences skill is invoked by the Context Engine during Step 3 (Relevance Filter) of context
package composition.

### Relevance Score

Developer preferences are scored at **0.9** for all `implementer` and `qa-reviewer` agent roles,
regardless of story type or file paths. This ensures they are always included within T3 context
packages.

| Agent Role | Relevance Score | Include Threshold |
|------------|----------------|------------------|
| `implementer` | 0.9 | Always included (threshold: 0.5) |
| `qa-reviewer` | 0.9 | Always included (threshold: 0.5) |
| `architect` | 0.7 | Included when budget allows |
| `self-heal` | 0.8 | Included (threshold: 0.7, so included) |
| `orchestrator` | 0.5 | Included as low-priority context |
| `strategist` | 0.2 | Excluded from strategic packages |

### Conflict Resolution

When a preference contradicts project DNA (`.maestro/dna.md`):

1. The preferences block is placed **before** the DNA patterns block in the context package.
2. The `Priority: HIGH` header signals precedence.
3. When a conflict is detected at compose time, add an explicit note:

```
[Preferences vs. Project DNA conflict detected]
  Preference: "Named exports only"
  Project DNA: "Mixed exports detected"
  Resolution: Follow preference — use named exports.
```

### Injection Position

In the context package assembly order, preferences are injected after task instructions but
before CLAUDE.md constraints:

1. Task instructions (story spec, acceptance criteria) — always first
2. **Developer Preferences** — injected here at relevance 0.9
3. CLAUDE.md constraints (project-level rules)
4. Code patterns from DNA
5. File contents
6. Interfaces and type definitions
7. QA history

This ordering ensures agents see developer preferences before project conventions, establishing
the correct override hierarchy.

### Token Budget

The preferences block typically consumes 150-300 tokens. This is reserved from the T3 implementer
budget (4-8K) before other context pieces are scored.

If the preferences file exceeds 500 tokens (unusually long), trim to the most specific sections:
Anti-Patterns first, then Coding Patterns, then Tech Stack, then Conventions. Never trim
Anti-Patterns — they represent the highest-risk constraints.

---

## Integration Points

- **Invoked by:** `context-engine` skill (Step 3, Relevance Filter, all agent dispatches)
- **Reads:** `~/.claude/maestro-preferences.md`
- **Written by:** `/maestro preferences` command only — agents never write to this file
- **Conflicts with:** `.maestro/dna.md` — preferences win when they conflict
- **Token cost:** 150-300 tokens per agent invocation (reserved from T3 budget)
