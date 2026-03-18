---
name: plugin-data
description: "Durable key-value storage for Maestro via ${CLAUDE_PLUGIN_DATA}. Defines what lives in plugin data vs project state, migration paths from .maestro/, and access patterns for scripts and skills."
---

# Plugin Data

`${CLAUDE_PLUGIN_DATA}` is a durable storage directory introduced in Claude Code v2.1.78. It is the native primitive for Maestro's cross-project memory, feature registry, corrections log, and security baselines.

## What ${CLAUDE_PLUGIN_DATA} Provides

- **Durable directory** — survives session resets and context compactions
- **Plugin-isolated** — each plugin gets its own subdirectory; Maestro's path is typically `~/.claude/plugins/data/maestro/`
- **Universally available** — accessible in all hooks, skills, and agent dispatches as an environment variable
- **Cross-project** — the same directory is visible regardless of which repo is open

## Storage Split: What Moves vs What Stays

### Moves to ${CLAUDE_PLUGIN_DATA} (cross-project data)

These files contain knowledge that applies beyond a single project. Moving them here means corrections in one project help all future projects, and memory survives context compaction.

| Current Location | New Location |
|-----------------|-------------|
| `.maestro/memory/semantic.md` | `${CLAUDE_PLUGIN_DATA}/memory/semantic.md` |
| `.maestro/memory/episodic.md` | `${CLAUDE_PLUGIN_DATA}/memory/episodic.md` |
| `.maestro/registry.json` | `${CLAUDE_PLUGIN_DATA}/registry.json` |
| `.maestro/security/baseline.json` | `${CLAUDE_PLUGIN_DATA}/security/baseline.json` |
| `.maestro/corrections.md` | `${CLAUDE_PLUGIN_DATA}/corrections.md` |

Model stats (QA pass rates per model) also belong here, as they accumulate across projects.

### Stays in .maestro/ (project-specific state)

These files are scoped to the current project and should remain in the repo or local project directory.

| File | Reason |
|------|--------|
| `state.local.md` | Current session state — project-specific |
| `dna.md` | Project DNA — unique per repo |
| `config.yml` | Project configuration |
| `specs/` | Feature specifications for this project |
| `stories/` | Story files for this project |
| `steering/` — steering files | Steering rules scoped to this project |
| `HANDOFF.md` | Session handoff — project-specific context |

## Access Patterns

### Shell scripts

Use the env var directly, with a fallback to `.maestro/` if the variable is not set:

```sh
MEMORY_DIR="${CLAUDE_PLUGIN_DATA:-$(pwd)/.maestro}/memory"
REGISTRY="${CLAUDE_PLUGIN_DATA:-$(pwd)/.maestro}/registry.json"
CORRECTIONS="${CLAUDE_PLUGIN_DATA:-$(pwd)/.maestro}/corrections.md"
BASELINE="${CLAUDE_PLUGIN_DATA:-$(pwd)/.maestro}/security/baseline.json"
```

Always create the directory before writing:

```sh
mkdir -p "${CLAUDE_PLUGIN_DATA}/memory"
```

### Skills

Reference `${CLAUDE_PLUGIN_DATA}` in instructions using the variable syntax. Skills do not need to know the resolved path — the runtime expands it.

```
Read from: ${CLAUDE_PLUGIN_DATA}/memory/semantic.md
Write to:  ${CLAUDE_PLUGIN_DATA}/corrections.md
```

### Fallback rule

If `$CLAUDE_PLUGIN_DATA` is not set (older Claude Code version or local dev without plugin support), fall back to `.maestro/` in the current working directory. This keeps Maestro functional across environments.

## Benefits

- **Survives session resets** — context compaction does not erase memory or the corrections log
- **Cross-project learning** — a correction captured in project A improves behaviour in project B
- **Clean separation** — project-specific state (`.maestro/`) stays in the repo; plugin state stays outside it
- **No git pollution** — plugin data lives outside the repo; it is not committed, diff'd, or reviewed
- **Security baseline portability** — integrity baselines established in one project carry over to related projects

## Integration Points

### memory/SKILL.md

Replace `.maestro/memory/` paths with `${CLAUDE_PLUGIN_DATA}/memory/`. The `initialize()` operation creates the directory if absent. All read/write operations (save_semantic, save_episodic, build_context, decay_sweep) target plugin data.

### self-correct/SKILL.md

The corrections log at `${CLAUDE_PLUGIN_DATA}/corrections.md` persists cross-project. A pattern learned from one project (e.g., "never use default exports") is available in the next session on a different repo.

### feature-registry/SKILL.md

The registry at `${CLAUDE_PLUGIN_DATA}/registry.json` stores requirement tracking state that is not tied to a single project's git history.

### security-drift/SKILL.md

Security baselines at `${CLAUDE_PLUGIN_DATA}/security/baseline.json` persist across projects. Once a baseline is established for a class of files, it is reusable.

### All shell scripts

Every script that currently reads from or writes to `.maestro/` for cross-project data must add the fallback pattern:

```sh
DATA_ROOT="${CLAUDE_PLUGIN_DATA:-$(pwd)/.maestro}"
```

This single change makes all scripts compatible with both plugin-data-aware and legacy environments.
