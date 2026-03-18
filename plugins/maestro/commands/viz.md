---
name: viz
description: "Visualize stories, architecture, roadmaps, and progress with Mermaid diagrams and ASCII dashboards"
argument-hint: "[deps|arch|roadmap|progress|cost]"
allowed-tools:
  - Read
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Maestro Viz

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Generate visual diagrams and dashboards for the current Maestro session or project.

## Step 1: Check Data

Read `.maestro/state.local.md` and `.maestro/dna.md`. If neither exists:

```
[maestro] No project data to visualize. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show what's available

Check which data exists and offer the relevant visualizations:

Use AskUserQuestion:
- Question: "What would you like to visualize?"
- Header: "Viz"
- Options (only show what's available):
  1. label: "Progress dashboard", description: "Current session progress with story status and costs"
  2. label: "Story dependencies", description: "Mermaid graph showing story execution order"
  3. label: "Architecture diagram", description: "System component diagram from .maestro/architecture.md"
  4. label: "Cost breakdown", description: "Model cost matrix and spending analysis"

### `deps` — Story Dependency Graph

1. Read all files in `.maestro/stories/`
2. Parse frontmatter: id, title, depends_on, status
3. Derive status from `.maestro/state.local.md`
4. Generate Mermaid graph with status colors
5. Also show ASCII fallback for terminal

### `arch` — Architecture Diagram

1. Read `.maestro/architecture.md`
2. If it doesn't exist: "No architecture document found. Run /maestro plan first."
3. Extract components and relationships
4. Generate Mermaid LR graph

### `roadmap` — Roadmap Timeline

1. Read `.maestro/roadmap.md` or milestone files
2. If they don't exist: "No roadmap found. Use /maestro magnum-opus to generate milestones."
3. Generate Mermaid Gantt chart

### `progress` — Progress Dashboard

1. Read `.maestro/state.local.md` for session state
2. Read story files for titles
3. Read `.maestro/token-ledger.md` for costs
4. Generate ASCII progress dashboard (always ASCII — works everywhere)

### `cost` — Cost Breakdown

1. Read `.maestro/token-ledger.md`
2. Read `.maestro/config.yaml` for model assignments
3. Generate ASCII cost matrix showing actual spend per model per task type
4. Show total spend, average per story, cost trends
