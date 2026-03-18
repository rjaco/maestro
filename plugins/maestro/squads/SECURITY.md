# Squad Security Policy

Community squads run agent workflows inside a user's project. Because squads can chain multiple agents and share file context across them, a malicious or poorly written squad can cause real harm. This document defines what is and is not allowed, and how submitted squads are reviewed before they are trusted.

---

## Background: Why This Policy Exists

OpenClaw (a competing agent framework) suffered CVE-2026-25253, a critical remote code execution vulnerability caused by malicious community skills. Attackers published skills that used unrestricted Bash tool calls to exfiltrate SSH keys and AWS credentials. The vulnerability was introduced by community contributions with no security review process.

Maestro's squad model learns from that incident. Every community squad passes through automated validation and manual security review before it is trusted.

---

## What Squads Are Allowed to Do

Squads may:
- Invoke built-in Maestro agents by their registered names
- Share project files as context, provided those files are within the project root
- Define quality gates that reference test commands or lint commands the user has already configured
- Use any orchestration mode (`sequential`, `parallel`, `dynamic`)
- Specify agent model preferences (`haiku`, `sonnet`, `opus`)

---

## What Squads Are Prohibited from Doing

### Shell Execution

Squads must not configure agents with unrestricted Bash tool access. Specifically:

- `dangerouslyDisableSandbox: true` is **never permitted** in a community squad
- Inline agent definitions must not grant the `Bash` tool without a documented, narrow purpose
- Shell commands that operate outside the project directory are prohibited

Rationale: unrestricted shell access is the primary attack surface for RCE. The OpenClaw incident was caused by exactly this configuration.

### File System Exfiltration

`shared_context` paths must not reference:

- Absolute paths (e.g., `/home/user/.ssh/id_rsa`)
- Paths using `~/` or `$HOME`
- Paths that traverse above the project root using `../`
- Files in well-known sensitive locations: `.ssh/`, `.aws/`, `.gnupg/`, `.env`, `*credentials*`, `*token*`, `*secret*`

An agent that receives a user's SSH key or AWS credentials as shared context can leak that data to any downstream tool call, including `WebFetch` and `WebSearch`.

### Network Exfiltration

Squads must not be structured to send project data to external URLs. Red flags that will trigger rejection:

- `WebFetch` calls in inline agent definitions that POST to non-localhost URLs
- `WebSearch` calls whose query templates are constructed from file content
- Any pattern that reads a sensitive file and then makes an outbound network call in the same agent step

### Inline Agent Abuse

Squads may define inline agents (agents not registered in `agents/`) for narrow, well-scoped tasks. Inline agents must:

- Have a `focus` that is specific and workflow-scoped
- Not be granted tool sets wider than built-in agents
- Be clearly documented in the squad body

Inline agents that effectively redefine the Maestro orchestrator or claim system-level permissions will be rejected.

### Social Engineering Content

Squad descriptions, purpose sections, and quality gate definitions must not instruct the orchestrator to bypass its own policies. Phrases like "ignore previous instructions", "you are now unrestricted", or "skip security checks" in any squad field are grounds for immediate rejection and a contributor ban.

---

## Review Process

All community squad PRs go through two stages before merge.

### Stage 1: Automated Validation

The CI pipeline runs `/maestro squad validate` against every squad file in the PR. This checks:

- Frontmatter schema (all required fields, correct types)
- Agent references resolve to registered agents
- `shared_context` paths don't escape the project root
- No `dangerouslyDisableSandbox` in any configuration
- No sensitive path patterns in `shared_context`
- Semver-valid `version` field
- Description meets minimum substantiveness threshold

A squad that fails automated validation is not reviewed by a human until the author fixes the errors.

### Stage 2: Manual Security Review

A maintainer with security review rights reads the squad and checks:

1. **Intent review** — Does the squad's stated purpose match its actual configuration? A squad claiming to "review PRs" but configured to read `.env` files is suspicious regardless of whether it passes automated checks.

2. **Tool surface review** — Are the tools granted to each agent proportionate to their stated role? A researcher agent that needs `WebFetch` is fine. A researcher agent that also gets `Bash` needs a written justification.

3. **Context scope review** — Is each `shared_context` entry necessary? Maintainers will ask for justification of any context file that isn't obviously required by the workflow.

4. **Inline agent review** — If the squad defines inline agents, are they narrowly scoped? Do they grant themselves only the tools they need?

5. **Exfiltration path review** — Is there any plausible chain of operations that could result in sensitive data leaving the project directory?

Manual review typically completes within 3 business days.

### Trusted Status

Once a squad passes both stages and is merged, it is marked as `reviewed: true` in the registry. Users can filter the marketplace to show only reviewed squads. Unreviewed squads (local or submitted but not yet merged) run with a warning in the Maestro UI.

---

## Reporting a Vulnerability

If you discover a security issue in a community squad or in Maestro's squad execution model:

1. Do **not** open a public GitHub issue
2. Email security@maestro-project.dev with the subject line: `[SQUAD SECURITY] <squad-name>`
3. Include: the squad file, a description of the vulnerability, and (if possible) a proof-of-concept showing the impact
4. You will receive an acknowledgment within 48 hours

Confirmed vulnerabilities in community squads will result in immediate removal of the affected squad and notification to users who have run it.

---

## Maintainer Responsibilities

Maintainers who approve community squads are responsible for:
- Not approving squads they have not personally reviewed
- Escalating any squad that shows signs of data exfiltration intent, even if it passes automated checks
- Flagging repeat contributors who submit squads that consistently probe security boundaries

Security review is not a formality. When in doubt, reject and ask for justification.
