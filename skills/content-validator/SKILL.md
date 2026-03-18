---
name: content-validator
description: "Validate markdown output against format contracts, SEO signals, readability, and structural rules. Replaces test suites for non-code work."
---

# Content Validator

Universal validation engine for markdown outputs produced by Maestro skills. Checks frontmatter schemas, structural integrity, cross-references, word counts, readability, SEO signals, and link health. This skill replaces test suites for non-code workflows -- every content output has a contract, and this validator enforces it.

## When to Use

- Called automatically by the QA reviewer in knowledge-work mode (non-code tasks)
- Called by `content-pipeline` after finalization
- Called manually via `/content-validator path/to/file.md`
- Called by `output-contracts` to validate any skill output

## Input

- **file** — Path to the markdown file to validate (from `$ARGUMENTS`)
- **contract** — Optional: path to a contract YAML or inline contract. If omitted, infers the contract from the file's `type` frontmatter field.
- **strict** — Optional: `true` | `false` (default: `true`). In strict mode, warnings are treated as failures.

## Validation Types

### 1. Frontmatter Schema Validation

Parse the YAML frontmatter block and validate against the contract's `frontmatter` definition.

**Checks:**
- All required fields are present
- Field types match (string, integer, date, list)
- Enum fields contain only allowed values
- List fields meet min/max length constraints
- Date fields are valid ISO 8601 format
- Integer fields are within specified ranges

**Example contract:**
```yaml
frontmatter:
  type: "enum(blog,case-study,email,social)"
  status: "enum(draft,review,ready)"
  target_audience: string
  keywords: "list(string, min=1, max=8)"
  word_count: integer
  reading_time: integer
  seo_score: "integer(0-100)"
  created: date
  slug: string
```

**Validation output:**
```
+---------------------------------------------+
| Frontmatter Validation                       |
+---------------------------------------------+
  Field             Status
  ----------------  ------
  type              (ok) "blog" is valid enum value
  status            (ok) "ready" is valid enum value
  target_audience   (ok) string present
  keywords          (ok) 4 items (min: 1, max: 8)
  word_count        (ok) 1423 is valid integer
  reading_time      (ok) 6 is valid integer
  seo_score         (ok) 92 in range 0-100
  created           (ok) 2026-03-17 is valid date
  slug              (ok) string present
```

### 2. Structural Validation

Verify the document's heading hierarchy and required sections.

**Checks:**
- Required sections from the contract's `required_sections` list are present
- Heading hierarchy follows H1 > H2 > H3 order (no skipped levels)
- Document starts with exactly one H1
- No orphan H3 headings (every H3 must be under an H2)
- No orphan H4 headings (every H4 must be under an H3)
- Sections appear in the expected order (if `ordered: true` in contract)

**Validation output:**
```
+---------------------------------------------+
| Structural Validation                        |
+---------------------------------------------+
  Check                   Status
  ----------------------  ------
  H1 present              (ok) "How to Reduce CI/CD Costs"
  Required sections       (ok) 2/2 present
  Heading hierarchy       (ok) H1 > H2 > H3, no skips
  Orphan headings         (ok) None detected
  Section order           (ok) Matches contract
```

**Hierarchy violation example:**
```
  Heading hierarchy       (x) H3 at line 45 without parent H2
                              Line 44: ## Setup Guide
                              Line 45: #### Advanced Config  <-- skips H3
```

### 3. Cross-Reference Validation

Check that internal links to other `.maestro/` files resolve correctly.

**Checks:**
- Every `[text](path)` link where path starts with `.maestro/` must point to an existing file
- Every `[text](path#anchor)` link must point to a valid heading anchor in the target file
- Relative links are resolved from the file's directory
- Flag broken links with their line number and target path

**Validation output:**
```
+---------------------------------------------+
| Cross-Reference Validation                   |
+---------------------------------------------+
  Link                          Status
  ----------------------------  ------
  .maestro/strategy.md          (ok) file exists
  .maestro/research.md#seo      (ok) file + anchor exist
  .maestro/content/old-post.md  (x) file not found (line 87)
```

### 4. Word Count Bounds

Verify the document body (excluding frontmatter and sources section) meets the word count constraints.

**Checks:**
- Actual word count is at or above `min_words`
- Actual word count is at or below `max_words`
- Frontmatter `word_count` field matches actual count (tolerance: +/- 5%)

**Validation output:**
```
+---------------------------------------------+
| Word Count Validation                        |
+---------------------------------------------+
  Metric              Value     Status
  ------------------  --------  ------
  Actual word count   1423      (ok) within 800-3000
  Frontmatter claim   1423      (ok) matches actual
  Min bound           800       (ok) 1423 >= 800
  Max bound           3000      (ok) 1423 <= 3000
```

### 5. Readability Check

Analyze the prose for readability and writing quality.

**Checks:**
- **Average sentence length** — Target: 15-20 words. Flag sentences over 25 words.
- **Passive voice percentage** — Target: under 10%. Count sentences using passive constructions.
- **Jargon density** — Ratio of domain-specific terms to total words. Target: under 5% for general audiences, under 15% for technical audiences.
- **Paragraph length** — Flag paragraphs over 4 sentences.
- **Flesch-Kincaid grade level** — Target depends on audience (see content-pipeline).

**Scoring:**
- Compute a readability score from 0-100 based on these factors
- 90-100: Excellent readability
- 70-89: Good readability
- 50-69: Needs improvement
- Below 50: Significant readability issues

**Validation output:**
```
+---------------------------------------------+
| Readability Check                            |
+---------------------------------------------+
  Metric                Value     Target    Status
  --------------------  --------  --------  ------
  Avg sentence length   17 words  15-20     (ok)
  Passive voice         7%        < 10%     (ok)
  Jargon density        3.2%      < 5%      (ok)
  Long paragraphs       0         0         (ok)
  Flesch-Kincaid        9.2       8-10      (ok)
  Readability score     91/100              (ok)
```

### 6. SEO Signal Validation

Check for the presence and quality of SEO elements.

**Checks:**
- **Title (H1):** Contains at least one target keyword, under 60 characters
- **Meta description:** Present in frontmatter or first paragraph, 150-160 characters, contains keyword
- **Headings:** H2s contain secondary keywords where natural
- **Keyword presence:** Primary keyword appears in first 100 words
- **Keyword density:** Primary keyword 1-2% of total word count
- **Internal links:** At least 3 internal links to other content
- **Alt text:** All images have descriptive alt attributes

**Validation output:**
```
+---------------------------------------------+
| SEO Signal Validation                        |
+---------------------------------------------+
  Signal              Status
  ------------------  ------
  Title keyword       (ok) "CI/CD" in H1
  Title length        (ok) 42 chars (max: 60)
  Meta description    (ok) 155 chars, keyword present
  Heading keywords    (ok) 3/4 H2s contain keywords
  First 100 words     (ok) Primary keyword at word 12
  Keyword density     (ok) 1.4% (target: 1-2%)
  Internal links      (!) 2 found (target: 3+)
  Image alt text      (ok) All images covered
```

### 7. Link Health Validation

Verify that links in the document are functional.

**Internal link checks (always run):**
- Links to `.maestro/` files resolve to existing files
- Links to anchors within files resolve to existing headings
- Relative links resolve correctly from the file's location

**External link checks (optional, requires `--check-external`):**
- Use `curl -sI` to check HTTP status codes for external URLs
- Flag any link returning 4xx or 5xx status
- Skip external checks by default to avoid rate limiting and network dependency

**Validation output:**
```
+---------------------------------------------+
| Link Health                                  |
+---------------------------------------------+
  Link                              Status
  --------------------------------  ------
  .maestro/strategy.md              (ok) exists
  .maestro/content/prev-post.md     (ok) exists
  https://example.com/stats         (ok) 200
  https://example.com/old-page      (x) 404 Not Found
```

## Output Contract Pattern

Skills declare their output contract in YAML, either in the skill's frontmatter or in a dedicated contract file. The content-validator reads this contract and validates against it.

```yaml
output_contract:
  file: "path/pattern"
  required_sections:
    - "## Section1"
    - "## Section2"
  frontmatter:
    type: string
    status: "enum(draft,review,ready)"
  min_words: 800
  max_words: 3000
  checks:
    - frontmatter
    - structure
    - cross_references
    - word_count
    - readability
    - seo
    - links
```

**Field reference:**

| Field | Type | Description |
|-------|------|-------------|
| `file` | string | Glob pattern for the output file path |
| `required_sections` | list | Heading strings that must be present |
| `frontmatter` | object | Schema for frontmatter fields |
| `min_words` | integer | Minimum word count for body content |
| `max_words` | integer | Maximum word count for body content |
| `checks` | list | Which validation types to run (default: all) |
| `ordered` | boolean | Whether required_sections must appear in order |
| `audience` | string | Audience type for readability targets (general/technical) |

## Validation Summary

After running all checks, produce a combined summary:

```
+---------------------------------------------+
| Validation Summary                           |
+---------------------------------------------+
  File: .maestro/content/2026-03-17-reduce-cicd-costs.md

  Check                 Result
  --------------------  ------
  Frontmatter schema    (ok) 9/9 fields valid
  Structure             (ok) All sections present
  Cross-references      (ok) 3/3 links resolve
  Word count            (ok) 1423 words (800-3000)
  Readability           (ok) Score: 91/100
  SEO signals           (!) 1 warning (internal links)
  Link health           (ok) 5/5 links healthy

  Overall: PASS (1 warning)
```

**Exit conditions:**
- `PASS` — All checks pass (warnings allowed in non-strict mode)
- `WARN` — All checks pass but warnings present (strict mode treats as FAIL)
- `FAIL` — One or more checks failed

## Integration Points

### With Content Pipeline

Called after Step 6 (Finalize) to validate the output before marking as `ready`. If validation fails, the pipeline loops back to fix the issues.

### With QA Reviewer

In knowledge-work mode (non-code tasks), the QA reviewer invokes content-validator instead of running test suites. The validation summary replaces test results in the QA report.

### With Output Contracts

The `output-contracts` skill defines contracts for all skill output types. Content-validator reads these contracts and validates any file against them.

### With Marketing Automation

Validates ad copy outputs, campaign files, and A/B test documents against their respective contracts.

## Error Handling

| Error | Action |
|-------|--------|
| File not found | Report `(x) File not found` and exit |
| No frontmatter block | Report `(x) No YAML frontmatter` and skip schema validation |
| Contract not found | Attempt to infer from file type, warn if inference fails |
| External link timeout | Skip link, report `(!) Timeout` instead of `(x)` |
| Malformed YAML frontmatter | Report parse error with line number |

## Example Invocation

```
/content-validator .maestro/content/2026-03-17-reduce-cicd-costs.md
```

With explicit contract:
```
/content-validator .maestro/content/report.md --contract .maestro/contracts/research.yaml
```

Strict mode with external link checks:
```
/content-validator .maestro/content/post.md --strict --check-external
```
