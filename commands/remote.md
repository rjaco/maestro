---
name: remote
description: "Manage remote control access — set up Telegram, Discord, or HTTP bot integrations to control Maestro from a phone or external service"
argument-hint: "[setup <provider>|status|disconnect]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - AskUserQuestion
---

# Maestro Remote

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
██████╗ ███████╗███╗   ███╗ ██████╗ ████████╗███████╗
██╔══██╗██╔════╝████╗ ████║██╔═══██╗╚══██╔══╝██╔════╝
██████╔╝█████╗  ██╔████╔██║██║   ██║   ██║   █████╗
██╔══██╗██╔══╝  ██║╚██╔╝██║██║   ██║   ██║   ██╔══╝
██║  ██║███████╗██║ ╚═╝ ██║╚██████╔╝   ██║   ███████╗
╚═╝  ╚═╝╚══════╝╚═╝     ╚═╝ ╚═════╝   ╚═╝   ╚══════╝
```

Control Maestro from your phone or any external service. Routes messages from Telegram, Discord, or HTTP to Claude Code via the Agent SDK. Run `/maestro status`, trigger builds, and receive alerts without opening a terminal.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show remote control status

Read `.maestro/config.yaml` for any `remote` configuration block.

```
+---------------------------------------------+
| Remote Control                              |
+---------------------------------------------+

  Provider:  <telegram|discord|http|none>
  Status:    <connected|disconnected|not configured>
  Bot file:  <path to bot process, if configured>

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Remote"
- Options:
  1. label: "Set up a provider", description: "Configure Telegram, Discord, or HTTP remote access"
  2. label: "Check connection status", description: "Verify the bot process is running"
  3. label: "Disconnect", description: "Remove remote control configuration"

### `setup <provider>` — Configure a remote control provider

Valid providers: `telegram` | `discord` | `http`

If provider is not provided or not recognized:

Use AskUserQuestion:
- Question: "Which remote control method would you like to set up?"
- Header: "Provider"
- Options:
  1. label: "Telegram", description: "Control Maestro via Telegram messages using a bot token"
  2. label: "Discord", description: "Control Maestro via Discord messages with the !m prefix"
  3. label: "HTTP", description: "Expose a local HTTP endpoint (use with Tailscale for remote access)"
  4. label: "Claude Code native", description: "Use claude --remote-control for built-in HTTP listener"

---

#### Telegram Setup

Use AskUserQuestion:
- Question: "Paste your Telegram Bot Token (from @BotFather):"
- Header: "Telegram Token"

Use AskUserQuestion:
- Question: "Paste your Telegram user ID (from @userinfobot). Only this ID will be allowed to send commands."
- Header: "Allowed User ID"

Use AskUserQuestion:
- Question: "What is the absolute path to the project directory Maestro should operate in?"
- Header: "Project Directory"

Write the configuration to `.maestro/config.yaml` under `remote.telegram`. Generate a bot process file at `.maestro/bots/telegram-bot.ts` using the Telegram (grammY) pattern from `skills/remote-control/SKILL.md`:

- Uses `grammy` for Telegram long-polling
- Calls `query()` from `@anthropic-ai/claude-agent-sdk`
- Maintains per-chat sessions in SQLite (`.maestro/bot-sessions.db`)
- Applies the allowlist check before processing any message
- Sends `<i>Running…</i>` immediately while the query executes
- Formats result as `<pre>...</pre>` using HTML parse mode
- Includes notification bridge for `[CHECKPOINT]`, `QA REJECTED`, and `Feature complete` markers

Display setup instructions:

```
+---------------------------------------------+
| Telegram Bot Setup                          |
+---------------------------------------------+

  Config saved to .maestro/config.yaml
  Bot file:   .maestro/bots/telegram-bot.ts

  To start the bot:
    cd .maestro/bots
    npx ts-node telegram-bot.ts

  To run as a background service:
    macOS:  launchd plist → ~/Library/LaunchAgents/com.maestro.telegram.plist
    Linux:  systemd unit  → /etc/systemd/system/maestro-telegram.service

  Test it:
    Send "status" to your bot in Telegram.

  Security:
    Allowed ID:  <user_id>
    Rate limit:  1 query / 30 seconds
    Sessions:    .maestro/bot-sessions.db

  (i) See skills/remote-control/SKILL.md for session management and security details.
```

---

#### Discord Setup

Use AskUserQuestion:
- Question: "Paste your Discord Bot Token (from the Discord Developer Portal):"
- Header: "Discord Token"

Use AskUserQuestion:
- Question: "Paste your Discord user ID. Only this ID will be allowed to send commands."
- Header: "Allowed User ID"

Use AskUserQuestion:
- Question: "What is the absolute path to the project directory Maestro should operate in?"
- Header: "Project Directory"

Write the configuration to `.maestro/config.yaml` under `remote.discord`. Generate a bot process file at `.maestro/bots/discord-bot.ts` using the Discord (discord.js) pattern from `skills/remote-control/SKILL.md`:

- Uses `discord.js` with `MessageContent` intent
- Triggers on messages starting with `!m ` (strips the prefix before passing to query)
- Calls `query()` from `@anthropic-ai/claude-agent-sdk`
- Maintains per-channel sessions in SQLite
- Chunks replies into 1900-character blocks to respect Discord's 2000-char limit

Display setup instructions:

```
+---------------------------------------------+
| Discord Bot Setup                           |
+---------------------------------------------+

  Config saved to .maestro/config.yaml
  Bot file:   .maestro/bots/discord-bot.ts

  Usage:
    In any Discord channel: !m <your command>
    Example: !m maestro status

  To start the bot:
    cd .maestro/bots
    npx ts-node discord-bot.ts

  Security:
    Allowed ID:  <user_id>
    Rate limit:  1 query / 30 seconds per channel

  (i) Consider using slash commands (/maestro) for better Discord UX.
```

---

#### HTTP Setup

Use AskUserQuestion:
- Question: "Which HTTP method would you like to use?"
- Header: "HTTP Method"
- Options:
  1. label: "Claude Code native (--remote-control)", description: "Built-in HTTP listener, no extra code needed"
  2. label: "Express API", description: "Custom HTTP endpoint at port 3100 for CI/CD and n8n integrations"

**Claude Code native:**

```
+---------------------------------------------+
| Claude Code Remote Control                  |
+---------------------------------------------+

  Start the listener:
    claude --remote-control --port 9000

  Send a command:
    curl -X POST http://192.168.1.10:9000/message \
      -H "Content-Type: application/json" \
      -d '{"message": "maestro status"}'

  Secure remote access (no public port required):
    1. Install Tailscale on both machines
    2. Use the Tailscale IP instead of local IP

  (i) Best for ad-hoc remote access from the same network.
```

**Express API:**

Generate `.maestro/bots/http-api.ts` using the Express pattern from `skills/remote-control/SKILL.md`. Generate a random `BOT_SECRET` token and write it to `.maestro/config.yaml` under `remote.http.secret`.

```
+---------------------------------------------+
| HTTP API Setup                              |
+---------------------------------------------+

  Config saved to .maestro/config.yaml
  Bot file:   .maestro/bots/http-api.ts
  Port:       3100
  Secret:     <generated token>

  To start the API:
    cd .maestro/bots
    npx ts-node http-api.ts

  Send a command:
    curl -X POST http://localhost:3100/maestro \
      -H "Content-Type: application/json" \
      -H "x-api-key: <secret>" \
      -d '{"prompt": "maestro status", "chat_id": "default"}'

  (i) Use with CI/CD webhooks, n8n automations, or any HTTP client.
  (i) Protect with Tailscale or a reverse proxy before exposing publicly.
```

### `status` — Check connection status

Read `.maestro/config.yaml` for `remote` configuration. Check if the configured bot process file exists.

Run `ps aux | grep maestro-bot` or equivalent to check if the daemon is running.

```
+---------------------------------------------+
| Remote Control Status                       |
+---------------------------------------------+

  Provider:    <telegram|discord|http|none>
  Bot file:    <path>
  Process:     <running (PID <N>) | not running | not configured>
  Sessions:    <N> active sessions in .maestro/bot-sessions.db

  Last command: <timestamp | never>
```

If the process is not running but was configured:

```
  (!) Bot process is not running.

  Restart with:
    npx ts-node .maestro/bots/<provider>-bot.ts

  To run as a persistent service, see:
    skills/remote-control/SKILL.md — "Background Service" section
```

If no provider is configured:

```
[maestro] No remote control provider configured.

  Set one up with:
    /maestro remote setup telegram
    /maestro remote setup discord
    /maestro remote setup http
```

### `disconnect` — Remove remote control configuration

Read `.maestro/config.yaml` for the active provider. If none is configured:

```
[maestro] No remote control provider is currently configured.
```

Use AskUserQuestion:
- Question: "Remove remote control configuration for '<provider>'? The bot process will need to be stopped manually."
- Header: "Confirm Disconnect"
- Options:
  1. label: "Yes, disconnect", description: "Remove config and session database"
  2. label: "Cancel", description: "Keep the remote control configured"

Remove the `remote` block from `.maestro/config.yaml`. Note: this does NOT stop a running bot process — the user must do that manually.

```
[maestro] Remote control configuration removed.

  (!) If the bot process is still running, stop it manually:
        ps aux | grep maestro-bot
        kill <PID>

  (i) Set up again with: /maestro remote setup <provider>
```

## Security Checklist

Before going live with any provider, verify:

- Allowlist contains only your personal user ID (not a group or channel)
- Rate limiting is set to 1 query / 30 seconds to prevent abuse
- `BOT_SECRET` header is enforced for HTTP endpoints
- `bypassPermissions` is only set in trusted local environments
- Environment variable values are redacted from output sent to chat
- A lock file at `/tmp/maestro-bot.lock` prevents duplicate daemon instances

## Error Handling

| Error | Action |
|-------|--------|
| Invalid bot token | Display error from provider, ask user to re-enter token |
| User ID not on allowlist | Silently ignore (no reply to unauthorized senders) |
| Agent SDK unavailable | Warn user, check Node.js and package installation |
| Session DB corrupted | Back up and recreate `.maestro/bot-sessions.db` |
| Rate limit exceeded | Reply "rate limit — try again in 30 seconds" |
| Bot process already running | Detect lock file, exit to prevent duplicates |
