---
id: M2-07
slug: knowledge-graph
title: "Knowledge graph for codebase understanding with PageRank"
type: feature
depends_on: []
parallel_safe: true
complexity: high
model_recommendation: sonnet
---

## Acceptance Criteria

1. New skill `skills/knowledge-graph/SKILL.md` exists (200+ lines)
2. Builds a lightweight codebase knowledge graph from:
   - File import/export relationships
   - Function call chains
   - Shared type usage
   - Git co-change frequency (files changed together)
3. PageRank-style scoring identifies "hub" files (most connected, most important)
4. Context Engine integration: when composing context for an agent, prioritize hub files and their neighbors
5. Graph stored as `.maestro/knowledge-graph.md` (human-readable) with file→connections mapping
6. Graph refresh: automatically rebuilds when project DNA changes
7. No external dependencies — pure markdown + bash implementation
8. Mirror: skill exists in both root and plugins/maestro/skills/

## Context for Implementer

Ruflo uses a knowledge graph with PageRank and community detection for codebase understanding. Maestro's equivalent should be simpler — no database, no vector store:

1. **Build phase**: Parse imports/requires/use statements from source files. Use `grep` for patterns like `import`, `require`, `from`, `use`. Record file→file edges.
2. **Score phase**: Simple PageRank: iterate N times, distribute each file's score equally among its imports. Files imported by many files get high scores.
3. **Output**: Ranked list of files by importance score, plus adjacency list.
4. **Integration**: Context Engine reads the knowledge graph and includes top-ranked files + neighbors of the file being modified.

This is NOT a full graph database. It's a lightweight analysis tool that helps the Context Engine make better decisions about which files to include in agent context.

Reference: skills/context-engine/SKILL.md for context composition
Reference: skills/project-dna/SKILL.md for project structure analysis
