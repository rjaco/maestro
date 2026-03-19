---
name: mcp-elicitation
description: "MCP elicitation for missing config values. When Maestro needs a config value that is not set, it prompts the user inline via MCP elicitation rather than failing silently or blocking on a separate setup command."
---

# MCP Elicitation for Config

Claude Code v2.1 added MCP elicitation — MCP servers can prompt for missing values mid-session without interrupting the flow. Maestro uses elicitation to collect non-sensitive config values at the moment they are first needed, rather than failing with "run /maestro config first."

## What Elicitation Replaces

Before elicitation, a missing config value forced one of two bad outcomes:

| Old behavior | Problem |
|---|---|
| Silent no-op ("kanban sync is disabled") | User never learns why a feature isn't working |
| Hard stop ("set `integrations.kanban.provider` first") | Interrupts the work to run a separate setup command |

With elicitation, Maestro prompts inline at the exact moment the value is needed — the user answers once, Maestro continues, and the value is saved for future sessions.

## When Elicitation Fires

Elicitation is triggered when a skill reads a config key and finds it `null` or absent — AND the key is required to proceed. Skills mark required keys with `elicit: true` in their config schema.

```
Skill needs config value
    |
    v
Read .maestro/config.yaml
    |
    v
Value is null or absent
    |
    v
Key has elicit: true?
    |
    +-- No  → Silent no-op or warn (skill decides)
    |
    +-- Yes → Elicit from user, save answer, continue
```

Elicitation is skipped when `MAESTRO_CI=true`. In CI mode, missing elicitable values cause the skill to fall back to its default (or no-op) without blocking. See the ci-mode skill.

## Elicitable Config Values

Only non-sensitive config values are elicitable. Secrets (API keys, tokens, passwords) are never elicited — they must be set in environment variables or via secure credential management.

| Skill | Config Key | Elicitation Prompt |
|-------|-----------|-------------------|
| kanban | `integrations.kanban.provider` | "Which project management tool do you use?" |
| brain | `integrations.knowledge_base.provider` | "Do you use a second brain (Obsidian, Notion)?" |
| brain | `integrations.knowledge_base.vault_path` | "Where is your Obsidian vault?" |
| notify | `notifications.providers.slack.webhook_url` | "What's your Slack webhook URL?" (non-secret endpoint) |
| notify | `notifications.providers.discord.webhook_url` | "What's your Discord webhook URL?" |
| kanban | `integrations.kanban.project_id` | "What's your [provider] project ID?" |
| ci-mode | `ci_mode.fail_fast` | "Should Maestro stop on first failure in CI?" |

### What Is NOT Elicitable

| Value | Reason |
|-------|--------|
| `ANTHROPIC_API_KEY` | Secret — use environment variable |
| `MAESTRO_WEBHOOK_SECRET` | Secret — use environment variable |
| Slack bot tokens | Secret — use environment variable |
| OAuth tokens | Secret — use environment variable |
| Database passwords | Secret — use environment variable |

If a skill needs a secret that is not set, it warns the user with the correct environment variable name and falls back gracefully. It never elicits secrets.

## Elicitation Prompt Format

Elicitation prompts use a consistent format to distinguish them from regular agent output:

```
+---------------------------------------------+
| Maestro needs one thing to continue         |
+---------------------------------------------+

  Setting up kanban sync, but no provider is configured.

  Which project management tool do you use?

  [1] GitHub Issues   — uses gh CLI, no extra setup
  [2] Jira            — requires Atlassian MCP Server
  [3] Linear          — requires Linear MCP Server
  [4] None            — skip kanban sync

  Your answer will be saved to .maestro/config.yaml.
  Run /maestro config to change it later.
```

For free-text values (vault path, webhook URL), the prompt uses a text input:

```
+---------------------------------------------+
| Maestro needs one thing to continue         |
+---------------------------------------------+

  Second brain is set to Obsidian, but no vault path is configured.

  Where is your Obsidian vault?
  (Example: /Users/rodrigo/Documents/my-vault)

  > _
```

## Saving Elicited Values

After the user responds, Maestro immediately writes the value to `.maestro/config.yaml`:

1. Read the current config file
2. Write the elicited value to the correct key path
3. Log: `(i) Saved [config.key] to .maestro/config.yaml`
4. Continue the skill without restarting

The value persists across sessions — elicitation runs once per missing key, not once per session.

## Integration with Onboarding

The `onboarding` skill asks 4 setup questions up front. Elicitation handles the rest — any config value not covered by onboarding is collected at first use.

This means:
- Onboarding stays at 4 questions (no bloat)
- Users who skip onboarding still get a smooth first-use experience
- Power users who configure manually never see elicitation prompts

```
First-time user                    Power user
       |                                |
  /maestro init                  Edits config.yaml
       |                                |
  onboarding (4 Q)               Runs /maestro
       |                                |
  Starts building                 Kanban sync fires
       |                                |
  Adds kanban story         vault_path is null
       |                                |
  kanban.provider = null         Elicitation fires
       |                                |
  Elicitation fires              Answers once
       |                                |
  Answers once                   Continues
       |
  Continues
```

## Implementation Pattern

Skills that support elicitation follow this pattern when reading a config key:

```
function get_config_with_elicitation(key, elicit_prompt):
    value = read .maestro/config.yaml key
    if value is null or absent:
        if MAESTRO_CI:
            return null    # no-op in CI, never block
        answer = elicit(elicit_prompt)
        if answer is not null:
            write answer to .maestro/config.yaml at key
            return answer
        return null
    return value
```

Skills must gracefully handle a `null` return from this function — elicitation can be dismissed by the user ("None / Skip").

## CI Mode Behavior

When `MAESTRO_CI=true`, all elicitation is suppressed. Missing config values result in the skill's fallback behavior:

| Skill | Missing config | CI fallback |
|-------|---------------|-------------|
| kanban | `provider: null` | No kanban sync, continue |
| brain | `vault_path: null` | No brain sync, continue |
| notify | `webhook_url: null` | No notification, continue |

A `warn` event is emitted to the JSON output stream when a CI fallback occurs:

```json
{
  "level": "warn",
  "event": "config.missing",
  "data": {
    "key": "integrations.kanban.provider",
    "skill": "kanban",
    "action": "skipped"
  }
}
```

## Error Handling

| Condition | Behavior |
|-----------|----------|
| User dismisses prompt ("None") | Write `null` to config, continue with fallback |
| Elicitation times out | Treat as dismissed, log warn |
| Config file not writable | Warn, use value for session only (not persisted) |
| Elicitation in CI mode | Skip, use fallback, emit `config.missing` warn event |
| Secret key accidentally marked elicitable | Log error, never elicit, fall back |

## Configuration

```yaml
elicitation:
  enabled: true          # set false to disable all elicitation (fall back to manual config)
  save_on_answer: true   # persist answers to .maestro/config.yaml immediately
  prompt_style: box      # box | inline — box uses the framed format, inline is compact
```
