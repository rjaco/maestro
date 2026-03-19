---
name: disconnect
description: "Disconnect an external service — remove credentials and deactivate"
argument-hint: "<service-name>"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Disconnect

Disconnects an external service by removing its credentials and deactivating its configuration in `.maestro/services.yaml`. The procedure varies by credential tier.

## Step 1: Validate the Argument

If no service name was provided:

```
[maestro] Usage: /maestro disconnect <service-name>

Example: /maestro disconnect stripe
```

List known services from `.maestro/services.yaml` to help the user pick.

## Step 2: Look Up the Service

Read `.maestro/services.yaml` and find the service entry. If not found:

```
[maestro] Service "<name>" not found in .maestro/services.yaml.

Known services: aws, stripe, sendgrid, github
```

Read the `auth_method` field to determine the tier.

## Step 3: Confirm with the User

Use AskUserQuestion:
- Question: "Disconnect <service>? This will remove its credentials and deactivate it."
- Header: "Disconnect: <service>"
- Options:
  1. label: "Yes, disconnect", description: "Remove credentials and deactivate in services.yaml"
  2. label: "No, cancel", description: "Leave everything unchanged"

If the user cancels, output:

```
[maestro] Disconnect cancelled. <service> is still active.
```

## Step 4: Remove Credentials by Tier

### Tier 1: Environment Variables (`auth_method: env`)

Environment variables cannot be unset remotely. Guide the user:

```
[maestro] <service> uses environment variables. To remove:

  Unset from current session:
    unset VAR_NAME_1
    unset VAR_NAME_2

  Remove from shell profile (~/.bashrc or ~/.zshrc):
    Delete or comment out the export lines for:
      VAR_NAME_1
      VAR_NAME_2

  Then reload: source ~/.bashrc
```

List all `required_vars` from the service config.

### Tier 2: Encrypted Vault (`auth_method: vault`)

Remove the service section from the vault:

```bash
./scripts/vault-manage.sh edit
# Remove the <service>: block from the YAML, save, and quit.
# The vault is automatically re-encrypted on save.
```

Alternatively, if a `vault-manage.sh delete-service` command exists, use it. Otherwise use `edit`.

Verify the removal:

```bash
./scripts/vault-manage.sh list
# Confirm <service> no longer appears
```

### Tier 3: MCP Server (`auth_method: mcp`)

Maestro does not store credentials for MCP services. Guide the user:

```
[maestro] <service> uses an MCP server. To disconnect:

1. Open Claude Code settings (Cmd+, or Ctrl+,)
2. Navigate to "MCP Servers"
3. Remove or disable the <service> MCP server
4. Restart Claude Code to apply changes

No credential files need to be deleted — Maestro never stored them.
```

## Step 5: Deactivate in services.yaml

Comment out or remove the service entry from `.maestro/services.yaml`.

Preferred approach — comment it out so it can be restored:

```yaml
# <service>:            # disconnected [date]
#   auth_method: vault
#   required_vars: [...]
#   health_check: "..."
```

Use Edit to make this change precisely. Do not rewrite the whole file.

## Step 6: Confirm

```
[maestro] <service> disconnected.

  Credentials removed: yes (vault section deleted)
  services.yaml: deactivated (commented out)

  To reconnect, run /maestro init or restore the entry in .maestro/services.yaml.
```

If any step failed (e.g., vault edit was cancelled), report what completed and what did not:

```
[maestro] Partial disconnect for <service>:
  (ok) services.yaml deactivated
  (!)  Vault section not removed — run: ./scripts/vault-manage.sh edit
```

## Safety Notes

- Do not delete the `age-identity` file as part of disconnecting a single service. The identity is shared across all vault services.
- Do not delete `.maestro/vault.age` unless the user explicitly asks to destroy the entire vault.
- If the service is active in a running process, warn that in-flight requests may still use the credential until the process restarts.
