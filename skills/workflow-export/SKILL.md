---
name: workflow-export
description: "Export Maestro plans as declarative YAML workflow files. Import to replay or share workflows across projects."
---

# Workflow Export / Import

Export Maestro plans as declarative, human-editable YAML workflow files. Import them in another project to replay the same architecture. Share workflows across teams and projects like reusable blueprints.

## Purpose

Maestro produces stories, config, and architecture during planning. This skill captures that entire plan as a portable YAML file (`.maestro/plan.yaml`) that can be:

- **Shared** — Copy a plan.yaml into another project to replicate the same feature
- **Version-controlled** — Commit plan.yaml alongside code for reproducible builds
- **Edited** — YAML is human-readable, git-diffable, and easy to tweak
- **Replayed** — Import a plan.yaml and Maestro recreates the stories and config
- **Templated** — Build a library of reusable plan.yaml files for common features

## Configuration

No configuration required. This skill is always available.

Optional settings in `.maestro/config.yaml`:

```yaml
workflow:
  export_dir: ".maestro"            # where plan.yaml is saved (default: .maestro)
  template_dir: ".maestro/templates" # where template plan.yaml files live
  include_config: true              # include config snapshot in export
  include_architecture: true        # include architecture summary in export
```

## Operations

### export()

Export the current plan and stories to a declarative YAML workflow file.

#### Step 1: Read Stories

Glob `.maestro/stories/*.md` and read each story file. Extract from YAML frontmatter:

- `id` — Story number
- `slug` — Kebab-case identifier
- `title` — Human-readable title
- `type` — frontend, backend, data, integration, infrastructure, test
- `depends_on` — List of dependency story IDs
- `parallel_safe` — Boolean
- `complexity` — simple, medium, complex
- `model` — Recommended model (haiku, sonnet, opus)

From the body, extract:
- `acceptance_criteria` — List of testable criteria
- `context` — Implementation context notes
- `files.create` — Files to create
- `files.modify` — Files to modify
- `files.reference` — Reference files

If no stories exist:
```
[maestro] No stories to export.

  (i) Run /maestro plan or /maestro first to generate stories.
```
Return early.

#### Step 2: Read Configuration Snapshot

Read `.maestro/config.yaml` and extract relevant settings:

- `mode` — yolo, checkpoint, careful
- `models.planning` — Model for planning phases
- `models.execution` — Model for implementation
- `models.qa` — Model for QA review
- `models.commit` — Model for git operations
- `quality_gates` — QA iteration limits, self-heal limits
- `cost_tracking` — Ledger and forecast settings

#### Step 3: Read Architecture Summary

If `.maestro/dna.md` exists, extract:
- `tech_stack` — Languages, frameworks, tools
- `file_structure` — Project directory layout
- `patterns` — Coding patterns and conventions
- `constraints` — Known constraints

If an architecture document exists in `.maestro/plans/` (from a prior `/maestro plan` run), extract:
- `approach` — Architecture approach description
- `data_flow` — How data moves through the system
- `trade_offs` — Considered trade-offs

#### Step 4: Generate plan.yaml

Compose the YAML workflow file:

```yaml
# Maestro Workflow Plan
# Generated: [ISO timestamp]
# Project: [project name from DNA]
# Feature: [feature description from state]
#
# Usage:
#   Copy this file to another project's .maestro/ directory
#   Run: /maestro workflow-import
#   Stories will be recreated from this plan.

version: "1"
feature: "[feature description]"
created: "[ISO timestamp]"
source_project: "[project name]"

# Configuration snapshot
config:
  mode: "[mode]"
  models:
    planning: "[model]"
    execution: "[model]"
    qa: "[model]"
    commit: "[model]"
  quality_gates:
    max_qa_iterations: [N]
    max_self_heal: [N]
    require_tests: [true|false]

# Architecture summary (project-specific, adapt for target)
architecture:
  tech_stack:
    - "[language/framework]"
    - "[language/framework]"
  approach: "[one-line architecture description]"
  data_flow: "[data flow description]"
  patterns:
    - "[pattern 1]"
    - "[pattern 2]"
  constraints:
    - "[constraint 1]"

# Story definitions
stories:
  - id: 1
    slug: "[slug]"
    title: "[title]"
    type: "[type]"
    complexity: "[complexity]"
    model: "[model]"
    depends_on: []
    parallel_safe: [true|false]
    acceptance_criteria:
      - "[criterion 1]"
      - "[criterion 2]"
      - "[criterion 3]"
    context:
      - "[context note 1]"
      - "[context note 2]"
    files:
      create:
        - "[file path]"
      modify:
        - "[file path]"
      reference:
        - "[file path]"

  - id: 2
    slug: "[slug]"
    title: "[title]"
    # ... same structure ...

# Dependency graph (for visualization)
dependency_graph:
  roots: [1]
  edges:
    - from: 1
      to: 2
    - from: 2
      to: [3, 4]
    - from: [3, 4]
      to: 5
  critical_path: [1, 2, 3, 5]
  parallel_groups:
    - [3, 4]

# Metadata
metadata:
  total_stories: [N]
  estimated_tokens: [N]
  estimated_cost: "[N.NN]"
  story_types:
    backend: [N]
    frontend: [N]
    data: [N]
    test: [N]
```

#### Step 5: Write the File

Write the generated YAML to the configured export directory:

```
.maestro/plan.yaml
```

Display confirmation:

```
+---------------------------------------------+
| Workflow Exported                           |
+---------------------------------------------+

  File:      .maestro/plan.yaml
  Feature:   [feature description]
  Stories:   [N] stories
  Config:    [included|excluded]
  Arch:      [included|excluded]

  (ok) Plan exported successfully.

  Usage:
    Share:    Copy plan.yaml to another project
    Import:   /maestro workflow-import
    Edit:     Open plan.yaml in any editor
    Version:  git add .maestro/plan.yaml
```

### import(file_path?)

Import a plan.yaml file and recreate stories in the current project.

#### Step 1: Locate the Plan File

If `file_path` is provided, use it. Otherwise, check default locations:

1. `.maestro/plan.yaml`
2. `.maestro/templates/*.yaml` (if multiple, ask user to choose)

If no plan file found:
```
[maestro] No plan.yaml found.

  (i) Place a plan.yaml in .maestro/ or specify a path:
      /maestro workflow-import path/to/plan.yaml
```
Return early.

#### Step 2: Read and Validate the Plan

Read the YAML file and validate:

- `version` must be "1"
- `stories` array must exist and have at least 1 entry
- Each story must have `id`, `slug`, `title`, `type`
- `depends_on` references must be valid (point to existing story IDs)
- No cycles in the dependency graph

If validation fails:

```
  (x) Plan validation failed:
      - Story 3 depends on story 99 (not found)
      - Story "frontend" missing required field: type

  (i) Fix the plan.yaml and re-run import.
```
Return early.

#### Step 3: Adapt to Target Project

The imported plan may reference file paths and patterns from a different project. Check for compatibility:

1. Read `.maestro/dna.md` in the target project (if exists)
2. Compare `architecture.tech_stack` from the plan with the target project
3. Flag mismatches:

```
  (!) Compatibility check:
      (ok) Both projects use TypeScript
      (ok) Both projects use React
      (!)  Plan references Prisma, target uses Drizzle
      (!)  Plan references src/routes/, target uses app/api/

  (i) File paths in stories may need updating.
```

Use AskUserQuestion:
- Question: "Plan was created for a different project. How to proceed?"
- Header: "Compat"
- Options:
  1. label: "Import and adapt (Recommended)", description: "Import stories, let Maestro adjust file paths during execution"
  2. label: "Import as-is", description: "Import stories with original file paths"
  3. label: "Review each story", description: "Go through stories one by one"
  4. label: "Cancel", description: "Abort import"

#### Step 4: Create Story Files

For each story in the plan:

1. Generate the story markdown file following the project's story template
2. Write to `.maestro/stories/[NN-slug].md`
3. Include all frontmatter fields from the plan
4. Include acceptance criteria and context in the body

If `.maestro/stories/` already has files:

Use AskUserQuestion:
- Question: "Stories directory already has [N] files. How to proceed?"
- Header: "Existing"
- Options:
  1. label: "Replace all (Recommended)", description: "Remove existing stories, import plan stories"
  2. label: "Merge", description: "Add plan stories after existing ones (renumber)"
  3. label: "Cancel", description: "Keep existing stories, abort import"

#### Step 5: Apply Configuration

If the plan includes a `config` section and `include_config` is true:

Use AskUserQuestion:
- Question: "Plan includes configuration. Apply it?"
- Header: "Config"
- Options:
  1. label: "Apply config (Recommended)", description: "Update .maestro/config.yaml with plan settings"
  2. label: "Keep current config", description: "Use existing project configuration"
  3. label: "Review differences", description: "Compare plan config with current config"

If "Review differences":
```
  Config Comparison:
    mode:       plan=[checkpoint]   current=[yolo]
    qa model:   plan=[opus]         current=[sonnet]
    max QA:     plan=[3]            current=[2]
```

Then re-ask whether to apply.

#### Step 6: Display Import Result

```
+---------------------------------------------+
| Workflow Imported                           |
+---------------------------------------------+

  Source:    [source_project or "unknown"]
  Feature:  [feature description]
  Stories:  [N] stories created
  Config:   [applied|kept current]

  Stories created:
    01-[slug]    [type]    [complexity]
    02-[slug]    [type]    [complexity]
    03-[slug]    [type]    [complexity]
    ...

  (ok) Plan imported. Ready to execute.

  Next steps:
    /maestro status          View the imported plan
    /maestro deps            See the dependency graph
    /maestro cost-estimate   Estimate cost for this plan
    /maestro "[feature]"     Start building
```

### save_template(name, description?)

Save the current plan as a reusable template.

#### Step 1: Export First

If `.maestro/plan.yaml` does not exist, run `export()` first.

#### Step 2: Copy to Template Directory

```
mkdir -p .maestro/templates/
cp .maestro/plan.yaml .maestro/templates/[name].yaml
```

#### Step 3: Add Template Metadata

Prepend template metadata to the file:

```yaml
# Template: [name]
# Description: [description or auto-generated]
# Created: [date]
# Based on: [feature description]
#
# Usage:
#   /maestro workflow-import .maestro/templates/[name].yaml

template:
  name: "[name]"
  description: "[description]"
  category: "[auto-detected: auth, api, frontend, fullstack, infra]"
  tags:
    - "[tag1]"
    - "[tag2]"
```

#### Step 4: Generalize

Strip project-specific details:
- Replace absolute file paths with pattern placeholders (e.g., `src/routes/` becomes `[routes_dir]/`)
- Remove project-specific names from acceptance criteria
- Keep architecture patterns generic

Display confirmation:

```
[maestro] Template saved: .maestro/templates/[name].yaml

  (i) Share this file to replicate the workflow in other projects.
  (i) Edit the template to adjust for different tech stacks.
```

### list_templates()

List available templates from `.maestro/templates/` and built-in templates.

```
+---------------------------------------------+
| Workflow Templates                          |
+---------------------------------------------+

  Local templates:
    auth-flow.yaml       "User auth with JWT"       5 stories
    crud-api.yaml        "REST API with CRUD"       3 stories

  Built-in templates:
    (i) No built-in templates installed.
        See: github.com/maestro/templates

  Usage:
    /maestro workflow-import .maestro/templates/auth-flow.yaml
```

## Pre-Built Template Library

These are suggested template structures for common features. They serve as reference patterns — the actual templates are generated from real plan exports.

### auth-basic.yaml
- Stories: user model, auth routes, middleware, login page, tests
- 5 stories, medium complexity
- Tech-agnostic (works with any backend framework)

### crud-api.yaml
- Stories: model/schema, CRUD routes, validation, tests
- 3-4 stories, simple complexity
- Parameterized: resource name, fields

### dashboard.yaml
- Stories: layout, data fetching, charts/widgets, filters, responsive
- 5-6 stories, medium complexity
- Frontend-focused

### realtime.yaml
- Stories: WebSocket setup, event handlers, client connection, presence, tests
- 6 stories, complex
- Requires WebSocket-capable backend

### deployment-pipeline.yaml
- Stories: CI config, Docker setup, env management, monitoring, health checks
- 4-5 stories, medium complexity
- Infrastructure-focused

## YAML Schema Reference

The complete schema for `plan.yaml`:

```yaml
# Required fields
version: "1"                    # Schema version (always "1")
feature: string                 # Feature description
created: string                 # ISO 8601 timestamp
stories: array                  # At least 1 story

# Required per story
stories[].id: integer           # Sequential, starting at 1
stories[].slug: string          # Kebab-case identifier
stories[].title: string         # Human-readable title
stories[].type: enum            # frontend|backend|data|integration|infrastructure|test

# Optional per story
stories[].complexity: enum      # simple|medium|complex (default: medium)
stories[].model: enum           # haiku|sonnet|opus (default: sonnet)
stories[].depends_on: array     # List of story IDs (default: [])
stories[].parallel_safe: bool   # Can run in parallel (default: false)
stories[].acceptance_criteria: array  # Testable criteria
stories[].context: array        # Implementation notes
stories[].files: object         # create, modify, reference arrays

# Optional top-level
source_project: string          # Origin project name
config: object                  # Configuration snapshot
architecture: object            # Architecture summary
dependency_graph: object        # Graph structure
metadata: object                # Aggregate statistics
template: object                # Template metadata (for templates only)
```

## Integration Points

- **Decompose Skill**: produces stories that `export()` reads
- **Plan Command**: generates architecture that `export()` includes
- **Config**: reads `.maestro/config.yaml` for settings snapshot
- **DNA**: reads `.maestro/dna.md` for project context
- **Deps Command**: can visualize the dependency graph from plan.yaml
- **Cost Estimate**: can estimate cost from an imported plan
- **Dev-Loop**: executes stories created by `import()`

### Invocation from Commands

This skill is invoked by:

```
/maestro workflow-export          # calls export()
/maestro workflow-import [path]   # calls import(path)
/maestro workflow-template [name] # calls save_template(name)
/maestro workflow-list            # calls list_templates()
```

These commands are not separate command files — they are handled by the main `/maestro` command which delegates to this skill when it detects the `workflow-` prefix.

## Error Handling

| Error | Action |
|-------|--------|
| No stories to export | Show message, suggest running /maestro first |
| Plan file not found for import | Show message with path suggestions |
| Invalid YAML syntax | Show parse error with line number |
| Schema validation failure | List specific issues, suggest fixes |
| Dependency cycle in plan | Report the cycle, refuse to import |
| Stories directory conflict | Ask user: replace, merge, or cancel |
| Config conflict | Ask user: apply plan config or keep current |
| Incompatible tech stack | Warn, offer to adapt or import as-is |
| Write permission error | Show error, suggest checking permissions |

All errors are non-fatal for the main Maestro workflow. Export/import failures do not block other operations.

## Output Contract

```yaml
output_contract:
  export:
    file_pattern: ".maestro/plan.yaml"
    format: "YAML"
    required_fields:
      - "version"
      - "feature"
      - "created"
      - "stories"
    optional_fields:
      - "config"
      - "architecture"
      - "dependency_graph"
      - "metadata"
  import:
    creates:
      - ".maestro/stories/*.md"
    modifies:
      - ".maestro/config.yaml (if config applied)"
  templates:
    directory: ".maestro/templates/"
    format: "YAML (same schema as plan.yaml with template metadata)"
  display:
    format: "box-drawing"
    sections:
      - "Workflow Exported"
      - "Workflow Imported"
      - "Workflow Templates"
  user_decisions:
    tool: "AskUserQuestion"
    gates:
      - "Compatibility check (import)"
      - "Existing stories handling (import)"
      - "Config application (import)"
```
