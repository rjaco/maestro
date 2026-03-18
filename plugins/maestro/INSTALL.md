# Maestro Installation Guide

## Quick Install (Recommended)

### Method 1: From GitHub (works on Terminal + Desktop)

```bash
# Add the marketplace
/plugin marketplace add rjaco/maestro-orchestrator

# Install the plugin
/plugin install maestro@rjaco-maestro-orchestrator
```

Or in one line from the terminal:

```bash
claude --plugin-dir /path/to/maestro/plugins/maestro
```

### Method 2: Claude Code Desktop

1. Open Claude Code Desktop
2. Click **Customize** in the left sidebar
3. Click **Browse plugins**
4. Search for "maestro" (if published) or click **Upload plugin**
5. Select the `plugins/maestro/` directory

### Method 3: Local Development

```bash
# Clone the repo
git clone https://github.com/rjaco/maestro-orchestrator.git

# Run Claude Code with the plugin
claude --plugin-dir ./maestro-orchestrator/plugins/maestro
```

### Method 4: Manual Installation

```bash
# Copy the plugin to Claude Code's plugin directory
cp -r plugins/maestro ~/.claude/plugins/local/maestro

# Or add the marketplace to your settings
# In Claude Code, run:
/plugin marketplace add rjaco/maestro-orchestrator
```

## Post-Installation

### Verify Installation

```bash
# In Claude Code, type:
/maestro:help

# Or check the plugin list:
/plugin
```

You should see "maestro" in the Installed tab with all commands available.

### Initialize for Your Project

```bash
cd /path/to/your/project
claude

# Then type:
/maestro init
```

Maestro will ask about your project, scan your codebase, and create the `.maestro/` directory.

### Verify Everything Works

```bash
/maestro doctor
```

## Installation Scopes

| Scope | Command | Who sees it |
|-------|---------|-------------|
| User (default) | `/plugin install maestro@marketplace` | All your projects |
| Project | `/plugin install maestro@marketplace --scope project` | All collaborators |
| Local | `/plugin install maestro@marketplace --scope local` | Only you, this repo |

## Remote Control Compatibility

Maestro works with Claude Code's Remote Control feature. Start a remote session:

```bash
# Start Claude Code with remote control
claude --remote-control "My Project"

# Or from an existing session
/remote-control My Project
```

Then open the session from your phone (Claude iOS/Android app) or browser (claude.ai/code) and use Maestro commands normally:

```
/maestro status
/maestro board
/maestro brain search "auth"
```

All Maestro commands work via Remote Control — they're standard Claude Code skills.

## Dispatch Compatibility

Maestro IS a dispatch system. It decomposes features into stories and dispatches specialized agents to implement them. If you also have the [Dispatch plugin](https://github.com/bassimeledath/dispatch), they complement each other:

| Feature | Dispatch | Maestro |
|---------|----------|---------|
| Task decomposition | Manual | Automatic (decompose skill) |
| Worker agents | Generic workers | Specialized (implementer, QA, fixer) |
| Quality gates | None | QA review, self-heal, trust metrics |
| Cost tracking | None | Token ledger, forecast |
| Session management | Worker tracking | Full state management |
| Knowledge persistence | None | Brain + memory system |

You can use Dispatch for ad-hoc parallel tasks and Maestro for structured feature development.

## Commands Reference

| Command | Description |
|---------|-------------|
| `/maestro "task"` | Build a feature autonomously |
| `/maestro opus "vision"` | Build an entire product (Magnum Opus) |
| `/maestro plan "task"` | Deep planning with codebase exploration |
| `/maestro init` | Initialize for this project |
| `/maestro status` | View progress, resume, pause, abort |
| `/maestro model` | View/change model assignments |
| `/maestro help [topic]` | Contextual help and FAQ |
| `/maestro doctor` | Health check and diagnostics |
| `/maestro config` | View/edit configuration |
| `/maestro board` | Kanban board view |
| `/maestro brain` | Second brain operations |
| `/maestro history` | Past sessions and cost analysis |
| `/maestro notify` | Push notifications (Slack, Discord, Telegram) |
| `/maestro viz` | Visual dashboards and Mermaid diagrams |
| `/maestro demo` | Interactive demo — learn how Maestro works |
| `/maestro quick-start` | Pick from pre-built task templates |

## Troubleshooting

### "Unknown skill: maestro"

The plugin isn't loaded. Try:
1. `/plugin` — check if maestro appears in Installed tab
2. If not, reinstall: `/plugin marketplace add rjaco/maestro-orchestrator`
3. Then: `/plugin install maestro@rjaco-maestro-orchestrator`
4. Restart Claude Code

### Commands show as `/maestro:maestro-init` instead of `/maestro:init`

You have an old cached version. Fix:
1. `/plugin` → Installed → Uninstall maestro
2. Reinstall from marketplace
3. Or: delete `~/.claude/plugins/cache/maestro-orchestrator/` and reinstall

### Stop hook error on exit

If you see "JSON validation failed" when exiting:
1. Check that `stop-hook.sh` uses `"approve"` (not `"allow"`)
2. Update plugin: `/plugin` → Installed → Update maestro

### Desktop can't find the plugin

Desktop reads from `~/.claude/plugins/`. Make sure:
1. Plugin is installed at user scope (not project scope)
2. Restart Claude Code Desktop after installing

For more help: `/maestro help troubleshooting`
