---
name: service-registry
description: "Manage external service connections for autonomous agents. Read, write, and validate entries in .maestro/services.yaml."
---

# Service Registry

The service registry is the single source of truth for all external service connections Maestro agents can use. It lives at `.maestro/services.yaml` and tracks credentials, health checks, capabilities, and connection status for every configured service.

## Registry File Location

```
.maestro/services.yaml
```

If this file does not exist, create it from the template in `skills/service-registry/service-templates.md`.

## Schema

Each entry in `services:` has the following fields:

| Field | Type | Description |
|-------|------|-------------|
| `name` | string | Human-readable display name |
| `type` | string | Service category: `cloud`, `payment`, `communication`, `development`, `domain` |
| `auth_method` | string | How credentials are supplied: `env`, `vault`, or `mcp` |
| `credentials` | object | Credential spec — shape depends on `auth_method` |
| `cli_tool` | string | (optional) CLI binary used to interact with this service |
| `health_check` | string | Bash command that exits 0 when the service is reachable and credentials are valid |
| `capabilities` | list | What this service can do — used by agents to select the right service |
| `status` | string | Current connection state: `connected`, `disconnected`, or `error` |

### auth_method Values

**`env`** — Credentials come from environment variables.
```yaml
auth_method: env
credentials:
  env_vars:
    - MY_API_KEY
    - MY_API_SECRET
```
To verify: check that each listed env var is set and non-empty before running the health check.

**`vault`** — Credentials are stored in a secrets vault (HashiCorp Vault, 1Password, etc.).
```yaml
auth_method: vault
credentials:
  vault_path: "secret/myservice/credentials"
  keys:
    - api_key
    - api_secret
```
To verify: attempt to read the vault path. The vault skill handles the actual retrieval.

**`mcp`** — Credentials are managed by an MCP server. The server handles auth transparently.
```yaml
auth_method: mcp
credentials:
  mcp_server: "my-service-mcp"
```
To verify: check that the MCP server is listed in Claude Code's active servers.

### status Values

| Value | Meaning |
|-------|---------|
| `connected` | Health check passed on last verification |
| `disconnected` | Never connected, or connection was explicitly removed |
| `error` | Health check ran but failed — credentials may be invalid or service unreachable |

## Operations

### List All Services

Read `.maestro/services.yaml` and display a formatted table:

```
Service        Type           Status         Capabilities
─────────────────────────────────────────────────────────
aws            cloud          connected      compute, storage, dns, serverless
cloudflare     cloud          disconnected   dns, cdn, serverless
github         development    connected      repos, issues, actions, packages
stripe         payment        error          payments, subscriptions, invoicing
```

### Inspect a Service

Read the YAML entry for the named service and show all fields. Check which env vars are set:

```
Service: aws
─────────────────────────────────────────
Name:         Amazon Web Services
Type:         cloud
Auth:         env
Status:       connected

Credentials:
  AWS_ACCESS_KEY_ID        [set]
  AWS_SECRET_ACCESS_KEY    [set]
  AWS_DEFAULT_REGION       [set]

CLI Tool:     aws
Capabilities: compute, storage, dns, serverless

Health check: aws sts get-caller-identity
```

Use `bash -c "printenv VAR_NAME"` to check if each env var is set (do not print the value — just `[set]` or `[not set]`).

### Add a Service

1. Check if `services.yaml` already has an entry for the service key.
2. If not, pull the template from `service-templates.md` for common services, or build a new entry from scratch using the schema above.
3. Write the new entry to `services.yaml`.
4. Set `status: disconnected` on creation.
5. Prompt the user to run `/maestro connect <service>` to complete setup.

### Remove a Service

1. Confirm with the user before removing.
2. Remove the entry from `services.yaml`.
3. Do not remove env vars from the environment — just remove the registry entry.

### Run Health Check

For a given service:

1. Read the `health_check` field.
2. If `auth_method: env`, first verify that all `credentials.env_vars` are set. If any are missing, set `status: error` and report which vars are missing — do not attempt the health check.
3. Run the health check command via Bash.
4. If exit code 0: set `status: connected`, report success.
5. If non-zero: set `status: error`, capture stderr, report the error.

Always write the updated status back to `services.yaml`.

### Run Health Check for All Services

Iterate over every entry in `services.yaml`. Run each health check in sequence. Report a summary table on completion.

## Capability Index

Agents use capabilities to find the right service for a task. Common capability values:

| Capability | Services that provide it |
|------------|--------------------------|
| `compute` | aws, digitalocean |
| `storage` | aws, digitalocean |
| `dns` | aws, cloudflare, vercel, digitalocean, namecheap |
| `serverless` | aws, cloudflare, vercel |
| `cdn` | cloudflare |
| `hosting` | vercel |
| `databases` | digitalocean |
| `payments` | stripe |
| `subscriptions` | stripe |
| `invoicing` | stripe |
| `email` | sendgrid |
| `sms` | twilio |
| `voice` | twilio |
| `phone_numbers` | twilio |
| `messaging` | telegram, slack |
| `notifications` | telegram, slack |
| `repos` | github |
| `issues` | github |
| `actions` | github |
| `packages` | github |
| `domain_purchase` | namecheap |
| `domain_management` | namecheap |

To find a service by capability, scan `services.yaml` for entries whose `capabilities` list contains the needed value and whose `status` is `connected`.

## Integration Points

- **`/maestro connect <service>`** — Full credential setup wizard. Calls this skill's health check logic after credential entry.
- **`/maestro services`** — Displays the registry table. Calls the list operation above.
- **`/maestro services health`** — Runs health checks for all services.
- **Autonomous agents** — Read the registry to discover available services before planning tasks that require external integrations.

## Error Handling

- `services.yaml` missing → create it from `service-templates.md` with all services in `disconnected` state.
- Service key not found → list available services, suggest closest match.
- Health check command missing → log `status: error` with message "no health_check defined".
- Env var check: never print credential values. Only show `[set]` or `[not set]`.
