---
name: mcp-server
description: "MCP server definition exposing Maestro capabilities as tools for Claude Desktop, Cowork, and other MCP clients."
---

# MCP Server

Maestro bundles an MCP server definition (`.mcp.json`) that exposes key orchestration capabilities as MCP tools. This enables Claude Desktop, Claude Cowork, and any MCP-compatible client to invoke Maestro operations programmatically.

## Available Tools

| Tool | Purpose | Input |
|------|---------|-------|
| `maestro_status` | Get current session status | None |
| `maestro_build` | Build a feature autonomously | `feature` (string), `mode` (optional) |
| `maestro_plan` | Plan a feature without executing | `feature` (string) |
| `maestro_squad_list` | List available squads | None |
| `maestro_health` | Get project health score | None |

## Tool Details

### maestro_status

Returns the current Maestro session state:

```json
{
  "active": true,
  "feature": "User authentication system",
  "milestone": "3/5",
  "story": "2/6",
  "phase": "implement",
  "mode": "checkpoint",
  "spend": "$4.80"
}
```

If no session is active, returns `{ "active": false, "message": "No active session" }`.

### maestro_build

Starts a full dev-loop cycle:

1. Auto-initializes if `.maestro/dna.md` is missing (via auto-init skill)
2. Decomposes the feature into stories (via decompose skill)
3. Executes stories via the dev-loop (7-phase cycle per story)
4. Returns a summary of completed work

**Input:**
- `feature` (required): Description of what to build
- `mode` (optional): `yolo` | `checkpoint` | `careful` (default: `checkpoint`)

### maestro_plan

Generates a plan without executing:

1. Analyzes the feature against project DNA
2. Decomposes into 2-8 stories with dependency graph
3. Estimates token cost and time
4. Returns the plan as structured data

**Input:**
- `feature` (required): Description of what to plan

### maestro_squad_list

Lists all available squads from the `squads/` directory:

```json
{
  "squads": [
    {
      "name": "full-stack-dev",
      "description": "Full-stack web development team",
      "agents": 5,
      "orchestration": "dag"
    }
  ],
  "active": null
}
```

### maestro_health

Returns the project health score:

```json
{
  "score": 82,
  "dimensions": {
    "tests": 90,
    "types": 85,
    "lint": 95,
    "dependencies": 70,
    "tech_debt": 72
  },
  "trend": "improving"
}
```

## Configuration

The `.mcp.json` file at the plugin root defines the server. Claude Code automatically discovers it when the plugin is installed.

### For Claude Desktop

Claude Desktop connects to MCP servers configured in its settings. To use Maestro tools:

1. Install the Maestro plugin in Claude Code
2. The MCP server is automatically available to Claude Desktop if both share the same MCP configuration
3. Tools appear in Claude Desktop's tool palette as `maestro_*`

### For External MCP Clients

Any MCP-compatible client can connect to Maestro's tools:

```json
{
  "mcpServers": {
    "maestro": {
      "command": "claude",
      "args": ["mcp", "serve", "--plugin", "maestro"]
    }
  }
}
```

## Security

MCP tools execute within the Claude Code sandbox:
- File access is scoped to the project directory
- No network access unless explicitly granted
- No secrets exposure — tools read `.maestro/` state, not credentials
- All operations go through the same permission model as slash commands

## Integration

- **Defined in:** `.mcp.json` at plugin root
- **Discovered by:** Claude Code plugin loader, Claude Desktop MCP client
- **Backed by:** Corresponding skills (status → status command, build → maestro command, etc.)
