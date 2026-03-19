---
name: credential-manager
description: "Three-tier credential management: environment variables (simple), age-encrypted vault (secure), or MCP server (integrated). Handles credential retrieval, injection, rotation, and validation without ever exposing raw secrets in output."
---

# Credential Manager

Manages external service credentials across three storage tiers. Each service declares its tier in `.maestro/services.yaml` via `auth_method`. This skill handles credential retrieval, injection into commands, validation, and rotation — with strict security rules throughout.

## SECURITY RULES — Read Before Anything Else

These rules are non-negotiable. Violate any of them and you are creating a security incident.

1. **NEVER log or display credential values.** Not in output, not in code blocks, not in explanations.
2. **NEVER commit `.maestro/vault.yaml`** (the plaintext vault). The encrypted `.maestro/vault.age` is safe to commit; the plaintext YAML is not.
3. **Mask all credentials in output.** Show only the first 4 characters followed by `****`. Example: `AKIA****`.
4. **Delete temp files after vault operations.** Always use traps to guarantee cleanup — do not rely on the happy path.
5. **Env var values are not secrets once logged by a process.** Warn users that tier-1 credentials are visible in process listings.

## Tier Overview

| Tier | Storage | Security | Best for |
|------|---------|----------|----------|
| 1 — env | Shell environment variables | Low — visible in process listings | Dev machines, simple setups |
| 2 — vault | `.maestro/vault.age` (age-encrypted) | High — encrypted at rest | Production secrets, API keys |
| 3 — mcp | MCP server manages credentials | Highest — Maestro never sees raw secrets | Services with MCP integration |

## services.yaml Format

Services are declared in `.maestro/services.yaml`:

```yaml
services:
  aws:
    auth_method: vault           # tier-2
    required_vars:
      - AWS_ACCESS_KEY_ID
      - AWS_SECRET_ACCESS_KEY
      - AWS_DEFAULT_REGION
    health_check: "aws sts get-caller-identity"

  stripe:
    auth_method: env             # tier-1
    required_vars:
      - STRIPE_API_KEY
    health_check: "curl -s https://api.stripe.com/v1/balance -u $STRIPE_API_KEY: | jq .object"

  github:
    auth_method: mcp             # tier-3
    mcp_prefix: "mcp__github__"
    health_check: null           # MCP server handles its own health

  sendgrid:
    auth_method: vault
    required_vars:
      - SENDGRID_API_KEY
    health_check: "curl -s https://api.sendgrid.com/v3/scopes -H 'Authorization: Bearer $SENDGRID_API_KEY' | jq .scopes"
```

## How to Check Which Tier a Service Uses

1. Read `.maestro/services.yaml`
2. Find the service entry
3. Read the `auth_method` field: `env` | `vault` | `mcp`
4. If the service is not in `services.yaml`, report it as unconfigured and offer to set it up

```bash
# Quick check:
cat .maestro/services.yaml | grep -A2 "servicename:"
```

## Retrieving Credentials

### Tier 1: Environment Variables

Check each required variable with `printenv`:

```bash
# For each required_var in the service config:
printenv AWS_ACCESS_KEY_ID   # returns value if set, empty if not
```

Verify all required vars are set:

```bash
for var in AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_DEFAULT_REGION; do
  if [ -z "${!var:-}" ]; then
    echo "MISSING: $var"
  else
    echo "OK: $var is set"
  fi
done
```

Report status using masked values only: `AWS_ACCESS_KEY_ID: AKIA****`

### Tier 2: Encrypted Vault

Use `scripts/vault-manage.sh` to retrieve credentials:

```bash
# Get credentials for a service (returns JSON)
./scripts/vault-manage.sh get aws
# Output: {"AWS_ACCESS_KEY_ID": "AKIA...", "AWS_SECRET_ACCESS_KEY": "wJal..."}
```

To inject vault credentials into a command for execution:

```bash
# Decrypt, inject, run command, temp file is cleaned up automatically
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

./scripts/vault-manage.sh get aws > "$TMPFILE"
env $(cat "$TMPFILE" | python3 -c "
import sys, json
creds = json.load(sys.stdin)
print(' '.join(f'{k}={v}' for k, v in creds.items()))
") aws sts get-caller-identity

rm -f "$TMPFILE"
```

Never store decrypted credentials in a file without a trap. Never display the JSON output to the user — only show masked values.

### Tier 3: MCP Server

No credential retrieval needed. The MCP server manages credentials internally.

When you need to call a service configured as `auth_method: mcp`:
- Use the MCP tools directly via the configured `mcp_prefix`
- Example: for `mcp_prefix: "mcp__stripe__"`, call `mcp__stripe__list_customers` etc.
- Maestro never sees the raw credentials — the MCP server handles authentication

## Setting Credentials

### Tier 1: Setting Environment Variables

Guide the user — do not set these yourself:

```
To set STRIPE_API_KEY for this session:
  export STRIPE_API_KEY="your-key-here"

To persist across sessions, add to your shell profile:
  echo 'export STRIPE_API_KEY="your-key-here"' >> ~/.bashrc   # bash
  echo 'export STRIPE_API_KEY="your-key-here"' >> ~/.zshrc    # zsh

Then reload: source ~/.bashrc
```

Remind the user that env vars are visible in process listings (`ps aux`, `/proc/*/environ`).

### Tier 2: Setting Vault Credentials

Use `vault-manage.sh set` to add or update a credential:

```bash
# Syntax: vault-manage.sh set <service> <key> <value>
./scripts/vault-manage.sh set aws AWS_ACCESS_KEY_ID "AKIA..."
./scripts/vault-manage.sh set aws AWS_SECRET_ACCESS_KEY "wJal..."
./scripts/vault-manage.sh set aws AWS_DEFAULT_REGION "us-east-1"
```

Alternatively, edit the vault directly:

```bash
./scripts/vault-manage.sh edit
# Opens $EDITOR with decrypted plaintext, re-encrypts on save
# The temp plaintext file is deleted automatically
```

After setting credentials, run `verify` to confirm the vault decrypts cleanly:

```bash
./scripts/vault-manage.sh verify
```

### Tier 3: Setting MCP Server Credentials

Guide the user to configure the MCP server in Claude Code settings:

```
To configure the [service] MCP server:

1. Open Claude Code settings (Cmd+, or Ctrl+,)
2. Navigate to "MCP Servers"
3. Add or update the [service] server configuration
4. Provide credentials as required by the MCP server's documentation
5. Restart Claude Code to apply changes

Maestro will then use the MCP tools automatically — no credential storage needed.
```

## Validating Credentials

Run the service's `health_check` command from `services.yaml`:

```bash
# Example for AWS (tier-2):
# 1. Load credentials from vault
CREDS=$(./scripts/vault-manage.sh get aws)
# 2. Inject and run health check
env $(echo "$CREDS" | python3 -c "
import sys, json
creds = json.load(sys.stdin)
print(' '.join(f'{k}={v}' for k, v in creds.items()))
") aws sts get-caller-identity

# Example for Stripe (tier-1):
# Credentials already in environment
curl -s https://api.stripe.com/v1/balance \
  -u "${STRIPE_API_KEY}:" | jq .object
```

Interpret the result:
- HTTP 200 / command exit 0 → credentials valid, report "OK"
- HTTP 401/403 / auth error → credentials invalid or expired
- HTTP 429 → rate limited, credentials likely valid — report "RATE_LIMITED (credentials likely ok)"
- Network error → service unreachable, credentials not verified

Never display the raw API response if it contains credential details.

## Rotating Credentials

Credential rotation procedure:

1. **Generate new credentials** in the service's dashboard/console
2. **Update the credential** using the appropriate tier method (see "Setting Credentials" above)
3. **Validate** using the `health_check` command
4. **Revoke the old credential** in the service's dashboard once validation passes
5. **Confirm** rotation is complete

For vault-stored credentials (tier-2), the rotation is atomic — the vault is re-encrypted with new values and the old plaintext is never written to disk unencrypted.

Prompt the user to revoke the old credential only after the new one has been validated. Revoking before validation risks a service outage.

## Vault Initialization

If no vault exists yet, initialize one:

```bash
./scripts/vault-manage.sh init
# Generates age identity at ~/.maestro/age-identity
# Creates empty encrypted vault at .maestro/vault.age
```

The generated identity files:
- `~/.maestro/age-identity` — private key. NEVER commit. NEVER share.
- `~/.maestro/age-identity.pub` — public key. Safe to share for encryption.

Add these to `.gitignore` if not already present:
```
.maestro/vault.yaml
~/.maestro/age-identity
```

The encrypted vault (`.maestro/vault.age`) is safe to commit.

## Adding a New Service

1. Decide which tier is appropriate for the service
2. Add the service to `.maestro/services.yaml` with correct `auth_method`, `required_vars`, and `health_check`
3. If vault: run `vault-manage.sh init` if vault doesn't exist yet, then `vault-manage.sh set` for each credential
4. If env: guide user to export the required variables
5. If mcp: guide user to configure the MCP server in Claude Code settings
6. Validate with `health_check`
7. Confirm service is operational

## Disconnecting a Service

Use `/maestro disconnect <service>` to remove credentials and deactivate a service.

The disconnect command will:
1. Identify the service's tier from `services.yaml`
2. For vault: remove the service's section from the vault
3. For env: instruct the user to unset the variables
4. For mcp: instruct the user to remove the MCP server from Claude Code settings
5. Remove or comment out the service entry in `services.yaml`
6. Confirm the service is no longer accessible

## Troubleshooting

**"age not found"** — Install age: `brew install age` (macOS) or `apt install age` (Linux)

**"Cannot decrypt vault"** — The age identity at `~/.maestro/age-identity` may be missing or mismatched with the key used to encrypt the vault. Check: `ls -la ~/.maestro/`

**"No vault found"** — Run `./scripts/vault-manage.sh init` to create one

**"Permission denied on identity file"** — The identity file must be 600: `chmod 600 ~/.maestro/age-identity`

**Missing env var** — The variable may not be exported in the current shell session. Check with `printenv VAR_NAME`. If missing, export it or add to shell profile.

**MCP tool not available** — The MCP server may not be running or configured. Check Claude Code MCP settings.
