---
name: first-run
description: "First-run detection and tutorial. Detects when Maestro is being used for the first time in a project and offers guided onboarding."
---

# First-Run Detection & Tutorial

Detects whether this is the user's first time using Maestro in this project and provides a contextual welcome message with guided next steps.

## Detection

A first-run condition is present when ANY of the following are true:

1. `.maestro/dna.md` does not exist
2. `.maestro/config.yaml` does not exist
3. `.maestro/services.yaml` does not exist (no services configured)
4. `.maestro/state.md` does not exist OR its History section contains only the init entry

Check these files before any major command runs (e.g., before `/maestro`, `/maestro plan`, `/maestro opus`). If any condition is met, the project is considered a first-run environment.

## When to Trigger

This skill is invoked at the start of any top-level Maestro command when first-run is detected. It does NOT run for:
- `/maestro init` (the user is already doing setup)
- `/maestro setup` (the user is already doing setup)
- `/maestro help` (informational, no project required)
- `/maestro doctor` (diagnostic, no project required)

## Welcome Message

When first-run is detected, display this message before the command's own output:

```
+---------------------------------------------+
| Welcome to Maestro!                         |
+---------------------------------------------+
  (i) Looks like this is your first time here.

  Get started in 3 steps:
    1. /maestro init      Auto-discover your project
    2. /maestro setup     Configure autonomous features
    3. /maestro "task"    Build something!

  Or run /maestro demo for an interactive walkthrough.
+---------------------------------------------+
```

Then use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "First Run"
- Options:
  1. label: "Run /maestro init now (Recommended)", description: "Auto-discover your tech stack and create project DNA"
  2. label: "Take the guided tour", description: "Interactive walkthrough of Maestro's key features"
  3. label: "Skip — continue with my original command", description: "Proceed without setup (some features may not work)"

If the user chooses "Run /maestro init now", execute the init flow. After init completes, ask:
- Question: "Init complete. What next?"
- Header: "Next Step"
- Options:
  1. label: "Run /maestro setup (Recommended)", description: "Connect services, configure autonomy, set up notifications"
  2. label: "Skip to my original command", description: "Continue with what you originally asked for"

If the user chooses "Take the guided tour", run the Guided Tour (see below).

If the user chooses "Skip", continue with the original command but note at the bottom:

```
[maestro] (!) Running without full setup. Run /maestro init then /maestro setup when ready.
```

## Guided Tour

A concise interactive walkthrough of Maestro's capabilities. Run after the user selects the guided tour option.

### Tour Step 1: What Maestro Does

Display:

```
+---------------------------------------------+
| Maestro: What It Does        (Tour 1/4)     |
+---------------------------------------------+
  Maestro is an autonomous orchestrator for
  Claude Code. It can:

  Orchestrate    Break features into stories,
                 delegate to specialized agents,
                 and manage the full dev loop.

  Automate       Run multi-step pipelines with
                 quality gates, self-healing,
                 and cost tracking.

  Connect        Integrate with GitHub, AWS,
                 Vercel, Telegram, Slack, and
                 other external services.
```

Use AskUserQuestion:
- Question: " "
- Header: "Tour 1/4"
- Options:
  1. label: "Next: Key commands", description: ""
  2. label: "Exit tour", description: "I've seen enough, let me get started"

### Tour Step 2: Key Commands

Display:

```
+---------------------------------------------+
| Key Commands                 (Tour 2/4)     |
+---------------------------------------------+
  /maestro "feature"   Build a complete feature
                       autonomously end-to-end

  /maestro plan        Generate a feature plan
                       from a description

  /maestro opus        Grand strategy: roadmaps,
                       milestones, full projects

  /maestro chain run   Execute a named pipeline
  /maestro status      Show current session state
  /maestro doctor      Check installation health
  /maestro setup       Configure everything
```

Use AskUserQuestion:
- Question: " "
- Header: "Tour 2/4"
- Options:
  1. label: "Next: Autonomy modes", description: ""
  2. label: "Exit tour", description: ""

### Tour Step 3: Autonomy & Spending

Display:

```
+---------------------------------------------+
| Autonomy & Spending          (Tour 3/4)     |
+---------------------------------------------+
  Maestro has three autonomy modes:

  Full Auto    Runs everything without asking.
               Best for overnight or CI runs.

  Tiered       Runs freely until a spending
               threshold — then asks. This is
               the recommended default.

  Manual       Asks before every external
               action. Maximum control.

  Spending limits protect against runaway
  costs. Set them in /maestro setup.
```

Use AskUserQuestion:
- Question: " "
- Header: "Tour 3/4"
- Options:
  1. label: "Next: Notifications", description: ""
  2. label: "Exit tour", description: ""

### Tour Step 4: Notifications

Display:

```
+---------------------------------------------+
| Notifications                (Tour 4/4)     |
+---------------------------------------------+
  Maestro can push status updates to:

    Telegram    Real-time bot messages
    Slack       Channel webhooks
    Discord     Channel webhooks
    Terminal    Always-on (default)

  Configure in /maestro setup > notifications.

  Notification levels:
    All         Every action and status update
    Important   Completions, errors, spending
    Critical    Failures only
```

Use AskUserQuestion:
- Question: "Tour complete. What would you like to do?"
- Header: "Tour 4/4"
- Options:
  1. label: "Run /maestro init (Recommended)", description: "Set up this project now"
  2. label: "Run /maestro setup", description: "Configure services and autonomy"
  3. label: "Go to my original command", description: "I'll set up later"

## Detection Implementation

At the start of any qualifying command, run this check:

```bash
# First-run detection
HAS_DNA=0
HAS_CONFIG=0
HAS_SERVICES=0
HAS_STATE=0

[ -f ".maestro/dna.md" ] && HAS_DNA=1
[ -f ".maestro/config.yaml" ] && HAS_CONFIG=1
[ -f ".maestro/services.yaml" ] && HAS_SERVICES=1
[ -f ".maestro/state.md" ] && HAS_STATE=1

# First run if any critical file is missing
if [ "$HAS_DNA" = "0" ] || [ "$HAS_CONFIG" = "0" ]; then
  echo "first_run:true"
else
  echo "first_run:false"
fi
```

If `first_run:true`, invoke this skill before the command's main logic.

## State Persistence

After the user completes init or setup via this skill, do not re-trigger the first-run message in the same session. Track this with a session flag — do not write to disk for this purpose.
