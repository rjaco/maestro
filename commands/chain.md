---
name: chain
description: "Execute multi-service task chains — sequences of actions across services with dependency resolution and rollback"
argument-hint: "[run|list|templates|status|abort]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
  - Agent
---

# Maestro Chain

Execute multi-service task chains — ordered sequences of service actions with dependency resolution, variable substitution, and automatic rollback on failure.

## Step 1: Read Config and State

1. Read `.maestro/config.yaml` for autonomy mode and spending limits
2. Check `.maestro/chains/` for active chain state files
3. Parse `$ARGUMENTS` to determine subcommand

## Step 2: Handle Subcommand

### No arguments — Show status

If `$ARGUMENTS` is empty:

1. Check for active chains in `.maestro/chains/*.state.yaml`
2. If a chain is running, show its status (same as `status` below)
3. If no chain is running:

```
Maestro Chain

Multi-service task orchestration with dependency resolution and rollback.

Usage:
  /maestro chain run <template>       Run a pre-built template
  /maestro chain run --custom         Define and run a custom chain
  /maestro chain list                 List available templates
  /maestro chain status               Show running chain status
  /maestro chain abort                Abort chain and trigger rollback

Templates:
  launch-website      buy-domain → setup-dns → deploy-app → configure-email → announce
  setup-infrastructure  create-server → configure-dns → deploy-app → setup-monitoring
  email-campaign      create-template → upload-contacts → send-test → send-campaign
  social-media-blitz  create-content → post-twitter → post-linkedin → post-instagram

Run /maestro chain list for details.
```

---

### `list` — List available templates

Display all chain templates from the task-chain skill:

```
Available chain templates:

  launch-website
    Steps: buy domain → setup DNS → deploy app → configure email → announce
    Services: namecheap, cloudflare, vercel, sendgrid, twitter
    Cost estimate: ~$12.99 + deploy costs
    Reversible: partial (domain purchase irreversible)

  setup-infrastructure
    Steps: create server → configure DNS → deploy app → setup monitoring
    Services: digitalocean, cloudflare, ssh, betteruptime
    Cost estimate: ~$6/mo (server) + domain costs
    Reversible: partial (server billed from creation)

  email-campaign
    Steps: create template → upload contacts → send test → send campaign
    Services: sendgrid
    Cost estimate: depends on list size
    Reversible: partial (sent emails irreversible)

  social-media-blitz
    Steps: create content → post twitter → post linkedin → post instagram
    Services: twitter, linkedin, instagram
    Cost estimate: $0 (organic posts)
    Reversible: no (public posts)

Run /maestro chain run <template> to execute a template.
```

---

### `run <template>` — Run a pre-built chain

1. Load the template from the task-chain skill
2. Identify required parameters
3. If parameters are missing, prompt for them:

Use AskUserQuestion for each missing parameter:
- Question: "What [parameter_name] should this chain use?"
- Header: "Chain: [template name]"

4. Substitute parameters into the chain definition
5. Display pre-run summary:

```
Chain: launch-website
═══════════════════════════════════════════════════
Steps:
  1. buy-domain     namecheap    Purchase domain myapp.com             T3 — needs approval
  2. setup-dns      cloudflare   Add DNS records for myapp.com         T2
  3. deploy-app     vercel       Deploy application to Vercel          T2
  4. configure-email  sendgrid   Configure email for myapp.com         T2
  5. announce       twitter      Post launch announcement              T3 — needs approval

Estimated cost: $12.99 (domain)
Irreversible steps: buy-domain, announce

Autonomy mode: tiered (T3 steps require your approval)
```

6. Confirm with AskUserQuestion:
   - Question: "Start this chain?"
   - Header: "Chain: launch-website"
   - Options:
     1. label: "Start", description: "Begin executing steps in order"
     2. label: "Edit parameters", description: "Change one or more input values"
     3. label: "Cancel", description: "Do not run this chain"

7. If confirmed, invoke the task-chain skill to execute

---

### `run --custom` — Define and run a custom chain

1. Ask the user for the chain YAML definition:

Use AskUserQuestion:
- Question: "Paste your chain YAML definition (or describe what you want to build)"
- Header: "Custom Chain"

2. If the user provides a description rather than YAML:
   - Generate the chain YAML from the description using task-chain skill conventions
   - Display the generated YAML for approval

Use AskUserQuestion:
- Question: "Does this chain definition look correct?"
- Header: "Generated Chain"
- Options:
  1. label: "Yes, run it", description: "Execute this chain as defined"
  2. label: "Edit it", description: "Make changes before running"
  3. label: "Cancel", description: "Do not run"

3. Validate the chain:
   - Check all step IDs are unique
   - Verify `depends_on` references exist
   - Detect dependency cycles
   - Resolve all `{{variable}}` references — confirm no broken references

4. If validation passes: run as in `run <template>` step 5 above
5. If validation fails: show errors and stop

---

### `status` — Show running chain status

1. Find active chain state in `.maestro/chains/*.state.yaml`
2. If no active chain:
   ```
   No chain is currently running.
   ```
3. If chain is active, render the status table:

```
Chain: Launch myapp.com
═══════════════════════════════════════════════════
Step              Service      Status      Cost     Time
──────────────────────────────────────────────────
buy-domain        namecheap    done        $12.99   8s
setup-dns         cloudflare   done        $0       3s
deploy-app        vercel       running     $0       ...
setup-email       sendgrid     pending     $0       —
announce          twitter      pending     $0       —
──────────────────────────────────────────────────
Total: $12.99 | Elapsed: 14s | 3/5 steps complete
```

Include captured outputs from completed steps:
```
Outputs so far:
  domain_name   myapp.com
  zone_id       abc123
```

---

### `abort` — Abort running chain and trigger rollback

1. Check for active chain

2. If no chain is running:
   ```
   No chain is currently running.
   ```

3. If chain is running, show what will be rolled back:

```
Abort will trigger rollback of completed steps:

  setup-dns      Deleting DNS zone for myapp.com     (reversible)
  buy-domain     Cannot rollback — domain purchase   (irreversible)

This will stop the chain at: deploy-app (currently running)
```

4. Confirm with AskUserQuestion:
   - Question: "Abort the chain and roll back completed steps?"
   - Header: "Abort: Launch myapp.com"
   - Options:
     1. label: "Abort and rollback", description: "Stop chain and reverse completed steps"
     2. label: "Cancel", description: "Keep the chain running"

5. If confirmed: invoke rollback engine via task-chain skill with abort signal

6. Display rollback results as they complete (same display as rollback-engine.md)

---

## Step 3: Post-Execution

After any chain completes (success or failure):

1. Archive chain state to `.maestro/logs/chains/`
2. Clear active chain from daemon state if daemon is running
3. Show final summary

On success:
```
Chain complete: Launch myapp.com
5/5 steps completed | Cost: $12.99 | Time: 40s

Key outputs:
  deploy_url   https://myapp.vercel.app
  tweet_url    https://twitter.com/user/status/1234567890
```

On failure (after rollback):
```
Chain failed: Launch myapp.com
Failed at: deploy-app (Build error: missing env var)
Rollback: 1 of 2 steps reversed (buy-domain cannot be undone)
Cost incurred: $12.99 (non-recoverable)

To retry: fix the build error, then run /maestro chain run launch-website again.
```

## Error Handling

- Missing service credentials → before starting, list which credentials are needed and how to add them
- Dependency cycle detected → show the cycle path and stop
- Invalid YAML → show parse error with line number
- Chain already running → prompt to view status or abort before starting new one
