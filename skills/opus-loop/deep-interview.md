# Deep Interview — 10-Dimension Adaptive Vision Interview

A structured conversation that extracts the full vision from the user. Each dimension has targeted questions, follow-up triggers for vague answers, and skip conditions for when the user has already provided sufficient detail.

## Interview Protocol

- Ask 1-3 questions per dimension. NEVER dump all dimensions at once.
- Adapt based on responses: detailed answers skip follow-ups, vague answers get deeper probing.
- If the user says "I don't know" or "you decide," propose a sensible default and ask for confirmation.
- Keep the conversation natural. No interrogation vibes.
- After all dimensions are covered, synthesize into `.maestro/vision.md`.

### Adaptive Flow Control

The interview is NOT a rigid sequence. Use these rules to determine flow:

**Detect user expertise level from first response:**
- **Expert** (detailed, uses technical terms, clear vision): Skip basic questions, focus on constraints and edge cases. Ask 5-7 total questions across all dimensions.
- **Intermediate** (knows what they want, some gaps): Standard flow, 8-12 questions.
- **Exploring** (vague, uncertain, "I'm not sure"): Propose options for each dimension, confirm. 12-15 questions.

**Information already in the VISION description:**
Before asking any question, check if the user's initial `/maestro opus` description already answers it. Extract all information from the initial description first, then only ask about gaps.

Example: `/maestro opus "Build a SaaS analytics dashboard with Stripe billing, Next.js, target SMBs, freemium model"`
- Core Purpose: COVERED (analytics dashboard)
- Target Audience: COVERED (SMBs)
- Business Model: COVERED (freemium + Stripe)
- Technical Context: PARTIALLY COVERED (Next.js, Stripe)
- Questions to ask: Scope, Design, Integrations, Success Criteria

**Information from existing codebase:**
If `.maestro/dna.md` exists, read it. The tech stack, framework, and existing code patterns answer many technical questions without asking the user.

### Conversation Pacing

| Situation | Action |
|-----------|--------|
| User gives long, detailed answer | Thank them briefly, extract all info, skip related dimensions |
| User gives one-word answer | Follow up: "Can you tell me more about that?" |
| User says "I don't know" | Propose 2-3 options: "Here are common approaches: [A], [B], [C]. Which resonates?" |
| User says "you decide" | Pick the best option based on context, state it explicitly: "I'll go with [X] because [reason]. You can change this later." |
| User volunteers info about another dimension | Capture it immediately, mark that dimension as covered |
| User is getting impatient | Compress remaining questions into one: "A few quick ones: [batch remaining]" |
| User asks a question back | Answer it, then continue the interview |

## Dimensions

### 1. Core Purpose

**Ask:** "In one sentence, what does this product do? Who is it for, and what problem does it solve?"

**Follow-up triggers:**
- Vague answer ("it helps people"): "Can you give me a specific scenario? A user opens the app and does what?"
- Too broad ("it does everything"): "If you could only ship one feature, what would it be?"
- Solution without problem: "What pain point does this address? What happens if this product doesn't exist?"

**Skip if:** The user's initial VISION description already contains a clear value proposition.

### 2. Target Audience

**Ask:** "Who are your first 100 users? Be as specific as possible — job title, industry, pain point."

**Follow-up triggers:**
- "Everyone": "Who would pay for this today, without you convincing them?"
- Multiple audiences: "Which one is the primary? We will optimize for them first."
- Only demographics, no behavior: "What are they currently doing to solve this problem?"

**Skip if:** Audience is obvious from context (e.g., "developer documentation tool" implies developers).

### 3. Scope and Ambition

**Ask:** "What is the MVP — the smallest version that delivers value? And what is the full vision beyond that?"

**Follow-up triggers:**
- No clear boundary: "What would you cut to launch in half the time?"
- Only MVP, no vision: "Where does this go in a year? What features come after launch?"
- Only vision, no MVP: "What is the ONE thing a user must be able to do on day 1?"

**Skip if:** The VISION description already distinguishes MVP from future phases.

### 4. Competitive Landscape

**Ask:** "What existing products are closest to what you are building? What do they get right, and where do they fall short?"

**Follow-up triggers:**
- "Nothing like this exists": "What do people currently use as a workaround? Spreadsheets? Email? A competitor's half-solution?"
- Names competitors but no analysis: "What specifically would make someone switch from [competitor] to yours?"

**Skip if:** `--skip-research` flag is set (the mega research sprint will cover this thoroughly).

### 5. Business Model

**Ask:** "How does this make money? Free, freemium, subscription, one-time, marketplace, ads?"

**Follow-up triggers:**
- "I'll figure it out later": "That is fine for MVP, but I need to know so I design the data model correctly. Lean toward subscription or one-time?"
- "It's free/open source": "Understood. Any plans for premium features or sponsorships?"

**Default proposals if user is unsure:**
- SaaS product → "Freemium with paid tiers is the safest bet."
- Content site → "Ad-supported with premium content is standard."
- Internal tool → "No monetization needed. We'll skip this."
- Open source → "Sponsorships + paid support is common."

**Skip if:** The product is clearly an internal tool, open-source project, or personal project with no revenue intent.

### 6. Technical Context

**Ask:** "Any hard technical requirements? Specific APIs to integrate, platforms to support, performance targets, compliance needs?"

**Follow-up triggers:**
- "Just make it work": "Understood. I will choose the best tools from the project DNA. Any technologies you specifically want or want to avoid?"
- Complex requirements: "Let me make sure I understand: [restate requirements]. Correct?"

**Auto-fill from DNA:** If `.maestro/dna.md` exists, state what you already know: "I see you're using Next.js with Supabase and Tailwind. I'll build on that stack. Anything else I should know?"

**Skip if:** Project DNA already captures the full tech stack and the VISION does not introduce new technical dimensions.

### 7. Design and UX

**Ask:** "Describe the user experience you want. Any reference products, design styles, or specific UX patterns? Mobile-first or desktop-first?"

**Follow-up triggers:**
- "Like [product]": "What specifically about [product]'s UX? The navigation? The dashboard layout? The onboarding flow?"
- No opinion: "I will design a clean, modern interface following current best practices. Any strong preferences on color, tone, or density?"
- Multiple references: "I'll blend elements from those. Which aspect of each should I prioritize?"

**Skip if:** The product is purely backend, API, or CLI with no user-facing UI.

### 8. Integrations and Data

**Ask:** "What external services does this connect to? Any existing databases, APIs, or data sources to integrate?"

**Follow-up triggers:**
- Many integrations: "Which integrations are essential for launch, and which can wait?"
- "I need to import data from X": "What format? CSV, API, database dump? How much data?"
- Auth mention: "Do you want social login (Google, GitHub), magic link, or password-based auth?"

**Skip if:** The VISION description is self-contained with no external dependencies.

### 9. Success Criteria

**Ask:** "How do you know this project succeeded? Give me 3-5 measurable outcomes."

**Follow-up triggers:**
- Vague ("users like it"): "What number would make you smile? 100 signups? $1K MRR? 50% task completion rate?"
- Only business metrics: "Any technical success criteria? Load time under 2 seconds? 99.9% uptime? Zero critical bugs?"
- Only technical metrics: "Any user-facing success criteria? Adoption rate? Retention? NPS?"

**Default proposals by product type:**
- SaaS: "100 signups in first month, 20% weekly active, Lighthouse > 85"
- Content site: "1000 organic visits/month within 3 months, 2+ min avg session"
- Internal tool: "Team adoption > 80%, task completion time reduced by 50%"
- Open source: "100 GitHub stars, 10 contributors within 6 months"

**NEVER skip this dimension.** Always establish success criteria. If the user cannot define them, propose defaults and confirm.

### 10. Constraints and Preferences

**Ask:** "Any constraints I should know about? Deadline, budget, team size, existing codebase limitations, regulatory requirements?"

**Follow-up triggers:**
- Tight deadline: "What can we cut to hit the deadline? What is non-negotiable?"
- Budget constraint: "I will optimize for cost. Milestone-pause mode will give you checkpoints to control spend."
- No constraints: "I'll estimate token cost per milestone so you can decide as we go."

**Always establish at minimum:**
- Timeline expectation (even if "flexible")
- Autonomy preference (milestone-pause vs. full-auto)
- Any absolute rules ("never modify X", "always use Y")

## Synthesis

After covering all dimensions, generate `.maestro/vision.md` using the template below. Fill every section — if a dimension was skipped, note why (e.g., "N/A — backend-only product" for Design Direction).

```markdown
---
product_name: "[Name]"
created: "[ISO date]"
interview_questions: [N]
dimensions_covered: [N]/10
dimensions_skipped: [list or "none"]
---

# Vision — [Product Name]

## Core Purpose
[One paragraph: what it does, who it is for, what problem it solves]

## Target Audience
### Primary
[Specific persona with demographics, behavior, and pain points]

### Secondary
[Additional audiences, or "None — focused on primary"]

### Anti-Persona (NOT building for)
[Who this product is NOT for — prevents scope creep]

## Scope
### MVP (Milestones 1-2)
- [Feature 1] — [why it's essential]
- [Feature 2] — [why it's essential]
- [Feature 3] — [why it's essential]

### Full Vision (Milestones 3+)
- [Feature 4] — [why it's valuable post-launch]
- [Feature 5] — [why it's valuable post-launch]

### Explicitly Out of Scope
- [Feature X] — [why we're NOT building this]

## Competitive Landscape
| Competitor | Strengths | Weaknesses | Our Advantage |
|-----------|-----------|------------|--------------|
| [Name] | [strengths] | [weaknesses] | [how we're different] |

## Business Model
[Revenue model, pricing strategy, or "Not applicable — [reason]"]

## Technical Requirements
- Stack: [framework, database, hosting]
- Integrations: [external services]
- Performance: [targets]
- Compliance: [requirements, or "None"]

## Design Direction
- Style: [modern/minimal/bold/etc.]
- References: [inspiration products]
- Platform: [mobile-first/desktop-first/responsive]
- Accessibility: [WCAG level target]

## Success Criteria
1. [Measurable outcome 1 with number and timeline]
2. [Measurable outcome 2 with number and timeline]
3. [Measurable outcome 3 with number and timeline]

## Constraints
- Timeline: [deadline or "flexible"]
- Budget: [token/cost budget or "flexible"]
- Autonomy: [milestone-pause / full-auto / until-pause]
- Rules: [absolute constraints from user]
```

Present the vision document to the user for approval using AskUserQuestion before proceeding to research or roadmap generation.

## Interview Duration Guide

| Initial Description Quality | Questions to Ask | Est. Time |
|---------------------------|-----------------|-----------|
| Detailed (paragraph+, specifics) | 4-6 questions | 2-3 min |
| Moderate (sentence, some specifics) | 7-10 questions | 4-6 min |
| Minimal ("Build a X") | 10-15 questions | 6-10 min |

The interview should NEVER take more than 15 questions. If you're at 10 questions and still have gaps, batch the remaining into one final question: "A few quick ones to round out the vision: [list remaining gaps]."
