---
name: "speed-dev"
description: "Speed-focused development team for rapid prototyping, hackathons, and MVPs. Minimal review overhead — implement, quick-check, commit."
version: "1.0.0"
author: "Maestro"
agents:
  - role: implementer
    agent: "maestro:maestro-implementer"
    model: haiku
    focus: "Fast, working implementation of the acceptance criteria. Prioritize shipping over polish — correct behavior, no unnecessary abstractions, no gold-plating. Flag blockers immediately rather than speculating."
    tools: [Read, Edit, Write, Bash, Grep, Glob]
  - role: quick-reviewer
    agent: "maestro:maestro-qa-reviewer"
    model: sonnet
    focus: "Rapid correctness check. Verify the acceptance criteria are met and no obvious breakage exists (syntax errors, missing files, broken imports). Flag only blocking issues — not style, not optimization. Report APPROVED or REJECTED in under 5 bullet points."
    tools: [Read, Grep, Glob]
  - role: committer
    agent: "maestro:maestro-implementer"
    model: haiku
    focus: "Stage changed files, write a concise conventional commit message, and create the commit. No analysis — just commit what the implementer produced. If quick-reviewer reported REJECTED, summarize the rejection reason in the commit message and stop."
    tools: [Bash]
orchestration_mode: sequential
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "Acceptance criteria are met — each criterion is traceable to a file change"
  - "No syntax errors or broken imports in modified files"
  - "Quick-reviewer approves before committer runs"
---

# Squad: Speed Dev

## Purpose

Rapid prototyping and MVP delivery with minimal ceremony. This squad skips the architecture phase, the dedicated test agent, and the multi-pass review cycle. Instead it runs a single implementer, a fast correctness check, and an automated commit — three agents, one pass, done.

Use this squad when speed is the primary constraint: hackathons, throwaway prototypes, time-boxed experiments, or small standalone bug fixes where the risk of a mistake is low and iteration is fast.

Do not use this squad for production deployments, security-sensitive features, or any story where a mistake has significant downstream consequences. Use `quality-gate` or `full-stack-dev` for those.

## Agents

### implementer (haiku)

The core of the squad. Implements the story from acceptance criteria to working code.

Responsibilities:
- Read the story and understand the acceptance criteria
- Implement the minimal, working solution — no speculative abstractions
- Prefer editing existing files over creating new ones
- Use idiomatic patterns already present in the codebase (consult dna.md)
- Do not write tests unless the acceptance criteria explicitly require them
- Report STATUS: DONE or STATUS: BLOCKED — no STATUS: NEEDS_CONTEXT speculation

The implementer moves fast and stays focused. If anything is ambiguous, make a reasonable choice and document it in a code comment — do not pause.

### quick-reviewer (sonnet)

A lightweight correctness gate. Not a full QA review.

Responsibilities:
- Check that every acceptance criterion maps to a visible code change
- Verify no broken imports, missing files, or syntax errors
- Confirm the implementation does not obviously break adjacent functionality
- Report APPROVED with a one-line summary, or REJECTED with a short bulleted list of blocking issues only

The quick-reviewer does not check style, optimization, test coverage, or architecture. Those are out of scope for this squad.

### committer (haiku)

Handles the git commit after quick-reviewer approves.

Responsibilities:
- Run `git add` on the files the implementer modified
- Write a conventional commit message: `type(scope): short description`
- Create the commit
- If quick-reviewer reported REJECTED, stop — do not commit broken work

## Workflow

```
implementer → quick-reviewer → committer
```

1. **implementer** receives the story and produces working code meeting the acceptance criteria.

2. **quick-reviewer** receives the diff and verifies correctness. Reports APPROVED or REJECTED.

3. **committer** runs only on APPROVED. Stages files and commits with a conventional commit message.

## Context Sharing

Every agent in this squad receives:
- `.maestro/dna.md` — Project DNA: tech stack, conventions, naming rules
- `CLAUDE.md` — Project-level rules all agents must follow

In addition:
- **quick-reviewer** receives the implementer's full diff as context
- **committer** receives the list of modified files and the quick-reviewer's verdict

## Quality Gates

1. **Criteria coverage** — Every acceptance criterion must map to a traceable file change.
2. **No broken imports** — Modified files must not introduce syntax errors or unresolved imports.
3. **Quick-reviewer approval** — Committer does not run unless quick-reviewer reports APPROVED.

## When to Use

- Hackathons and time-boxed sprints where shipping beats polish
- Throwaway prototypes and proof-of-concept spikes
- MVPs where fast iteration and user feedback are more valuable than code quality
- Small bug fixes in low-risk areas with obvious, contained changes
- Standalone scripts, tooling, or automation that doesn't ship to end users
