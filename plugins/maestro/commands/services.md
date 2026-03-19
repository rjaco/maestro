---
name: services
description: "List all configured external services with connection status"
argument-hint: "[status|health]"
allowed-tools:
  - Read
  - Bash
---

# Services

Display external service connection status from `.maestro/services.yaml`.

## No Arguments or `status` — Show Registry Table

Read `.maestro/services.yaml`.

If the file does not exist:
```
[maestro] No service registry found.

  Run /maestro init or copy .maestro/services.yaml from the template at:
  skills/service-registry/service-templates.md
```
Stop here.

Display a formatted table sorted by type, then name:

```
+------------------------------------------------------------------+
| Maestro Services                                                 |
+------------------------------------------------------------------+

  Service        Type           Status         Capabilities
  ─────────────────────────────────────────────────────────────────
  aws            cloud          connected      compute, storage, dns, serverless
  cloudflare     cloud          disconnected   dns, cdn, serverless
  digitalocean   cloud          disconnected   compute, storage, dns, databases
  vercel         cloud          disconnected   hosting, serverless, dns
  github         development    connected      repos, issues, actions, packages
  namecheap      domain         disconnected   domain_purchase, domain_management, dns
  stripe         payment        error          payments, subscriptions, invoicing
  sendgrid       communication  disconnected   email
  slack          communication  disconnected   messaging, notifications
  telegram       communication  disconnected   messaging, notifications
  twilio         communication  disconnected   sms, voice, phone_numbers

  Summary: 2 connected  |  1 error  |  8 disconnected

  (i) Connect a service: /maestro connect <service>
  (i) Run health checks: /maestro services health
```

### Status Indicators

Format the `Status` column with text indicators (no color, as output may not support ANSI):

| Status | Display |
|--------|---------|
| `connected` | `connected` |
| `disconnected` | `disconnected` |
| `error` | `error (!)` |

If any services have `status: error`, add a note after the table:
```
  (!) Services with errors — run /maestro connect <service> to reconfigure:
      stripe
```

## `health` — Run Health Checks for All Services

Read `.maestro/services.yaml`. For each service entry, run its health check.

### Pre-check: Credential Verification

Before running each health check, verify env vars are set (for `auth_method: env` services):

```bash
bash -c "printenv VAR_NAME"
```

If any required env vars are missing, skip the health check for that service and mark it `error` with a note.

### Running Checks

Show progress as checks run:
```
[maestro] Running health checks...

  aws            checking...
  aws            connected (aws sts get-caller-identity: ok)

  cloudflare     checking...
  cloudflare     error — missing env var: CLOUDFLARE_API_TOKEN

  github         checking...
  github         connected (gh auth status: ok)

  stripe         checking...
  stripe         error — health check failed (exit 1)
```

After all checks complete, write the updated statuses back to `.maestro/services.yaml`.

Show a final summary table using the same format as the `status` subcommand, followed by:
```
  Health check complete. Registry updated.

  (i) To fix a failed service: /maestro connect <service>
```

### Health Check Execution

Run each health check with a timeout to prevent hangs:

```bash
timeout 15 bash -c "<health_check_command>"
```

If a health check times out after 15 seconds, mark that service `error` with note "health check timed out".

Capture exit code and stderr. Do not print raw credential values that may appear in health check output. If output contains a known env var name, redact its value.

## Single Service Status

If `$ARGUMENTS` matches a service key exactly (e.g., `/maestro services github`), show the detailed inspection view:

```
Service: github
─────────────────────────────────────────────────────
Name:         GitHub
Type:         development
Auth:         env
Status:       connected

Credentials:
  GITHUB_TOKEN             [set]

CLI Tool:     gh
Capabilities: repos, issues, actions, packages

Health check: gh auth status

Last updated: (not tracked — run /maestro services health to refresh)
```

Check each env var with `bash -c "printenv VAR_NAME"` and show `[set]` or `[not set]`. Never print the value.

If the service key is not found in the registry, show:
```
[maestro] Service "<name>" not found.

  Known services: aws, cloudflare, vercel, digitalocean, stripe, sendgrid,
                  twilio, namecheap, telegram, slack, github
```
