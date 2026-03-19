---
name: proactive-service
description: "Detect when a task requires a service not yet connected, suggest connecting it, and route to the best available alternative. Called mid-task when a service dependency is unmet."
---

# Proactive Service Suggestion

Detects when the current task requires a service that is not connected, prompts the user to connect it or use an alternative, and routes execution accordingly.

## When to Invoke

Call this skill when, during task execution, you determine that completing the task requires a specific external service and that service is not listed as connected in `.maestro/services.yaml`.

## Input

- Current task description or request text
- Contents of `.maestro/services.yaml` (read at skill entry)

## Process

### Step 1: Read Connected Services

Read `.maestro/services.yaml`. Build a map of:
- Which services are connected (`connected: true`)
- Which capabilities each service provides (the `capabilities` field)

If `.maestro/services.yaml` does not exist, treat all services as not connected.

### Step 2: Detect Required Service

Scan the task description for trigger keywords and map them to required services:

| Task keywords | Required service(s) | Capability |
|---------------|---------------------|------------|
| deploy, host, publish, hosting | vercel, aws, cloudflare | hosting |
| domain, DNS, nameserver | cloudflare, namecheap | dns |
| email, send mail, SMTP | sendgrid | email |
| SMS, text message, phone | twilio | sms |
| payment, charge, subscribe, billing | stripe | payments |
| tweet, post to Twitter, social media | browser-agent | social |
| buy domain, purchase domain | namecheap, stripe | domain-purchase |

Match on substring, case-insensitive.

### Step 3: Check Capability Coverage

For each detected required service:

1. Check if the exact service is connected.
2. If not, check if any other connected service shares the same capability.

If a connected alternative exists, prefer it and skip to Step 5 (display routing decision).

If no connected service covers the capability, proceed to Step 4.

### Step 4: Prompt User

Display the service requirement and ask what to do.

Output format:
```
[maestro] (i) This task requires <Service Name> (<capability label>).
              <Service Name> is not connected.
```

Then use AskUserQuestion:
- **Question**: "How would you like to proceed?"
- **Header**: "Service Required: <service-name>"
- **Options**:
  1. Connect now — run `/maestro connect <service-name>`
  2. Use alternative — check for another connected <capability> service
  3. Skip — continue without this capability

Handle each selection:

**Option 1 — Connect now:**
Output:
```
[maestro] (i) Starting connect flow for <service-name>...
```
Invoke the connect command inline: run `/maestro connect <service-name>` and wait for it to complete. Once connected, re-read `.maestro/services.yaml` and continue task execution.

**Option 2 — Use alternative:**
Re-scan `services.yaml` for any service with a matching `capabilities` entry that is connected. If found, display the routing decision (Step 5) and use it. If none found:
```
[maestro] (x) No connected service provides <capability>. Connect one to continue.
```
Offer options 1 and 3 again.

**Option 3 — Skip:**
Log in `.maestro/state.local.md`:
```
[proactive-service] Skipped: <service-name> unavailable for <capability> at <timestamp>
```
Continue task execution, noting in output:
```
[maestro] (!) Continuing without <capability> — some steps may be skipped.
```

### Step 5: Display Routing Decision (Capability-Based)

When multiple services can fulfill a capability, display which one was selected and why:

```
[maestro] (i) Multiple services can handle <capability>:
  (ok) <service-a>    — connected, recommended
  --   <service-b>    — not connected
  --   <service-c>    — not connected

  Using: <service-a>
```

Then proceed with the selected service.

## Output

- User-facing prompt via AskUserQuestion when a service is missing
- Routing decision display when multiple services cover a capability
- Log entry in `.maestro/state.local.md` when a service is skipped
- Resumes task execution with the selected service or without the capability
