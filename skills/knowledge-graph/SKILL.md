---
name: knowledge-graph
description: Lightweight codebase knowledge graph with PageRank scoring — identifies hub files and relationships for smarter context composition
---

# Knowledge Graph

Builds a lightweight codebase knowledge graph by extracting relationships between files, then ranks them by architectural importance using a PageRank-style algorithm. The resulting graph is stored as `.maestro/knowledge-graph.md` and consumed by the Context Engine to compose smarter, more targeted agent context packages.

## Why It Exists

The Context Engine needs to answer: "Given that an agent is working on file X, which other files are most likely to matter?" Without structural knowledge, the Context Engine falls back to directory proximity and keyword matching — both of which miss cross-directory dependencies and shared utility hubs.

The Knowledge Graph gives the Context Engine a structural map: which files are imported by many others (hubs), which files always change together (co-change clusters), and which files are isolated (low priority for context). This lets the Context Engine make decisions based on actual coupling, not proximity.

## Phases

### Phase 1: Build — Relationship Extraction

Scan source files to extract three edge types. Each edge connects a source file to a target file and is tagged with its type.

#### Import Edges

Use grep patterns to find import statements across languages. Run from the project root, excluding `node_modules/`, `dist/`, `build/`, `.git/`, and any generated directories identified in `.maestro/dna.md`.

**TypeScript / JavaScript:**
```bash
grep -rn "import .* from ['\"]\..*['\"]" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  src/
grep -rn "require(['\"]\..*['\"])" \
  --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
  src/
```

Only relative imports (starting with `./` or `../`) are extracted. Absolute imports from `node_modules` are noise and are discarded. Resolve relative paths to canonical project-root-relative paths before storing.

**Python:**
```bash
grep -rn "^from \. import\|^from \.\." \
  --include="*.py" \
  src/ app/
```

**Rust:**
```bash
grep -rn "^use crate::\|^use super::" \
  --include="*.rs" \
  src/
```

**Go:**
```bash
grep -rn "\"[^\"]*\/[^\"]*\"" \
  --include="*.go" \
  . | grep -v "_test.go"
```

For non-code projects (pure markdown, like Maestro itself), use cross-reference patterns instead:

```bash
grep -rn "\[.*\](.*\.md)" \
  --include="*.md" \
  . | grep -v "node_modules"
```

This captures `[link text](path/to/file.md)` references and treats them as import-equivalent edges.

#### Type Edges

Detect shared type and interface usage across files. A type edge connects the file that defines a type to every file that uses it. This captures coupling that import edges may miss when types are re-exported through barrel files.

```bash
# Extract exported type/interface names from definition files
grep -rn "^export \(type\|interface\|enum\) \w\+" \
  --include="*.ts" --include="*.tsx" \
  src/

# For each type name, find files that reference it
# (run per type; batch by grouping types from the same file)
grep -rn "TypeName" --include="*.ts" --include="*.tsx" src/
```

Store type edges with lower weight than import edges — they indicate shared vocabulary, not a hard dependency.

#### Co-change Edges

Extract files that frequently change together from git history. Co-changing files are coupled in ways that static analysis cannot detect (e.g., a config file and its consumer, or a test file and its subject).

```bash
# Get the last 50 commits that touched source files
git log --name-only --pretty=format:"COMMIT" -n 50 | \
  awk '/^COMMIT$/{if(files) print files; files=""} \
       /\.(ts|tsx|js|py|rs|go|md)$/{files=files" "$0}'
```

For each commit, collect the set of files changed together. For every pair (A, B) in that set, increment a co-change counter. After processing all commits:

- Pairs with co-change count >= 3 → add a co-change edge
- Pairs with co-change count < 3 → discard (too sparse to be meaningful)

Co-change edges are bidirectional: if A and B co-change, add edges in both directions.

#### Adjacency List Construction

After extracting all edges, build an adjacency list:

```
file → { imports: [files], imported_by: [files], co_changes: [files], type_refs: [files] }
```

Normalize all file paths to be relative to the project root. Deduplicate edges of the same type between the same pair of files.

For non-code projects where only cross-reference edges exist, merge them into the `imports` bucket — the downstream PageRank computation does not distinguish between edge sources, only the count and direction.

---

### Phase 2: Score — PageRank-Style Importance

Compute an importance score for each file using a simplified PageRank algorithm. No external dependencies — pure iterative computation.

#### Algorithm

```
Initialize:
  scores = { file: 1.0 for all files in adjacency list }
  damping = 0.85
  iterations = 10

For each iteration (1..10):
  new_scores = {}
  For each file F:
    incoming = all files G where F appears in G.imports OR G.imported_by OR G.co_changes
    contribution = sum( scores[G] / outdegree(G) for G in incoming )
    new_scores[F] = (1 - damping) + damping * contribution
  scores = new_scores

Return scores
```

**Outdegree** is the total number of outgoing edges from a file (sum of all edge lists for that file). If outdegree is 0, treat it as 1 to avoid division by zero.

**What high scores mean:**
- A file with a high PageRank score is imported by many other highly-ranked files.
- These are architectural hubs — utilities, type definitions, shared middleware, base classes.
- Including them in an agent's context package has high leverage: the agent immediately understands the interfaces used throughout the codebase.

**What low scores mean:**
- A file with a low PageRank score is a leaf — it imports others but is not imported.
- Leaf files are story-specific: an agent working on that exact file needs it, but agents working elsewhere do not.

#### Score Normalization

After the final iteration, normalize scores to the range [0.0, 1.0]:

```
max_score = max(scores.values())
normalized = { file: score / max_score for file, score in scores.items() }
```

Store the normalized scores in the output.

---

### Phase 3: Output — Human-Readable Graph

Write the graph to `.maestro/knowledge-graph.md` using the following format:

```markdown
# Knowledge Graph

**Generated:** [ISO 8601 timestamp]
**Commit:** [short SHA from `git rev-parse --short HEAD`]
**Files analyzed:** [N]
**Edges found:** [N] (imports: [N], type-refs: [N], co-changes: [N])

## Top 20 Hub Files (by PageRank)

| Rank | File | Score | Connections |
|------|------|-------|-------------|
| 1 | src/lib/auth.ts | 0.842 | 23 |
| 2 | src/types/index.ts | 0.791 | 19 |
| ... | ... | ... | ... |

## Adjacency List

### src/lib/auth.ts
- **imports:** src/types/index.ts, src/config/env.ts
- **imported_by:** src/routes/login.ts, src/routes/register.ts, src/middleware/session.ts
- **co-changes:** src/middleware/auth.ts, tests/auth.test.ts
- **type-refs:** src/types/session.ts

### src/types/index.ts
- **imports:** (none)
- **imported_by:** src/lib/auth.ts, src/routes/login.ts, src/routes/register.ts, ...
- **co-changes:** src/lib/auth.ts
- **type-refs:** (none)
```

**Connections** in the hub table = total number of unique files in all edge lists for that file (imports + imported_by + co-changes + type-refs, deduplicated).

The adjacency list section lists every file with at least one edge. Files with no edges (isolated, unconnected) are omitted — they add no graph information.

---

### Phase 4: Integration with the Context Engine

The Context Engine uses the knowledge graph during Step 3 (Relevance Filter) and Step 4 (Compose Package) of its pipeline.

#### Lookup Protocol

When composing context for an agent working on file X:

1. **Read** `.maestro/knowledge-graph.md` (if absent or stale, trigger a rebuild — see Refresh Triggers below).

2. **Find X's adjacency entry.** If X is not in the graph (e.g., a new file being created), skip graph-based augmentation.

3. **Collect candidate files** from X's edge lists:
   - `imports` → files X depends on directly (high relevance: agent must understand what X uses)
   - `imported_by` → files that depend on X (medium relevance: agent must not break their contracts)
   - `co-changes` → files that historically change with X (medium relevance: they may need updating too)
   - `type-refs` → shared types (high relevance if the story involves type changes)

4. **Score each candidate** using its PageRank score as a relevance multiplier:
   ```
   graph_relevance(candidate) = edge_type_weight * candidate.pagerank_score
   ```
   Edge type weights: `imports` = 1.0, `type-refs` = 0.9, `imported_by` = 0.7, `co-changes` = 0.6.

5. **Merge with the Context Engine's existing relevance scores.** If a file already has a relevance score from path matching or keyword extraction, take the maximum of the two scores rather than adding them.

6. **Boost hub files.** Any file in the Top 20 hub list with PageRank >= 0.6 gets a +0.2 score bonus in the Context Engine's relevance calculation, regardless of direct adjacency to X. Hubs are broadly useful.

#### Example

Agent working on `src/routes/login.ts` (a backend story, Tier T3):

```
Graph lookup for src/routes/login.ts:
  imports:     src/lib/auth.ts (score 0.842), src/types/index.ts (score 0.791)
  imported_by: (none — it's a leaf route)
  co-changes:  src/middleware/session.ts (score 0.612), tests/auth.test.ts (score 0.443)
  type-refs:   src/types/user.ts (score 0.389)

Candidate relevance:
  src/lib/auth.ts      → 1.0 * 0.842 = 0.842 (imports edge)
  src/types/index.ts   → 1.0 * 0.791 = 0.791 (imports edge)
  src/middleware/session.ts → 0.6 * 0.612 = 0.367 (co-change edge)
  src/types/user.ts    → 0.9 * 0.389 = 0.350 (type-ref edge)
  tests/auth.test.ts   → 0.6 * 0.443 = 0.266 (co-change edge)

After merge with Context Engine scores (T3 threshold: 0.5):
  src/lib/auth.ts      → included (0.842)
  src/types/index.ts   → included (0.791)
  src/middleware/session.ts → excluded (0.367 < 0.5)
  src/types/user.ts    → excluded (0.350 < 0.5)
  tests/auth.test.ts   → excluded (0.266 < 0.5)
```

The Context Engine would then extract targeted line ranges from `auth.ts` and `types/index.ts` per its file content extraction rules, rather than including them in full.

---

## Refresh Triggers

The knowledge graph must stay in sync with the codebase. Stale graph data leads to wrong context recommendations.

| Trigger | Action |
|---------|--------|
| `maestro init` | Full build from scratch |
| `project-dna` detects stack changes | Full rebuild (dependency structure may have changed significantly) |
| Git pull / merge / rebase | Staleness check → incremental or full rebuild |
| Story DONE (implementer reports success) | Incremental update for the files the story modified |
| Graph is absent at Context Engine query time | Full build, then answer the query |
| User request (`/maestro knowledge-graph`) | Full rebuild, verbose output |

### Staleness Check

```bash
LAST_COMMIT=$(grep "^\*\*Commit:\*\*" .maestro/knowledge-graph.md | awk '{print $2}')
CHANGED=$(git diff --name-only "$LAST_COMMIT" HEAD | wc -l)
TOTAL=$(grep "^\*\*Files analyzed:\*\*" .maestro/knowledge-graph.md | awk '{print $3}')
PERCENT=$(( CHANGED * 100 / TOTAL ))
```

- `PERCENT >= 15` → full rebuild
- `PERCENT < 15` → incremental update (re-extract edges only for changed files, rerun PageRank)
- `LAST_COMMIT` not found → full rebuild

### Incremental Update

When only a few files changed:

1. Remove all edges that reference any of the changed files (both incoming and outgoing).
2. Re-extract edges for the changed files using the grep patterns from Phase 1.
3. Add the new edges back into the adjacency list.
4. Rerun PageRank (10 iterations) over the full updated graph.
5. Update the hub table and the changed files' adjacency entries.
6. Update the `**Generated:**` and `**Commit:**` headers.

---

## Non-Code Projects

For projects that are primarily markdown (like Maestro itself), import edges are replaced by cross-reference edges extracted from markdown links. The rest of the algorithm is identical.

Cross-reference extraction:
```bash
grep -rn "\[.\+\](\..*\.md)" --include="*.md" . \
  | grep -v "node_modules\|\.git"
```

Each match `[text](path/to/target.md)` creates an edge from the containing file to `target.md`.

**Interpretation for markdown projects:**
- High PageRank = a document referenced by many others (e.g., a glossary, an architecture overview, a shared style guide)
- Co-changes = documents that are always updated together (e.g., a skill and its corresponding plugin mirror)
- Hub documents should be included in context packages for agents editing related documents

---

## Output Contract

```yaml
output_contract:
  file_pattern: ".maestro/knowledge-graph.md"
  required_sections:
    - "# Knowledge Graph"
    - "## Top 20 Hub Files (by PageRank)"
    - "## Adjacency List"
  required_metadata:
    generated: datetime
    commit: string
    files_analyzed: integer
    edges_found: integer
  minimum_lines: 40
```

## Integration Points

- **Invoked by:** `context-engine/SKILL.md` (during relevance filtering, Steps 3-4)
- **Invoked by:** `index-health/SKILL.md` (validates graph freshness during session start)
- **Triggered by:** `project-dna/SKILL.md` (requests rebuild on stack change detection)
- **Reads from:** project source files, `git log`, `.maestro/dna.md` (for exclusion lists)
- **Writes to:** `.maestro/knowledge-graph.md`

## Limitations

- **Dynamic imports** (`import(path)` with a variable) cannot be resolved statically — they are excluded.
- **Barrel re-exports** (`export * from './sub'`) collapse the dependency chain; the barrel file's score absorbs the sub-files' edges.
- **Monorepos** with multiple `package.json` roots: run per-package and merge the graphs. Cross-package edges are captured only if both packages are under the project root.
- **Very large codebases** (10,000+ files): cap the adjacency list at the top 2,000 files by edge count. Leaf files with zero edges are excluded from PageRank computation but remain reachable via direct lookup.
- **Graph reflects static structure only.** Runtime coupling (e.g., dependency injection, event buses) is not captured. Co-change edges partially compensate for this.
