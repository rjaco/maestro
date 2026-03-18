---
name: preferences
description: "Manage your global developer preferences profile — tech stack, patterns, anti-patterns, and conventions shared across all projects"
argument-hint: "[show|set KEY VALUE|edit|reset]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - AskUserQuestion
---

# Maestro Preferences

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage your global developer preferences. Preferences are stored in `~/.claude/maestro-preferences.md`
and injected into every implementer agent as a high-priority constraint — they travel with you across all projects.

The **preferences file** is yours. Agents read it but never overwrite it. Only you edit it.

## Preferences File Location

`~/.claude/maestro-preferences.md` — global, not per-project.

---

## No Arguments or `show` — Display Current Preferences

Read `~/.claude/maestro-preferences.md` and display it formatted:

```
+---------------------------------------------+
| Developer Preferences                       |
+---------------------------------------------+
  Tech Stack
    Framework          Next.js (App Router)
    Language           TypeScript (strict mode)
    Styling            Tailwind CSS + shadcn/ui
    Database           Supabase (PostgreSQL)
    Testing            Vitest
    Package manager    npm

  Coding Patterns
    Named exports only (no default exports)
    Server Components by default, 'use client' only when needed
    Zod for all validation
    Error handling: explicit try/catch, no silent failures

  Anti-Patterns (Never Do)
    No class components
    No CSS modules
    No any types
    No console.log in production code

  Conventions
    File naming: kebab-case
    Component naming: PascalCase
    Import aliases: @/ for src/
    Commit style: conventional commits

  (i) Use /maestro preferences set KEY VALUE to update a preference.
  (i) Use /maestro preferences edit to open the full preferences for editing.
```

If `~/.claude/maestro-preferences.md` does not exist:

```
[maestro] No preferences found.
          Run /maestro preferences edit to create yours, or
          /maestro preferences reset to start from the default template.
```

---

## `set KEY VALUE` — Update a Single Preference

Support dot-notation for nested keys. Key maps to sections and fields in the preferences file.

### Supported Keys

| Key | Section | Example Value |
|-----|---------|---------------|
| `stack.framework` | Tech Stack | `"Next.js (App Router)"` |
| `stack.language` | Tech Stack | `"TypeScript (strict mode)"` |
| `stack.styling` | Tech Stack | `"Tailwind CSS + shadcn/ui"` |
| `stack.database` | Tech Stack | `"Supabase (PostgreSQL)"` |
| `stack.testing` | Tech Stack | `"Vitest"` |
| `stack.package_manager` | Tech Stack | `"npm"` |
| `patterns.exports` | Coding Patterns | `"Named exports only"` |
| `patterns.components` | Coding Patterns | `"Server Components by default"` |
| `patterns.validation` | Coding Patterns | `"Zod for all validation"` |
| `patterns.error_handling` | Coding Patterns | `"explicit try/catch, no silent failures"` |
| `conventions.file_naming` | Conventions | `"kebab-case"` |
| `conventions.component_naming` | Conventions | `"PascalCase"` |
| `conventions.import_aliases` | Conventions | `"@/ for src/"` |
| `conventions.commit_style` | Conventions | `"conventional commits"` |

For `anti_patterns` (a list), `set anti_patterns.add "No CSS modules"` appends a new item.
Use `set anti_patterns.remove "No CSS modules"` to remove an existing item.

### Output on Success

```
[maestro] Updated: stack.framework = Next.js (App Router)

  (i) This preference applies to all projects on this machine.
  (i) Agents will respect it starting from the next invocation.
```

### Output on Unknown Key

```
[maestro] Unknown preference key: stack.runtime

  Valid keys: stack.framework, stack.language, stack.styling, stack.database,
              stack.testing, stack.package_manager, patterns.exports,
              patterns.components, patterns.validation, patterns.error_handling,
              conventions.file_naming, conventions.component_naming,
              conventions.import_aliases, conventions.commit_style,
              anti_patterns.add, anti_patterns.remove

  Use /maestro preferences edit to make free-form edits.
```

---

## `edit` — Open Full Preferences for Editing

1. If `~/.claude/maestro-preferences.md` does not exist, create it from the template
   (`templates/preferences.md` in the Maestro plugin directory) with today's date filled in.
2. Display the full file content and invite the user to describe their changes conversationally.
3. Apply changes inline or instruct the user to edit the file directly with their editor.

```
[maestro] Opening preferences for editing.
          File: ~/.claude/maestro-preferences.md

[Current content shown here]

  What would you like to change?
```

Use AskUserQuestion to prompt for changes if no inline edits are provided:

**Question:** "What would you like to update in your preferences?"

**Options:**
1. **Tech Stack** — "Change framework, language, styling, database, or testing tools"
2. **Coding Patterns** — "Update export style, component model, validation, or error handling"
3. **Anti-Patterns** — "Add or remove things agents should never do"
4. **Conventions** — "Update file naming, component naming, import aliases, or commit style"
5. **Free-form edit** — "Describe any change and I'll apply it"

After applying changes, update the `last_updated` field in the frontmatter to today's date.

---

## `reset` — Reset to Blank Template

Ask for confirmation before resetting:

Use AskUserQuestion:
- Question: "Reset preferences to the blank template? Your current preferences will be lost."
- Header: "Reset Preferences"
- Options:
  1. label: "Yes, reset to template", description: "Start fresh with an empty preferences file"
  2. label: "Cancel", description: "Keep current preferences"

On confirmation:
1. Copy `templates/preferences.md` to `~/.claude/maestro-preferences.md`.
2. Fill in `created` and `last_updated` with today's date.
3. Display the blank template and prompt the user to fill it in.

```
[maestro] Preferences reset to blank template.
          File: ~/.claude/maestro-preferences.md

  Fill in your preferences and save the file.
  Run /maestro preferences show to verify when done.
```

---

## Interactive Mode (no arguments)

When `$ARGUMENTS` is empty, after showing current preferences, use AskUserQuestion to offer:

**Question:** "What would you like to do?"

**Options:**
1. **Edit preferences** — "Open the full preferences file for editing"
2. **Update a single value** — "Change one preference with set KEY VALUE"
3. **Reset to template** — "Start fresh with a blank preferences file"
4. **Done** — "Exit preferences"
