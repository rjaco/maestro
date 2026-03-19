---
name: connect
description: "Connect an external service to Maestro — interactive setup wizard for credentials and configuration"
argument-hint: "<service-name>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
  - Glob
---

# Connect Service

Interactive credential setup wizard for external services. Walks through credential entry, validates the connection, and updates the service registry.

## Entry Point

`$ARGUMENTS` is the service name (e.g., `aws`, `github`, `stripe`).

If `$ARGUMENTS` is empty, use AskUserQuestion:

**Question:** "Which service would you like to connect?"

**Options:** List all services from `.maestro/services.yaml` that have `status: disconnected` or `status: error`, showing each service's name and type. Add an option "Other — enter a service not in the registry" at the end.

## Step 1 — Load the Service Entry

Read `.maestro/services.yaml`. Find the entry matching `$ARGUMENTS`.

If the service is not found:
```
[maestro] Service "<name>" not found in the registry.

  Known services: aws, cloudflare, vercel, digitalocean, stripe, sendgrid,
                  twilio, namecheap, telegram, slack, github

  To add a new service not in this list, edit .maestro/services.yaml directly
  using the schema in skills/service-registry/SKILL.md.
```
Stop here.

If the service already has `status: connected`:

Use AskUserQuestion:
- **Question:** "`<name>` is already connected. What would you like to do?"
- **Options:**
  1. **Re-verify** — "Run the health check again to confirm the connection is still valid"
  2. **Reconfigure** — "Update the credentials for this service"
  3. **Cancel** — "Leave the current configuration unchanged"

If "Cancel", stop. If "Re-verify", skip to Step 4. If "Reconfigure", continue to Step 2.

## Step 2 — Choose Auth Method

Read the `auth_method` field for this service. If it is already set to a specific method in the template, use that method directly and skip asking. Only prompt if there is a reason to offer a choice (e.g., the service supports multiple methods).

For services using `auth_method: env` (the default for all built-in templates), proceed directly to Step 3.

If offering a choice, use AskUserQuestion:
- **Question:** "How should Maestro store credentials for `<name>`?"
- **Options:**
  1. **Environment variables** — "Read credentials from shell env vars (recommended for local dev)"
  2. **Vault** — "Read credentials from a secrets vault (recommended for production)"
  3. **MCP server** — "Credentials managed by an MCP server"

Update `auth_method` in `services.yaml` based on the selection.

## Step 3 — Credential Setup

### For `auth_method: env`

Display the list of required env vars from `credentials.env_vars`.

Check each var with `bash -c "printenv VAR_NAME"` (do not print the value).

Show the current state:
```
Credentials required for <name>:

  AWS_ACCESS_KEY_ID        [set]
  AWS_SECRET_ACCESS_KEY    [not set]
  AWS_DEFAULT_REGION       [set]
```

If any vars are not set, use AskUserQuestion:

**Question:** "Some credentials are missing. How would you like to proceed?"

**Options:**
1. **Set them now** — "I'll provide the values and Maestro will add them to a .env file or export them"
2. **I'll set them manually** — "I'll set the env vars myself, then re-run /maestro connect <service>"
3. **Cancel** — "Abort the connection setup"

If "Set them now": for each missing var, use AskUserQuestion with a text input:
- **Question:** "Enter value for `<VAR_NAME>`:"
- **Header:** "`<service name>` credentials"

After the user provides a value, write `export VAR_NAME="value"` to `.maestro/.env.local` (create if it does not exist). Inform the user:
```
[maestro] Saved to .maestro/.env.local
  Run: source .maestro/.env.local  (or add to your shell profile)
```

If "I'll set them manually": show instructions and stop:
```
[maestro] Set these environment variables, then run /maestro connect <service> again:

  export AWS_SECRET_ACCESS_KEY="your-key-here"
```

### For `auth_method: vault`

Ask for the vault path if not already set:

**Question:** "Enter the vault path for `<service name>` credentials (e.g., `secret/myapp/aws`):"

Update `credentials.vault_path` in `services.yaml`.

Test vault access with: `vault kv get <path>` (if vault CLI is available) or inform the user to verify manually.

### For `auth_method: mcp`

Ask for the MCP server name:

**Question:** "Enter the MCP server name that manages `<service name>` credentials:"

Update `credentials.mcp_server` in `services.yaml`.

Note: MCP-managed credentials are validated implicitly when the health check runs.

## Step 4 — Run Health Check

Read the `health_check` field for this service.

If no health check is defined:
```
[maestro] No health check defined for <service>. Marking as connected.
```
Update `status: connected` in `services.yaml` and stop.

Run the health check:
```bash
bash -c "<health_check_command>"
```

Show the result:

**On success (exit code 0):**
```
[maestro] Connected: <service name>

  Health check: passed
  Status updated: connected

  Capabilities available: <comma-separated list>
```
Update `status: connected` in `.maestro/services.yaml`.

**On failure (non-zero exit code):**
```
[maestro] Connection failed: <service name>

  Health check: failed
  Error: <stderr output>

  Possible causes:
  - Credentials may be invalid or expired
  - The service may be temporarily unreachable
  - A required CLI tool may not be installed

  Status updated: error
```
Update `status: error` in `.maestro/services.yaml`.

Use AskUserQuestion:
- **Question:** "What would you like to do?"
- **Options:**
  1. **Retry** — "Re-run the health check (if you just fixed the credentials)"
  2. **Reconfigure credentials** — "Go back to credential setup"
  3. **Leave as-is** — "Keep status: error and exit"

Loop back to the appropriate step based on selection.

## Step 5 — Completion

After a successful connection, show:

```
[maestro] <service name> is now connected.

  To see all connected services: /maestro services
  To check connection health:    /maestro services health
```

If the service is a cloud provider with a CLI tool, also suggest:
```
  CLI tool (<cli_tool>) is configured and ready to use.
```
