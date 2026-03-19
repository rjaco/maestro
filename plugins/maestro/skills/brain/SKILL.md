---
name: brain
description: "Second brain integration. Connects to Obsidian or Notion for persistent knowledge management. Stores decisions, architecture notes, retrospectives, and session summaries."
---

# Second Brain Integration

Connects Maestro to a knowledge base (Obsidian vault or Notion workspace) for persistent project memory across sessions. Stores decisions, architecture notes, retrospectives, and session summaries. Retrieves relevant context before decomposition and implementation.

## Provider Architecture

Provider-agnostic interface. Delegates to sub-files based on `integrations.knowledge_base.provider` in `.maestro/config.yaml`.

| Provider | Sub-file | Tool Used |
|----------|----------|-----------|
| `obsidian` | `provider-obsidian.md` | Obsidian CLI or direct file I/O |
| `notion` | `provider-notion.md` | Notion MCP Server |

If no provider is configured, all brain operations are no-ops.

## Vault Structure

Regardless of provider, Maestro organizes its knowledge in a consistent hierarchy:

```
maestro/
  decisions/          Architecture and design decisions
  retrospectives/     Session retrospectives and learnings
  summaries/          Session TLDR summaries
  research/           Research findings worth preserving
  daily/              Daily briefings
```

For Obsidian, this is a subfolder within the vault. For Notion, this maps to a database with category tags.

## Note Format

Every note saved by Maestro follows this structure:

```markdown
---
date: YYYY-MM-DD
project: [project name from DNA]
category: decision | retrospective | summary | research | daily
tags: [relevant tags]
maestro_session: [session_id]
---

# [Title]

[Content]

---
*Saved by Maestro on [date] from session [session_id]*
```

## Operations

### connect(provider, path_or_workspace)

Interactive setup for the knowledge base connection. Called by `/maestro brain connect`.

1. If provider not specified, detect available providers:
   - Check for Obsidian CLI (`which obsidian`)
   - Check for Notion MCP tools (`mcp__notion__*`)
   - If both available, ask user to choose
   - If neither available, show setup instructions

2. For Obsidian:
   - Ask for vault path (or detect from common locations)
   - Verify the path exists and is accessible
   - Create the `maestro/` subfolder structure if it doesn't exist
   - Write config: `integrations.knowledge_base.provider: obsidian`, `vault_path: /path/to/vault`

3. For Notion:
   - Verify Notion MCP tools are available
   - Search for or create a "Maestro Knowledge Base" database
   - Write config: `integrations.knowledge_base.provider: notion`

4. Enable sync: `integrations.knowledge_base.sync_enabled: true`

### save(content, category, title)

Save a note to the knowledge base.

**Input:**
- `content`: Markdown content to save
- `category`: decision | retrospective | summary | research | daily
- `title`: Note title

**Process:**
1. Generate frontmatter with date, project, category, tags, session_id
2. Combine frontmatter + content
3. Delegate to provider:
   - Obsidian: write file to `{vault_path}/maestro/{category}/{date}-{slug}.md`
   - Notion: create page in the knowledge base database

### search(query)

Search the knowledge base for relevant entries.

**Input:** Natural language query string.

**Process:**
1. Delegate search to provider:
   - Obsidian: use `obsidian search --vault PATH --query TERM` or grep the vault directory
   - Notion: use `mcp__notion__search` with the query
2. Return top 5-10 results with title, date, category, and a content excerpt (first 200 chars)

**Output:**

```
+---------------------------------------------+
| Brain Search: "authentication"              |
+---------------------------------------------+

  1. Decision: Use JWT for API auth (2026-03-10)
     "Decided on JWT tokens with 15min expiry
      and refresh tokens in httpOnly cookies..."

  2. Research: Auth provider comparison (2026-03-08)
     "Compared Auth0, Clerk, Supabase Auth.
      Supabase selected for cost and integration..."

  3. Summary: Session — Add login flow (2026-03-12)
     "Built email/password login with 5 stories.
      Key decision: bcrypt for hashing, not argon2..."

  [1] Read full note
  [2] New search
  [3] Inject into current context
```

### inject_context(topic)

Search the knowledge base and inject relevant entries into the agent context. Called automatically by the context engine before decomposition and implementation.

**Process:**
1. Search for `topic` (usually the feature description or story title)
2. Select top 3 most relevant results
3. Format as a context block:

```
[Knowledge Base Context]
The following prior decisions and learnings are relevant:

1. Decision (2026-03-10): Use JWT for API auth
   - JWT tokens with 15min expiry
   - Refresh tokens in httpOnly cookies
   - Supabase Auth for provider

2. Learning (2026-03-12): Session build
   - bcrypt chosen over argon2 for compatibility
   - Rate limiting on auth endpoints is critical

[End Knowledge Base Context]
```

4. This block is injected into the agent context by the context engine.

### session_summary(session_id)

Generate a TLDR of the current session and save it.

**Process:**
1. Read `.maestro/state.local.md` for session info
2. Read completed story files for what was built
3. Read `.maestro/token-ledger.md` for cost data
4. Generate a structured summary:

```markdown
# Session Summary: [Feature Name]

**Date:** [date]
**Stories:** [N] completed, [N] skipped
**Cost:** ~$[N.NN]
**Time:** [duration]

## What Was Built
- [Story 1 title]: [one-line description of changes]
- [Story 2 title]: [one-line description of changes]

## Key Decisions
- [Decision 1 extracted from session context]
- [Decision 2]

## Blockers Encountered
- [Blocker 1, if any]

## Lessons Learned
- [Learning 1, if any]

## Next Steps
- [Suggested follow-up work]
```

5. Save to knowledge base with category `summary`.

### daily_briefing()

Generate a morning briefing from recent vault activity and project state.

**Process:**
1. Read recent notes from the knowledge base (last 7 days)
2. Read `.maestro/state.md` for project state
3. Read `.maestro/trust.yaml` for trust metrics
4. Check for pending/paused sessions
5. Generate briefing:

```
+---------------------------------------------+
| Daily Briefing                              |
+---------------------------------------------+

  Project: [name]
  Trust:   [level] ([N] stories, [N]% QA rate)

  Recent Activity (last 7 days):
    [date] [category]: [title]
    [date] [category]: [title]

  Pending:
    (!) Paused session: [feature name] (3/5 stories)
    (i) Last active: [date]

  From your notes:
    [any recent decisions or learnings]

  Suggested:
    [1] Resume paused session
    [2] Start new feature
    [3] Review recent decisions
```

## Integration Points

### In Context Engine

Before composing the context package for an agent:

```
if config.integrations.knowledge_base.sync_enabled:
    brain_context = brain.inject_context(story_title)
    add brain_context to context package
```

### In Decompose Skill

Before decomposing a feature:

```
if config.integrations.knowledge_base.sync_enabled:
    prior_decisions = brain.search(feature_description)
    inject relevant decisions into decomposition context
```

### In Retrospective Skill

After generating improvement proposals:

```
if config.integrations.knowledge_base.sync_enabled:
    brain.save(retrospective_content, "retrospective", title)
```

### In Dev-Loop (auto-checkpoint)

At CHECKPOINT, if session has been running 30+ minutes or 3+ stories:

```
if config.integrations.knowledge_base.sync_enabled:
    brain.session_summary(session_id)
```

## Error Handling

| Error | Action |
|-------|--------|
| Provider not configured | Silent no-op |
| Vault path not accessible | Warn once per session, continue |
| MCP server not responding | Warn, skip brain operations |
| Search returns no results | Return empty, do not inject |
| Save fails | Log warning, continue (non-blocking) |

All brain operations are non-blocking — the dev-loop never stops because of a knowledge base issue.

## Graceful Degradation

Brain operations require an MCP server for Notion and direct file access for Obsidian. This section documents detection, fallback behavior, and user guidance when providers are unavailable.

### Detection

Before invoking provider-specific operations, probe for the required tool or binary:

| Provider | Detection Method | Required |
|----------|-----------------|----------|
| `obsidian` | Check vault path exists and is readable (file I/O — no MCP required) | Vault directory accessible |
| `notion` | ToolSearch probe with query `"notion"`, look for `mcp__notion__*` tools | Notion MCP server |

For Notion, run the ToolSearch probe once at session start. If no `mcp__notion__*` tools are found, fall back immediately.

For Obsidian, check that `integrations.knowledge_base.vault_path` exists on disk. If the path is missing or unreadable, fall back.

### Fallback Behavior

When a provider is unavailable:

1. **Warn once** at session start — not on every operation.
2. **Skip all brain operations** for the session: no `save`, no `search`, no `inject_context`, no `session_summary`.
3. **Never block the dev-loop.** The brain skill is a knowledge enhancement — missing access must not interrupt story implementation.
4. **Context injection** (`inject_context`) silently returns empty — agents receive no knowledge base context but proceed normally.

### User Guidance Messages

Display these messages at session start when the provider is not detected (once per session):

**Notion MCP not detected:**
```
(!) Notion MCP not detected. Second brain sync is disabled for this session.
    Install with: npx @modelcontextprotocol/create-server notion
    Or switch to Obsidian: set integrations.knowledge_base.provider: obsidian in .maestro/config.yaml
    Falling back to: no knowledge base sync (context injection and saves are disabled)
```

**Obsidian vault path not accessible:**
```
(!) Obsidian vault not found at: [vault_path]
    Second brain sync is disabled for this session.
    To fix: update integrations.knowledge_base.vault_path in .maestro/config.yaml
    Or run: /maestro brain connect obsidian
    Falling back to: no knowledge base sync (context injection and saves are disabled)
```

**No provider configured (first-time setup hint):**
```
(i) No second brain configured. Knowledge base sync is disabled.
    To enable: run /maestro brain connect
    Supported providers: obsidian (file-based), notion (MCP)
```

### Degraded Mode Behavior Summary

| Provider Configured | Available | Result |
|--------------------|-----------|--------|
| `notion` | Yes (MCP detected) | Full brain sync |
| `notion` | No (MCP missing) | Warn once, all operations no-op |
| `obsidian` | Yes (vault path readable) | Full brain sync |
| `obsidian` | No (path missing/unreadable) | Warn once, all operations no-op |
| `null` / unset | — | Silent no-op (no warning) |

The provider is never auto-switched. If the user configured `notion` and the MCP is missing, Maestro warns and degrades — it does not redirect saves to Obsidian without explicit user reconfiguration.
