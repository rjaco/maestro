---
name: content
description: "Run the content pipeline — create blog posts, case studies, email campaigns, and social content with SEO optimization and editorial review"
argument-hint: "[create <type>|list|status]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Skill
  - WebSearch
  - AskUserQuestion
---

# Maestro Content

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
 ██████╗ ██████╗ ███╗   ██╗████████╗███████╗███╗   ██╗████████╗
██╔════╝██╔═══██╗████╗  ██║╚══██╔══╝██╔════╝████╗  ██║╚══██╔══╝
██║     ██║   ██║██╔██╗ ██║   ██║   █████╗  ██╔██╗ ██║   ██║
██║     ██║   ██║██║╚██╗██║   ██║   ██╔══╝  ██║╚██╗██║   ██║
╚██████╗╚██████╔╝██║ ╚████║   ██║   ███████╗██║ ╚████║   ██║
 ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚═╝  ╚═══╝   ╚═╝
```

Autonomous content creation pipeline. Takes a topic from brief to publication-ready output with SEO optimization and editorial QA. Supports blog posts, case studies, email campaigns, and social media content.

## Step 1: Check Prerequisites

Read `.maestro/config.yaml`. If it does not exist:

```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show content status

Glob `.maestro/content/*.md` to count existing content files. Display a summary:

```
+---------------------------------------------+
| Content Pipeline                            |
+---------------------------------------------+

  Content files: <N> in .maestro/content/
  Formats:       blog, case-study, email, social

```

Use AskUserQuestion:
- Question: "What would you like to do?"
- Header: "Content"
- Options:
  1. label: "Create content", description: "Write a new blog post, case study, email, or social post"
  2. label: "List content", description: "Show all existing content files"
  3. label: "Check status", description: "Review content in draft or review state"

### `create <type>` — Create new content

Valid types: `blog` | `case-study` | `email` | `social`

If type is not provided or not recognized:

Use AskUserQuestion:
- Question: "What type of content would you like to create?"
- Header: "Content Type"
- Options:
  1. label: "Blog post", description: "Long-form article (800-3000 words) with SEO optimization"
  2. label: "Case study", description: "Story-driven proof of results (600-2000 words)"
  3. label: "Email campaign", description: "Targeted email with subject, hook, and CTA (100-600 words)"
  4. label: "Social media", description: "Short-form post for LinkedIn, Twitter, or other platforms (30-300 words)"

Once a type is selected, gather required inputs interactively:

Use AskUserQuestion:
- Question: "What is the topic or subject for this <type>?"
- Header: "Topic"

Use AskUserQuestion:
- Question: "Who is the target audience? (e.g., 'senior engineers', 'marketing managers', 'founders')"
- Header: "Audience"

Use AskUserQuestion:
- Question: "What tone should this use?"
- Header: "Tone"
- Options:
  1. label: "Professional", description: "Formal, authoritative, business-appropriate"
  2. label: "Conversational", description: "Approachable, friendly, plain language"
  3. label: "Technical", description: "Precise, detailed, assumes domain knowledge"
  4. label: "Persuasive", description: "Benefit-driven, action-oriented, compelling"

Use AskUserQuestion:
- Question: "List your target SEO keywords, comma-separated (3-8 recommended). Skip to use auto-generated keywords."
- Header: "Keywords"

Invoke the content-pipeline skill from `skills/content-pipeline/SKILL.md` with the collected inputs. The skill will:

1. Research the topic via WebSearch
2. Build a structured outline appropriate for the format
3. Draft the full content
4. Run an SEO audit (7 checks)
5. Run an editorial QA pass (6 checks)
6. Save to `.maestro/content/{YYYY-MM-DD}-{slug}.md`

Display progress inline:

```
[maestro] Content pipeline started
[maestro] Researching: <topic>
[maestro] Outline: <N> sections, <type> format
[maestro] Draft: <word_count> words
[maestro] SEO audit: <N>/7 passing
[maestro] Editorial QA: <N>/6 passing
[maestro] Saved: .maestro/content/<date>-<slug>.md
[maestro] Status: <draft|review|ready>
```

After completion, show a summary box:

```
+---------------------------------------------+
| Content Created                             |
+---------------------------------------------+

  File:      .maestro/content/<date>-<slug>.md
  Type:      <type>
  Words:     <count>
  Reading:   <N> min
  SEO Score: <N>/100
  Status:    <draft|review|ready>

  (i) Edit the file to move from draft → review → ready
  (i) Run /maestro content status to see all pending content
```

### `list` — List all content files

Glob `.maestro/content/*.md`. For each file, read the frontmatter to extract `type`, `status`, `slug`, `word_count`, `reading_time`, and `created`.

```
+---------------------------------------------+
| Content Files                               |
+---------------------------------------------+

  Date        Slug                              Type        Status    Words
  ----------  --------------------------------  ----------  --------  -----
  2026-03-17  reduce-cicd-pipeline-costs        blog        ready     1450
  2026-03-16  q1-engineering-case-study         case-study  review    920
  2026-03-15  onboarding-email-sequence         email       draft     340
  2026-03-14  weekly-engineering-update         social      ready     180

  Total: <N> files  (<N> ready, <N> review, <N> draft)
```

If `.maestro/content/` contains no files:

```
[maestro] No content files found.

  Create your first piece with:
    /maestro content create blog
```

### `status` — Show content in progress

Glob `.maestro/content/*.md` and filter to files where `status` is `draft` or `review`.

```
+---------------------------------------------+
| Content in Progress                         |
+---------------------------------------------+

  DRAFT (needs writing or revision)
  ----------------------------------
  2026-03-15  onboarding-email-sequence         email    340 words

  REVIEW (ready for human review)
  --------------------------------
  2026-03-16  q1-engineering-case-study         case-study  920 words

  (i) Update the status field in each file's frontmatter when done.
  (i) Valid statuses: draft → review → ready
```

If no in-progress content:

```
[maestro] All content is either ready or the queue is empty.

  Create new content with:
    /maestro content create <type>
```

## Error Handling

| Error | Action |
|-------|--------|
| No topic provided | Prompt interactively with AskUserQuestion |
| Invalid format | List valid formats, ask user to choose |
| WebSearch unavailable | Draft without research, save as `draft` status |
| SEO checks fail | Save as `review` status with issues noted in file |
| `.maestro/content/` doesn't exist | Create the directory before saving |
