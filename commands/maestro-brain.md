---
name: maestro-brain
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
---

# Maestro Brain

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

  [1] Connect Obsidian vault
  [2] Connect Notion workspace
  [3] Learn more (/maestro help integrations)
```

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
     [1] Yes, auto-detect vault location
     [2] Yes, specify path manually
     [3] No, skip for now
   ```

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

     [1] Read a note (enter number)
     [2] New search
     [3] Inject results into current context
   ```

4. If user selects "Read a note", read the full note and display it.

5. If user selects "Inject into context", format results as a context block for use in the current conversation.

### `save TITLE` — Save to Knowledge Base

1. Check provider is configured.

2. Ask for category if not obvious from context:
   ```
   [maestro] What kind of note is this?

     [1] Decision — architecture or design decision
     [2] Research — findings worth preserving
     [3] Learning — lesson learned or insight
     [4] Other — general note
   ```

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

     [1] Save as-is
     [2] Edit before saving
     [3] Cancel
   ```

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

     [1] Save to brain
     [2] Edit before saving
     [3] Cancel
   ```

5. Save to the knowledge base with category `summary`.

### `daily` — Morning Briefing

1. Invoke the brain skill's `daily_briefing()` operation.

2. Display the briefing (see brain SKILL.md for format).

3. End with:
   ```
   [maestro] What would you like to work on today?
   ```
