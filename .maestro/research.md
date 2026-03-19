# OpenClaw Research: Installation, Startup, and Day-to-Day Flow

**Research date:** 2026-03-18
**Sources:** docs.openclaw.ai, github.com/openclaw/openclaw, npm, brew, multiple tutorials

---

## 1. How to INSTALL OpenClaw

There are four supported methods. All require Node >= 22 (Node 24 recommended).

### Method A — One-line installer script (recommended for new users)

macOS / Linux / WSL2:
```bash
curl -fsSL https://openclaw.ai/install.sh | bash
```

Skip the interactive onboarding if you want to do it manually later:
```bash
curl -fsSL https://openclaw.ai/install.sh | bash -s -- --no-onboard
```

Windows (PowerShell):
```powershell
iwr -useb https://openclaw.ai/install.ps1 | iex
# Skip onboarding variant:
& ([scriptblock]::Create((iwr -useb https://openclaw.ai/install.ps1))) -NoOnboard
```

### Method B — npm global install

```bash
npm install -g openclaw@latest
```

### Method C — pnpm global install

```bash
pnpm add -g openclaw@latest
pnpm approve-builds -g   # required after pnpm install
```

### Method D — Homebrew (macOS/Linux binary)

OpenClaw is published as `openclaw-cli` on Homebrew Formulae with bottle (pre-built binary) support:
```bash
brew install openclaw-cli
```
Source: https://formulae.brew.sh/formula/openclaw-cli

### Method E — Build from source

```bash
git clone https://github.com/openclaw/openclaw.git
cd openclaw
pnpm install
pnpm ui:build
pnpm build
pnpm link --global
```

### Method F — Install from GitHub main branch directly

```bash
npm install -g github:openclaw/openclaw#main
# or
pnpm add -g github:openclaw/openclaw#main
```

---

## 2. How to START for the First Time

After installing the CLI binary, the canonical first-run command is:

```bash
openclaw onboard --install-daemon
```

This is an interactive wizard that walks through:
- Workspace directory (default `~/.openclaw/workspace`)
- LLM provider selection and API key entry (Anthropic, OpenAI, Mistral, Ollama local)
- Gateway port (default 18789) and bind address
- Channel setup (Telegram, WhatsApp, Discord, etc.)
- Skills activation
- Daemon registration (launchd on macOS, systemd on Linux)

Key `onboard` flags:
```
--workspace <dir>          # agent workspace path
--reset                    # clear config, creds, and sessions
--reset-scope <scope>      # config | config+creds+sessions | full
--non-interactive          # skip all prompts (CI/headless use)
--mode <local|remote>      # local = gateway runs here; remote = connect to existing
--flow <quickstart|advanced|manual>
--auth-choice <provider>
--anthropic-api-key <key>
--openai-api-key <key>
--gateway-port <port>
--gateway-bind <loopback|lan|tailnet|auto|custom>
--tailscale <off|serve|funnel>
--node-manager <npm|pnpm|bun>
--json                     # machine-readable output
```

After onboarding, verify everything works:
```bash
openclaw doctor    # health checks and config validation
openclaw status    # gateway status and linked session health
openclaw dashboard # open browser UI at http://127.0.0.1:18789/
```

---

## 3. How the Gateway Daemon Gets Registered

The `--install-daemon` flag in `openclaw onboard` (or `openclaw gateway install`) registers the Gateway as a persistent background service.

### macOS — launchd LaunchAgent

The installer creates a plist at:
```
~/Library/LaunchAgents/com.openclaw.gateway.plist
```

Managed via launchctl:
```bash
launchctl kickstart -k gui/$UID/bot.molt.gateway   # start / restart
launchctl bootout gui/$UID/bot.molt.gateway         # stop
```

Or via the CLI abstraction:
```bash
openclaw gateway install    # register the service
openclaw gateway start
openclaw gateway stop
openclaw gateway restart
openclaw gateway status
openclaw gateway uninstall  # remove service registration
```

The manual plist (when not using the CLI installer) looks like:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>com.openclaw.gateway</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/local/bin/openclaw</string>
    <string>gateway</string>
    <string>start</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/tmp/openclaw-gateway.log</string>
  <key>StandardErrorPath</key><string>/tmp/openclaw-gateway-error.log</string>
</dict>
</plist>
```
Load it manually:
```bash
launchctl load ~/Library/LaunchAgents/com.openclaw.gateway.plist
```

### Linux — systemd user service

The installer creates a systemd unit. Manual equivalent at `/etc/systemd/system/openclaw.service`:
```ini
[Unit]
Description=OpenClaw Gateway
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/home/youruser
ExecStart=/usr/local/bin/openclaw gateway start
Restart=on-failure
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
```

```bash
sudo systemctl daemon-reload
sudo systemctl enable openclaw
sudo systemctl start openclaw
```

### Alternative — pm2 process manager

```bash
npm install -g pm2
pm2 start "openclaw gateway start" --name openclaw
pm2 save
pm2 startup
```

### Alternative — foreground / nohup

```bash
openclaw gateway --port 18789          # foreground (dev/debug)
nohup openclaw gateway start &         # detached, no daemon
```

---

## 4. What Happens When You Open a Terminal

If the daemon was installed via `--install-daemon`:
- The Gateway is ALREADY running in the background when you open a terminal. It started at login via launchd/systemd.
- You do not need to run any start command.
- The gateway listens at `http://127.0.0.1:18789/` by default.
- The heartbeat runs every 30 minutes (every hour with Anthropic OAuth). On each heartbeat, the agent reads `HEARTBEAT.md` in the workspace, decides whether to act, and either messages you or responds `HEARTBEAT_OK`.

Check gateway state:
```bash
openclaw gateway status     # probe RPC and service state
openclaw health             # fetch gateway /health endpoint
curl http://localhost:18789/health   # raw HTTP check
```

If the daemon was NOT installed (manual foreground mode):
- You must run `openclaw gateway --port 18789` in a terminal each session.
- Closing that terminal stops the gateway.

---

## 5. How to Connect Messaging Channels

### Telegram (simplest first channel)

1. Open Telegram, message `@BotFather`, run `/newbot`, save the token.

2. Add token to config `~/.openclaw/openclaw.json`:
```json5
{
  channels: {
    telegram: {
      enabled: true,
      botToken: "123:abc",
      dmPolicy: "pairing",
      groups: { "*": { requireMention: true } },
    },
  },
}
```
Or via env var: `TELEGRAM_BOT_TOKEN=123:abc`

3. Start/restart the gateway:
```bash
openclaw gateway restart
```

4. Send the bot a DM in Telegram. A pairing code appears in the gateway log.

5. Approve the pairing:
```bash
openclaw pairing list telegram
openclaw pairing approve telegram <CODE>
```

Note: Pairing codes expire after 1 hour.

Key Telegram config options:
- `dmPolicy`: `pairing` | `allowlist` | `open` | `disabled`
- `allowFrom`: array of numeric Telegram user IDs (for allowlist mode)
- `groupPolicy`: `open` | `allowlist` | `disabled`
- `requireMention`: boolean — whether bot must be @mentioned in groups

Important: Telegram does NOT use `openclaw channels login telegram`. The token goes directly in config or env, unlike WhatsApp which uses a QR login flow.

### Other channels via CLI wizard

```bash
openclaw channels add --channel slack
openclaw channels add --channel discord
openclaw channels add --channel whatsapp
openclaw channels add --channel signal
openclaw channels add --channel imessage
openclaw channels add --channel msteams
openclaw channels add --channel googlechat
openclaw channels add --channel mattermost
```

Supported channels: whatsapp, telegram, discord, googlechat, slack, mattermost, signal, imessage, msteams (plus 25+ others including Matrix, IRC, Twitch).

WhatsApp uses a QR-code web session login:
```bash
openclaw channels login --channel whatsapp
```

Check channel health:
```bash
openclaw channels list
openclaw channels status --probe
openclaw channels logs --channel telegram
```

Slack uses the Bolt framework. Teams without inbound HTTP can use Socket Mode. The Slack app requires scopes and event delivery configuration done during `openclaw channels add --channel slack`.

Multi-channel: Each channel adapter runs in its own lightweight thread. Multiple channels can run simultaneously without performance degradation. Start with one, verify responses, then add more.

---

## 6. Day-to-Day Usage Flow

Once running, OpenClaw is primarily used by talking to it through a connected messaging channel — you send a natural language message to your bot in Telegram, WhatsApp, Discord, etc., and it responds there. No commands needed. You just talk to it.

### Option A — Chat through messaging app (primary use)
Just send a message to your bot in Telegram/Slack/Discord/WhatsApp. No terminal needed.

### Option B — Terminal UI (TUI)
Interactive terminal dashboard showing active channels, request/response logs, model usage, memory state:
```bash
openclaw tui
openclaw tui --url ws://127.0.0.1:18789 --session main
```

### Option C — Direct agent call from CLI
```bash
openclaw agent --message "Ship checklist" --thinking high
openclaw agent --message "Summarize my emails" --deliver --channel telegram
```

### Option D — Send a message to a specific recipient
```bash
openclaw message send --to +1234567890 --message "Hello"
openclaw message send --target @user --channel slack --message "Deploy done"
```

### Option E — Browser dashboard
```bash
openclaw dashboard
# opens http://127.0.0.1:18789/ in browser
```

### Configuration changes
```bash
openclaw config get channels.telegram.dmPolicy
openclaw config set channels.telegram.dmPolicy open
openclaw config edit                   # opens config in $EDITOR
openclaw gateway restart               # apply changes
```

---

## 7. How `openclaw onboard` Works

`openclaw onboard` is the interactive setup wizard. When run with `--install-daemon` it covers:

1. **Gateway setup** — port selection (default 18789), bind address, auth token generation
2. **Workspace init** — creates `~/.openclaw/workspace/` with `HEARTBEAT.md`, `AGENTS.md`, memory files
3. **LLM auth** — walks through provider selection (Anthropic, OpenAI, Mistral, Ollama) and API key entry
4. **Channel setup** — optional Telegram/WhatsApp/Discord pairing
5. **Skills activation** — enables relevant skills based on answers
6. **Daemon install** — registers the Gateway as launchd (macOS) or systemd (Linux) service so it survives reboots
7. **Health check** — runs `openclaw doctor` automatically to verify everything

Non-interactive / scripted onboard (CI or headless):
```bash
openclaw onboard \
  --non-interactive \
  --mode local \
  --flow quickstart \
  --anthropic-api-key sk-ant-... \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --install-daemon
```

Reset and re-run onboarding:
```bash
openclaw onboard --reset --reset-scope full
```

---

## 8. The macOS Menu Bar App

The macOS companion app is a native Swift application located in `apps/macos/` in the repo. It is a menu-bar-resident app with no Dock icon.

### What it does
- Sits permanently in the macOS top bar (next to Wi-Fi, battery, clock)
- Clicking the icon drops a floating panel for: typing a message, seeing recent activity, triggering quick actions, monitoring agent status
- Owns macOS TCC permission prompts: Notifications, Accessibility, Screen Recording, Microphone, Speech Recognition, Automation/AppleScript
- Manages and attaches to the Gateway locally (via launchd or manually)
- Exposes the Mac as a **node** to the Gateway over WebSocket at `ws://127.0.0.1:18789`
- The app connects to the same Gateway that the CLI and web UI use (standard WebSocket RPC, Bearer token auth)

### Icon states
- Idle: normal icon
- Working (main session): full-tint badge with animation + activity glyph (exec/read/write/edit/attach)
- Working (other session): muted badge, no animation
- Status bar label format: `"Main · exec: pnpm test"` or `"Other · read: [path]"`
- Debug override: Settings > Debug > "Icon override"

### Gateway management from the app
```bash
openclaw gateway install   # register launchd service (same as --install-daemon)
launchctl kickstart -k gui/$UID/bot.molt.gateway
launchctl bootout gui/$UID/bot.molt.gateway
```

### Node capabilities exposed when app is running
When the macOS app is running and connected, the agent gains access to macOS-specific tools:
- `canvas.present`, `canvas.navigate`, `canvas.eval` — overlay/canvas operations
- `camera.snap`, `camera.clip` — webcam capture
- `screen.record` — screen recording
- `system.run` — shell execution
- `system.notify` — macOS notification delivery

CLI equivalents for remote node control:
```bash
openclaw nodes canvas snapshot --node myMac
openclaw nodes camera snap --node myMac --facing front
openclaw nodes screen record --node myMac --duration 10s
openclaw nodes notify --node myMac --title "Done" --body "Deploy complete"
openclaw nodes run --node myMac ls -la
```

### Building the app from source
```bash
cd apps/macos
swift build
# or use the package script:
scripts/package-mac-app.sh
```

---

## 9. Minimal Setup to Run OpenClaw Autonomously

The smallest path to a fully autonomous, always-on agent:

```bash
# Step 1: Install
npm install -g openclaw@latest

# Step 2: Onboard with daemon (interactive — recommended path)
openclaw onboard --install-daemon

# Step 2 (alternative): fully non-interactive
openclaw onboard \
  --non-interactive \
  --anthropic-api-key sk-ant-YOUR_KEY \
  --gateway-port 18789 \
  --gateway-bind loopback \
  --install-daemon

# Step 3: Add a channel (Telegram is fastest)
# Edit ~/.openclaw/openclaw.json directly or:
openclaw config set channels.telegram.enabled true
openclaw config set channels.telegram.botToken "123:abc"
openclaw config set channels.telegram.dmPolicy open
openclaw gateway restart

# Step 4: Verify
openclaw doctor
openclaw gateway status
openclaw channels status --probe

# Step 5: Message the bot in Telegram — it responds immediately
# (if dmPolicy is "pairing", run: openclaw pairing approve telegram <CODE>)
```

After this, the gateway runs on every login via launchd/systemd. The agent wakes on:
- Incoming messages on connected channels
- Heartbeat timer (every 30 min — reads `~/.openclaw/workspace/HEARTBEAT.md` and acts or responds `HEARTBEAT_OK`)
- `openclaw system event --text "..." --mode now` (manual trigger)
- Cron jobs: `openclaw cron add --name daily-report --every 24h --system-event`

No terminal needs to be open.

---

## Technical Patterns

- Gateway runs on port 18789 by default (configurable via `openclaw config set gateway.port <port>` or `--port` flag)
- All clients (CLI, TUI, browser, macOS app, mobile) connect via WebSocket RPC to the same gateway at `ws://127.0.0.1:18789`
- Authentication: Bearer token via `Authorization` header (generated during onboard or via `openclaw doctor --generate-gateway-token`)
- Config file: `~/.openclaw/openclaw.json` (JSON5 format — allows comments)
- Workspace: `~/.openclaw/workspace/` — contains `HEARTBEAT.md`, `AGENTS.md`, memory files the agent reads and writes
- State isolation: `--dev` flag uses `~/.openclaw-dev`; `--profile <name>` uses `~/.openclaw-<name>`
- Multi-agent: `openclaw agents add <name>` creates isolated agents; `openclaw agents bind` routes specific channels to specific agents
- Model fallback: `openclaw models fallbacks add <model>` — agent tries fallbacks on provider failure
- `openclaw daemon` is a legacy alias for `openclaw gateway` service commands (status/install/start/stop/restart)

---

## Sources

- [Install - OpenClaw](https://docs.openclaw.ai/install)
- [CLI Reference - OpenClaw](https://docs.openclaw.ai/cli)
- [Telegram - OpenClaw](https://docs.openclaw.ai/channels/telegram)
- [Menu Bar - OpenClaw](https://docs.openclaw.ai/platforms/mac/menu-bar)
- [OpenClaw Docs Index](https://docs.openclaw.ai/llms.txt)
- [GitHub - openclaw/openclaw](https://github.com/openclaw/openclaw)
- [openclaw-cli - Homebrew](https://formulae.brew.sh/formula/openclaw-cli)
- [openclaw - npm](https://www.npmjs.com/package/openclaw)
- [OpenClaw Gateway: Daemon & Headless Mode - CrewClaw](https://www.crewclaw.com/blog/openclaw-gateway-daemon-guide)
- [OpenClaw Gateway Commands: Port 18789 Setup - Meta Intelligence](https://www.meta-intelligence.tech/en/insight-openclaw-gateway-commands)
- [macOS App - OpenClaw](https://openclawcn.com/en/docs/platforms/macos/)
- [macOS App Installation - DeepWiki](https://deepwiki.com/openclaw/openclaw/2.4-macos-app-installation)
- [Channel Architecture - DeepWiki](https://deepwiki.com/openclaw/openclaw/4.1-channel-architecture)
- [How to Install OpenClaw 2026 - Medium](https://medium.com/@guljabeen222/how-to-install-openclaw-2026-the-complete-step-by-step-guide-516b74c163b9)
- [How to Install and Run OpenClaw on Mac - Medium/Zilliz](https://medium.com/@zilliz_learn/how-to-install-and-run-openclaw-previously-clawdbot-moltbot-on-mac-9cb6adb64eef)
