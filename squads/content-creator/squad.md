---
name: "content-creator"
description: "Content creation and marketing team that produces SEO-optimized articles, blog posts, documentation, and social media assets"
version: "1.0.0"
author: "Maestro"
agents:
  - role: researcher
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Topic research, competitor content analysis, and keyword identification. Produces a research brief — target audience, primary keyword, secondary keywords, content angle, and competitor gap — that the writer executes against."
    tools: [Read, Write, Grep, Glob, WebSearch, WebFetch]
  - role: writer
    agent: "maestro:maestro-implementer"
    model: sonnet
    focus: "Draft creation, SEO optimization, and structured content. Consumes the research brief. Produces complete, structured drafts with hooks, H2/H3 sections, internal links, and CTAs tuned to the funnel stage."
    tools: [Read, Edit, Write, Grep, Glob]
  - role: editor
    agent: "maestro:maestro-qa-reviewer"
    model: opus
    focus: "Review for tone, accuracy, readability, brand consistency, and SEO completeness. Read-only. Reports APPROVED or REJECTED with specific line-level feedback."
    tools: [Read, Grep, Glob]
orchestration_mode: sequential
shared_context:
  - ".maestro/dna.md"
  - "CLAUDE.md"
quality_gates:
  - "Researcher produces an explicit brief before writing begins — no undirected drafts"
  - "Primary keyword appears in H1, first paragraph, and at least one H2"
  - "Readability is grade 8 or below — short sentences, active voice, concrete words"
  - "Every claim cites a source or links to evidence"
  - "CTA is present, specific, and aligned to the content's funnel stage"
  - "Editor approves with no issues at confidence >= 80"
---

# Squad: Content Creator

## Purpose

Produce marketing content, blog posts, documentation, and social media assets with consistent quality, SEO alignment, and brand voice. This squad enforces a research-first discipline: no writing begins until there is an explicit brief defining the audience, keyword strategy, and content angle. The editor provides a final gate that catches tone, accuracy, and SEO issues before content is published.

Use this squad when a story requires producing original written content — especially content intended to rank in search, represent the brand publicly, or persuade a specific audience.

## Agents

### researcher (sonnet)

The first agent to run. Transforms a content request into a concrete brief that leaves nothing ambiguous for the writer.

Responsibilities:
- Identify the target audience: who they are, what they already know, what they need
- Determine search intent: informational, navigational, commercial, or transactional
- Select the primary keyword and 2-4 secondary keywords based on relevance and opportunity
- Survey the top-ranking competitor pieces: what they cover, what they miss, what angles are overused
- Identify the content's differentiating angle — what makes this piece worth reading over existing results
- Define the funnel stage: awareness, consideration, or decision
- Recommend content format: long-form article, listicle, how-to guide, case study, social thread
- Produce a structured research brief the writer receives as context

The researcher does not write the content. It produces the blueprint that makes the writing focused and defensible.

### writer (sonnet)

Transforms the research brief into a complete, structured draft.

Responsibilities:
- Open with a hook: a statistic, question, or bold claim that earns the next paragraph
- Follow the format recommended in the brief (listicle, how-to, narrative, etc.)
- Use H2 and H3 structure that covers the topic's subtopics and signals depth to search engines
- Place the primary keyword in the H1, first 100 words, and at least one H2 — naturally, not mechanically
- Distribute secondary keywords through H2s and body paragraphs without forcing them
- Include 2-3 internal links with descriptive anchor text
- Include 1-2 external links to authoritative sources for claims and statistics
- Write every paragraph for the reader first — clarity and utility over keyword density
- End with a CTA that is specific to the content's funnel stage
- Write a meta description of 150-160 characters with the primary keyword and a clear value proposition

### editor (opus)

The final gate before content ships. Read-only — never rewrites, only flags.

Responsibilities:
- Verify the brief was followed: right audience, right keyword placement, right format
- Check tone and brand voice: does this sound like the project, or generic?
- Audit readability: sentences over 25 words, passive voice, abstract jargon, missing transitions
- Verify every factual claim has a cited source or linked evidence
- Check SEO completeness: keyword in H1 + first paragraph + H2, internal links, meta description
- Confirm the CTA is present and matched to the funnel stage
- Flag any content that could embarrass the brand or create legal exposure
- Report APPROVED or REJECTED with specific, line-level feedback (confidence threshold: 80)

## Workflow

```
researcher → writer → editor
```

1. **researcher** receives the content request and produces a research brief: audience definition, keyword strategy, competitor gap analysis, recommended angle, funnel stage, and format. This brief is added to the writer's context.

2. **writer** receives the research brief and produces a complete draft: structured with H2/H3 headings, SEO elements in place, internal and external links, and a CTA. The draft is the deliverable passed to the editor.

3. **editor** receives the full draft and the research brief. It verifies the draft against the brief, checks readability and brand voice, audits SEO completeness, and approves or rejects with specific feedback.

## Context Sharing

Every agent in this squad receives:
- `.maestro/dna.md` — Project DNA: brand voice, audience definition, content style guide
- `CLAUDE.md` — Project-level rules all agents must follow

In addition:
- **writer** receives the researcher's brief as injected context
- **editor** receives the full draft and the research brief to verify alignment

## Quality Gates

1. **Research gate** — Writer must have an explicit brief before drafting. Brief must include: target audience, primary keyword, secondary keywords, competitor gap, recommended angle, funnel stage, and format.
2. **Keyword placement** — Primary keyword must appear in H1, first 100 words, and at least one H2. Secondary keywords must be present and distributed naturally.
3. **Readability** — Readability score at grade 8 or below. Flagging criteria: paragraphs over 5 sentences, sentences over 25 words, passive voice constructions, unexplained jargon.
4. **Citation integrity** — Every statistical claim or factual assertion links to or names its source. No invented statistics. No vague attributions like "studies show."
5. **CTA presence** — Every piece ends with one clear, specific call to action matched to its funnel stage.
6. **Editor approval** — No issues with confidence >= 80 may remain open. Editor must report STATUS: APPROVED.

## When to Use

- Blog posts and long-form articles intended for organic search traffic
- Product documentation that needs to be readable and on-brand
- Case studies, whitepapers, and gated content assets
- Social media threads or carousel content that requires research backing
- Email campaign copy where tone and persuasion matter
- Any content that will represent the brand publicly and be evaluated against competitors
