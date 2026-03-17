# Deep Interview — 10-Dimension Adaptive Vision Interview

A structured conversation that extracts the full vision from the user. Each dimension has targeted questions, follow-up triggers for vague answers, and skip conditions for when the user has already provided sufficient detail.

## Interview Protocol

- Ask 1-3 questions per dimension. Never dump all dimensions at once.
- Adapt based on responses: detailed answers skip follow-ups, vague answers get deeper probing.
- If the user says "I don't know" or "you decide," propose a sensible default and ask for confirmation.
- Keep the conversation natural. No interrogation vibes.
- After all dimensions are covered, synthesize into `.maestro/vision.md`.

## Dimensions

### 1. Core Purpose

**Ask:** "In one sentence, what does this product do? Who is it for, and what problem does it solve?"

**Follow-up triggers:**
- Vague answer ("it helps people"): "Can you give me a specific scenario? A user opens the app and does what?"
- Too broad ("it does everything"): "If you could only ship one feature, what would it be?"

**Skip if:** The user's initial VISION description already contains a clear value proposition.

### 2. Target Audience

**Ask:** "Who are your first 100 users? Be as specific as possible — job title, industry, pain point."

**Follow-up triggers:**
- "Everyone": "Who would pay for this today, without you convincing them?"
- Multiple audiences: "Which one is the primary? We will optimize for them first."

**Skip if:** Audience is obvious from context (e.g., "Build a developer documentation tool" implies developers).

### 3. Scope and Ambition

**Ask:** "What is the MVP — the smallest version that delivers value? And what is the full vision beyond that?"

**Follow-up triggers:**
- No clear boundary: "What would you cut to launch in half the time?"
- Only MVP, no vision: "Where does this go in a year? What features come after launch?"

**Skip if:** The VISION description already distinguishes MVP from future phases.

### 4. Competitive Landscape

**Ask:** "What existing products are closest to what you are building? What do they get right, and where do they fall short?"

**Follow-up triggers:**
- "Nothing like this exists": "What do people currently use as a workaround? Spreadsheets? Email? A competitor's half-solution?"
- Names competitors but no analysis: "What specifically would make someone switch from [competitor] to yours?"

**Skip if:** `--skip-research` flag is set (research sprint will cover this).

### 5. Business Model

**Ask:** "How does this make money? Free, freemium, subscription, one-time, marketplace, ads?"

**Follow-up triggers:**
- "I'll figure it out later": "That is fine for MVP, but I need to know so I design the data model correctly. Lean toward subscription or one-time?"
- "It's free/open source": "Understood. Any plans for premium features or sponsorships?"

**Skip if:** The product is clearly an internal tool, open-source project, or personal project with no revenue intent.

### 6. Technical Context

**Ask:** "Any hard technical requirements? Specific APIs to integrate, platforms to support, performance targets, compliance needs?"

**Follow-up triggers:**
- "Just make it work": "Understood. I will choose the best tools from the project DNA. Any technologies you specifically want or want to avoid?"
- Complex requirements: "Let me make sure I understand: [restate requirements]. Correct?"

**Skip if:** Project DNA already captures the full tech stack and the VISION does not introduce new technical dimensions.

### 7. Design and UX

**Ask:** "Describe the user experience you want. Any reference products, design styles, or specific UX patterns? Mobile-first or desktop-first?"

**Follow-up triggers:**
- "Like [product]": "What specifically about [product]'s UX? The navigation? The dashboard layout? The onboarding flow?"
- No opinion: "I will design a clean, modern interface following current best practices. Any strong preferences on color, tone, or density?"

**Skip if:** The product is purely backend, API, or CLI with no user-facing UI.

### 8. Integrations and Data

**Ask:** "What external services does this connect to? Any existing databases, APIs, or data sources to integrate?"

**Follow-up triggers:**
- Many integrations: "Which integrations are essential for launch, and which can wait?"
- "I need to import data from X": "What format? CSV, API, database dump? How much data?"

**Skip if:** The VISION description is self-contained with no external dependencies.

### 9. Success Criteria

**Ask:** "How do you know this project succeeded? Give me 3-5 measurable outcomes."

**Follow-up triggers:**
- Vague ("users like it"): "What number would make you smile? 100 signups? $1K MRR? 50% task completion rate?"
- Only business metrics: "Any technical success criteria? Load time under 2 seconds? 99.9% uptime? Zero critical bugs?"

**Skip if:** Never skip. Always establish success criteria. If the user cannot define them, propose defaults based on the product type.

### 10. Constraints and Preferences

**Ask:** "Any constraints I should know about? Deadline, budget, team size, existing codebase limitations, regulatory requirements?"

**Follow-up triggers:**
- Tight deadline: "What can we cut to hit the deadline? What is non-negotiable?"
- Budget constraint: "I will optimize for cost. Milestone-pause mode will give you checkpoints to control spend."

**Skip if:** No constraints exist (rare — at minimum, establish a rough timeline expectation).

## Synthesis

After covering all dimensions, generate `.maestro/vision.md`:

```markdown
# Vision — [Product Name]

## Core Purpose
[One paragraph: what it does, who it is for, what problem it solves]

## Target Audience
[Primary audience with specifics. Secondary audiences if relevant.]

## Scope
### MVP (Milestone 1-2)
- [Feature 1]
- [Feature 2]
- [Feature 3]

### Full Vision (Milestone 3+)
- [Feature 4]
- [Feature 5]

## Competitive Landscape
- [Competitor 1]: [strengths / weaknesses]
- [Competitor 2]: [strengths / weaknesses]
- Our differentiator: [what makes this different]

## Business Model
[Revenue model, pricing strategy, or "not applicable"]

## Technical Requirements
- [Requirement 1]
- [Requirement 2]
- [Integration 1]

## Design Direction
[UX approach, reference products, mobile/desktop priority]

## Success Criteria
1. [Measurable outcome 1]
2. [Measurable outcome 2]
3. [Measurable outcome 3]

## Constraints
- Timeline: [deadline or "flexible"]
- Budget: [token/cost budget or "flexible"]
- Other: [regulatory, team, technical constraints]
```

Present the vision document to the user for approval before proceeding to research or roadmap generation.
