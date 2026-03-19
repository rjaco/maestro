---
id: M1-01
slug: plugin-json-metadata
title: "Complete plugin.json metadata to Anthropic-official standards"
type: infrastructure
depends_on: []
parallel_safe: true
complexity: simple
model_recommendation: sonnet
---

## Acceptance Criteria

1. `plugins/maestro/.claude-plugin/plugin.json` has ALL fields populated: name, description, version, author (name, url), license, keywords (10+), homepage, repository, categories
2. Author field includes a URL pointing to the GitHub repo
3. Keywords cover: orchestrator, autonomous, agents, strategy, architecture, execution, self-improving, magnum-opus, kanban, second-brain, memory, TDD, quality-gates, multi-agent
4. Categories field includes appropriate Claude Code marketplace categories
5. The root `.claude-plugin/marketplace.json` and `plugins/maestro/.claude-plugin/plugin.json` are consistent

## Files

- **Modify:** `plugins/maestro/.claude-plugin/plugin.json`
- **Modify:** `.claude-plugin/marketplace.json` (if it needs updating for consistency)
- **Reference:** The existing plugin.json for current state

## Context for Implementer

- Current plugin.json has: name, description, version, author (name only), license, keywords (16)
- Missing: author.url, homepage, repository, categories
- Follow the Claude Code plugin specification for field names and types
- Keep version at 1.1.0 (do not bump)
- The marketplace.json wraps the plugin — ensure it stays consistent
