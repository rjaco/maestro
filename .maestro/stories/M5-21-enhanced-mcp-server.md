---
id: M5-21
slug: enhanced-mcp-server
title: "Enhanced MCP server — full Maestro capabilities as MCP tools"
type: enhancement
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. Enhanced `.mcp.json` with additional MCP tools:
   - `maestro_status` — get current session status
   - `maestro_stories` — list stories for current milestone
   - `maestro_metrics` — get cost, quality, progress metrics
   - `maestro_control` — pause/resume/abort operations
   - `maestro_health` — run health check and return results
2. Each tool has clear input/output schema
3. Tools work in Claude Desktop and Cowork contexts
4. Error handling: tools return structured errors, not crashes
5. Enhanced `skills/mcp-server/SKILL.md` documents all tools
6. Mirror: .mcp.json and skill in both root and plugins/maestro/

## Context for Implementer

Read the current `.mcp.json` and `skills/mcp-server/SKILL.md` first.

The MCP server exposes Maestro capabilities as tools that Claude Desktop and other MCP clients can call. Current tools may be limited. Add tools that make Maestro controllable from any MCP-capable client.

Tool definitions follow the MCP specification:
```json
{
  "mcpServers": {
    "maestro": {
      "type": "stdio",
      "command": "${CLAUDE_PLUGIN_ROOT}/scripts/mcp-server.sh",
      "args": [],
      "env": {}
    }
  }
}
```

For tools that need to read state, they should read `.maestro/state.local.md`.
For control tools, they should update `.maestro/state.local.md` (e.g., set phase: paused).

Reference: .mcp.json (current)
Reference: skills/mcp-server/SKILL.md (current)
Reference: plugins/maestro/.mcp.json (mirror)
