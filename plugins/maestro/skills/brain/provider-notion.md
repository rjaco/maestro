---
name: brain-provider-notion
description: "Notion provider for second brain integration. Uses Notion MCP Server for workspace operations."
---

# Brain Provider: Notion

Connects Maestro to a Notion workspace for persistent knowledge management using the official Notion MCP Server.

## Prerequisites

- Notion MCP Server installed and configured (OAuth-based)
- MCP tools with `mcp__notion__` prefix available
- Notion integration has access to the target workspace

## Database Setup

On first connect, create a "Maestro Knowledge Base" database in the workspace:

```
mcp__notion__create_database
  parent_page_id: {user_selected_page}
  title: "Maestro Knowledge Base"
  properties:
    Title:     title
    Category:  select (decision, retrospective, summary, research, daily)
    Project:   rich_text
    Date:      date
    Tags:      multi_select
    Session:   rich_text
```

If the database already exists (search for it), reuse it.

Store the database ID in `.maestro/config.yaml` as `integrations.knowledge_base.database_id`.

## Operations

### connect()

1. Verify Notion MCP tools are available (search for `mcp__notion__` prefix)

2. If not available:
   ```
   [maestro] Notion MCP Server not detected.

     Install it:
       1. Create an integration at notion.so/profile/integrations
       2. Add the MCP server to your Claude Code config
       3. Share the target workspace with the integration

     See /maestro help integrations for details.
   ```

3. Search for existing Maestro database:
   ```
   mcp__notion__search
     query: "Maestro Knowledge Base"
     filter: { property: "object", value: "database" }
   ```

4. If found, confirm reuse. If not, ask user to select a parent page and create the database.

5. Update config:
   ```yaml
   integrations:
     knowledge_base:
       provider: notion
       database_id: "{database_id}"
       sync_enabled: true
   ```

### save(content, category, title)

Create a page in the Maestro Knowledge Base database:

```
mcp__notion__create_page
  database_id: {configured_database_id}
  properties:
    Title:    "{title}"
    Category: "{category}"
    Project:  "{project_name}"
    Date:     "{ISO_date}"
    Tags:     ["maestro", "{project_name}"]
    Session:  "{session_id}"
  content: |
    {content_as_notion_blocks}
```

Convert markdown content to Notion block format:
- Headings → heading blocks
- Paragraphs → paragraph blocks
- Lists → bulleted_list_item blocks
- Code blocks → code blocks
- Horizontal rules → divider blocks

### search(query)

Search the knowledge base database:

```
mcp__notion__search
  query: "{query}"
  filter:
    property: "object"
    value: "page"
```

Filter results to only pages in the Maestro Knowledge Base database.

For each result:
1. Extract properties (title, category, date, project)
2. Read first paragraph of page content for excerpt
3. Sort by date (most recent first)
4. Return top 5 results

### read(page_id)

Read the full content of a page:

```
mcp__notion__get_page
  page_id: "{page_id}"
```

Also fetch child blocks for the page content:

```
mcp__notion__get_block_children
  block_id: "{page_id}"
```

### list(category, limit)

Query the database filtered by category:

```
mcp__notion__query_database
  database_id: {configured_database_id}
  filter:
    property: "Category"
    select:
      equals: "{category}"
  sorts:
    - property: "Date"
      direction: "descending"
  page_size: {limit}
```

### open_in_notion(page_id)

Construct the Notion URL and open in browser:

```bash
open "https://notion.so/{page_id_without_hyphens}"
```

## Notion-Specific Features

### Rich Properties

Leverage Notion's property types for structured data:
- Category as select (enables filtering in Notion views)
- Tags as multi-select (enables faceted search)
- Date as date (enables timeline views)
- Project as text (enables grouping)

### Database Views

Users can create custom Notion views of their Maestro knowledge base:
- Table view grouped by category
- Timeline view by date
- Board view by project
- Gallery view of recent summaries

### Linked Databases

Users can embed linked views of the Maestro database in other Notion pages for cross-referencing.

## Error Handling

- Notion MCP not available → report with setup instructions
- Database not found → offer to create it
- Page creation fails → log warning, continue
- Search fails → return empty results
- Rate limited → back off once, then warn
- All operations non-blocking
