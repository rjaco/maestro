# Maestro Tests

Smoke tests that validate the structural integrity of the Maestro plugin.

## Run all tests

```
./tests/smoke-test.sh
```

## Run from any directory

```
./tests/smoke-test.sh /path/to/maestro
```

## What is checked

| Check | What it validates |
|-------|------------------|
| hooks | Every `command` entry in `hooks/hooks.json` resolves to an executable script |
| skills | Every `skills/*/SKILL.md` exists and has `name:` and `description:` frontmatter |
| mirror | Every `skills/*/SKILL.md` has a matching copy under `plugins/maestro/skills/` |
| commands | Every `commands/*.md` has `---` frontmatter with a `name:` field |
| agents | Every `agents/*.md` has `name:`, `description:`, and `model:` frontmatter fields |
| json | `hooks/hooks.json`, `.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json` are valid JSON |
| symlinks | No broken symlinks exist anywhere in the project tree |

## Exit codes

- `0` — all checks passed
- `1` — one or more checks failed

## Dependencies

Only standard tools are required: `bash`, `grep`, `find`, `python3`.
