---
name: content-pipeline
description: "Autonomous content creation pipeline. Generates blog posts, case studies, email campaigns with SEO optimization and editorial review."
---

# Content Pipeline

Autonomous content creation pipeline that takes a topic from brief to publication-ready output. Supports blog posts, case studies, email campaigns, and social media content with built-in SEO optimization and editorial quality assurance.

## Input

- **topic** — The subject to write about (from `$ARGUMENTS` or upstream classifier)
- **audience** — Target reader persona (e.g., "senior engineers", "marketing managers", "founders")
- **format** — Output type: `blog` | `case-study` | `email` | `social`
- **tone** — Writing voice: `professional` | `conversational` | `technical` | `persuasive`
- **keywords** — Target SEO keywords (comma-separated list, 3-8 recommended)
- **Optional:** `.maestro/strategy.md` for positioning and content pillar alignment
- **Optional:** `.maestro/research.md` for competitive context and data points
- **Optional:** `.maestro/voice.md` for brand voice guidelines

## Process

### Step 1: Research Topic

Gather context before writing. Do not draft without understanding the landscape.

1. Read `.maestro/strategy.md` if it exists to align content with positioning and pillars.
2. Read `.maestro/research.md` if it exists to pull competitive data and market context.
3. Read `.maestro/voice.md` if it exists for brand voice guidelines.
4. Use WebSearch to find:
   - Top 5 existing articles on the topic (understand what already ranks)
   - Recent data points, statistics, or studies to cite
   - Common angles and gaps in existing coverage
   - Related keywords and questions people ask (People Also Ask, related searches)
5. Identify the unique angle — what this piece offers that existing content does not.

Record sources for proper citation in the final output.

### Step 2: Outline

Build a structured outline before drafting. The outline varies by format:

**Blog post outline:**
```
- H1: Title (include primary keyword)
- Introduction (hook + thesis + what the reader will learn)
- H2: Section 1 (supporting point or argument)
  - H3: Subsection (if needed)
- H2: Section 2
- H2: Section 3
- H2: Conclusion / Key Takeaways
- CTA (what the reader should do next)
```

**Case study outline:**
```
- H1: [Company/Project] — [Result achieved]
- H2: The Challenge
- H2: The Approach
- H2: The Implementation
- H2: Results & Metrics
- H2: Key Takeaways
- CTA
```

**Email campaign outline:**
```
- Subject line (3-5 variations)
- Preview text
- Opening hook (first 2 sentences)
- Body (problem → solution → proof)
- CTA (single, clear action)
- P.S. line (optional secondary hook)
```

**Social media outline:**
```
- Hook (first line — must stop the scroll)
- Body (3-5 short paragraphs or bullet points)
- CTA or question to drive engagement
- Hashtags (platform-appropriate count)
```

### Step 3: Draft

Write the full content following the outline. Apply these rules:

1. **Lead with value.** The first paragraph must tell the reader why this matters to them.
2. **One idea per paragraph.** Short paragraphs (2-4 sentences max).
3. **Use concrete examples.** No abstract claims without supporting evidence.
4. **Include data.** Cite at least 2-3 statistics or data points from research.
5. **Write for scanners.** Use subheadings, bold key phrases, and bullet lists.
6. **Match the tone.** Adjust formality, sentence length, and vocabulary to the specified tone.
7. **Respect word count targets:**

| Format     | Target Words | Min  | Max   |
|------------|-------------|------|-------|
| blog       | 1200-1800   | 800  | 3000  |
| case-study | 800-1200    | 600  | 2000  |
| email      | 200-400     | 100  | 600   |
| social     | 50-200      | 30   | 300   |

### Step 4: SEO Optimization

Apply SEO checks to the draft. Each check produces a pass/fail result:

```
+---------------------------------------------+
| SEO Audit                                    |
+---------------------------------------------+
  Check               Status
  ------------------  ------
  Title tag           (ok) Primary keyword in H1, under 60 chars
  Meta description    (ok) 150-160 chars, includes keyword
  Heading hierarchy   (ok) H1 > H2 > H3, no skipped levels
  Keyword density     (ok) Primary: 1.2%, Secondary: 0.8%
  Internal links      (!) Only 1 internal link (target: 3-5)
  Image alt text      (ok) All images have descriptive alt text
  URL slug            (ok) Short, keyword-rich, hyphenated
  First paragraph     (ok) Primary keyword in first 100 words
```

**SEO rules:**
- **Title tag:** Primary keyword present, under 60 characters
- **Meta description:** 150-160 characters, includes primary keyword, compelling
- **Heading hierarchy:** Proper H1 > H2 > H3 nesting, no level skipping
- **Keyword density:** Primary keyword 1-2% of word count, secondary 0.5-1%
- **Internal links:** 3-5 links to other `.maestro/content/` files or project pages
- **First paragraph:** Primary keyword appears in the first 100 words
- **URL slug:** Short, keyword-rich, hyphenated (auto-generated from title)

Fix any failing checks before proceeding.

### Step 5: Editorial Review

Run editorial quality assurance. This replaces human editor passes:

1. **Readability score** — Target Flesch-Kincaid grade level 8-10 for blog/email, 10-12 for technical/case-study.
   - Sentences over 25 words: flag and split
   - Paragraphs over 4 sentences: flag and break up
   - Passive voice: keep under 10% of sentences

2. **AI cliche detection** — Flag and rewrite any of these:
   - "In today's fast-paced world..."
   - "It's important to note that..."
   - "In conclusion..."
   - "Leverage" (use "use"), "utilize" (use "use"), "synergy"
   - "Dive deep", "game-changer", "revolutionary", "cutting-edge"
   - "At the end of the day..."
   - "It goes without saying..."

3. **Tone consistency** — Verify the tone matches the specified target throughout. Flag sections that drift.

4. **Citation check** — Every data point or statistic must have a source. No orphan claims.

5. **CTA clarity** — The call-to-action must be specific and actionable. "Learn more" is too vague. "Download the template" or "Start your free trial" is concrete.

```
+---------------------------------------------+
| Editorial QA                                 |
+---------------------------------------------+
  Check               Status
  ------------------  ------
  Readability         (ok) Grade 9.2 (target: 8-10)
  AI cliches          (ok) 0 detected
  Tone consistency    (ok) Conversational throughout
  Citations           (!) 1 unsourced claim in Section 2
  CTA clarity         (ok) Specific action with clear value
  Passive voice       (ok) 6% (target: under 10%)
```

Fix any issues before finalizing.

### Step 6: Finalize

1. Generate the output file with proper frontmatter.
2. Generate the slug from the title (lowercase, hyphenated, no special characters).
3. Calculate reading time: `ceil(word_count / 238)` minutes.
4. Save to `.maestro/content/{YYYY-MM-DD}-{slug}.md`.
5. If brain is configured, also store in brain for cross-session retrieval.

## Output Format

Every content file follows this structure:

```markdown
---
type: blog | case-study | email | social
status: draft | review | ready
target_audience: "description of audience"
keywords:
  - primary keyword
  - secondary keyword
  - tertiary keyword
word_count: 1423
reading_time: 6
seo_score: 92
created: YYYY-MM-DD
slug: the-url-slug
---

# Title Here

[Content body...]

---

## Sources

1. [Source title](URL) — accessed YYYY-MM-DD
2. [Source title](URL) — accessed YYYY-MM-DD
```

## Output Contract

```yaml
output_contract:
  file: ".maestro/content/{date}-{slug}.md"
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
  required_sections:
    blog:
      - "# {title}"
      - "## Sources"
    case-study:
      - "# {title}"
      - "## The Challenge"
      - "## The Approach"
      - "## Results & Metrics"
      - "## Key Takeaways"
      - "## Sources"
    email:
      - "Subject:"
      - "Preview:"
      - "Body:"
      - "CTA:"
    social:
      - "Hook:"
      - "Body:"
      - "CTA:"
  word_bounds:
    blog: { min: 800, max: 3000 }
    case-study: { min: 600, max: 2000 }
    email: { min: 100, max: 600 }
    social: { min: 30, max: 300 }
```

## Integration Points

### With Strategy Skill

Reads `.maestro/strategy.md` to align content with:
- Content pillars (Step 5 of strategy)
- SEO keyword clusters
- Channel priorities (determines which format to use)

### With Content Validator

After finalization, invoke the `content-validator` skill to validate the output against the output contract. If validation fails, loop back to the failing step (SEO or editorial) and fix.

### With Kanban

If kanban integration is configured, content pieces can be tracked as tasks:
- `draft` status maps to "In Progress"
- `review` status maps to "In Review"
- `ready` status maps to "Done"

### With Brain

If brain is configured, store completed content in brain for:
- Cross-session retrieval of past content
- Building an internal content library
- Avoiding duplicate topics

## Error Handling

| Error | Action |
|-------|--------|
| No topic provided | Ask user for topic and audience |
| WebSearch unavailable | Draft without research, mark as `draft` not `ready` |
| SEO checks fail after 2 revision passes | Save as `review` status, flag issues in frontmatter |
| Word count outside bounds | Trim or expand, then re-check |
| Voice file missing | Use default tone, note in output |

## Example Invocation

```
/content-pipeline "How to reduce CI/CD pipeline costs" --audience "DevOps engineers" --format blog --tone technical --keywords "CI/CD costs, pipeline optimization, build times"
```

Output:
```
[maestro] Content pipeline started
[maestro] Researching: CI/CD pipeline cost reduction
[maestro] Outline: 5 sections, blog format
[maestro] Draft: 1,450 words
[maestro] SEO audit: 6/7 passing (fixing internal links)
[maestro] Editorial QA: 5/5 passing
[maestro] Saved: .maestro/content/2026-03-17-reduce-cicd-pipeline-costs.md
[maestro] Status: ready
```
