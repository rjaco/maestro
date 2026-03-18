---
name: skill-factory
description: "Auto-create project-specific specialist skills from profile templates. Uses skill-creator plugin for validation. Customizes profiles with project DNA."
---

# Skill Factory

Generates project-specific specialist skills by combining generic profile templates with the project's DNA. Each generated skill is a fully-formed SKILL.md that an agent can use as its system prompt, pre-loaded with the project's tech stack, conventions, file structure, and patterns.

## Input

- Project DNA (`.maestro/dna.md`) — tech stack, patterns, conventions, architecture
- Profile templates (`profiles/*.md`) — generic role definitions with placeholder sections
- Project CLAUDE.md (if present) — additional conventions and constraints
- Specialist list — which profiles to generate (default: all available profiles)

## Process

### Step 1: Read Project DNA

Load `.maestro/dna.md` and extract:
- **Tech stack** — frameworks, languages, libraries, tools
- **Patterns** — component conventions, API patterns, data access patterns
- **Architecture** — layers, boundaries, data flow
- **Conventions** — naming, file organization, export patterns, styling
- **Sensitive areas** — files/directories that must not be modified
- **Integration points** — external services, APIs, databases

If DNA does not exist, run the `project-dna` skill first to generate it.

### Step 2: Read CLAUDE.md

If the project has a CLAUDE.md (or equivalent convention file), extract:
- Rules and constraints relevant to each specialist role
- File organization patterns
- Allowed and forbidden modifications
- Testing conventions
- Design system tokens and patterns

### Step 3: Load Profile Templates

For each requested specialist, load the corresponding template from `profiles/`:

| Profile | Template File |
|---------|---------------|
| Frontend Engineer | `profiles/frontend-engineer.md` |
| Backend Engineer | `profiles/backend-engineer.md` |
| Data Engineer | `profiles/data-engineer.md` |
| Designer | `profiles/designer.md` |
| SEO Specialist | `profiles/seo-specialist.md` |
| Copywriter | `profiles/copywriter.md` |
| DevOps Engineer | `profiles/devops.md` |
| Security Reviewer | `profiles/security-reviewer.md` |

### Step 4: Customize Each Profile

For each profile template, produce a project-specific skill by:

1. **Injecting tech stack** — Replace generic references with project-specific tools. "Use the project's component library" becomes "Use `src/components/ui/` primitives (Button, Card, Badge, Input). Merge classes with `cn()` from `@/lib/utils`."

2. **Injecting patterns** — Replace generic pattern descriptions with concrete examples from the codebase. "Follow the project's API route pattern" becomes the actual route handler structure extracted from an existing route file.

3. **Injecting constraints** — Add CLAUDE.md rules relevant to the role. A frontend engineer gets component conventions and design system rules. A backend engineer gets API route rules and data layer restrictions.

4. **Injecting file map** — Add the directory structure relevant to the role. A frontend engineer gets `src/components/` and `src/app/` structure. A backend engineer gets `src/lib/` and `src/app/api/` structure.

5. **Pruning irrelevant sections** — Remove generic guidance that conflicts with or is superseded by project-specific conventions.

### Step 5: Validate

If the `skill-creator` plugin is available in the environment, validate each generated SKILL.md:
- YAML frontmatter is valid (name, description present)
- Body has required sections (no empty placeholders)
- Token count is within the target range for the role's typical tier
- No conflicting instructions between the skill and CLAUDE.md

If `skill-creator` is not available, perform a basic structural check:
- Frontmatter parses correctly
- All template placeholders have been replaced
- No `{{placeholder}}` markers remain in the output

### Step 6: Write Skills

Write each generated skill to the project's skill directory:

```
.claude/skills/
  maestro-frontend-engineer/SKILL.md
  maestro-backend-engineer/SKILL.md
  maestro-data-engineer/SKILL.md
  maestro-designer/SKILL.md
  maestro-seo-specialist/SKILL.md
  maestro-copywriter/SKILL.md
  maestro-devops/SKILL.md
  maestro-security-reviewer/SKILL.md
```

Prefix with `maestro-` to distinguish from user-created skills.

## Output

- Generated SKILL.md files in `.claude/skills/maestro-*/`
- Summary report listing each generated skill, its token count, and any warnings
- Skills are immediately available for agent dispatch by the delegation skill

## Regeneration

Run the Skill Factory again after significant DNA changes (new tech stack, new conventions, architectural refactor). It will overwrite existing `maestro-*` skills with updated versions. User-created skills outside the `maestro-*` namespace are never touched.

## Autonomous Skill Generation (OpenClaw-inspired)

Beyond profile-based generation, the Skill Factory can create entirely new skills on-the-fly when Maestro detects recurring task patterns.

### Pattern Detection

During retrospectives or dev-loop execution, the factory monitors for:
- **Repeated commands**: User runs the same bash sequence 3+ times across sessions
- **Recurring context**: Same files/patterns referenced in multiple stories
- **Custom workflows**: User describes a multi-step process that doesn't match existing skills
- **Missing coverage**: Tasks that require manual intervention because no skill handles them

### Auto-Generation Flow

1. **Detect pattern**: "User always runs `npm run seed && npm run migrate` before testing"
2. **Propose skill**: "Create a `maestro-db-reset` skill that runs seed + migrate?"
3. **User approves**: Via AskUserQuestion
4. **Generate SKILL.md**: Full skill with frontmatter, description, steps, error handling
5. **Write to `.claude/skills/maestro-[name]/SKILL.md`**
6. **Register**: Immediately available in current and future sessions
7. **Log**: Record skill creation in `.maestro/memory/semantic.md`

### Skill Template for Auto-Generated Skills

```markdown
---
name: maestro-[slug]
description: "[Auto-generated] [one-line description of what the skill does]"
---

# [Skill Name]

Auto-generated by Maestro Skill Factory on [date].
Source: [pattern detected from session/retrospective]

## What This Does

[Description of the task this skill automates]

## Steps

1. [Step 1]
2. [Step 2]
3. [Step 3]

## When to Use

[Trigger conditions — when should this skill be invoked?]

## Error Handling

[What to do if steps fail]
```

### Skill Registry

Maintain a registry of auto-generated skills in `.maestro/skills-registry.md`:

```markdown
# Auto-Generated Skills

| Name | Created | Source | Times Used |
|------|---------|--------|------------|
| maestro-db-reset | 2026-03-15 | Repeated pattern | 4 |
| maestro-deploy-staging | 2026-03-16 | User request | 2 |
```
