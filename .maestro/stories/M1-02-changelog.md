---
id: M1-02
slug: changelog
title: "Create CHANGELOG.md with full version history"
type: infrastructure
depends_on: []
parallel_safe: true
complexity: medium
model_recommendation: sonnet
---

## Acceptance Criteria

1. `CHANGELOG.md` exists at the project root following Keep a Changelog format (https://keepachangelog.com)
2. Documents v1.0.0 initial release with the original feature set (3-layer architecture, dev-loop, 6 agents, stop hook, etc.)
3. Documents v1.1.0 with all enhancements made in this session (delegation enforcement, parallel dispatch, self-improvement, context engine enhancements, YAML parser fix, new hooks)
4. Each version has sections: Added, Changed, Fixed (only sections that apply)
5. Uses semantic versioning with clear scope descriptions
6. Links at bottom follow Keep a Changelog convention: [Unreleased], [1.1.0], [1.0.0]

## Files

- **Create:** `CHANGELOG.md`
- **Reference:** `plugins/maestro/.claude-plugin/plugin.json` (for version)
- **Reference:** Git history (`git log --oneline`) for what changed between versions

## Context for Implementer

- The project started as a single commit "chore: restructure as marketplace" (v1.0.0)
- The development branch has many subsequent commits adding features
- Use `git log --oneline` to understand the progression
- v1.0.0: Initial plugin with 6 agents, 40+ skills, 3-layer architecture, dev-loop, hooks
- v1.1.0: Core execution engine enhancements (delegation, parallel dispatch, self-improvement metrics, context engine, YAML parser fix, PreToolUse hook, SessionStart hook)
- Keep entries concise but specific — each bullet should describe a concrete change
