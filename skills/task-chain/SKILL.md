---
name: task-chain
description: "Multi-service task chain orchestrator. Executes sequences of actions across services with dependency resolution, variable substitution, rollback, and receipt notifications."
---

# Task Chain Orchestrator

A task chain is a sequence of service actions that depend on each other. Each step's output can feed into the next step's input. If a step fails, the chain rolls back completed steps. The rollback engine is documented in `rollback-engine.md`.

## Chain Definition Format

Chains are defined in YAML — either inline or in `.maestro/chains/<name>.yaml`:

```yaml
chain:
  name: "Launch myapp.com"
  steps:
    - id: buy-domain
      service: namecheap
      action: "Purchase domain myapp.com"
      tier: T3  # irreversible
      estimated_cost: 12.99
      outputs:
        - domain_name: "myapp.com"
      rollback: null  # cannot undo a purchase

    - id: setup-dns
      service: cloudflare
      action: "Add DNS records for myapp.com"
      tier: T2
      depends_on: buy-domain
      inputs:
        domain: "{{buy-domain.domain_name}}"
      outputs:
        - zone_id: "<from API response>"
      rollback: "Delete DNS zone for myapp.com"

    - id: deploy-app
      service: vercel
      action: "Deploy application to Vercel"
      tier: T2
      estimated_cost: 0
      depends_on: setup-dns
      outputs:
        - deploy_url: "<from vercel deploy>"
      rollback: "Remove Vercel deployment"

    - id: setup-email
      service: sendgrid
      action: "Configure email sending for myapp.com"
      tier: T2
      depends_on: setup-dns
      rollback: "Remove SendGrid domain verification"

    - id: announce
      service: twitter
      action: "Post launch announcement"
      tier: T3  # irreversible — public post
      depends_on: deploy-app
      inputs:
        url: "{{deploy-app.deploy_url}}"
      rollback: null  # cannot undo a tweet
```

## Step Fields

| Field | Required | Description |
|-------|----------|-------------|
| `id` | yes | Unique step identifier within the chain |
| `service` | yes | Which service skill to invoke |
| `action` | yes | Natural-language description of the action |
| `tier` | yes | T1 (read-only), T2 (reversible write), T3 (irreversible/costly) |
| `depends_on` | no | Step ID or list of step IDs this step waits for |
| `inputs` | no | Key-value pairs; values may reference `{{step_id.output_name}}` |
| `outputs` | no | Named outputs captured from the service response |
| `rollback` | yes | Rollback instruction, or `null` if irreversible |
| `estimated_cost` | no | Expected cost in USD for budget tracking |

## Execution Algorithm

```
1. Parse chain YAML
2. Build dependency graph from depends_on fields
3. Topological sort — determine valid execution order
   - Validate: no cycles, all depends_on IDs exist
4. For each step (in topological order):
   a. Resolve inputs — substitute {{step_id.output_name}} with captured values
   b. Classify action tier — use step definition or ask autonomy engine
   c. Check approval — T1 auto-executes, T2 may require tier confirmation,
      T3 always requires explicit approval unless autonomy mode is full-auto
   d. Execute action using the appropriate service skill
   e. Capture outputs — store key-value pairs from response
   f. Send action receipt to notification hub
   g. On failure:
      - Log failure details with exit code and error message
      - Invoke rollback engine (see rollback-engine.md)
      - Send failure notification to all channels
      - Stop chain execution
5. On success:
   - Send completion notification with summary
   - Write chain result to .maestro/logs/chains/<chain-name>-<timestamp>.yaml
```

## Variable Substitution

Inputs support `{{step_id.output_name}}` syntax. Resolution rules:

1. `step_id` must be a step that appears earlier in the execution order (already completed)
2. `output_name` must match a key in that step's captured outputs
3. If a reference cannot be resolved, halt the chain before starting — report the unresolved reference
4. Substitution is recursive — resolved values may themselves contain further references (max depth: 5)

Example:
```yaml
inputs:
  domain: "{{buy-domain.domain_name}}"   # resolves to "myapp.com"
  url:    "{{deploy-app.deploy_url}}"    # resolves to "https://myapp.vercel.app"
```

## Dependency Graph

Steps without `depends_on` run first. Steps that share the same dependency set can run in parallel if the service skills support it. When in doubt, run sequentially.

```
buy-domain
    ├── setup-dns
    │       ├── deploy-app
    │       │       └── announce
    │       └── setup-email
    └── (none)
```

Topological order: buy-domain → setup-dns → deploy-app + setup-email (parallel) → announce

## Autonomy Tier Enforcement

| Tier | Autonomy: manual | Autonomy: tiered | Autonomy: full-auto |
|------|-----------------|-----------------|---------------------|
| T1 (read-only) | auto-execute | auto-execute | auto-execute |
| T2 (reversible) | require approval | auto-execute | auto-execute |
| T3 (irreversible/costly) | require approval | require approval | auto-execute |

Approval prompt (T3 in tiered mode):
```
Step requires approval: announce
  Service: twitter
  Action: Post launch announcement
  Cost: $0
  Reversible: No

Approve this step? [yes/no/abort]
```

## Chain Status Display

Render status after each step completes:

```
Chain: Launch myapp.com
═══════════════════════════════════════════════════
Step           Service      Status      Cost     Time
───────────────────────────────────────────────────
buy-domain     namecheap    done        $12.99   8s
setup-dns      cloudflare   done        $0       3s
deploy-app     vercel       running     $0       ...
setup-email    sendgrid     pending     $0       —
announce       twitter      pending     $0       —
───────────────────────────────────────────────────
Total: $12.99 | Elapsed: 14s | 3/5 steps complete
```

Status values: `pending`, `running`, `done`, `failed`, `rolled-back`, `skipped`

## Chain Templates

Pre-built chains live in `chains/` within this skill directory. Load them by name:

### 1. launch-website

```yaml
chain:
  name: "Launch Website"
  template: launch-website
  steps:
    - id: buy-domain
      service: namecheap
      action: "Purchase domain {{domain}}"
      tier: T3
      estimated_cost: 12.99
      outputs:
        - domain_name: "{{domain}}"
      rollback: null

    - id: setup-dns
      service: cloudflare
      action: "Create DNS zone and records for {{domain}}"
      tier: T2
      depends_on: buy-domain
      inputs:
        domain: "{{buy-domain.domain_name}}"
      outputs:
        - zone_id: "<zone id>"
        - nameservers: "<ns list>"
      rollback: "Delete Cloudflare zone for {{domain}}"

    - id: deploy-app
      service: vercel
      action: "Deploy project to Vercel and link custom domain"
      tier: T2
      depends_on: setup-dns
      outputs:
        - deploy_url: "<vercel url>"
        - project_id: "<project id>"
      rollback: "Remove Vercel project"

    - id: configure-email
      service: sendgrid
      action: "Add and verify domain {{domain}} in SendGrid"
      tier: T2
      depends_on: setup-dns
      inputs:
        domain: "{{buy-domain.domain_name}}"
      rollback: "Remove SendGrid domain {{domain}}"

    - id: announce
      service: twitter
      action: "Post launch tweet: {{announcement}}"
      tier: T3
      depends_on: deploy-app
      inputs:
        url: "{{deploy-app.deploy_url}}"
      rollback: null
```

Parameters: `domain`, `announcement`

### 2. setup-infrastructure

```yaml
chain:
  name: "Setup Infrastructure"
  template: setup-infrastructure
  steps:
    - id: create-server
      service: digitalocean
      action: "Create {{size}} droplet in {{region}}"
      tier: T3
      outputs:
        - server_ip: "<ip address>"
        - server_id: "<droplet id>"
      rollback: "Destroy DigitalOcean droplet {{create-server.server_id}}"

    - id: configure-dns
      service: cloudflare
      action: "Point {{domain}} A record to {{create-server.server_ip}}"
      tier: T2
      depends_on: create-server
      inputs:
        ip: "{{create-server.server_ip}}"
      outputs:
        - record_id: "<dns record id>"
      rollback: "Delete DNS A record for {{domain}}"

    - id: deploy-app
      service: ssh
      action: "Deploy application to {{create-server.server_ip}} via SSH"
      tier: T2
      depends_on: configure-dns
      inputs:
        host: "{{create-server.server_ip}}"
      outputs:
        - app_url: "https://{{domain}}"
      rollback: "Stop and remove application on server"

    - id: setup-monitoring
      service: betteruptime
      action: "Add uptime monitor for {{deploy-app.app_url}}"
      tier: T2
      depends_on: deploy-app
      inputs:
        url: "{{deploy-app.app_url}}"
      rollback: "Remove uptime monitor"
```

Parameters: `domain`, `size`, `region`

### 3. email-campaign

```yaml
chain:
  name: "Email Campaign"
  template: email-campaign
  steps:
    - id: create-template
      service: sendgrid
      action: "Create email template: {{subject}}"
      tier: T2
      outputs:
        - template_id: "<template id>"
      rollback: "Delete SendGrid template {{create-template.template_id}}"

    - id: upload-contacts
      service: sendgrid
      action: "Upload contact list from {{contacts_file}}"
      tier: T2
      depends_on: create-template
      outputs:
        - list_id: "<contact list id>"
        - contact_count: "<count>"
      rollback: "Delete contact list {{upload-contacts.list_id}}"

    - id: send-test
      service: sendgrid
      action: "Send test email to {{test_email}} using template"
      tier: T2
      depends_on: upload-contacts
      inputs:
        template_id: "{{create-template.template_id}}"
      rollback: null

    - id: approve-and-send
      service: sendgrid
      action: "Send campaign to {{upload-contacts.contact_count}} contacts"
      tier: T3
      depends_on: send-test
      inputs:
        template_id: "{{create-template.template_id}}"
        list_id: "{{upload-contacts.list_id}}"
      rollback: null
```

Parameters: `subject`, `contacts_file`, `test_email`

### 4. social-media-blitz

```yaml
chain:
  name: "Social Media Blitz"
  template: social-media-blitz
  steps:
    - id: create-content
      service: internal
      action: "Generate post content for announcement: {{message}}"
      tier: T1
      outputs:
        - twitter_text: "<140 char version>"
        - linkedin_text: "<longer version>"
        - instagram_caption: "<caption with hashtags>"
      rollback: null

    - id: post-twitter
      service: twitter
      action: "Post: {{create-content.twitter_text}}"
      tier: T3
      depends_on: create-content
      outputs:
        - tweet_id: "<tweet id>"
        - tweet_url: "<url>"
      rollback: null

    - id: post-linkedin
      service: linkedin
      action: "Post: {{create-content.linkedin_text}}"
      tier: T3
      depends_on: create-content
      outputs:
        - post_url: "<url>"
      rollback: null

    - id: post-instagram
      service: instagram
      action: "Post with caption: {{create-content.instagram_caption}}"
      tier: T3
      depends_on: create-content
      outputs:
        - post_url: "<url>"
      rollback: null
```

Parameters: `message`

## Output Capture

After each step executes, capture outputs from the service response:

1. Read the service skill's response data
2. Map response fields to output names defined in the step
3. Store in chain context: `chain.outputs[step_id][output_name] = value`
4. Write snapshot to `.maestro/chains/<chain-name>.state.yaml` after each step

```yaml
# .maestro/chains/launch-myapp.state.yaml
chain: "Launch myapp.com"
started_at: "2026-03-19T14:00:00Z"
status: running
completed_steps:
  buy-domain:
    status: done
    completed_at: "2026-03-19T14:00:08Z"
    outputs:
      domain_name: "myapp.com"
    cost: 12.99
  setup-dns:
    status: done
    completed_at: "2026-03-19T14:00:11Z"
    outputs:
      zone_id: "abc123"
    cost: 0
current_step: deploy-app
pending_steps:
  - setup-email
  - announce
total_cost: 12.99
```

## Completion Summary

On chain success, display and log:

```
Chain complete: Launch myapp.com
═══════════════════════════════════════════════════
Step           Service      Status      Cost     Time
───────────────────────────────────────────────────
buy-domain     namecheap    done        $12.99   8s
setup-dns      cloudflare   done        $0       3s
deploy-app     vercel       done        $0       22s
setup-email    sendgrid     done        $0       5s
announce       twitter      done        $0       2s
───────────────────────────────────────────────────
Total: $12.99 | Elapsed: 40s | 5/5 steps complete

Outputs:
  deploy_url   https://myapp.vercel.app
  zone_id      abc123
  tweet_url    https://twitter.com/user/status/123
```

Send completion notification via notify skill:
```
[Maestro Chain] Launch myapp.com — complete
Steps: 5/5 | Cost: $12.99 | Time: 40s
```

## Integration Points

### With autonomy engine

Before each step:
- Check current autonomy mode
- Apply tier rules from the table above
- Log approval decisions to `.maestro/logs/autonomy.log`

### With notification hub (notify skill)

After each step:
- Send action receipt: `chain_step_complete` event
- On failure: `chain_step_failed` event
- On chain completion: `chain_complete` event
- On rollback: `chain_rollback_complete` event

### With credential manager

Service skills require credentials. Before invoking a service step:
- Verify the service credential is available
- If missing: halt the chain before starting — report which credential is needed

### With spending controls

Before executing any step with `estimated_cost > 0`:
- Check current session spend against configured limits
- If limit would be exceeded: pause and ask for approval

## Error Handling

- Dependency cycle detected → refuse to run, report the cycle
- Unknown service → halt before starting, list available services
- Unresolved variable → halt before starting, report the reference
- Step execution failure → trigger rollback engine, send failure notification
- Rollback failure → log and continue rolling back remaining steps
- State file write failure → log warning and continue (state is best-effort)
