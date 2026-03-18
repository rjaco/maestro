# Squad Validation Rules

Before a squad is accepted — either by the community review process or by the local validator — it must pass every rule in this document. Rules are grouped by category. Each rule states what is checked, why it matters, and what a failing example looks like.

Run the validator with:

```
/maestro squad validate <squad-name>
```

The validator exits `0` if all rules pass, `1` if any rule fails. Each failure prints the rule ID, a description of the violation, and the field or line where the violation was found.

---

## Category 1: Frontmatter Schema

### V-01 — Required fields present

All of these fields must be present in the YAML frontmatter:

| Field | Type |
|-------|------|
| `name` | string |
| `description` | string |
| `version` | string |
| `author` | string |
| `agents` | list (at least one item) |

**Fail example:**
```yaml
---
name: my-squad
description: "Does stuff"
agents:
  - role: worker
    agent: maestro-implementer
---
```
Missing `version` and `author`.

---

### V-02 — Field types are correct

Each field must match its declared type. A `version` field that is an integer (`1`) fails. An `agents` field that is a string instead of a list fails.

**Fail example:**
```yaml
version: 1        # must be a string: "1.0.0"
agents: "solo"    # must be a list
```

---

### V-03 — Name matches filename

The `name` field in frontmatter must match the filename (without the `.md` extension). A file named `code-review-squad.md` must have `name: code-review-squad`.

**Why:** Prevents registry collisions where two squads claim the same name.

---

### V-04 — Orchestration mode is a known value

If `orchestration_mode` is present, it must be one of: `sequential`, `parallel`, `dynamic`.

**Fail example:**
```yaml
orchestration_mode: waterfall   # not a valid mode
```

---

## Category 2: Agent References

### V-05 — Agent references resolve

Each entry in `agents` must reference either:
- A registered built-in agent (one of: `maestro-implementer`, `maestro-qa-reviewer`, `maestro-strategist`, `maestro-researcher`, `maestro-fixer`, `maestro-proactive`)
- An inline agent definition that includes all required inline fields (see V-06)

**Fail example:**
```yaml
agents:
  - role: builder
    agent: my-custom-agent   # not a registered agent and no inline definition
```

---

### V-06 — Inline agents have required fields

An inline agent (one not referencing a registered agent) must include:
- `role` — string, the agent's role in this squad
- `focus` — string, what this agent specifically does
- `model` — one of `haiku`, `sonnet`, `opus`

**Fail example:**
```yaml
agents:
  - role: summarizer
    # missing: focus, model, and no registered agent reference
```

---

### V-07 — Model values are valid

Each agent's `model` field, if present, must be one of: `haiku`, `sonnet`, `opus`.

**Fail example:**
```yaml
model: gpt-4   # not a Maestro model identifier
```

---

## Category 3: Security Rules

These rules exist to prevent community squads from being used as attack vectors. See `SECURITY.md` for the full security policy.

### V-08 — No dangerouslyDisableSandbox

No field in the squad file — frontmatter or body — may contain the string `dangerouslyDisableSandbox`. This configuration disables the Bash tool sandbox and is the primary vector for RCE attacks.

**Fail example:**
```yaml
agents:
  - role: runner
    agent: maestro-implementer
    config:
      dangerouslyDisableSandbox: true   # rejected
```

---

### V-09 — No unrestricted Bash grants

Inline agent definitions must not grant unrestricted `Bash` tool access. Any inline agent that includes `Bash` in its tool list must also include a `justification` field explaining why it needs shell access and what commands are expected.

**Fail example:**
```yaml
agents:
  - role: executor
    focus: "Run the build"
    model: sonnet
    tools: [Bash, Read, Write]   # Bash without justification
```

---

### V-10 — shared_context paths don't escape project root

Every path listed under `shared_context` must:
- Be a relative path (must not start with `/`)
- Not use `~/` or `$HOME` or `$`-prefixed variables
- Not contain `../` (directory traversal)
- Not reference well-known sensitive locations: `.ssh`, `.aws`, `.gnupg`, `.env`, and patterns matching `*credential*`, `*token*`, `*secret*`, `*password*`

**Fail examples:**
```yaml
shared_context:
  - ../sibling-project/config.json   # traversal
  - /home/user/.aws/credentials      # absolute path to sensitive file
  - ~/.ssh/id_rsa                    # home-relative sensitive file
  - .env                             # environment secrets file
```

---

### V-11 — No absolute paths anywhere in frontmatter

No frontmatter field may contain an absolute path (a string beginning with `/`). This applies to `shared_context`, any `config` subfields, and custom fields.

---

### V-12 — No social-engineering content

The squad file must not contain any of the following phrases (case-insensitive) in any field:
- "ignore previous instructions"
- "ignore your instructions"
- "you are now"
- "disregard your"
- "bypass security"
- "skip security"
- "pretend you are"
- "act as if you have no restrictions"

These patterns indicate prompt injection attempts designed to override the orchestrator's behavior.

---

## Category 4: Content Quality

### V-13 — Description is substantive

The `description` field must:
- Be at least 20 characters
- Not be a placeholder like "a squad", "my squad", "todo", "description here", "does stuff"
- Contain at least one verb (describes what the squad *does*)

**Fail examples:**
```yaml
description: "a squad"
description: "my workflow"
description: "todo"
```

---

### V-14 — Version follows semver

The `version` field must match the pattern `MAJOR.MINOR.PATCH` where each component is a non-negative integer. Pre-release labels (e.g., `1.0.0-beta.1`) are accepted. Build metadata (e.g., `1.0.0+build.1`) is accepted.

**Fail examples:**
```yaml
version: "v1.0"        # missing patch component
version: "1.0.0.0"     # four components
version: "latest"      # not semver
version: 1             # not a string
```

---

### V-15 — Author is a valid identifier

The `author` field must be a non-empty string. It must not be a placeholder value: `your-github-handle`, `anonymous`, `unknown`, `author`.

---

### V-16 — Body contains required sections

The Markdown body (after frontmatter) must contain all of these second-level headings:
- `## Purpose`
- `## Agents`
- `## Workflow`

The sections `## Context Sharing` and `## Quality Gates` are required if `shared_context` or `quality_gates` are specified in frontmatter. If those frontmatter fields are absent, the corresponding body sections are optional.

---

## Summary Table

| Rule | Category | Blocking |
|------|----------|----------|
| V-01 | Frontmatter | Yes |
| V-02 | Frontmatter | Yes |
| V-03 | Frontmatter | Yes |
| V-04 | Frontmatter | Yes |
| V-05 | Agent References | Yes |
| V-06 | Agent References | Yes |
| V-07 | Agent References | Yes |
| V-08 | Security | Yes |
| V-09 | Security | Yes |
| V-10 | Security | Yes |
| V-11 | Security | Yes |
| V-12 | Security | Yes |
| V-13 | Content Quality | Yes |
| V-14 | Content Quality | Yes |
| V-15 | Content Quality | Yes |
| V-16 | Content Quality | Yes |

All rules are blocking. A squad that fails any single rule will not be accepted by the validator.

---

## Adding a New Validation Rule

Validation rules are versioned alongside Maestro. To propose a new rule:

1. Open a GitHub discussion describing the threat or quality problem the rule addresses
2. Provide at least two real examples of squads that would have been caught by the rule
3. If accepted, a maintainer will assign a rule ID and implement the check in the validator
