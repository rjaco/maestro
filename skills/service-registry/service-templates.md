---
name: service-templates
description: "Reference templates for common external services. Used by the service-registry skill when adding a new service or initializing .maestro/services.yaml."
---

# Service Templates

These are the canonical YAML entries for well-known services. When a user adds one of these services, copy the relevant block into `.maestro/services.yaml` and set `status: disconnected`.

## Cloud Infrastructure

### Amazon Web Services

```yaml
aws:
  name: "Amazon Web Services"
  type: cloud
  auth_method: env
  credentials:
    env_vars:
      - AWS_ACCESS_KEY_ID
      - AWS_SECRET_ACCESS_KEY
      - AWS_DEFAULT_REGION
  cli_tool: aws
  health_check: "aws sts get-caller-identity"
  capabilities:
    - compute
    - storage
    - dns
    - serverless
  status: disconnected
```

### Cloudflare

```yaml
cloudflare:
  name: "Cloudflare"
  type: cloud
  auth_method: env
  credentials:
    env_vars:
      - CLOUDFLARE_API_TOKEN
  cli_tool: wrangler
  health_check: "curl -s -H 'Authorization: Bearer $CLOUDFLARE_API_TOKEN' https://api.cloudflare.com/client/v4/user/tokens/verify | grep -q success"
  capabilities:
    - dns
    - cdn
    - serverless
  status: disconnected
```

### Vercel

```yaml
vercel:
  name: "Vercel"
  type: cloud
  auth_method: env
  credentials:
    env_vars:
      - VERCEL_TOKEN
  cli_tool: vercel
  health_check: "vercel whoami"
  capabilities:
    - hosting
    - serverless
    - dns
  status: disconnected
```

### DigitalOcean

```yaml
digitalocean:
  name: "DigitalOcean"
  type: cloud
  auth_method: env
  credentials:
    env_vars:
      - DIGITALOCEAN_ACCESS_TOKEN
  cli_tool: doctl
  health_check: "doctl account get"
  capabilities:
    - compute
    - storage
    - dns
    - databases
  status: disconnected
```

## Payments

### Stripe

```yaml
stripe:
  name: "Stripe"
  type: payment
  auth_method: env
  credentials:
    env_vars:
      - STRIPE_API_KEY
  health_check: "curl -s -u $STRIPE_API_KEY: https://api.stripe.com/v1/balance | grep -q available"
  capabilities:
    - payments
    - subscriptions
    - invoicing
  status: disconnected
```

## Communication

### SendGrid

```yaml
sendgrid:
  name: "SendGrid"
  type: communication
  auth_method: env
  credentials:
    env_vars:
      - SENDGRID_API_KEY
  health_check: "curl -s -H 'Authorization: Bearer $SENDGRID_API_KEY' https://api.sendgrid.com/v3/user/profile | grep -q username"
  capabilities:
    - email
  status: disconnected
```

### Twilio

```yaml
twilio:
  name: "Twilio"
  type: communication
  auth_method: env
  credentials:
    env_vars:
      - TWILIO_ACCOUNT_SID
      - TWILIO_AUTH_TOKEN
  health_check: "curl -s -u $TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID.json | grep -q sid"
  capabilities:
    - sms
    - voice
    - phone_numbers
  status: disconnected
```

### Telegram Bot

```yaml
telegram:
  name: "Telegram Bot"
  type: communication
  auth_method: env
  credentials:
    env_vars:
      - TELEGRAM_BOT_TOKEN
      - TELEGRAM_CHAT_ID
  health_check: "curl -s https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe | grep -q ok"
  capabilities:
    - messaging
    - notifications
  status: disconnected
```

### Slack

```yaml
slack:
  name: "Slack"
  type: communication
  auth_method: env
  credentials:
    env_vars:
      - SLACK_WEBHOOK_URL
  health_check: "curl -s -o /dev/null -w '%{http_code}' -X POST $SLACK_WEBHOOK_URL -d '{\"text\":\"health check\"}' | grep -q 200"
  capabilities:
    - messaging
    - notifications
  status: disconnected
```

## Domain Registrars

### Namecheap

```yaml
namecheap:
  name: "Namecheap"
  type: domain
  auth_method: env
  credentials:
    env_vars:
      - NAMECHEAP_API_USER
      - NAMECHEAP_API_KEY
  health_check: "curl -s 'https://api.namecheap.com/xml.response?ApiUser=$NAMECHEAP_API_USER&ApiKey=$NAMECHEAP_API_KEY&UserName=$NAMECHEAP_API_USER&Command=namecheap.domains.getList&ClientIp=auto' | grep -q Status"
  capabilities:
    - domain_purchase
    - domain_management
    - dns
  status: disconnected
```

## Development

### GitHub

```yaml
github:
  name: "GitHub"
  type: development
  auth_method: env
  credentials:
    env_vars:
      - GITHUB_TOKEN
  cli_tool: gh
  health_check: "gh auth status"
  capabilities:
    - repos
    - issues
    - actions
    - packages
  status: disconnected
```

## Full Registry Template

Use this block to initialize `.maestro/services.yaml` from scratch:

```yaml
# .maestro/services.yaml
# Maestro Service Registry
# Managed by /maestro connect and /maestro services
# Do not edit status fields manually — use /maestro connect <service> to update them

services:
  aws:
    name: "Amazon Web Services"
    type: cloud
    auth_method: env
    credentials:
      env_vars:
        - AWS_ACCESS_KEY_ID
        - AWS_SECRET_ACCESS_KEY
        - AWS_DEFAULT_REGION
    cli_tool: aws
    health_check: "aws sts get-caller-identity"
    capabilities:
      - compute
      - storage
      - dns
      - serverless
    status: disconnected

  cloudflare:
    name: "Cloudflare"
    type: cloud
    auth_method: env
    credentials:
      env_vars:
        - CLOUDFLARE_API_TOKEN
    cli_tool: wrangler
    health_check: "curl -s -H 'Authorization: Bearer $CLOUDFLARE_API_TOKEN' https://api.cloudflare.com/client/v4/user/tokens/verify | grep -q success"
    capabilities:
      - dns
      - cdn
      - serverless
    status: disconnected

  vercel:
    name: "Vercel"
    type: cloud
    auth_method: env
    credentials:
      env_vars:
        - VERCEL_TOKEN
    cli_tool: vercel
    health_check: "vercel whoami"
    capabilities:
      - hosting
      - serverless
      - dns
    status: disconnected

  digitalocean:
    name: "DigitalOcean"
    type: cloud
    auth_method: env
    credentials:
      env_vars:
        - DIGITALOCEAN_ACCESS_TOKEN
    cli_tool: doctl
    health_check: "doctl account get"
    capabilities:
      - compute
      - storage
      - dns
      - databases
    status: disconnected

  stripe:
    name: "Stripe"
    type: payment
    auth_method: env
    credentials:
      env_vars:
        - STRIPE_API_KEY
    health_check: "curl -s -u $STRIPE_API_KEY: https://api.stripe.com/v1/balance | grep -q available"
    capabilities:
      - payments
      - subscriptions
      - invoicing
    status: disconnected

  sendgrid:
    name: "SendGrid"
    type: communication
    auth_method: env
    credentials:
      env_vars:
        - SENDGRID_API_KEY
    health_check: "curl -s -H 'Authorization: Bearer $SENDGRID_API_KEY' https://api.sendgrid.com/v3/user/profile | grep -q username"
    capabilities:
      - email
    status: disconnected

  twilio:
    name: "Twilio"
    type: communication
    auth_method: env
    credentials:
      env_vars:
        - TWILIO_ACCOUNT_SID
        - TWILIO_AUTH_TOKEN
    health_check: "curl -s -u $TWILIO_ACCOUNT_SID:$TWILIO_AUTH_TOKEN https://api.twilio.com/2010-04-01/Accounts/$TWILIO_ACCOUNT_SID.json | grep -q sid"
    capabilities:
      - sms
      - voice
      - phone_numbers
    status: disconnected

  namecheap:
    name: "Namecheap"
    type: domain
    auth_method: env
    credentials:
      env_vars:
        - NAMECHEAP_API_USER
        - NAMECHEAP_API_KEY
    health_check: "curl -s 'https://api.namecheap.com/xml.response?ApiUser=$NAMECHEAP_API_USER&ApiKey=$NAMECHEAP_API_KEY&UserName=$NAMECHEAP_API_USER&Command=namecheap.domains.getList&ClientIp=auto' | grep -q Status"
    capabilities:
      - domain_purchase
      - domain_management
      - dns
    status: disconnected

  telegram:
    name: "Telegram Bot"
    type: communication
    auth_method: env
    credentials:
      env_vars:
        - TELEGRAM_BOT_TOKEN
        - TELEGRAM_CHAT_ID
    health_check: "curl -s https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/getMe | grep -q ok"
    capabilities:
      - messaging
      - notifications
    status: disconnected

  slack:
    name: "Slack"
    type: communication
    auth_method: env
    credentials:
      env_vars:
        - SLACK_WEBHOOK_URL
    health_check: "curl -s -o /dev/null -w '%{http_code}' -X POST $SLACK_WEBHOOK_URL -d '{\"text\":\"health check\"}' | grep -q 200"
    capabilities:
      - messaging
      - notifications
    status: disconnected

  github:
    name: "GitHub"
    type: development
    auth_method: env
    credentials:
      env_vars:
        - GITHUB_TOKEN
    cli_tool: gh
    health_check: "gh auth status"
    capabilities:
      - repos
      - issues
      - actions
      - packages
    status: disconnected
```
