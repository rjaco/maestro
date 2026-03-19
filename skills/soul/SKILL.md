---
name: soul
description: "Persistent developer identity and SOUL state management. Stores identity, learned patterns, and preferences with optional cross-project portability via CLAUDE_PLUGIN_DATA."
---

# Maestro SOUL

Maestro's SOUL system gives the assistant a persistent developer identity that travels with the developer across sessions. It stores who you are as a developer, how you like to work, and what patterns you've established — so every session starts with full context about your preferences.

## What SOUL Stores

### Identity (`SOUL.md`)

Core developer identity: role, expertise, communication style, values, and the working relationship between you and Maestro.

```markdown
# Developer SOUL

## Identity
- Role: [your role]
- Expertise: [primary domains]
- Style: [how you like to work]

## Values
- [what matters to you in software]

## Working Agreement
- [how Maestro should behave with you specifically]
```

### Learned Patterns (`memory/`)

Patterns Maestro has inferred from your behavior over time. Feeds into the memory skill's semantic memory.

### Developer Preferences (`preferences.md`)

Explicit preferences that apply across all projects:
- Preferred languages and frameworks
- Code style rules
- Communication preferences (verbose vs terse, etc.)
- Default execution mode preference

## Portable Identity (CLAUDE_PLUGIN_DATA)

When the `CLAUDE_PLUGIN_DATA` environment variable is set (Claude Code v2.1.78+),
Maestro can store SOUL files in this directory for cross-project portability:

- `${CLAUDE_PLUGIN_DATA}/SOUL.md` — persistent identity
- `${CLAUDE_PLUGIN_DATA}/memory/` — learned patterns
- `${CLAUDE_PLUGIN_DATA}/preferences.md` — developer preferences

### Resolution Order
1. Project-local: `.maestro/SOUL.md` (highest priority — project-specific overrides)
2. Plugin data: `${CLAUDE_PLUGIN_DATA}/SOUL.md` (portable identity)
3. Default template: `templates/soul-profiles/casual.md` (fallback)

This mirrors OpenClaw's `~/.openclaw/workspace/` pattern — your developer
identity travels with you across projects.

## Operations

### load()

Load SOUL state at session start following the resolution order above.

1. Check for `.maestro/SOUL.md` — if present, use it (project-specific override)
2. If `CLAUDE_PLUGIN_DATA` is set, check `${CLAUDE_PLUGIN_DATA}/SOUL.md`
3. Fall back to `templates/soul-profiles/casual.md`
4. Merge preferences: project-local takes precedence over plugin data

### save(scope)

Save SOUL state after updates.

- `scope: "project"` — write to `.maestro/SOUL.md` (project-specific)
- `scope: "global"` — write to `${CLAUDE_PLUGIN_DATA}/SOUL.md` (cross-project, requires `CLAUDE_PLUGIN_DATA`)

### inject()

Inject SOUL context into agent prompts during session start. Returns a compact identity block:

```
[Developer Identity]
Role: Senior backend engineer
Style: Terse, pragmatic, test-first
Values: Correctness over speed, explicit over implicit
[End Identity]
```

## Profiles

Maestro ships with three starter profiles in `templates/soul-profiles/`:

- `casual.md` — relaxed, exploratory, learning-oriented
- `professional.md` — structured, rigorous, production-focused
- `expert.md` — minimal hand-holding, maximum autonomy

Initialize with a profile:
```
/maestro init --soul casual
/maestro init --soul professional
/maestro init --soul expert
```

## Integration with Memory

SOUL is the stable identity layer. The memory skill handles ephemeral and session-specific knowledge. Together they give Maestro a full picture of who you are and what you've been working on.

At session start, both are loaded:
```
soul.load()          # stable identity
memory.initialize()  # session context with decay
```

The context engine injects both into agent prompts, with SOUL taking the highest-priority slot in the context budget.
