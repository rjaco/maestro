---
name: service-health
description: "Validate service connections defined in .maestro/services.yaml. Checks credentials, runs health_check commands, and reports connection status. Supports single-service and batch checks with auto-detection of unconfigured services."
---

# Service Health Check

Validates that services registered in `.maestro/services.yaml` are reachable and authenticated. Reports status per service and detects available integrations not yet in the registry.

## When to Use

- Before starting work that depends on an external service
- During `/maestro doctor` diagnostics
- After rotating credentials to confirm the new values work
- On demand: `/maestro health` or `/maestro health <service>`

---

## Single Service Health Check

Given a service name, perform the following steps in order:

### Step 1 — Read Service Entry

Read `.maestro/services.yaml` and locate the entry for the named service. If the service is not found, report:

```
Service '<name>' not found in .maestro/services.yaml
Run /maestro connect <name> to register it.
```

### Step 2 — Verify Credentials

Check the `auth_method` field and verify credentials are available:

**`auth_method: env`**

For each variable listed under `env_vars`, check existence with `printenv`:

```bash
printenv VAR_NAME > /dev/null 2>&1 && echo "set" || echo "not set"
```

Never print the credential value. If any variable is missing, set status to `error` and report which ones are absent:

```
Missing credentials: CLOUDFLARE_API_TOKEN
```

**`auth_method: vault`**

Run the vault verification command:

```bash
scripts/vault-manage.sh verify <service>
```

If the script exits non-zero, set status to `error` and capture the output.

**`auth_method: mcp`**

Use ToolSearch to check whether MCP tools with the service's prefix are available. Example: for a service with `mcp_prefix: mcp__stripe`, search for `+mcp__stripe`. If no tools are returned, credentials are considered unavailable.

**`auth_method: none`** or field absent

Skip credential check, proceed to Step 3.

### Step 3 — Run Health Check Command

If all required credentials are present, execute the `health_check` command via Bash:

```bash
<health_check command from services.yaml>
```

Capture stdout and stderr. Evaluate exit code:

- **Exit 0** → set `status: connected`. Capture the first line of stdout as `details` (e.g., identity confirmation).
- **Non-zero exit** → set `status: error`. Capture stderr as `details`.

If the service has no `health_check` field defined, set `status: disconnected` with `details: no health check defined`.

### Step 4 — Update services.yaml

Write the updated `status` and `last_checked` timestamp back to the service entry in `.maestro/services.yaml`:

```yaml
services:
  aws:
    auth_method: env
    env_vars: [AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY]
    health_check: "aws sts get-caller-identity --query Account --output text"
    status: connected
    last_checked: "2026-03-19T14:22:00Z"
    details: "arn:aws:iam::123456789012:user/deploy"
```

### Step 5 — Report Result

Display a single-line result:

```
aws  env  connected  identity: arn:aws:iam::123456789012:user/deploy
```

---

## Batch Health Check (All Services)

To check every service in `.maestro/services.yaml`:

1. Iterate over each service entry in `services` map order.
2. Run the single-service health check for each (Steps 1-4 above).
3. After all checks complete, display the summary table:

```
Service Health Report
═══════════════════════════════════════════════════
Service        Auth     Status        Details
───────────────────────────────────────────────────
aws            env      connected     identity: arn:aws:iam::123
cloudflare     env      error         CLOUDFLARE_API_TOKEN not set
github         env      connected     gh authenticated as octocat
stripe         env      disconnected  no health check defined
telegram       env      error         Bot token invalid
───────────────────────────────────────────────────
Connected: 2  |  Error: 2  |  Disconnected: 1
```

Column widths adjust to the longest value in each column. Minimum widths: Service 14, Auth 8, Status 13, Details 20.

**Status color coding** (when terminal supports color):
- `connected` — green
- `error` — red
- `disconnected` — dim/grey

The script `scripts/service-health-check.sh` can be used to run the batch check non-interactively and parse results programmatically.

---

## Auto-Detection of Unconfigured Services

After the batch check (or when invoked standalone as `/maestro detect-services`), scan the environment for available integrations not yet registered in services.yaml.

### CLI Tools

Check for common cloud and platform CLIs:

```bash
for tool in aws gcloud az vercel doctl wrangler gh heroku fly railway; do
  which "$tool" 2>/dev/null && "$tool" --version 2>/dev/null | head -1
done
```

### MCP Servers

Use ToolSearch to check for each known MCP prefix:

| Prefix | Service |
|--------|---------|
| `+mcp__asana` | Asana |
| `+mcp__linear` | Linear |
| `+mcp__notion` | Notion |
| `+mcp__stripe` | Stripe |
| `+mcp__github` | GitHub MCP |

If ToolSearch returns results for a prefix, the MCP server is active.

### Environment Variables

Check for common service tokens (existence only, never print values):

```bash
[ -n "$AWS_ACCESS_KEY_ID" ]     && echo "aws_key: set"
[ -n "$STRIPE_API_KEY" ]        && echo "stripe_key: set"
[ -n "$GITHUB_TOKEN" ]          && echo "github_token: set"
[ -n "$CLOUDFLARE_API_TOKEN" ]  && echo "cloudflare_token: set"
[ -n "$TELEGRAM_BOT_TOKEN" ]    && echo "telegram_token: set"
[ -n "$SLACK_BOT_TOKEN" ]       && echo "slack_token: set"
[ -n "$OPENAI_API_KEY" ]        && echo "openai_key: set"
[ -n "$DATABASE_URL" ]          && echo "database_url: set"
```

### Report Discovered Services

Compare detected tools/MCPs/env vars against the names already in services.yaml. Report only those not yet registered:

```
Detected services not in registry:
  gcloud (CLI found, version 450.0.0)
  mcp__linear (MCP server active)
  OPENAI_API_KEY (env var present)

Add them with: /maestro connect <service>
```

If all detected services are already registered, skip this section.

---

## services.yaml Format Reference

The skill reads and writes `.maestro/services.yaml` in this format:

```yaml
services:
  aws:
    auth_method: env          # env | vault | mcp | none
    env_vars:                 # required when auth_method is env
      - AWS_ACCESS_KEY_ID
      - AWS_SECRET_ACCESS_KEY
    health_check: "aws sts get-caller-identity --query Account --output text"
    status: connected         # connected | error | disconnected | unknown
    last_checked: "2026-03-19T14:22:00Z"
    details: "arn:aws:iam::123456789012:user/deploy"

  github:
    auth_method: env
    env_vars:
      - GITHUB_TOKEN
    health_check: "gh auth status"
    status: unknown

  stripe:
    auth_method: mcp
    mcp_prefix: mcp__stripe
    health_check: ""          # empty = no health check → disconnected
    status: unknown

  mydb:
    auth_method: vault
    vault_key: "secret/mydb/password"
    health_check: "psql $DATABASE_URL -c 'SELECT 1' -t -q"
    status: unknown
```

---

## Error Handling

| Situation | Action |
|-----------|--------|
| services.yaml missing | Report "No services configured. Run /maestro connect <service> to add one." |
| Service name not found | Report error, suggest `/maestro connect` |
| health_check command not found (command not in PATH) | Set status `error`, details: "command not found: <cmd>" |
| health_check times out (>30s) | Set status `error`, details: "health check timed out" |
| Vault script missing | Set status `error`, details: "scripts/vault-manage.sh not found" |
| YAML parse error | Report "services.yaml is malformed: <parse error>" |
| Credential value accidentally echoed | Never echo credential values; mask with `***` if unavoidable |

---

## Output Contract

```yaml
output_contract:
  single_check:
    fields: [service, auth_method, status, details, last_checked]
    status_values: [connected, error, disconnected, unknown]
  batch_check:
    fields: [per_service_rows, connected_count, error_count, disconnected_count]
    format: table with separator lines
  auto_detect:
    fields: [detected_services[].name, detected_services[].source, detected_services[].version]
    sources: [cli, mcp, env]
  services_yaml:
    written_fields: [status, last_checked, details]
```
