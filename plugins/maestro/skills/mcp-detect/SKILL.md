---
name: mcp-detect
description: "Detect available MCP servers and CLI tools in the current environment. Used by maestro-init, maestro-doctor, and integration skills."
---

# MCP Server Detection

Detects which external integrations are available in the current Claude Code environment. Called by `maestro-init` during setup and `maestro-doctor` during diagnostics.

## Detection Methods

### MCP Tool Prefix Detection

Check if specific MCP tool prefixes are available. The presence of these prefixes indicates the MCP server is installed and running:

| Integration | Tool Prefix | Example Tool |
|-------------|-------------|--------------|
| Asana | `mcp__asana__` | `mcp__asana__create_task` |
| Jira/Confluence | `mcp__atlassian__` | `mcp__atlassian__jira_get_issue` |
| Linear | `mcp__linear__` | `mcp__linear__create_issue` |
| Notion | `mcp__notion__` | `mcp__notion__search` |
| Playwright | `mcp__playwright__` or `mcp__plugin_playwright_playwright__` | `mcp__plugin_playwright_playwright__browser_navigate` |

**Detection approach:** Use the `ToolSearch` tool (a built-in Claude Code deferred tool loader) to probe for MCP tools by prefix. Call it with a keyword query matching the integration name:

```
ToolSearch(query: "+mcp__asana", max_results: 1)   → If results returned, Asana MCP is available
ToolSearch(query: "+mcp__linear", max_results: 1)   → If results returned, Linear MCP is available
ToolSearch(query: "+mcp__notion", max_results: 1)   → If results returned, Notion MCP is available
ToolSearch(query: "playwright", max_results: 1)      → If results returned, Playwright MCP is available
```

The `+` prefix in ToolSearch queries requires the term to appear in the tool name. If no results are returned, the MCP server is not configured.

**Alternative detection (if ToolSearch is not available):** Check for MCP configuration files:

```bash
# Check .mcp.json in project root
[ -f ".mcp.json" ] && cat .mcp.json | jq -r 'keys[]' 2>/dev/null

# Check Claude Code's MCP settings
[ -f "$HOME/.claude/settings.json" ] && cat "$HOME/.claude/settings.json" | jq -r '.mcpServers // {} | keys[]' 2>/dev/null
```

### CLI Tool Detection

Check if CLI tools are available in PATH:

```bash
# GitHub CLI
which gh 2>/dev/null && gh --version 2>/dev/null | head -1

# Obsidian CLI
which obsidian 2>/dev/null && obsidian --version 2>/dev/null

# Node.js (for any Node-based integrations)
which node 2>/dev/null && node --version 2>/dev/null
```

### Environment Variable Detection

Some integrations can be detected via environment variables:

```bash
# Check for common integration env vars (existence only, never print values)
[ -n "$ASANA_ACCESS_TOKEN" ] && echo "asana_token: set"
[ -n "$LINEAR_API_KEY" ] && echo "linear_key: set"
[ -n "$NOTION_TOKEN" ] && echo "notion_token: set"
[ -n "$JIRA_API_TOKEN" ] && echo "jira_token: set"
```

## Output Format

Present results using the standard output format:

```
+---------------------------------------------+
| Detected Integrations                       |
+---------------------------------------------+

  Project Management:
    (ok) GitHub CLI       v2.45.0
    (x)  Asana MCP       not detected
    (x)  Jira MCP        not detected
    (x)  Linear MCP      not detected

  Knowledge Base:
    (ok) Obsidian CLI    v1.12.3
    (x)  Notion MCP      not detected

  Development:
    (ok) Playwright      available
    (ok) Node.js         v22.1.0

  (i) Install MCP servers to enable integrations.
  (i) Run /maestro help integrations for setup guides.
```

## Config Update

After detection, update `.maestro/config.yaml` with the `integrations` section:

```yaml
integrations:
  kanban:
    provider: null        # auto-detected or user-set: asana | jira | linear | github
    auto_detected:
      - github            # list of detected providers
    sync_enabled: false
  knowledge_base:
    provider: null        # auto-detected or user-set: obsidian | notion
    auto_detected:
      - obsidian          # list of detected providers
    vault_path: null      # user must set this
    sync_enabled: false
  tools:
    playwright: true      # detected as available
    github_cli: true
    obsidian_cli: true
```

Only write the `auto_detected` lists based on what was actually found. Do not set `provider` automatically -- the user chooses which provider to activate via `/maestro config`.

## When Called

- **During `/maestro init`**: Full detection, write results to config
- **During `/maestro doctor`**: Full detection, display report, compare against config
- **During integration setup**: Verify specific provider is available before configuring
