---
name: onboarding
description: "First-run onboarding wizard. Configures Maestro interactively with 4 questions and writes answers to .maestro/config.yaml."
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Onboarding Wizard

Guides new users through first-time Maestro configuration. Collects 4 key preferences and writes them to `.maestro/config.yaml`. Can be re-run at any time via `/maestro onboarding` to reconfigure.

## When This Skill Runs

**Automatic trigger**: The `/maestro` command invokes this skill when:
- `$ARGUMENTS` is empty or contains a task description, AND
- `.maestro/` directory does not exist

**Manual trigger**: The user runs `/maestro onboarding` explicitly, regardless of project state.

---

## Step 1: Welcome

Display this banner and introduction:

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝

+---------------------------------------------+
| Welcome to Maestro                          |
+---------------------------------------------+

  Let's get you set up in 4 quick questions.
  You can change any of these later with /maestro config.
```

---

## Step 2: Ask 4 Questions

Ask the following questions in sequence, one at a time. Wait for the user's answer before proceeding to the next.

### Question 1 — Workflow Mode

Use AskUserQuestion:
- Question: "How hands-on do you want to be?"
- Header: "Workflow Mode (1/4)"
- Options:
  1. label: "Checkpoint (Recommended)", description: "Pause after each story for review — you stay in control"
  2. label: "Yolo", description: "Auto-approve everything. Maximum speed, minimum interruptions"
  3. label: "Careful", description: "Pause after every phase. Maximum visibility into each decision"

Store selection as `WORKFLOW_MODE`:
- Option 1 → `checkpoint`
- Option 2 → `yolo`
- Option 3 → `careful`

### Question 2 — Desktop Notifications

Use AskUserQuestion:
- Question: "Get a desktop notification when Maestro needs your attention?"
- Header: "Notifications (2/4)"
- Options:
  1. label: "Yes, notify me", description: "Ping when a story completes, QA needs review, or an error occurs"
  2. label: "No thanks", description: "I'll check back manually"

Store selection as `NOTIFICATIONS`:
- Option 1 → `desktop`
- Option 2 → `none`

### Question 3 — Kanban Provider

Use AskUserQuestion:
- Question: "Do you use a project management tool to track your work?"
- Header: "Kanban (3/4)"
- Options:
  1. label: "GitHub Issues", description: "Uses gh CLI — no extra setup needed"
  2. label: "Jira", description: "Requires Atlassian MCP Server"
  3. label: "Linear", description: "Requires Linear MCP Server"
  4. label: "None / Skip", description: "I don't use a kanban board"

Store selection as `KANBAN_PROVIDER`:
- Option 1 → `github`
- Option 2 → `jira`
- Option 3 → `linear`
- Option 4 → `null`

### Question 4 — Second Brain / Knowledge Base

Use AskUserQuestion:
- Question: "Do you use a second brain or knowledge base?"
- Header: "Knowledge Base (4/4)"
- Options:
  1. label: "Obsidian", description: "Saves decisions and summaries to your vault"
  2. label: "Notion", description: "Requires Notion MCP Server"
  3. label: "None / Skip", description: "I don't use a knowledge base"

Store selection as `BRAIN_PROVIDER`:
- Option 1 → `obsidian`
- Option 2 → `notion`
- Option 3 → `null`

---

## Step 3: Write Configuration

### 3a: Ensure .maestro/ directory exists

```bash
mkdir -p .maestro
```

### 3b: Check for existing config

If `.maestro/config.yaml` already exists, read it. Preserve all existing keys — only update the four keys set by this wizard:
- `default_mode`
- `notifications.enabled` and `notifications.providers`
- `integrations.kanban.provider`
- `integrations.knowledge_base.provider`

If no config exists, write the full default config below.

### 3c: Write config.yaml

If creating from scratch, write `.maestro/config.yaml` with these contents, substituting the user's answers:

```yaml
# Maestro Configuration
# Edit these values or run /maestro config to change them interactively.

# Default execution mode: yolo | checkpoint | careful
default_mode: [WORKFLOW_MODE]

# Default model for implementation agents
default_model: sonnet

# Cost tracking
cost_tracking:
  enabled: true
  forecast: true
  ledger: true
  budget_enforcement: true

# Quality gates
quality:
  max_qa_iterations: 5
  max_self_heal: 3
  run_tsc: true
  run_lint: true
  run_tests: true

# Model assignments per task type
models:
  planning: opus
  execution: sonnet
  review: opus
  simple: haiku
  research: sonnet

# Project-specific commands (auto-detected, override if needed)
commands:
  build: null
  test: null
  lint: null
  typecheck: null

# Scheduler (cron-based tasks)
scheduler:
  enabled: false

# Notifications
notifications:
  enabled: [true if NOTIFICATIONS=desktop, false if NOTIFICATIONS=none]
  providers:
    desktop:
      enabled: [true if NOTIFICATIONS=desktop, false otherwise]
    slack:
      webhook_url: null
    discord:
      webhook_url: null
  triggers:
    on_story_complete: true
    on_feature_complete: true
    on_qa_rejection: true
    on_self_heal_failure: true

# Explain mode — narrates each phase for new users
explain_mode: auto

# External integrations
integrations:
  kanban:
    provider: [KANBAN_PROVIDER]
    sync_enabled: false
    project_id: null
  knowledge_base:
    provider: [BRAIN_PROVIDER]
    vault_path: null
    sync_enabled: false
  tools:
    playwright: false
    github_cli: false
    obsidian_cli: false
```

If updating an existing config, use Edit to patch only the four relevant keys, preserving all other settings.

---

## Step 4: Show Summary

Display a box-formatted summary of what was configured:

```
+---------------------------------------------+
| Maestro Configured                          |
+---------------------------------------------+

  Workflow mode    [WORKFLOW_MODE]
  Notifications    [desktop / none]
  Kanban           [provider or none]
  Knowledge base   [provider or none]

  Settings saved to .maestro/config.yaml
```

Follow with contextual tips based on what the user selected:

- If `KANBAN_PROVIDER` is not null:
  ```
  (i) Kanban sync is off by default.
      Enable it: /maestro config set integrations.kanban.sync_enabled true
  ```

- If `BRAIN_PROVIDER` is `obsidian`:
  ```
  (i) Set your vault path to enable brain sync:
      /maestro brain connect
  ```

- If `BRAIN_PROVIDER` is `notion`:
  ```
  (i) Connect your Notion workspace:
      /maestro brain connect
  ```

- If `NOTIFICATIONS` is `desktop`:
  ```
  (i) Desktop notifications are on.
      Adjust triggers: /maestro config
  ```

Close with the ready-to-build message:

```
+---------------------------------------------+
| Ready to build.                             |
+---------------------------------------------+

  Next step:
    /maestro init          Scan your codebase and generate project DNA
    /maestro "your task"   Jump straight in (init runs automatically)

  Need help?
    /maestro help          Full usage reference
    /maestro config        View or change any setting
```

---

## Re-run Behavior

When invoked via `/maestro onboarding` explicitly:

1. If `.maestro/config.yaml` exists, read current values and show them before each question as the current setting:
   - Example: `Workflow Mode (1/4) — currently: checkpoint`
2. Any question the user answers updates the config. Questions work identically to first-run.
3. Show the same summary and ready-to-build message at the end.

---

## Important Notes

- This wizard deliberately asks only 4 questions. Do not add more questions or sub-questions.
- Never ask for API keys, tokens, or credentials during onboarding. Integrations requiring auth are set up via their dedicated commands (`/maestro brain connect`, `/maestro config`).
- If the user skips a question (selects "None / Skip"), write `null` for that value — do not leave the key absent.
- This skill does NOT run `/maestro init`. Onboarding configures preferences; init scans the codebase and builds project DNA. They are separate steps.
- After this skill completes, if a task description was originally passed to `/maestro`, resume routing that description through the normal maestro flow (init check → decompose → execute).
