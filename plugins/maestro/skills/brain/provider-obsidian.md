---
name: brain-provider-obsidian
description: "Obsidian provider for second brain integration. Uses Obsidian CLI or direct file I/O for vault operations."
---

# Brain Provider: Obsidian

Connects Maestro to an Obsidian vault for persistent knowledge management. Uses the Obsidian CLI (v1.12+) when available, falls back to direct file system operations.

## Prerequisites

- Obsidian vault exists at the configured path
- Optionally: Obsidian CLI enabled (Settings > General > CLI)
- Configured via: `integrations.knowledge_base.vault_path` in `.maestro/config.yaml`

## Detection

```bash
# Check if Obsidian CLI is available
which obsidian 2>/dev/null

# If not available, check common vault locations
ls ~/Documents/Obsidian 2>/dev/null
ls ~/obsidian 2>/dev/null
ls ~/vault 2>/dev/null
```

The provider works with or without the Obsidian CLI — it falls back to direct file I/O since an Obsidian vault is just a folder of markdown files.

## Vault Structure

Create this subfolder structure in the vault on first use:

```
{vault_path}/
  maestro/
    decisions/
    retrospectives/
    summaries/
    research/
    daily/
```

```bash
mkdir -p "{vault_path}/maestro/decisions"
mkdir -p "{vault_path}/maestro/retrospectives"
mkdir -p "{vault_path}/maestro/summaries"
mkdir -p "{vault_path}/maestro/research"
mkdir -p "{vault_path}/maestro/daily"
```

## Operations

### connect(vault_path)

1. Verify the path exists:
   ```bash
   [ -d "{vault_path}" ] && echo "exists" || echo "not found"
   ```

2. If the path doesn't exist, check common locations:
   ```bash
   for dir in ~/Documents/Obsidian ~/obsidian ~/vault ~/notes; do
     [ -d "$dir" ] && echo "found: $dir"
   done
   ```

3. Create the `maestro/` subfolder structure.

4. Optionally, create a Maestro index note:

   Write `{vault_path}/maestro/README.md`:
   ```markdown
   # Maestro Knowledge Base

   This folder is managed by [Maestro](https://github.com/maestro).
   It stores project knowledge across sessions.

   ## Folders
   - **decisions/** — Architecture and design decisions
   - **retrospectives/** — Session retrospectives and learnings
   - **summaries/** — Session TLDR summaries
   - **research/** — Research findings worth preserving
   - **daily/** — Daily briefings

   ## How It Works
   Maestro automatically saves important decisions, learnings, and
   session summaries here. Before starting new work, Maestro searches
   this knowledge base for relevant prior context.
   ```

5. Update `.maestro/config.yaml`:
   ```yaml
   integrations:
     knowledge_base:
       provider: obsidian
       vault_path: "{vault_path}"
       sync_enabled: true
   ```

### save(content, category, title)

Generate a slug from the title and date:

```bash
DATE=$(date +%Y-%m-%d)
SLUG=$(echo "{title}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | head -c 50)
FILEPATH="{vault_path}/maestro/{category}/${DATE}-${SLUG}.md"
```

Write the note with frontmatter:

```markdown
---
date: {DATE}
project: {project_name}
category: {category}
tags: [maestro, {project_name}]
---

# {title}

{content}

---
*Saved by Maestro on {DATE}*
```

Use the Write tool to create the file. If Obsidian is running, the note appears instantly in the vault.

### search(query)

**With Obsidian CLI:**
```bash
obsidian search --vault "{vault_path}" --query "{query}" --path "maestro/"
```

**Without Obsidian CLI (fallback):**
Use Grep tool to search the vault:

```
Grep pattern="{query}" path="{vault_path}/maestro" type="md"
```

For each match:
1. Read the file to extract frontmatter (date, category, title)
2. Extract the first 200 characters of content after the title
3. Sort by date (most recent first)
4. Return top 5 results

### read(note_path)

Read a specific note from the vault:

**With Obsidian CLI:**
```bash
obsidian read --vault "{vault_path}" --path "{note_path}"
```

**Without CLI:**
Use the Read tool directly on the file path.

### list(category, limit)

List recent notes in a category:

```bash
ls -t "{vault_path}/maestro/{category}/" | head -{limit}
```

Parse filenames to extract dates and titles.

### open_in_obsidian(note_path)

If Obsidian CLI is available, open the note in Obsidian:

```bash
obsidian open --vault "{vault_path}" --path "{note_path}"
```

If CLI is not available, just report the file path.

## Obsidian-Specific Features

### Wikilinks

When saving notes, use Obsidian wikilinks for cross-referencing:

- Reference other Maestro notes: `[[maestro/decisions/2026-03-10-jwt-auth]]`
- Reference daily notes: `[[maestro/daily/2026-03-17]]`

### Tags

Use Obsidian tags in frontmatter for discoverability:
- `#maestro` (always)
- `#maestro/decision`, `#maestro/retrospective`, etc.
- Project-specific tags from DNA

### Dataview Compatibility

Notes use standard YAML frontmatter that works with Obsidian's Dataview plugin, enabling users to create custom views of their Maestro knowledge base.

## Error Handling

- Vault path not found → suggest common locations or ask user
- Permission denied → suggest checking file permissions
- Obsidian CLI not available → fall back to file I/O (always works)
- Search returns empty → return empty list, no error
- Write fails → log warning, continue
