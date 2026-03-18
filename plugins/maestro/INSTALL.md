# Maestro Installation Guide

## Quick Install

### Claude Code Terminal

```bash
claude plugin install maestro
```

Then initialize for your project:

```
cd /path/to/your/project
claude
/maestro init
```

### Claude Code Desktop

1. Open Claude Code Desktop
2. Go to Settings > Plugins
3. Search for "maestro"
4. Click Install
5. Open your project folder
6. Type `/maestro init`

## Post-Installation

### First Run

Run `/maestro init` inside your project. Maestro will:

1. Ask you about your project (one open-ended question)
2. Scan your codebase (package.json, tsconfig, etc.)
3. Detect available integrations (MCP servers, CLI tools)
4. Show a preview of what it learned
5. Create the `.maestro/` directory with project DNA, config, and trust metrics

### Verify Installation

```
/maestro doctor
```

This checks core files, configuration, hooks, and detected integrations.

### Get Help

```
/maestro help
/maestro help commands
/maestro help modes
```

## Optional Integrations

### Kanban (Project Management)

Connect Maestro to Asana, Jira, Linear, or GitHub Issues to visualize stories on a kanban board.

#### GitHub Issues (simplest, no extra setup)

If you have `gh` CLI installed and authenticated:

```
/maestro config set integrations.kanban.provider github
/maestro config set integrations.kanban.sync_enabled true
```

#### Asana

1. Install the Asana MCP Server:
   - Follow instructions at developers.asana.com/docs/mcp-server
   - Add to your Claude Code MCP configuration

2. Configure Maestro:
   ```
   /maestro config set integrations.kanban.provider asana
   /maestro config set integrations.kanban.project_id YOUR_PROJECT_GID
   /maestro config set integrations.kanban.sync_enabled true
   ```

#### Jira

1. Install the Atlassian Remote MCP Server:
   - Follow instructions at atlassian.com/blog/announcements/remote-mcp-server
   - Authenticate with OAuth 2.1

2. Configure Maestro:
   ```
   /maestro config set integrations.kanban.provider jira
   /maestro config set integrations.kanban.project_id YOUR_PROJECT_KEY
   /maestro config set integrations.kanban.sync_enabled true
   ```

#### Linear

1. Install a Linear MCP Server
2. Configure Maestro:
   ```
   /maestro config set integrations.kanban.provider linear
   /maestro config set integrations.kanban.sync_enabled true
   ```

### Knowledge Base (Second Brain)

Connect Maestro to Obsidian or Notion to persist decisions, learnings, and session summaries.

#### Obsidian

1. Enable Obsidian CLI:
   - Open Obsidian > Settings > General > Command Line Interface > Enable
   - Restart your terminal

2. Connect:
   ```
   /maestro brain connect
   ```
   Maestro will auto-detect your vault location or ask for the path.

#### Notion

1. Install the Notion MCP Server:
   - Create an integration at notion.so/profile/integrations
   - Follow instructions at developers.notion.com/docs/mcp
   - Share target workspace with the integration

2. Connect:
   ```
   /maestro brain connect
   ```

### View Board

```
/maestro board
```

### Search Knowledge Base

```
/maestro brain search "authentication"
```

## Commands Reference

| Command | Description |
|---------|-------------|
| `/maestro "task"` | Build a feature autonomously |
| `/maestro opus "vision"` | Build an entire product (Magnum Opus) |
| `/maestro init` | Initialize for this project |
| `/maestro status` | View progress, resume, pause, abort |
| `/maestro model` | View/change model assignments |
| `/maestro help [topic]` | Contextual help and FAQ |
| `/maestro doctor` | Health check and diagnostics |
| `/maestro config` | View/edit configuration |
| `/maestro board` | Kanban board view |
| `/maestro brain` | Second brain operations |
| `/maestro history` | Past sessions and cost analysis |

## Troubleshooting

Run `/maestro doctor` to diagnose common issues.

For more help: `/maestro help troubleshooting`
