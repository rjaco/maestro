---
name: brain
description: "Second brain operations -- connect, search, save, and manage your knowledge base"
argument-hint: "[connect|search QUERY|save TITLE|tldr|daily]"
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - Skill
  - AskUserQuestion
---

# Maestro Brain

**ALWAYS display this ASCII banner as the FIRST thing in your response, before any other output:**

```
███╗   ███╗ █████╗ ███████╗███████╗████████╗██████╗  ██████╗
████╗ ████║██╔══██╗██╔════╝██╔════╝╚══██╔══╝██╔══██╗██╔═══██╗
██╔████╔██║███████║█████╗  ███████╗   ██║   ██████╔╝██║   ██║
██║╚██╔╝██║██╔══██║██╔══╝  ╚════██║   ██║   ██╔══██╗██║   ██║
██║ ╚═╝ ██║██║  ██║███████╗███████║   ██║   ██║  ██║╚██████╔╝
╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝╚══════╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝
```

Manage your second brain — a persistent knowledge base that accumulates project knowledge across Maestro sessions.

## Step 1: Check Configuration

Read `.maestro/config.yaml` and check `integrations.knowledge_base`.

If not initialized:
```
[maestro] Not initialized. Run /maestro init first.
```

## Step 2: Handle Arguments

### No arguments — Show status

```
+---------------------------------------------+
| Maestro Brain                               |
+---------------------------------------------+

  Provider    [obsidian|notion|not configured]
  Vault       [path or workspace name]
  Sync        [enabled|disabled]
  Notes       [N] total ([N] decisions, [N] summaries, ...)

  Commands:
    /maestro brain connect         Set up knowledge base
    /maestro brain search QUERY    Search your notes
    /maestro brain save TITLE      Save current context
    /maestro brain tldr            Save session summary
    /maestro brain daily           Morning briefing
```

If not configured:

```
+---------------------------------------------+
| Maestro Brain                               |
+---------------------------------------------+

  Status    Not configured

  Connect a knowledge base to persist decisions,
  learnings, and session summaries across sessions.

Use AskUserQuestion:
- Question: "Connect a knowledge base to persist decisions and learnings?"
- Header: "Brain"
- Options:
  1. label: "Connect Obsidian vault", description: "Local markdown files, works offline, Obsidian users"
  2. label: "Connect Notion workspace", description: "Cloud database, team collaboration, Notion users"
  3. label: "Learn more", description: "See /maestro help integrations for details"

### `connect` — Interactive Setup

1. Detect available providers:
   - Check for Obsidian CLI or vault directories
   - Check for Notion MCP tools

2. If both available:
   ```
   [maestro] Available knowledge base providers:

     [1] Obsidian — local vault, plain markdown files
         Best for: privacy, speed, offline use, Obsidian users
     [2] Notion — cloud workspace, rich database views
         Best for: team collaboration, structured data, Notion users
   ```

3. If only one available, suggest it:
   ```
   [maestro] Detected: Obsidian CLI available

     Connect your Obsidian vault?
   Use AskUserQuestion:
   - Question: "Detected: [provider] available. Connect now?"
   - Header: "Connect"
   - Options:
     1. label: "Yes, auto-detect path", description: "Search common vault locations automatically"
     2. label: "Yes, specify path", description: "I'll provide the vault path manually"
     3. label: "Skip", description: "Don't connect now"

4. Delegate to the appropriate provider's `connect()` operation.

5. After connecting, run a quick test:
   ```
   [maestro] Testing connection...

     (ok) Vault accessible at /Users/you/vault
     (ok) Maestro folder structure created
     (ok) Test note written and read back

   [maestro] Brain connected. Knowledge will be preserved
             across sessions automatically.
   ```

### `search QUERY` — Search Knowledge Base

1. Check that a provider is configured. If not, suggest connecting.

2. Invoke the brain skill's `search(query)` operation.

3. Display results:

   ```
   +---------------------------------------------+
   | Brain Search: "authentication"              |
   +---------------------------------------------+

     1. Decision: Use JWT for API auth (2026-03-10)
        "Decided on JWT tokens with 15min expiry
         and refresh tokens in httpOnly cookies..."

     2. Research: Auth provider comparison (2026-03-08)
        "Compared Auth0, Clerk, Supabase Auth.
         Supabase selected for cost and integration..."

     3. Summary: Add login flow session (2026-03-12)
        "Built email/password login with 5 stories.
         Key decision: bcrypt for hashing..."

   Use AskUserQuestion:
   - Question: "Found [N] results. What would you like to do?"
   - Header: "Results"
   - Options:
     1. label: "Read full note", description: "View the complete content of a result"
     2. label: "New search", description: "Search with different terms"
     3. label: "Inject into context", description: "Load relevant findings into the current conversation"

4. If user selects "Read a note", read the full note and display it.

5. If user selects "Inject into context", format results as a context block for use in the current conversation.

### `save TITLE` — Save to Knowledge Base

1. Check provider is configured.

2. Ask for category if not obvious from context:
   ```
   [maestro] What kind of note is this?

   Use AskUserQuestion:
   - Question: "What kind of note is this?"
   - Header: "Category"
   - Options:
     1. label: "Decision", description: "Architecture or design decision"
     2. label: "Research", description: "Findings worth preserving"
     3. label: "Learning", description: "Lesson learned or insight"
     4. label: "General", description: "Other note"

3. Generate content from the current conversation context:
   - Summarize the key points discussed
   - Include any decisions made
   - Note any code changes referenced

4. Preview before saving:
   ```
   +---------------------------------------------+
   | Save to Brain                               |
   +---------------------------------------------+

     Title     {TITLE}
     Category  {category}
     Project   {project_name}

     Preview:
       {first 5 lines of content}
       ...

   Use AskUserQuestion:
   - Question: "Save this note to your knowledge base?"
   - Header: "Save"
   - Options:
     1. label: "Save as-is (Recommended)", description: "Save to [category]/ with current content"
     2. label: "Edit before saving", description: "Modify the content before saving"
     3. label: "Cancel", description: "Don't save"

5. Save via the brain skill's `save()` operation.

6. Confirm:
   ```
   [maestro] Saved: "{TITLE}" to {category}/

     (i) This note will be available in future sessions.
   ```

### `tldr` — Session Summary

1. Check for an active or recently completed session in `.maestro/state.local.md`.

2. If no session data:
   ```
   [maestro] No session data to summarize.

     (i) Run /maestro "feature" first, then use /maestro brain tldr
         to save a summary of what was built.
   ```

3. Invoke the brain skill's `session_summary(session_id)` operation.

4. Preview the summary:
   ```
   +---------------------------------------------+
   | Session Summary                             |
   +---------------------------------------------+

     Feature   Add user authentication
     Date      2026-03-15
     Stories   5 completed
     Cost      ~$4.20

     What was built:
       - Database schema for users and sessions
       - API routes for login, register, logout
       - Auth middleware with JWT verification
       - Login and register pages
       - Integration tests

     Key decisions:
       - JWT with 15min expiry, refresh tokens in cookies
       - bcrypt for password hashing
       - Rate limiting on auth endpoints (10 req/min)

   Use AskUserQuestion:
   - Question: "Save this session summary to your knowledge base?"
   - Header: "TLDR"
   - Options:
     1. label: "Save (Recommended)", description: "Save to summaries/ in your knowledge base"
     2. label: "Edit first", description: "Modify the summary before saving"
     3. label: "Cancel", description: "Don't save"

5. Save to the knowledge base with category `summary`.

### `daily` — Morning Briefing

1. Invoke the brain skill's `daily_briefing()` operation.

2. Display the briefing (see brain SKILL.md for format).

3. End with:
   ```
   [maestro] What would you like to work on today?
   ```
