---
name: spec
description: "Create and manage feature specifications — structured artifacts consumed by all agents."
---

# /maestro spec

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage spec-driven workflows. Specs are structured feature specifications that become shared context artifacts for all agents.

## Subcommands

### `/maestro spec "description"`

Create a new spec interactively.

1. Parse the description for key nouns and intent
2. Generate a spec draft using the spec skill format:
   ```markdown
   ---
   name: "[extracted feature name]"
   status: draft
   created: [date]
   author: [from git config]
   priority: [inferred or ask]
   ---

   ## Problem
   ## Solution
   ## Requirements
   ## Non-Goals
   ## Technical Constraints
   ## Success Metrics
   ```
3. Present the draft via AskUserQuestion:
   - "Approve" → set status to `active`, save to `.maestro/specs/`
   - "Edit" → open for modifications
   - "Discard" → cancel

### `/maestro spec list`

List all specs with status:

```
Feature Specifications:

  user-auth        active         3 requirements  2026-03-18
  api-endpoints    implementing   5 requirements  2026-03-17
  dashboard-ui     complete       8 requirements  2026-03-15
  payment-flow     draft          0 requirements  2026-03-18
```

### `/maestro spec show <slug>`

Display the full spec with requirement completion status:

```
Spec: user-auth (active)

## Requirements
- [x] REQ-1: Login endpoint accepts email/password
- [x] REQ-2: JWT tokens expire after 15 minutes
- [ ] REQ-3: Password reset via email link
```

### `/maestro spec activate <slug>`

Set a spec as the active spec for the current session:
1. Set status to `active`
2. Register as T1 context in context-engine
3. Inform all agents that this spec drives the current work

### `/maestro spec complete <slug>`

Mark a spec as complete:
1. Verify all requirements are checked off
2. If unchecked requirements exist: warn and ask for confirmation
3. Set status to `complete`
4. Archive from active context

## Integration

- **decompose**: reads active spec to generate stories from requirements
- **context-engine**: loads active spec as T1 (always available to all agents)
- **qa-reviewer**: checks implementations against spec requirements
- **feature-registry**: spec requirements map to registry entries
- **ship**: includes spec completion status in PR description
