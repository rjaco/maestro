---
name: skill-pack
description: "Export and import collections of skills, agents, and profiles as portable skill packs. Enables community sharing and team-wide distribution of Maestro extensions."
---

# Skill Pack

A skill pack is a portable, versioned directory containing skills, agents, profiles, and a manifest. Use skill packs to share your Maestro extensions with your team or the community, or to import community packs into your project.

## Pack Format

A skill pack is a directory (or `.tar.gz` archive) with this structure:

```
my-pack/
  manifest.json        # Required: describes the pack
  skills/              # Optional: skill directories (each with SKILL.md)
    skill-name/
      SKILL.md
  agents/              # Optional: agent .md files
    maestro-agent-name.md
  profiles/            # Optional: profile .md files
    role-name.md
```

### manifest.json

```json
{
  "name": "seo-toolkit",
  "version": "1.0.0",
  "author": "Community Author",
  "description": "SEO analysis and optimization skills",
  "maestro_version": ">=1.1.0",
  "skills": ["seo-analyzer", "keyword-research", "meta-optimizer"],
  "agents": [],
  "profiles": ["seo-specialist"],
  "dependencies": []
}
```

| Field | Required | Description |
|-------|----------|-------------|
| `name` | Yes | Kebab-case pack identifier |
| `version` | Yes | Semver string (e.g., `1.0.0`) |
| `author` | Yes | Author name or GitHub handle |
| `description` | Yes | One-line summary |
| `maestro_version` | Yes | Version range (e.g., `>=1.1.0`) |
| `skills` | No | List of skill directory names included |
| `agents` | No | List of agent file names included (without `.md`) |
| `profiles` | No | List of profile file names included (without `.md`) |
| `dependencies` | No | List of other pack names this pack depends on |

## Operations

### export(name, output_dir?)

Export a named set of skills, agents, and profiles into a skill pack.

#### Step 1: Resolve Contents

Read the export list. The user provides a pack name and a list of skills/agents/profiles to include. If no list is given, prompt:

```
[maestro] Which items should be included in pack "[name]"?

  Available skills:    [list from skills/]
  Available agents:    [list from agents/]
  Available profiles:  [list from profiles/]

  Specify items:
    /maestro skill-pack export [name] --skills seo-analyzer,keyword-research
    /maestro skill-pack export [name] --all
```

If `--all` is passed, include everything.

#### Step 2: Validate Items

For each item in the list:
- Skills: check that `skills/[name]/SKILL.md` exists
- Agents: check that `agents/[name].md` exists
- Profiles: check that `profiles/[name].md` exists

Report any missing items and stop if there are errors:

```
  (x) Export failed:
      - Skill "missing-skill" not found in skills/
      - Agent "missing-agent" not found in agents/

  (i) Fix the item list and re-run.
```

#### Step 3: Build the Pack Directory

Create the pack directory at `output_dir` (default: current directory):

```
[name]-[version]/
  manifest.json
  skills/[name]/SKILL.md   (for each skill)
  agents/[name].md         (for each agent)
  profiles/[name].md       (for each profile)
```

#### Step 4: Generate manifest.json

Detect the current Maestro version from `maestro.md` frontmatter (or use `>=1.0.0` as fallback). Prompt for version and author if not provided:

Use AskUserQuestion if version/author are missing:
- Question: "Pack metadata needed"
- Header: "Pack Info"
- Fields: version (default: 1.0.0), author (default: GitHub username or "Unknown")

Write `manifest.json` with all resolved fields.

#### Step 5: Archive (Optional)

If `--archive` flag is passed, create a `.tar.gz`:

```bash
tar -czf [name]-[version].tar.gz [name]-[version]/
rm -rf [name]-[version]/
```

#### Step 6: Confirm

```
+---------------------------------------------+
| Skill Pack Exported                         |
+---------------------------------------------+

  Pack:      [name] v[version]
  Author:    [author]
  Output:    [path]
  Contents:
    Skills:    [N] ([list])
    Agents:    [N] ([list])
    Profiles:  [N] ([list])

  (ok) Pack exported successfully.

  Next steps:
    Share:    Upload to GitHub or community registry
    Import:   /maestro skill-pack import [path]
```

---

### import(path)

Import a skill pack from a local directory, `.tar.gz` archive, or GitHub URL.

#### Step 1: Locate the Pack

Accept any of:
- Local directory path: `./my-pack/` or `/abs/path/my-pack/`
- Local archive: `./my-pack-1.0.0.tar.gz`
- GitHub shorthand: `github:username/repo` or `github:username/repo/subdir`
- HTTPS URL: `https://github.com/...` (download the archive)

If the path cannot be resolved:
```
  (x) Cannot locate pack at: [path]

  (i) Accepted formats:
      Local directory:  ./my-pack/
      Local archive:    ./my-pack-1.0.0.tar.gz
      GitHub:           github:username/repo
```

#### Step 2: Read and Validate manifest.json

Parse `manifest.json`. Validate:
- `name`, `version`, `author`, `description` are present
- `maestro_version` range is satisfied by the current Maestro version
- All items listed in `skills`, `agents`, `profiles` have matching files in the pack

If validation fails:
```
  (x) Pack validation failed:
      - Missing required field: author
      - Skill "seo-analyzer" listed in manifest but not found in pack

  (i) The pack may be corrupted or incompatible.
```

If the Maestro version is out of range:
```
  (!) Compatibility warning:
      Pack requires Maestro [range], current version is [version].

  (i) The pack may not work correctly. Import anyway? [yes/no]
```

Use AskUserQuestion with options: "Import anyway" / "Cancel".

#### Step 3: Check for Conflicts

For each item in the pack, check if it already exists locally:

- `skills/[name]/SKILL.md` — skill exists
- `agents/[name].md` — agent exists
- `profiles/[name].md` — profile exists

If conflicts found:

Use AskUserQuestion:
- Question: "The following items already exist locally:"
- Header: "Conflicts"
- Body: list conflicting files
- Options:
  1. label: "Overwrite all (Recommended)", description: "Replace existing items with pack versions"
  2. label: "Skip conflicts", description: "Import only new items"
  3. label: "Cancel", description: "Abort import"

#### Step 4: Copy Files

Copy each item from the pack into the project:
- Skills: `skills/[name]/SKILL.md`
- Agents: `agents/[name].md`
- Profiles: `profiles/[name].md`

#### Step 5: Record Installation

Append to `.maestro/installed-packs.md` (create if absent):

```markdown
| Pack | Version | Author | Installed | Items |
|------|---------|--------|-----------|-------|
| seo-toolkit | 1.0.0 | author | 2026-03-18 | skills: seo-analyzer, keyword-research |
```

#### Step 6: Confirm

```
+---------------------------------------------+
| Skill Pack Imported                         |
+---------------------------------------------+

  Pack:      [name] v[version]
  Author:    [author]
  Installed:
    Skills:    [N] ([list])
    Agents:    [N] ([list])
    Profiles:  [N] ([list])

  (ok) Pack imported. Items are immediately available.

  Next steps:
    /maestro help     View available skills
    /maestro profile  Apply an imported profile
```

---

### list()

List all installed packs from `.maestro/installed-packs.md`.

```
+---------------------------------------------+
| Installed Skill Packs                       |
+---------------------------------------------+

  seo-toolkit     v1.0.0   by author    3 skills, 1 profile
  ai-workflows    v2.1.0   by author2   5 skills, 2 agents

  (i) To remove a pack: delete its files and remove the entry from
      .maestro/installed-packs.md
```

If no packs are installed:
```
  (i) No skill packs installed.

  Import a pack:
    /maestro skill-pack import ./my-pack/
    /maestro skill-pack import github:username/repo
```

## Invocation

This skill is invoked by the main `/maestro` command when it detects the `skill-pack` prefix:

```
/maestro skill-pack export <name>             # export()
/maestro skill-pack export <name> --all       # export all items
/maestro skill-pack export <name> --archive   # export as .tar.gz
/maestro skill-pack import <path>             # import()
/maestro skill-pack list                      # list()
```

## Error Handling

| Error | Action |
|-------|--------|
| Missing manifest.json | Report error, abort |
| Schema validation failure | List specific issues, abort |
| Maestro version mismatch | Warn, offer to import anyway |
| Item not found in pack | Report, abort |
| File conflict | Ask: overwrite, skip, or cancel |
| Download failure (GitHub) | Show error, suggest manual download |
| Write permission error | Show error, suggest checking permissions |

## Pack Registry

Community packs are hosted in the Maestro community registry at `github.com/maestro-ai/skill-packs`. Submit your pack by opening a pull request following the contribution guide in `CONTRIBUTING.md`.

## Output Contract

```yaml
output_contract:
  export:
    directory_pattern: "[name]-[version]/"
    archive_pattern: "[name]-[version].tar.gz"
    required_files:
      - "manifest.json"
    optional_dirs:
      - "skills/"
      - "agents/"
      - "profiles/"
  import:
    creates:
      - "skills/*/SKILL.md"
      - "agents/*.md"
      - "profiles/*.md"
      - ".maestro/installed-packs.md"
  display:
    format: "box-drawing"
    sections:
      - "Skill Pack Exported"
      - "Skill Pack Imported"
      - "Installed Skill Packs"
  user_decisions:
    tool: "AskUserQuestion"
    gates:
      - "Version mismatch (import)"
      - "File conflicts (import)"
      - "Missing metadata (export)"
```
