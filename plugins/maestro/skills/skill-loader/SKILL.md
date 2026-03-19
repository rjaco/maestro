---
name: skill-loader
description: "Declarative dependency gating and 4-tier skill precedence. Skills declare their requirements via frontmatter; the loader gates loading, logs skipped skills, and resolves name conflicts across workspace, runtime, global, and bundled tiers."
---

# Skill Loader

Governs how Maestro discovers, filters, and resolves skills at session start. Two responsibilities: gate skills whose dependencies are not satisfied, and apply the correct tier precedence when multiple definitions exist for the same skill name.

## Dependency Gating

Skills declare requirements in their YAML frontmatter under a `requires` key. The loader evaluates every declared requirement before registering a skill. If any single requirement fails, the skill is skipped and the reason is logged to `.maestro/logs/skill-loader.md`.

### Frontmatter Schema

```yaml
---
name: my-skill
description: "..."
requires:
  tools: ["Bash", "WebSearch"]          # Claude Code tools needed
  bins: ["gh", "node"]                   # CLI binaries that must be in PATH
  env: ["GITHUB_TOKEN"]                  # Env vars (check existence, never log values)
  mcp: ["mcp__playwright__"]             # MCP server prefixes (checked via ToolSearch)
  os: ["linux", "darwin"]               # Operating systems (uname -s, lowercased)
  plugins: ["feature-dev"]              # Other Claude Code plugins that must resolve
---
```

All `requires` fields are optional. A skill with no `requires` block always loads.

### Gate Evaluation

Evaluate gates in this order. Stop at the first failure.

#### `tools`

Check if each named tool is available in the current Claude Code session. The tool list comes from the active conversation context — if a tool appears in the available tools list, the check passes.

```
tools: ["Bash", "WebSearch"]
→ verify Bash is available
→ verify WebSearch is available
```

#### `bins`

Run `which <bin>` for each declared binary. A non-zero exit or empty output means the binary is absent.

```bash
which gh 2>/dev/null
which node 2>/dev/null
```

#### `env`

Check existence only. Never read or log the value.

```bash
[ -n "$GITHUB_TOKEN" ]
[ -n "$LINEAR_API_KEY" ]
```

A missing or empty variable fails the gate.

#### `mcp`

Use ToolSearch to probe for each declared prefix. If ToolSearch returns no results for the prefix, the MCP server is not present.

```
mcp: ["mcp__playwright__"]
→ ToolSearch("mcp__playwright__") — must return at least one result
```

#### `os`

Run `uname -s` and lowercase the result. Check against the declared list.

```bash
uname -s | tr '[:upper:]' '[:lower:]'
# linux, darwin, windows_nt, etc.
```

The skill loads only if the current OS matches one of the listed values.

#### `plugins`

Attempt to resolve each named plugin as a subagent type. If the resolution fails (plugin not installed or not active in this session), the gate fails.

### Failure Logging

When a skill is skipped, append to `.maestro/logs/skill-loader.md`:

```markdown
## [ISO timestamp] Skipped: <skill-name>

- **Tier**: workspace | runtime | global | bundled
- **Path**: .maestro/skills/<name>/SKILL.md
- **Reason**: bins gate failed — `gh` not found in PATH
```

Log the specific gate that failed and which value was missing. Never log env var values, only var names.

Create `.maestro/logs/` if it does not exist. If the log file grows beyond reasonable size, the loader appends regardless — log rotation is handled externally.

---

## Four-Tier Skill Precedence

When the same skill name is defined in multiple locations, the highest-priority tier wins. Lower tiers are ignored for that name.

### Tier Order (highest to lowest)

| Priority | Tier | Location | Purpose |
|----------|------|----------|---------|
| 1 | **Workspace** | `.maestro/skills/<name>/SKILL.md` | Project-specific overrides |
| 2 | **Runtime** | `.maestro/runtime-skills/<name>/SKILL.md` | Auto-generated from gaps |
| 3 | **Global** | `~/.claude/maestro-skills/<name>/SKILL.md` | User's personal skills |
| 4 | **Bundled** | `skills/<name>/SKILL.md` | Ships with Maestro plugin |

### Resolution Algorithm

At session start:

1. Collect all skill directories from all four tiers.
2. Index each skill by its `name` field (from frontmatter), not directory name. If the frontmatter `name` is absent, use the directory name.
3. For each unique skill name, keep only the highest-tier version. Discard the rest silently.
4. Run dependency gating on the surviving set.
5. Register passing skills for use in this session.

When a lower-tier skill is shadowed by a higher-tier one, do not log a warning — shadowing is expected behavior. Only log when a skill is skipped due to a failed gate.

### Workspace Tier

Skills in `.maestro/skills/` are project-specific customizations. They are committed to the project repo and take precedence over everything else. Use this tier to override a bundled skill's behavior for a particular project without modifying the plugin source.

Example: override the bundled `ship` skill with a project-specific version that runs an additional security scan.

### Runtime Tier

Skills in `.maestro/runtime-skills/` are auto-generated by the `runtime-author` skill when Maestro detects that a task has no good skill match. These are ephemeral and project-local. They are lower priority than workspace skills but higher than the user's global library.

### Global Tier

Skills in `~/.claude/maestro-skills/` are the user's personal library — skills they've built and reuse across all projects. Installing a skill here makes it available everywhere without committing it to any repo.

### Bundled Tier

Skills in `skills/` ship with the Maestro plugin and represent the default capability set. They are always the fallback when no higher tier defines a skill by that name.

---

## Integration Points

### Called By

- **Session init** — runs once at the start of every Maestro session, before any skill is dispatched
- **`/maestro doctor`** — shows which skills are loaded, which are skipped, and which tier each comes from
- **`skill-validator`** — can invoke the loader in dry-run mode to validate a skill before committing it

### Output to Session State

After loading completes, write the resolved skill registry to `.maestro/state.local.md` under a `skills` section:

```yaml
skills:
  loaded:
    - name: ship
      tier: bundled
      path: skills/ship/SKILL.md
    - name: git-craft
      tier: workspace
      path: .maestro/skills/git-craft/SKILL.md
  skipped:
    - name: kanban
      tier: bundled
      reason: bins gate failed — `gh` not found in PATH
```

This allows the orchestrator to know at a glance what is available before attempting dispatch.
