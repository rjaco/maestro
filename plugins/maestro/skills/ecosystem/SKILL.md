---
name: ecosystem
description: "Cross-platform compatibility for the Anthropic ecosystem. Detects environment (Claude Code Terminal, Desktop, Cowork) and adapts output format accordingly."
---

# Anthropic Ecosystem Integration

Maestro adapts its behavior and output based on which Anthropic platform it's running in. This skill provides environment detection and platform-specific adaptations.

## Platform Detection

### Claude Code Terminal
- **Detection**: Default environment. No special indicators.
- **Capabilities**: Full tool access, bash, file I/O, git, MCP servers
- **Output format**: ASCII art, text-based progress bars, plain markdown
- **Limitations**: No rich rendering (Mermaid diagrams shown as code blocks)

### Claude Code Desktop
- **Detection**: Check for desktop-specific tools or environment variables
- **Capabilities**: Full tool access + rich markdown rendering
- **Output format**: Mermaid diagrams rendered inline, rich formatting
- **Advantages**: Visual diagrams, better table rendering, file previews

### Claude Cowork
- **Detection**: Check for Cowork-specific capabilities (file output, spreadsheet generation)
- **Capabilities**: File access, multi-step tasks, professional document output
- **Output format**: Structured file outputs (markdown, HTML)
- **Adaptations**: Generate exportable reports, structured data files

### Agent SDK
- **Detection**: Running as programmatic agent (no interactive UI)
- **Capabilities**: All tools, but no AskUserQuestion (automated mode)
- **Output format**: Structured JSON/markdown for programmatic consumption
- **Adaptations**: Skip interactive prompts, use defaults or config-driven choices

## Output Adaptation

### Diagrams

| Platform | Approach |
|----------|----------|
| Terminal | ASCII art (always works) |
| Desktop | Mermaid code blocks (rendered by viewer) |
| Cowork | HTML file with embedded charts |
| Agent SDK | Raw data (JSON) for programmatic use |

### Progress Indicators

| Platform | Approach |
|----------|----------|
| Terminal | `[=====>    ] 5/10` ASCII progress bar |
| Desktop | Same, but with Mermaid Gantt for timeline |
| Cowork | Progress report as structured markdown file |
| Agent SDK | `{"completed": 5, "total": 10, "percent": 50}` |

### User Decisions

| Platform | Approach |
|----------|----------|
| Terminal | AskUserQuestion with text options |
| Desktop | AskUserQuestion with previews |
| Cowork | AskUserQuestion with previews |
| Agent SDK | Auto-select from config defaults (no interactive prompts) |

## Agent SDK Integration

For programmatic control of Maestro via the Anthropic Agent SDK:

### Python Example

```python
from anthropic import Claude

# Start a Maestro session programmatically
agent = Claude(
    model="claude-sonnet-4-6",
    cwd="/path/to/project",
    permission_mode="bypass_permissions"
)

# Initialize Maestro
result = agent.query("/maestro init")

# Build a feature
result = agent.query('/maestro "Add user auth" --yolo --no-forecast')

# Check status
result = agent.query("/maestro status")

# Read the state file for structured data
state = open(".maestro/state.local.md").read()
```

### TypeScript Example

```typescript
import { query } from '@anthropic-ai/claude-agent-sdk'

// Start a Maestro session
const result = await query({
  prompt: '/maestro "Add user auth" --yolo',
  cwd: '/path/to/project',
  permissionMode: 'bypassPermissions',
  settingSources: ['project', 'user']
})
```

## Cowork Integration

When running in Cowork, Maestro can:

1. **Generate reports as files**: Save progress reports, cost analyses, and build logs as structured markdown or HTML files that Cowork can present
2. **Batch operations**: Execute multiple features in sequence without interactive prompts
3. **Export data**: Generate CSV/JSON exports of token ledger, trust metrics, session history
4. **Knowledge management**: Interface with Cowork's file system for persistent project knowledge

### Cowork Workflow Example

```
User in Cowork: "Build the authentication system for my project"

Maestro:
1. Detects Cowork environment
2. Reads project files for DNA
3. Plans (auto-approve with defaults)
4. Implements via dev-loop (yolo mode)
5. Generates report file: build-report-2026-03-17.md
6. Presents report to user in Cowork
```

## Environment Detection Logic

At the start of each Maestro session:

1. Check for `CLAUDE_DESKTOP` env var → Desktop mode
2. Check for `CLAUDE_COWORK` env var → Cowork mode
3. Check for `CLAUDE_SDK` env var → Agent SDK mode
4. Check for AskUserQuestion tool availability → Interactive mode
5. Default → Terminal mode

Store detected environment in session state:
```yaml
environment: terminal | desktop | cowork | agent_sdk
```

Adapt all subsequent output based on this detection.

## Remote Control Compatibility

Maestro works seamlessly with Claude Code's Remote Control feature (`/remote-control`). When a session is accessed remotely (from phone, tablet, or browser):

### What works:
- All `/maestro` commands function normally
- AskUserQuestion menus render in the web/app UI
- Background agents dispatch and report results
- File edits and git operations execute on the local machine
- Notifications can be pushed to Slack/Discord/Telegram (reaches you even when away from terminal)

### Adaptations for remote:
- Keep responses concise (mobile screens are small)
- Progress updates should be self-contained (context may be lost between phone checks)
- Use AskUserQuestion for all decisions (no need to type commands)
- Checkpoints are especially valuable — they wait for your response from any device

### Best workflow:
```bash
# On your machine:
claude --remote-control "My Project"

# Then from your phone:
/maestro "Add user auth" --checkpoint

# Maestro runs on your machine, checkpoints reach your phone
# Review and approve from anywhere
```

## Dispatch Compatibility

Maestro and the [Dispatch plugin](https://github.com/bassimeledath/dispatch) solve similar problems differently. They can coexist:

### How they differ:

| Capability | Dispatch | Maestro |
|-----------|----------|---------|
| Purpose | Ad-hoc parallel tasks | Structured feature development |
| Decomposition | Manual (you define tasks) | Automatic (decompose skill) |
| Workers | Generic (same prompt) | Specialized (implementer, QA, fixer) |
| Quality | No review cycle | QA review + self-heal + trust |
| State | Worker tracking only | Full session state + resume |
| Cost | No tracking | Token ledger + forecast |
| Memory | None | Semantic + episodic decay |

### Using both together:

- Use **Dispatch** for quick parallel tasks: "research these 5 APIs", "fix these 3 bugs"
- Use **Maestro** for structured features: "Add user authentication with OAuth"
- Maestro's dev-loop already dispatches agents in parallel when stories are independent — it IS a dispatch system with quality gates on top

### If you only want one:

If your work is mostly features/products → use Maestro.
If your work is mostly ad-hoc parallel tasks → use Dispatch.
Both installed? They don't conflict — different commands, different state files.
