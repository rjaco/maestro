---
name: quick-connect
description: "Service quick-connect templates. Step-by-step guided setup for individual external services — AWS, GitHub, Vercel, Telegram, Slack, Discord, Stripe, DigitalOcean, Cloudflare."
---

# Service Quick-Connect Templates

Streamlined setup flows for connecting individual external services. Each flow validates the connection at every step and writes the result to `.maestro/services.yaml`.

Called by:
- `/maestro connect [service]` — direct service setup
- `/maestro setup` Phase 2 — per-service connection within the wizard

## Dispatch

The argument to `/maestro connect` determines which flow to run:

| Argument | Flow |
|----------|------|
| `aws` | AWS Quick-Connect |
| `github` or `gh` | GitHub Quick-Connect |
| `vercel` | Vercel Quick-Connect |
| `telegram` | Telegram Quick-Connect |
| `slack` | Slack Quick-Connect |
| `discord` | Discord Quick-Connect |
| `stripe` | Stripe Quick-Connect |
| `digitalocean` or `do` | DigitalOcean Quick-Connect |
| `cloudflare` or `cf` | Cloudflare Quick-Connect |
| `netlify` | Netlify Quick-Connect |
| `fly` | Fly.io Quick-Connect |
| (no argument) | Show service menu |

If no argument is given, display:

```
+---------------------------------------------+
| Quick Connect                               |
+---------------------------------------------+
  Available services:

    aws          Amazon Web Services
    github       GitHub (gh CLI)
    vercel       Vercel deployment
    telegram     Telegram bot notifications
    slack        Slack webhook notifications
    discord      Discord webhook notifications
    stripe       Stripe payment integration
    digitalocean DigitalOcean cloud
    cloudflare   Cloudflare Workers / Pages
    netlify      Netlify deployment
    fly          Fly.io deployment

  Usage: /maestro connect [service]
```

---

## AWS Quick-Connect

### Step 1: Check CLI

```bash
command -v aws >/dev/null 2>&1 && echo "aws_cli:found" || echo "aws_cli:missing"
```

If missing:
```
[maestro] AWS CLI not found.

  Install it:
    macOS:  brew install awscli
    Linux:  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" \
            -o awscliv2.zip && unzip awscliv2.zip && sudo ./aws/install
    Docs:   docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html

  After installing, run: /maestro connect aws
```
Stop — do not continue if CLI is missing.

### Step 2: Check Existing Credentials

```bash
aws sts get-caller-identity 2>&1
```

If the command succeeds, extract account ID and ARN.

Display:
```
[maestro] (ok) AWS credentials already configured.
  Account: [account_id]
  ARN:     [arn]
```

Use AskUserQuestion:
- Question: "AWS is already connected. What would you like to do?"
- Header: "AWS"
- Options:
  1. label: "Keep existing credentials (Recommended)", description: "No changes — mark as connected"
  2. label: "Reconfigure", description: "Run aws configure to replace credentials"

### Step 3: Configure (if not already set or user chose reconfigure)

Display:
```
[maestro] Running: aws configure

  You will need:
    - AWS Access Key ID
    - AWS Secret Access Key
    - Default region (e.g., us-east-1)
    - Default output format (press Enter for json)

  Get keys at: console.aws.amazon.com > IAM > Users > Security credentials
```

Then run interactively (the user will see the prompts in their terminal):
```bash
aws configure
```

### Step 4: Validate

```bash
aws sts get-caller-identity
```

If successful:
```
[maestro] (ok) AWS connected.
  Account: [account_id]
  User:    [arn]
```

If failed:
```
[maestro] (x) AWS connection failed.
  [error message]

  Common causes:
    - Incorrect access key or secret
    - Key has insufficient permissions (needs sts:GetCallerIdentity)
    - Wrong region configured

  Try: aws configure (re-enter credentials)
```

### Step 5: Write to services.yaml

Update `.maestro/services.yaml`:

```yaml
aws:
  status: connected
  account: "[account_id]"
  region: "[configured_region]"
  last_validated: "[timestamp]"
```

---

## GitHub Quick-Connect

### Step 1: Check CLI

```bash
command -v gh >/dev/null 2>&1 && echo "gh_cli:found" || echo "gh_cli:missing"
```

If missing:
```
[maestro] GitHub CLI (gh) not found.

  Install it:
    macOS:  brew install gh
    Linux:  See github.com/cli/cli/blob/trunk/docs/install_linux.md
    Docs:   cli.github.com

  After installing, run: /maestro connect github
```
Stop if CLI is missing.

### Step 2: Check Auth Status

```bash
gh auth status 2>&1
```

If already authenticated, show current user and skip to Step 4.

### Step 3: Authenticate

Display:
```
[maestro] GitHub CLI not authenticated.

  Running: gh auth login

  You can authenticate with:
    - GitHub.com (browser or token)
    - GitHub Enterprise Server
```

```bash
gh auth login
```

### Step 4: Validate

```bash
gh api user --jq '.login'
```

If successful:
```
[maestro] (ok) GitHub connected.
  User: [github_username]
```

If failed:
```
[maestro] (x) GitHub connection failed.
  [error]

  Try: gh auth login --web
```

### Step 5: Write to services.yaml

```yaml
github:
  status: connected
  user: "[github_username]"
  last_validated: "[timestamp]"
```

---

## Vercel Quick-Connect

### Step 1: Check CLI

```bash
command -v vercel >/dev/null 2>&1 && echo "vercel_cli:found" || echo "vercel_cli:missing"
```

If missing:
```
[maestro] Vercel CLI not found.

  Install it:
    npm install -g vercel
    or: pnpm add -g vercel

  After installing, run: /maestro connect vercel
```
Stop if CLI is missing.

### Step 2: Check Token

```bash
[ -n "$VERCEL_TOKEN" ] && echo "token:set" || echo "token:missing"
```

If token is missing:
```
[maestro] VERCEL_TOKEN not set.

  To get a Vercel token:
    1. Go to vercel.com/account/tokens
    2. Click "Create Token"
    3. Give it a name (e.g., "maestro")
    4. Copy the token

  Then set it:
    export VERCEL_TOKEN="your-token-here"

  Add to your shell profile (~/.zshrc or ~/.bashrc) to persist it.
  After setting, run: /maestro connect vercel
```
Stop if token is missing.

### Step 3: Validate

```bash
vercel whoami
```

If successful:
```
[maestro] (ok) Vercel connected.
  User: [vercel_username]
```

### Step 4: Write to services.yaml

```yaml
vercel:
  status: connected
  user: "[vercel_username]"
  last_validated: "[timestamp]"
```

---

## Telegram Quick-Connect

### Step 1: Check Bot Token

```bash
[ -n "$TELEGRAM_BOT_TOKEN" ] && echo "token:set" || echo "token:missing"
```

If token is missing:
```
[maestro] TELEGRAM_BOT_TOKEN not set.

  To set up a Telegram bot:
    1. Open Telegram and message @BotFather
    2. Send: /newbot
    3. Follow the prompts to name your bot
    4. BotFather will give you a token like:
       1234567890:ABCdefGHIjklMNOpqrSTUvwxYZ

  Set it in your environment:
    export TELEGRAM_BOT_TOKEN="your-token"

  Add to ~/.zshrc or ~/.bashrc to persist it.
  After setting, run: /maestro connect telegram
```
Stop if token is missing.

### Step 2: Validate Bot API

```bash
curl -s "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe"
```

Parse the response. If `"ok":true`:
```
[maestro] (ok) Telegram bot reachable.
  Bot: @[bot_username]
```

If not OK:
```
[maestro] (x) Telegram bot API failed.
  Response: [api_response]

  Common causes:
    - Invalid token (check for typos)
    - Token revoked (create a new one via @BotFather)
```
Stop on validation failure.

### Step 3: Get Chat ID

```bash
[ -n "$TELEGRAM_CHAT_ID" ] && echo "chat_id:set" || echo "chat_id:missing"
```

If `TELEGRAM_CHAT_ID` is not set:
```
[maestro] TELEGRAM_CHAT_ID not set.

  To get your chat ID:
    1. Send any message to your bot in Telegram
    2. Run this command:
       curl https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getUpdates
    3. Look for "chat":{"id": ...} in the response
    4. That number is your chat ID

  Set it:
    export TELEGRAM_CHAT_ID="your-chat-id"

  After setting, run: /maestro connect telegram
```
Stop if chat ID is missing.

### Step 4: Send Test Message

```bash
curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
  -d "chat_id=$TELEGRAM_CHAT_ID" \
  -d "text=Maestro connected successfully!"
```

If successful:
```
[maestro] (ok) Telegram connected.
  Bot:     @[bot_username]
  Chat ID: [chat_id]
  (i) Test message sent — check your Telegram.
```

### Step 5: Write to services.yaml

```yaml
telegram:
  status: connected
  bot_name: "[bot_username]"
  chat_id: "[chat_id]"
  last_validated: "[timestamp]"
```

---

## Slack Quick-Connect

### Step 1: Check Webhook URL

```bash
[ -n "$SLACK_WEBHOOK_URL" ] && echo "webhook:set" || echo "webhook:missing"
```

If missing:
```
[maestro] SLACK_WEBHOOK_URL not set.

  To create a Slack webhook:
    1. Go to api.slack.com/apps
    2. Click "Create New App" > From scratch
    3. Name it "Maestro", choose your workspace
    4. Go to "Incoming Webhooks" > toggle On
    5. Click "Add New Webhook to Workspace"
    6. Choose a channel and click Allow
    7. Copy the webhook URL

  Set it:
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."

  After setting, run: /maestro connect slack
```
Stop if webhook is missing.

### Step 2: Validate

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST "$SLACK_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"text":"Maestro connected successfully!"}'
```

If HTTP 200:
```
[maestro] (ok) Slack connected.
  (i) Test message sent — check your channel.
```

If not 200:
```
[maestro] (x) Slack webhook failed (HTTP [code]).

  Common causes:
    - Webhook URL revoked or deleted
    - Wrong URL (check for extra spaces)

  Recreate at: api.slack.com/apps
```

### Step 3: Write to services.yaml

```yaml
slack:
  status: connected
  last_validated: "[timestamp]"
```

---

## Discord Quick-Connect

### Step 1: Check Webhook URL

```bash
[ -n "$DISCORD_WEBHOOK_URL" ] && echo "webhook:set" || echo "webhook:missing"
```

If missing:
```
[maestro] DISCORD_WEBHOOK_URL not set.

  To create a Discord webhook:
    1. Open Discord and go to your server
    2. Right-click the channel > Edit Channel
    3. Go to Integrations > Webhooks
    4. Click "New Webhook"
    5. Name it "Maestro", click "Copy Webhook URL"

  Set it:
    export DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."

  After setting, run: /maestro connect discord
```
Stop if webhook is missing.

### Step 2: Validate

```bash
curl -s -o /dev/null -w "%{http_code}" -X POST "$DISCORD_WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d '{"content":"Maestro connected successfully!"}'
```

If HTTP 204 (Discord returns 204 on success):
```
[maestro] (ok) Discord connected.
  (i) Test message sent — check your channel.
```

If not 204:
```
[maestro] (x) Discord webhook failed (HTTP [code]).

  Common causes:
    - Webhook deleted in Discord
    - URL copied incorrectly

  Recreate at: Discord channel settings > Integrations
```

### Step 3: Write to services.yaml

```yaml
discord:
  status: connected
  last_validated: "[timestamp]"
```

---

## Stripe Quick-Connect

### Step 1: Check API Key

```bash
[ -n "$STRIPE_API_KEY" ] && echo "key:set" || echo "key:missing"
```

If missing:
```
[maestro] STRIPE_API_KEY not set.

  To get a Stripe API key:
    1. Go to dashboard.stripe.com/apikeys
    2. Copy your "Secret key" (starts with sk_)
    3. Use test keys (sk_test_...) for development

  Set it:
    export STRIPE_API_KEY="sk_test_..."

  After setting, run: /maestro connect stripe
```
Stop if key is missing.

### Step 2: Validate

```bash
curl -s -o /dev/null -w "%{http_code}" https://api.stripe.com/v1/balance \
  -u "$STRIPE_API_KEY:"
```

If HTTP 200:
```
[maestro] (ok) Stripe connected.
  (i) Key validated against Stripe API.
```

### Step 3: Write to services.yaml

```yaml
stripe:
  status: connected
  mode: "[test or live based on key prefix]"
  last_validated: "[timestamp]"
```

---

## DigitalOcean Quick-Connect

### Step 1: Check CLI

```bash
command -v doctl >/dev/null 2>&1 && echo "doctl:found" || echo "doctl:missing"
```

If missing:
```
[maestro] doctl CLI not found.

  Install it:
    macOS:  brew install doctl
    Linux:  snap install doctl
    Docs:   docs.digitalocean.com/reference/doctl/how-to/install

  After installing, run: /maestro connect digitalocean
```

### Step 2: Check Token

```bash
[ -n "$DO_ACCESS_TOKEN" ] && echo "token:set" || echo "token:missing"
doctl auth list 2>&1
```

If token missing and not authenticated:
```
[maestro] DigitalOcean token not set.

  To get a DigitalOcean token:
    1. Go to cloud.digitalocean.com/account/api/tokens
    2. Click "Generate New Token"
    3. Give it read/write access

  Set it:
    export DO_ACCESS_TOKEN="your-token"
  Or authenticate via CLI:
    doctl auth init
```

### Step 3: Validate

```bash
doctl account get
```

If successful:
```
[maestro] (ok) DigitalOcean connected.
  Account: [email]
```

### Step 4: Write to services.yaml

```yaml
digitalocean:
  status: connected
  account: "[email]"
  last_validated: "[timestamp]"
```

---

## Cloudflare Quick-Connect

### Step 1: Check CLI

```bash
command -v wrangler >/dev/null 2>&1 && echo "wrangler:found" || echo "wrangler:missing"
```

If missing:
```
[maestro] Wrangler CLI not found.

  Install it:
    npm install -g wrangler
    or: pnpm add -g wrangler

  After installing, run: /maestro connect cloudflare
```

### Step 2: Check Token

```bash
[ -n "$CLOUDFLARE_API_TOKEN" ] && echo "token:set" || echo "token:missing"
```

If missing:
```
[maestro] CLOUDFLARE_API_TOKEN not set.

  To get a Cloudflare API token:
    1. Go to dash.cloudflare.com/profile/api-tokens
    2. Click "Create Token"
    3. Use "Edit Cloudflare Workers" template
    4. Copy the token

  Set it:
    export CLOUDFLARE_API_TOKEN="your-token"
  Or authenticate via CLI:
    wrangler login

  After setting, run: /maestro connect cloudflare
```

### Step 3: Validate

```bash
wrangler whoami 2>&1
```

If successful:
```
[maestro] (ok) Cloudflare connected.
  Account: [account_name]
```

### Step 4: Write to services.yaml

```yaml
cloudflare:
  status: connected
  account: "[account_name]"
  last_validated: "[timestamp]"
```

---

## Netlify Quick-Connect

### Step 1: Check CLI

```bash
command -v netlify >/dev/null 2>&1 && echo "netlify:found" || echo "netlify:missing"
```

If missing:
```
[maestro] Netlify CLI not found.

  Install it:
    npm install -g netlify-cli
    or: pnpm add -g netlify-cli

  After installing, run: /maestro connect netlify
```

### Step 2: Check Auth

```bash
[ -n "$NETLIFY_AUTH_TOKEN" ] && echo "token:set" || echo "token:missing"
netlify status 2>&1
```

If not authenticated:
```
[maestro] Netlify not authenticated.

  Options:
    1. Set token:  export NETLIFY_AUTH_TOKEN="your-token"
       Get token:  app.netlify.com/user/applications
    2. Or run:     netlify login (browser-based auth)
```

### Step 3: Validate

```bash
netlify status
```

### Step 4: Write to services.yaml

```yaml
netlify:
  status: connected
  last_validated: "[timestamp]"
```

---

## Fly.io Quick-Connect

### Step 1: Check CLI

```bash
command -v fly >/dev/null 2>&1 && echo "fly:found" || echo "fly:missing"
```

If missing:
```
[maestro] Fly CLI not found.

  Install it:
    curl -L https://fly.io/install.sh | sh

  After installing, run: /maestro connect fly
```

### Step 2: Check Auth

```bash
[ -n "$FLY_API_TOKEN" ] && echo "token:set" || echo "token:missing"
fly auth whoami 2>&1
```

If not authenticated:
```
[maestro] Fly.io not authenticated.

  Options:
    1. Browser auth: fly auth login
    2. Token:        export FLY_API_TOKEN="your-token"
       Get token:    fly tokens create
```

### Step 3: Validate

```bash
fly auth whoami
```

### Step 4: Write to services.yaml

```yaml
fly:
  status: connected
  user: "[fly_email]"
  last_validated: "[timestamp]"
```

---

## services.yaml Schema

The full `.maestro/services.yaml` file follows this schema. Omit services that have never been attempted:

```yaml
# Maestro Services Configuration
# Last updated: [ISO timestamp]
# Written by: /maestro setup or /maestro connect

github:
  status: connected | skipped | error
  user: null | "[username]"
  last_validated: null | "[timestamp]"

aws:
  status: connected | skipped | error
  account: null | "[account_id]"
  region: null | "[region]"
  last_validated: null | "[timestamp]"

vercel:
  status: connected | skipped | error
  user: null | "[username]"
  last_validated: null | "[timestamp]"

telegram:
  status: connected | skipped | error
  bot_name: null | "[bot_username]"
  chat_id: null | "[chat_id]"
  last_validated: null | "[timestamp]"

slack:
  status: connected | skipped | error
  last_validated: null | "[timestamp]"

discord:
  status: connected | skipped | error
  last_validated: null | "[timestamp]"

stripe:
  status: connected | skipped | error
  mode: null | "test" | "live"
  last_validated: null | "[timestamp]"

digitalocean:
  status: connected | skipped | error
  account: null | "[email]"
  last_validated: null | "[timestamp]"

cloudflare:
  status: connected | skipped | error
  account: null | "[account_name]"
  last_validated: null | "[timestamp]"

netlify:
  status: connected | skipped | error
  last_validated: null | "[timestamp]"

fly:
  status: connected | skipped | error
  user: null | "[email]"
  last_validated: null | "[timestamp]"
```

## Rules

- Never print, log, or display credential values — only confirm whether they are set.
- If any validation step fails, set status to `error` in services.yaml and display the `(x)` indicator with a fix suggestion.
- Each flow is self-contained — failures in one service never block another.
- Always write to `.maestro/services.yaml` after each connect attempt (success or failure).
- Use `[maestro]` prefix for all output messages.
- Follow output-format standards: `(ok)`, `(x)`, `(i)` indicators. No emoji.
