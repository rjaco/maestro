---
name: quick-start
description: "Pick from pre-built task templates — zero thinking required"
argument-hint: ""
allowed-tools:
  - Read
  - AskUserQuestion
---

# Quick Start

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Interactive template picker for common tasks. Guides the user through category selection, template selection, placeholder filling, and confirmation -- then outputs the exact `/maestro` command to run.

## Behavior

Read the quick-start skill for template definitions, then walk the user through a 4-step selection flow using AskUserQuestion at each step.

## Step 1: Category Selection

Use AskUserQuestion:

- **Question**: "What kind of work?"
- **Options**:
  1. "Code" with description: "API endpoints, auth, tests, lint fixes, dark mode, migrations"
  2. "Content" with description: "Blog posts, case studies, documentation, landing pages"
  3. "Marketing" with description: "Competitor analysis, content calendars, ad copy, email sequences"
  4. "Research" with description: "Tech evaluations, architecture reviews, security audits"

## Step 2: Template Selection

Based on the category chosen in Step 1, use AskUserQuestion to show the relevant templates.

### If Code:

- **Question**: "Pick a template"
- **Options**:
  1. "Add API endpoint" with description: "REST endpoint with validation, auth, tests"
  2. "Add authentication" with description: "Email/password or OAuth login flow"
  3. "Add test suite" with description: "Unit + integration tests for existing code"
  4. "Fix lint errors" with description: "Auto-fix all linting issues (runs in yolo mode)"

If the user needs more code templates (dark mode, database migration), show a second AskUserQuestion with the remaining options.

### If Content:

- **Question**: "Pick a template"
- **Options**:
  1. "Blog post" with description: "SEO-optimized article with meta tags, 1500-2500 words"
  2. "Case study" with description: "Problem-solution-results format with metrics"
  3. "Documentation" with description: "Technical docs for a feature or API"
  4. "Landing page" with description: "Hero, features, CTA, social proof sections"

### If Marketing:

- **Question**: "Pick a template"
- **Options**:
  1. "Competitor analysis" with description: "Research 3-5 competitors across features and pricing"
  2. "Content calendar" with description: "3-month plan with topics and target keywords"
  3. "Ad copy" with description: "20+ variations for Google, Meta, and LinkedIn"
  4. "Email sequence" with description: "Onboarding or nurture drip campaign"

### If Research:

- **Question**: "Pick a template"
- **Options**:
  1. "Tech evaluation" with description: "Compare tools or frameworks for a decision"
  2. "Architecture review" with description: "Analyze current architecture, suggest improvements"
  3. "Security audit" with description: "Scan for common vulnerabilities and issues"

## Step 3: Fill Placeholders

Most templates have a placeholder (e.g., `[resource]`, `[topic]`, `[product]`). Ask the user to fill it in.

Use AskUserQuestion with a free-text prompt or provide examples:

| Template | Question | Examples |
|----------|----------|----------|
| Add API endpoint | "What resource? (e.g., users, products, payments)" | users, products, orders |
| Add authentication | "What method? (e.g., email/password, Google OAuth, magic link)" | email/password, OAuth |
| Add test suite | "What module? (e.g., auth, payments, data pipeline)" | auth, API routes |
| Blog post | "What topic?" | microservices, Series A, React |
| Competitor analysis | "What product?" | project management tool |
| Content calendar | "What audience?" | developers, SaaS founders |
| Ad copy | "What product?" | analytics dashboard |
| Case study | "What client or project?" | Acme Corp migration |
| Tech evaluation | "What options and use case? (e.g., Prisma vs Drizzle for our API)" | Prisma vs Drizzle |
| Email sequence | "What goal? (e.g., onboarding, re-engagement)" | onboarding |
| Documentation | "What feature?" | billing API |
| Landing page | "What product?" | our SaaS platform |
| Architecture review | "What system?" | backend API layer |
| Security audit | "What component?" | auth module |

Templates without placeholders (Fix lint errors, Add dark mode) skip this step.

## Step 4: Confirmation

Display the assembled command in the output-format standard:

```
+---------------------------------------------+
| Quick Start                                 |
+---------------------------------------------+
  Command    /maestro "Add users API endpoint"
  Mode       checkpoint
  Estimate   3-4 stories
```

Then use AskUserQuestion:

- **Question**: "Run this now?"
- **Options**:
  1. "Yes, run it" (Recommended) -- respond with the final `/maestro` command for the user to execute
  2. "Customize first" with description: "Change mode, add details, or adjust scope" -- show the command with flags the user can modify (e.g., `--yolo`, `--careful`, `--model opus`) and let them edit
  3. "Cancel" -- respond with: "No problem. Run `/maestro quick-start` anytime, or type your own `/maestro \"description\"` command."

## After Confirmation

If the user chose "Yes, run it", output the command clearly:

```
[maestro] Run this command:

  /maestro "Add users API endpoint"
```

If the user chose "Customize first", show the command with available flags:

```
[maestro] Customize your command:

  /maestro "Add users API endpoint"

  Available flags:
    --yolo          Auto-approve everything (fast)
    --checkpoint    Pause after each story (default)
    --careful       Pause after each phase (detailed)
    --model opus    Use Opus for all agents

  Edit the command above and run it when ready.
```
