---
name: health-badge
description: "Generates health badge data for Maestro: counts skills, commands, agents, hooks, and reads version. Outputs shields.io-compatible badge markdown or JSON."
---

# Health Badge

Runs a quick inventory of the Maestro installation and outputs badge data in shields.io-compatible markdown or JSON format. Used to keep README badges accurate and to provide a fast health snapshot.

## Usage

Invoke when you need to regenerate README badge values or inspect current plugin counts.

```
/maestro health-badge          # outputs badge markdown
/maestro health-badge --json   # outputs raw JSON
```

## Inventory Process

Execute each step in order:

### 1. Count Skills

```bash
ls skills/*/SKILL.md | wc -l
```

Pattern: `skills/*/SKILL.md` — one file per registered skill. Each SKILL.md is a first-class skill definition.

### 2. Count Commands

```bash
ls commands/*.md | wc -l
```

Pattern: `commands/*.md` — one file per slash command exposed to the user.

### 3. Count Agents

```bash
ls agents/*.md | wc -l
```

Pattern: `agents/*.md` — one file per purpose-built agent.

### 4. Count Hook Events

Parse `hooks/hooks.json` and count the top-level keys under `"hooks"`. Each key is a registered Claude Code hook event (e.g., `SessionStart`, `PreToolUse`, `Stop`).

```bash
cat hooks/hooks.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(len(d['hooks']))"
```

### 5. Read Version

Read `"version"` from `plugins/maestro/.claude-plugin/plugin.json`.

```bash
cat plugins/maestro/.claude-plugin/plugin.json | python3 -c "import json,sys; d=json.load(sys.stdin); print(d['version'])"
```

## Output Formats

### Markdown (default)

```markdown
![Version](https://img.shields.io/badge/version-{version}-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Skills](https://img.shields.io/badge/skills-{skills_count}%2B-purple)
![Commands](https://img.shields.io/badge/commands-{commands_count}%2B-orange)
![Agents](https://img.shields.io/badge/agents-{agents_count}-cyan)
![Hooks](https://img.shields.io/badge/hooks-{hooks_count}_events-yellow)
```

Replace `+` with `%2B` in shield URLs to ensure correct encoding.

### JSON (`--json`)

```json
{
  "version": "1.1.0",
  "license": "MIT",
  "skills_count": 84,
  "commands_count": 25,
  "agents_count": 6,
  "hooks_count": 6
}
```

## Example Output (Markdown)

```markdown
![Version](https://img.shields.io/badge/version-1.1.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Skills](https://img.shields.io/badge/skills-84%2B-purple)
![Commands](https://img.shields.io/badge/commands-25%2B-orange)
![Agents](https://img.shields.io/badge/agents-6-cyan)
![Hooks](https://img.shields.io/badge/hooks-6_events-yellow)
```

## Integration with README

After running this skill, paste the badge block at the top of `README.md`, immediately after the `# Maestro` heading and before the tagline. Run `/maestro health-badge` whenever the version bumps or new skills/commands/agents are added.

## Error Handling

| Condition | Action |
|-----------|--------|
| `hooks/hooks.json` missing | Report count as `0`, warn user |
| `plugin.json` missing | Report version as `unknown`, warn user |
| No SKILL.md files found | Report count as `0`, warn user |
