---
name: setup
description: "Complete autonomous setup wizard — connect services, configure autonomy, set up notifications in one guided flow"
argument-hint: "[quick|full|services|autonomy|notifications]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
  - Glob
  - Grep
  - ToolSearch
---

# Maestro Setup Wizard

Unified autonomous setup wizard. Configure services, autonomy, and notifications in one guided flow.

## Subcommand Dispatch

Check the argument passed to this command:

- No argument or `full` → run all 5 phases (Welcome, Services, Autonomy, Notifications, Summary)
- `quick` → Phase 1 check only, then auto-detect and apply defaults, then Phase 5 Summary
- `services` → Phase 2 only (Service Discovery & Connection)
- `autonomy` → Phase 3 only (Autonomy Configuration)
- `notifications` → Phase 4 only (Notification Setup)

---

## Phase 1: Welcome & Project Check

Display:

```
+---------------------------------------------+
| Maestro Autonomous Setup                    |
+---------------------------------------------+
  Welcome! This wizard will configure Maestro
  for autonomous operation in 4 steps:

  1. Connect external services
  2. Set up credentials
  3. Configure autonomy mode
  4. Set up notifications

  Estimated time: 3-5 minutes
```

Check if `.maestro/dna.md` exists in the current project directory.

If `.maestro/dna.md` does NOT exist:

Use AskUserQuestion:
- Question: "Project DNA not found. Maestro needs to be initialized before setup can continue."
- Header: "Init Required"
- Options:
  1. label: "Run /maestro init now", description: "Initialize the project first, then return to setup"
  2. label: "Cancel setup", description: "Exit the wizard — run /maestro init first"

If the user chooses "Run /maestro init now", execute the init command flow, then return to continue setup from Phase 2.

If `.maestro/dna.md` exists, proceed directly to Phase 2.

**Quick mode shortcut:** If the `quick` argument was passed, skip the welcome display, run the DNA check silently, then proceed to auto-configure using defaults (documented at the end of this file). Skip to Phase 5 after auto-configuration.

---

## Phase 2: Service Discovery & Connection

### 2a: Auto-Detect Available Services

Run these checks silently and collect results:

```bash
# CLI tool detection
command -v gh >/dev/null 2>&1 && echo "gh:found" || echo "gh:missing"
command -v aws >/dev/null 2>&1 && echo "aws:found" || echo "aws:missing"
command -v vercel >/dev/null 2>&1 && echo "vercel:found" || echo "vercel:missing"
command -v doctl >/dev/null 2>&1 && echo "doctl:found" || echo "doctl:missing"
command -v wrangler >/dev/null 2>&1 && echo "wrangler:found" || echo "wrangler:missing"
command -v firebase >/dev/null 2>&1 && echo "firebase:found" || echo "firebase:missing"
command -v netlify >/dev/null 2>&1 && echo "netlify:found" || echo "netlify:missing"
command -v fly >/dev/null 2>&1 && echo "fly:found" || echo "fly:missing"

# Environment variable detection (existence only — never print values)
[ -n "$AWS_ACCESS_KEY_ID" ] && echo "aws_key:set" || echo "aws_key:missing"
[ -n "$GITHUB_TOKEN" ] || [ -n "$GH_TOKEN" ] && echo "github_token:set" || echo "github_token:missing"
[ -n "$VERCEL_TOKEN" ] && echo "vercel_token:set" || echo "vercel_token:missing"
[ -n "$STRIPE_API_KEY" ] && echo "stripe_token:set" || echo "stripe_token:missing"
[ -n "$TELEGRAM_BOT_TOKEN" ] && echo "telegram_token:set" || echo "telegram_token:missing"
[ -n "$SENDGRID_API_KEY" ] && echo "sendgrid_token:set" || echo "sendgrid_token:missing"
[ -n "$SLACK_WEBHOOK_URL" ] && echo "slack_webhook:set" || echo "slack_webhook:missing"
[ -n "$DISCORD_WEBHOOK_URL" ] && echo "discord_webhook:set" || echo "discord_webhook:missing"
[ -n "$DO_ACCESS_TOKEN" ] && echo "do_token:set" || echo "do_token:missing"
[ -n "$CLOUDFLARE_API_TOKEN" ] && echo "cf_token:set" || echo "cf_token:missing"
[ -n "$FLY_API_TOKEN" ] && echo "fly_token:set" || echo "fly_token:missing"
[ -n "$FIREBASE_TOKEN" ] && echo "firebase_token:set" || echo "firebase_token:missing"
[ -n "$NETLIFY_AUTH_TOKEN" ] && echo "netlify_token:set" || echo "netlify_token:missing"
```

Also use ToolSearch to detect MCP servers:
- Check for `mcp__asana__` prefix → Asana
- Check for `mcp__atlassian__` prefix → Jira/Confluence
- Check for `mcp__linear__` prefix → Linear
- Check for `mcp__notion__` prefix → Notion
- Check for `mcp__plugin_playwright_playwright__` prefix → Playwright

### 2b: Classify Each Service

For each service, assign a status based on the detection results:

| Status | Meaning |
|--------|---------|
| `(ok)` | CLI found AND credentials/token set |
| `(i)`  | CLI found OR token set, but not both |
| `--`   | Neither CLI nor credentials detected |

### 2c: Display Service Report

Present findings (only show services where something was detected OR commonly-used services):

```
+---------------------------------------------+
| Detected Services                           |
+---------------------------------------------+
  (ok) GitHub        gh CLI found, GITHUB_TOKEN set
  (ok) AWS           aws CLI found, credentials set
  (i)  Vercel        vercel CLI found, no token
  (i)  Telegram      TELEGRAM_BOT_TOKEN set
  --   Stripe        not detected
  --   SendGrid      not detected
  --   DigitalOcean  not detected
  --   Cloudflare    not detected
```

Always show: GitHub, AWS, Vercel, Telegram, Slack, Discord, Stripe, SendGrid.
Show additional services only if they were detected.

### 2d: Ask Which Services to Connect

Use AskUserQuestion:
- Question: "Which services do you want to connect?"
- Header: "Services"
- multiSelect: true
- Options (pre-highlight those with `(ok)` or `(i)` status):
  - Each detected service as an option with its current status in the description
  - label: "Skip — I'll connect services later", description: "Proceed to autonomy configuration"

If the user selects "Skip", move to Phase 3.

### 2e: Run Connection Flow Per Service

For each selected service, run a targeted connection and health-check flow.

**GitHub:**
1. Check if `gh auth status` succeeds.
2. If not authenticated: display `[maestro] Run: gh auth login` and wait.
3. After authentication, validate: `gh api user --jq .login`
4. Write result to `.maestro/services.yaml` under `github`.

**AWS:**
1. Run `aws sts get-caller-identity` to check existing credentials.
2. If fails: display `[maestro] Run: aws configure — enter your access key and secret`
3. After configure, re-run health check.
4. Write result to `.maestro/services.yaml` under `aws`.

**Vercel:**
1. Check `VERCEL_TOKEN` env var. If missing:
   ```
   [maestro] To get a Vercel token:
     1. Go to vercel.com/account/tokens
     2. Create a new token
     3. Set it: export VERCEL_TOKEN="your-token"
   ```
2. If token set, validate: `vercel whoami`
3. Write result to `.maestro/services.yaml` under `vercel`.

**Telegram:**
1. Check `TELEGRAM_BOT_TOKEN` env var. If missing, display setup instructions (see skills/quick-connect/SKILL.md).
2. If token set, validate: `curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe" | grep -q '"ok":true'`
3. Write result to `.maestro/services.yaml` under `telegram`.

**Slack:**
1. Check `SLACK_WEBHOOK_URL` env var. If missing:
   ```
   [maestro] To get a Slack webhook:
     1. Go to api.slack.com/apps
     2. Create an app > Incoming Webhooks
     3. Set it: export SLACK_WEBHOOK_URL="your-webhook"
   ```
2. Validate: `curl -s -X POST "$SLACK_WEBHOOK_URL" -d '{"text":"Maestro test"}'`
3. Write result to `.maestro/services.yaml` under `slack`.

**Discord:**
1. Check `DISCORD_WEBHOOK_URL` env var. If missing:
   ```
   [maestro] To get a Discord webhook:
     1. Channel Settings > Integrations > Webhooks
     2. Create Webhook, copy URL
     3. Set it: export DISCORD_WEBHOOK_URL="your-webhook"
   ```
2. Validate by sending a test message.
3. Write result to `.maestro/services.yaml` under `discord`.

After all connections, display a compact result:

```
[maestro] Services configured:
  (ok) GitHub     connected (user: octocat)
  (ok) AWS        connected (account: 123456789)
  (x)  Vercel     skipped — token not set
```

---

## Phase 3: Autonomy Configuration

### 3a: Choose Autonomy Mode

Use AskUserQuestion:
- Question: "How autonomous should Maestro be?"
- Header: "Autonomy"
- Options:
  1. label: "Tiered — Auto for free actions, ask for spending over $50 (Recommended)", description: "Balanced: runs freely until a spending threshold is reached"
  2. label: "Full Auto — Do everything without asking", description: "Best for overnight runs. Maestro acts without confirmation."
  3. label: "Manual — Always ask before external actions", description: "Maximum control. You confirm every external action."

Map selections to config values:
- "Tiered" → `autonomy_mode: tiered`
- "Full Auto" → `autonomy_mode: full_auto`
- "Manual" → `autonomy_mode: manual`

### 3b: Set Spending Limits (only for tiered mode)

If the user chose "Tiered", use AskUserQuestion:
- Question: "Set spending limits?"
- Header: "Limits"
- Options:
  1. label: "Moderate ($50/action, $500/session, $1000/day) (Recommended)", description: "Suitable for most projects and team workflows"
  2. label: "Conservative ($25/action, $200/session, $500/day)", description: "Minimizes spend — prompts more often"
  3. label: "Liberal ($200/action, $2000/session, $5000/day)", description: "High-throughput workloads with large budgets"
  4. label: "Custom", description: "Enter your own per-action, per-session, and daily limits"

If "Custom" is selected, use AskUserQuestion for each limit:
- Question: "Per-action spending limit (USD)?" (free text)
- Question: "Per-session spending limit (USD)?" (free text)
- Question: "Daily spending limit (USD)?" (free text)

For "Full Auto" and "Manual" modes, skip spending limits. Use null for all limits.

---

## Phase 4: Notification Setup

### 4a: Choose Notification Channels

Use AskUserQuestion:
- Question: "Where should Maestro send notifications?"
- Header: "Notify"
- multiSelect: true
- Options:
  1. label: "Terminal only (default)", description: "No external push — all output stays in the terminal"
  2. label: "Telegram", description: "Push to a Telegram bot (requires bot token + chat ID)"
  3. label: "Slack", description: "Push to a Slack channel (requires webhook URL)"
  4. label: "Discord", description: "Push to a Discord channel (requires webhook URL)"

### 4b: Collect Provider Credentials (if not already set from Phase 2)

**Telegram** (if selected and `TELEGRAM_BOT_TOKEN` not set):
Use AskUserQuestion:
- Question: "Enter your Telegram bot token:"
- Header: "Telegram"
- Options (free text, fallback — display instructions):
  ```
  [maestro] To get a Telegram bot token:
    1. Message @BotFather on Telegram
    2. Send /newbot and follow the prompts
    3. Copy the bot token provided
  ```

Then ask for chat ID:
```
[maestro] To get your chat ID:
  1. Send any message to your bot
  2. Run: curl https://api.telegram.org/bot$TOKEN/getUpdates
  3. Look for "chat":{"id": ...} in the response
```

**Slack** (if selected and `SLACK_WEBHOOK_URL` not set):
Display:
```
[maestro] To get a Slack webhook URL:
  1. Go to api.slack.com/apps
  2. Create app > Incoming Webhooks > Add New Webhook
  3. Copy the webhook URL
  4. Set: export SLACK_WEBHOOK_URL="your-url"
```

**Discord** (if selected and `DISCORD_WEBHOOK_URL` not set):
Display:
```
[maestro] To get a Discord webhook URL:
  1. Open Discord > Channel Settings > Integrations
  2. Click Webhooks > New Webhook
  3. Copy webhook URL
  4. Set: export DISCORD_WEBHOOK_URL="your-url"
```

### 4c: Choose Notification Level

Use AskUserQuestion:
- Question: "How many notifications do you want?"
- Header: "Verbosity"
- Options:
  1. label: "Important — spending, errors, completions (Recommended)", description: "Notified when stories complete, QA fails, or budget thresholds hit"
  2. label: "All — every action and status update", description: "High volume — useful for debugging or monitoring"
  3. label: "Critical — failures and security only", description: "Minimal interruptions — only when action is required"

Map to config:
- "Important" → `notification_level: important`
- "All" → `notification_level: all`
- "Critical" → `notification_level: critical`

---

## Phase 5: Summary & Write Configuration

### 5a: Display Summary

```
+---------------------------------------------+
| Setup Complete                              |
+---------------------------------------------+
  Services:  [N] connected ([list])
  Autonomy:  [mode] ([limit summary if tiered])
  Notify:    [channels] ([level])

  (ok) Ready for autonomous operation!

  Quick start:
    /maestro "Build a landing page"
    /maestro chain run launch-website
    /maestro services health
```

### 5b: Write Configuration

Read the existing `.maestro/config.yaml` if it exists. Update (or create) `.maestro/config.yaml` with the values collected during setup. Preserve all existing fields — only overwrite the fields below:

```yaml
# Autonomy
autonomy_mode: [tiered|full_auto|manual]

spending_limits:
  per_action: [value or null]
  per_session: [value or null]
  per_day: [value or null]

# Notifications
notifications:
  enabled: [true if any external channel selected]
  level: [all|important|critical]
  providers:
    slack:
      webhook_url: [value or null]
    discord:
      webhook_url: [value or null]
    telegram:
      bot_token: [value or null]
      chat_id: [value or null]
  triggers:
    on_story_complete: true
    on_feature_complete: true
    on_qa_rejection: true
    on_self_heal_failure: true
    on_test_regression: true
```

Also write `.maestro/services.yaml` with the connection results from Phase 2:

```yaml
# Maestro Services — written by /maestro setup
# Last updated: [timestamp]

github:
  status: [connected|skipped|error]
  user: [github username or null]

aws:
  status: [connected|skipped|error]
  account: [account id or null]

vercel:
  status: [connected|skipped|error]

telegram:
  status: [connected|skipped|error]
  bot_name: [bot username or null]

slack:
  status: [connected|skipped|error]

discord:
  status: [connected|skipped|error]
```

Only include services that were offered during Phase 2. Set status to `skipped` for services the user did not choose to connect.

---

## Quick Mode (auto-configure with defaults)

When `quick` argument is passed:

1. Run Phase 1 DNA check (block if DNA missing).
2. Run Phase 2 detection silently — skip the connection flow, just record detected status.
3. Apply these defaults without asking:
   - Autonomy: `tiered`
   - Spending limits: Moderate ($50/action, $500/session, $1000/day)
   - Notifications: terminal only, `important` level
4. Write config and services.yaml.
5. Show Phase 5 Summary.

Display a note in the summary:
```
  (i) Quick mode applied defaults. Run /maestro setup to customize.
```

---

## Rules

- Never print credentials or token values — only print whether they are set or not.
- All user decisions use AskUserQuestion — no plain-text menus.
- The connect flow per service is best-effort: if a health check fails, log `(x)` and continue — do not block the wizard.
- If running a subcommand (services/autonomy/notifications), skip unrelated phases and go straight to Phase 5 to write partial config updates.
- Follow output-format standards: box-drawing, text indicators, `[maestro]` prefix.
