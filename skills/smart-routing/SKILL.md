---
name: smart-routing
description: "Automatically select the best integration method for a service — MCP, CLI, API, or browser — based on what is available. Called before any service interaction to determine the optimal route."
---

# Smart Task Routing

Determines the best method to interact with a given service by checking MCP server availability, CLI tool installation, API credentials, and browser capability — in priority order. Displays the routing decision before proceeding.

## When to Invoke

Call this skill before any step that interacts with an external service. Pass the service name and the intended action.

## Input

- `service`: The service to interact with (e.g., `github`, `aws`, `vercel`, `stripe`)
- `action`: A short description of what needs to be done (e.g., "deploy app", "create DNS record")
- Contents of `.maestro/services.yaml` (read at skill entry)

## Process

### Step 1: Read Service Config

Read `.maestro/services.yaml` to obtain:
- The service entry for the given `service` name
- `cli_tool`: the CLI binary name (e.g., `aws`, `vercel`, `gh`)
- `mcp_prefix`: the MCP tool prefix if known (e.g., `mcp__github__`)
- `api_credentials`: whether credentials are present

If the service entry is not found, use the known defaults table below.

### Step 2: Run Routing Algorithm

Check each route in priority order. Use the first available route.

**Priority 1 — MCP server**

Use ToolSearch to check for the service's MCP tool prefix (e.g., `mcp__github__`). If any tools are returned, MCP is available.

```
Route: MCP
Reason: <service> MCP server available — best integration, no credential exposure
```

**Priority 2 — CLI tool**

Run `which <cli_tool>` via Bash. If the command is found (exit code 0), CLI is available.

```
Route: CLI (<cli_tool> <command>)
Reason: <cli_tool> installed and authenticated
```

**Priority 3 — API via curl**

Check `.maestro/services.yaml` for the service's API credentials fields. If credentials are set (non-empty, non-null), API is available.

```
Route: API (curl)
Reason: API credentials set, using REST endpoint
```

**Priority 4 — Browser (Playwright)**

Use ToolSearch to check for `mcp__plugin_playwright_playwright__browser_navigate` or equivalent Playwright tool. If found, browser automation is available.

```
Route: Browser (Playwright)
Reason: No API, CLI, or MCP available — using browser automation
```

**No route available:**

If none of the above routes are available:

```
[maestro] (x) No route available for <service>.
              Connect the service first: /maestro connect <service>
```

Invoke the `proactive-service` skill to prompt the user.

### Step 3: Display Routing Decision

Always display the routing decision before proceeding:

```
[maestro] (i) Task: <action>
              Route: <route label>
              Reason: <one-line reason>
```

Example:
```
[maestro] (i) Task: Deploy app to Vercel
              Route: CLI (vercel deploy)
              Reason: vercel CLI installed and authenticated
```

### Step 4: Return Route

Return the selected route to the calling context:

```
route: mcp | cli | api | browser | none
tool_or_command: <specific tool name or CLI command prefix>
```

The caller uses this to invoke the correct integration method.

## Known Service Defaults

| Service | MCP prefix | CLI tool | API credential key |
|---------|-----------|----------|--------------------|
| github | `mcp__github__` | `gh` | `GITHUB_TOKEN` |
| aws | `mcp__aws__` | `aws` | `AWS_ACCESS_KEY_ID` |
| vercel | — | `vercel` | `VERCEL_TOKEN` |
| cloudflare | — | `wrangler` | `CLOUDFLARE_API_TOKEN` |
| stripe | `mcp__stripe__` | `stripe` | `STRIPE_SECRET_KEY` |
| sendgrid | — | — | `SENDGRID_API_KEY` |
| twilio | — | — | `TWILIO_AUTH_TOKEN` |
| namecheap | — | — | `NAMECHEAP_API_KEY` |
| digitalocean | — | `doctl` | `DIGITALOCEAN_TOKEN` |

## Route Priority Summary

| Route | When available | Notes |
|-------|---------------|-------|
| MCP | ToolSearch returns tools for the service prefix | Best integration, no credential exposure |
| CLI | `which <tool>` succeeds | Reliable, well-tested, authenticated via tool's own config |
| API | Credentials present in `services.yaml` | Universal fallback, uses curl |
| Browser | Playwright MCP available | Last resort for services without API or CLI |

## Output

- Routing decision displayed via `[maestro] (i)` line before every service interaction
- `route` and `tool_or_command` returned to the calling context
- Escalates to `proactive-service` skill if no route is available
