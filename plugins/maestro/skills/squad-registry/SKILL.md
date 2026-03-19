---
name: squad-registry
description: "Central registry of all available squads with domain/type indexes for fast routing. Populates .maestro/squad-registry.yaml from the squads/ directory, maintains by_domain and by_task indexes, and integrates with the classifier skill to match user intent to the best squad."
---

# Squad Registry

A persistent, indexed directory of every squad available in the project. The registry answers one question at dispatch time: given a user's intent, which squad is most qualified to handle it?

The registry is stored at `.maestro/squad-registry.yaml` and is the authoritative source for squad discovery. It is populated automatically on init, kept in sync when squads are installed or removed, and consumed by the classifier skill for routing decisions.

## Registry Format

`.maestro/squad-registry.yaml`:

```yaml
version: "1.0"
updated: "2026-03-18T14:00:00Z"

squads:
  - name: full-stack-dev
    domain: frontend
    type: specialist
    entry_agent: "maestro:maestro-implementer"
    keywords: [react, api, database, typescript, nextjs, frontend, backend, web]
    description: "Full-stack web development team"
    squad_file: squads/full-stack-dev/squad.md

  - name: devops-sre
    domain: devops
    type: specialist
    entry_agent: "maestro:maestro-implementer"
    keywords: [ci, cd, docker, kubernetes, deploy, infrastructure, terraform, pipeline]
    description: "DevOps and reliability engineering"
    squad_file: squads/devops-sre/squad.md

  - name: content-creator
    domain: content
    type: pipeline
    entry_agent: "maestro:maestro-strategist"
    keywords: [blog, copy, article, seo, marketing, social, content, writing]
    description: "Content creation and marketing team"
    squad_file: squads/content-creator/squad.md

indexes:
  by_domain:
    frontend: [full-stack-dev]
    backend: [full-stack-dev]
    devops: [devops-sre]
    content: [content-creator]
    research: []

  by_task:
    build_api: [full-stack-dev]
    build_ui: [full-stack-dev]
    deploy: [devops-sre]
    write_content: [content-creator]
    research_market: []
```

### Entry Fields

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Machine-readable identifier — matches directory name under `squads/` |
| `domain` | Yes | Primary domain: `frontend`, `backend`, `devops`, `content`, `research` |
| `type` | Yes | Squad role: `specialist` (deep expertise), `pipeline` (sequential stages), `advisory` (no file edits) |
| `entry_agent` | Yes | Subagent type dispatched for the first task in the squad |
| `keywords` | Yes | Free-form terms used for keyword matching against user intent |
| `description` | Yes | One-sentence purpose statement (copied from squad frontmatter) |
| `squad_file` | Yes | Relative path to the `squad.md` file |

### Domain Values

| Domain | Covers |
|--------|--------|
| `frontend` | UI, components, styling, client-side logic |
| `backend` | APIs, services, databases, auth |
| `devops` | CI/CD, infrastructure, containers, deployment |
| `content` | Writing, marketing, SEO, documentation |
| `research` | Market analysis, competitive intelligence, discovery |

### Type Values

| Type | Behavior |
|------|----------|
| `specialist` | Deep expertise in one area; dispatches implementers |
| `pipeline` | Sequential stages (e.g., research → draft → review); dispatches multiple agent types |
| `advisory` | Read-only analysis; does not create or modify files |

---

## Routing Indexes

Two indexes support fast squad selection without scanning every squad's keywords at runtime.

### `by_domain` Index

Maps each domain to an ordered list of squad names. Squads appear in priority order — the first match is the default recommendation.

```yaml
by_domain:
  frontend: [full-stack-dev, mobile-dev]
  backend:  [full-stack-dev, api-specialist]
  devops:   [devops-sre]
  content:  [content-creator]
  research: [market-researcher]
```

### `by_task` Index

Maps normalized task verbs to squad names. Task keys are derived from common user patterns:

| Task Key | Example User Phrases |
|----------|---------------------|
| `build_api` | "build an API", "create an endpoint", "add a route" |
| `build_ui` | "build a UI", "add a component", "design a page" |
| `fix_bug` | "fix a bug", "debug", "investigate an error" |
| `write_tests` | "write tests", "add coverage", "test this" |
| `deploy` | "deploy", "set up CI", "configure pipeline" |
| `write_content` | "write a blog post", "create copy", "draft content" |
| `research_market` | "research competitors", "analyze market", "find alternatives" |
| `refactor` | "refactor", "clean up", "restructure" |
| `security_review` | "audit security", "review permissions", "check vulnerabilities" |

---

## Keyword Matching

When the classifier receives a user intent (e.g., `/maestro build an API`), it selects a squad through this pipeline:

```
+---------------------------+
| 1. Normalize user intent  |
|    → tokenize, lowercase  |
+---------------------------+
           |
           v
+---------------------------+
| 2. Task key lookup        |
|    Match phrase patterns  |
|    to by_task keys        |
+---------------------------+
           |
      match found?
      /         \
    Yes          No
     |            |
     v            v
+----------+  +------------------+
| by_task  |  | 3. Keyword scan  |
| lookup   |  | Score each squad |
+----------+  | by keyword hits  |
     |        +------------------+
     |              |
     +------+-------+
            |
            v
+---------------------------+
| 4. Return best match      |
|    (highest score or      |
|    first by_task result)  |
+---------------------------+
```

### Scoring Algorithm

For keyword scan (step 3), score each squad entry:

1. Count how many of the squad's `keywords` appear in the normalized user intent.
2. Add 2 points for a `domain` match (if the intent contains a domain signal word).
3. Add 1 point for `type` match (e.g., user intent contains "research" → `advisory` type gets a bonus).
4. Select the squad with the highest score. On ties, prefer `specialist` over `pipeline` over `advisory`.

Minimum score to trigger a match: 1. If no squad scores above 0, return `null` and fall through to the default delegation flow.

### Match Output

The classifier emits a routing decision:

```yaml
routing_decision:
  matched_squad: full-stack-dev
  match_method: by_task         # or: keyword_scan, domain_fallback, none
  confidence: high              # high (by_task hit), medium (keyword_scan), low (domain_fallback)
  alternatives: [api-specialist]
  intent_tokens: [build, api, authentication]
```

The orchestrator reads `matched_squad` and activates it before dispatching. If `confidence: low`, present the match to the user for confirmation before activating.

---

## Operations

### init

Populate the registry from the `squads/` directory. Called by `auto-init` and `/maestro init`.

1. Scan `squads/` for subdirectories containing a `squad.md` file.
2. For each found squad, read its frontmatter: `name`, `description`, `domain`, `type`, `entry_agent` (if present), `keywords` (if present).
3. If `domain`, `type`, or `keywords` are missing from the squad frontmatter, infer them:
   - `domain`: scan agent `focus` fields for domain signal words
   - `type`: default to `specialist`
   - `keywords`: extract from `description` and agent `focus` strings
4. Build the `by_domain` and `by_task` indexes from all collected entries.
5. Write `.maestro/squad-registry.yaml`. Create `.maestro/` if it does not exist.
6. Log: `[registry] Indexed N squads. Domains: frontend (N), backend (N), devops (N).`

### refresh

Re-scan the `squads/` directory and rebuild the registry. Called when a squad is installed or removed.

Same steps as `init`, but:
- Preserve existing entries that have not changed (compare `squad_file` mtime).
- Add newly discovered squads.
- Remove entries whose `squad_file` no longer exists.
- Rebuild both indexes from the updated entry list.
- Update `version` timestamp.

Display:

```
[registry] Refreshed. +1 added, -0 removed. Total: 4 squads.
```

### lookup `<query>`

Search the registry for a squad matching a natural-language query.

Run the keyword matching pipeline against `<query>`. Return the top 3 matches with scores:

```
+---------------------------------------------+
| Registry Lookup: "build an API"             |
+---------------------------------------------+

  1. full-stack-dev      score: 5   [backend, specialist]
     "Full-stack web development team"

  2. api-specialist      score: 3   [backend, specialist]
     "Dedicated API and service layer team"

  3. devops-sre          score: 1   [devops, specialist]
     "DevOps and reliability engineering"

  Activate the best match with:
    /maestro squad activate full-stack-dev
```

### status

Display current registry state.

```
+---------------------------------------------+
| Squad Registry                              |
+---------------------------------------------+

  Registry:  .maestro/squad-registry.yaml
  Updated:   2026-03-18T14:00:00Z
  Squads:    4

  By Domain:
    frontend  2 squads
    backend   1 squad
    devops    1 squad
    content   0 squads
    research  0 squads

  Run /maestro squad-registry lookup <query> to test routing.
  Run /maestro squad-registry refresh to rescan squads/.
```

---

## Lifecycle Hooks

### On squad install

When `squad create` completes and writes a new `squads/<name>/squad.md`, call `squad-registry refresh` automatically.

### On squad remove

When a squad directory is deleted, call `squad-registry refresh` automatically.

### On session start

If `.maestro/squad-registry.yaml` does not exist, call `squad-registry init` silently before the first command that needs routing.

---

## Integration with Classifier

The classifier skill calls the registry's keyword matching pipeline when the user issues a command without explicitly naming a squad:

```
User: /maestro build an API for authentication

Classifier flow:
  1. No squad named in command
  2. Call squad-registry lookup "build an API for authentication"
  3. Receive: matched_squad = "full-stack-dev", confidence = "high"
  4. Auto-activate full-stack-dev for this task
  5. Dispatch via delegation skill with squad context loaded
```

If a squad is already active (set in `.maestro/state.local.md`), the registry lookup is skipped — the active squad takes precedence.

If `confidence: low`, the classifier prompts:

```
[maestro] Best match for "build an API": full-stack-dev (low confidence).

  Activate it?
    1. Yes — use full-stack-dev
    2. No — proceed without a squad
    3. Search — /maestro squad-registry lookup <different query>
```

---

## State Schema

`.maestro/squad-registry.yaml` top-level fields:

| Field | Type | Description |
|-------|------|-------------|
| `version` | string | Schema version, currently `"1.0"` |
| `updated` | ISO-8601 | Timestamp of last refresh |
| `squads` | array | All registered squad entries (see Entry Fields above) |
| `indexes.by_domain` | map | Domain → squad name list |
| `indexes.by_task` | map | Task key → squad name list |
