#!/usr/bin/env bash
# Maestro Plugin Self-Test
# Comprehensive validation of plugin structure, content quality, and consistency.
# Usage: bash scripts/self-test.sh

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0
TEST_NUM=0

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
CYAN='\033[36m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}PASS${RESET} $1"; }
warn() { echo -e "  ${YELLOW}WARN${RESET} $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  ${RED}FAIL${RESET} $1"; ERRORS=$((ERRORS + 1)); }

section() {
  TEST_NUM=$((TEST_NUM + 1))
  echo ""
  echo -e "${CYAN}[$TEST_NUM] $1${RESET}"
}

echo "========================================"
echo "  Maestro Plugin Self-Test"
echo "========================================"
echo ""

# --- Helper: check YAML frontmatter field exists ---
# Usage: has_yaml_field <file> <field>
has_yaml_field() {
  local file="$1"
  local field="$2"
  # Frontmatter is between the first two --- lines
  { awk '/^---/{n++; if(n==2) exit} n==1' "$file" 2>/dev/null || true; } | grep -q "^${field}:"
}

# ==============================================
# TEST 1: SKILL.md files have valid frontmatter
# ==============================================
section "SKILL.md files — valid YAML frontmatter (name + description)"
SKILL_ERRORS=0
for dir in "$PLUGIN_ROOT/skills"/*/; do
  skill=$(basename "$dir")
  skill_file="$dir/SKILL.md"
  if [[ ! -f "$skill_file" ]]; then
    # Missing SKILL.md is caught by test 8; skip here
    continue
  fi
  missing_fields=""
  has_yaml_field "$skill_file" "name"        || missing_fields="name $missing_fields"
  has_yaml_field "$skill_file" "description" || missing_fields="description $missing_fields"
  if [[ -n "$missing_fields" ]]; then
    fail "skills/$skill/SKILL.md missing frontmatter: ${missing_fields% }"
    SKILL_ERRORS=$((SKILL_ERRORS + 1))
  fi
done
if [[ $SKILL_ERRORS -eq 0 ]]; then
  pass "All SKILL.md files have required frontmatter fields"
fi

# ==============================================
# TEST 2: commands/*.md have valid frontmatter
# ==============================================
section "commands/*.md — valid YAML frontmatter"
CMD_ERRORS=0
for cmd_file in "$PLUGIN_ROOT/commands/"*.md; do
  cmd=$(basename "$cmd_file")
  if ! grep -q "^---" "$cmd_file" 2>/dev/null; then
    fail "commands/$cmd has no YAML frontmatter block"
    CMD_ERRORS=$((CMD_ERRORS + 1))
  fi
done
if [[ $CMD_ERRORS -eq 0 ]]; then
  TOTAL_CMDS=$({ ls "$PLUGIN_ROOT/commands/"*.md 2>/dev/null || true; } | wc -l)
  pass "All $TOTAL_CMDS command files have frontmatter"
fi

# ==============================================
# TEST 3: agents/*.md have valid frontmatter (name, description, model)
# ==============================================
section "agents/*.md — valid YAML frontmatter (name, description, model)"
AGENT_ERRORS=0
for agent_file in "$PLUGIN_ROOT/agents/"*.md; do
  agent=$(basename "$agent_file")
  missing_fields=""
  has_yaml_field "$agent_file" "name"        || missing_fields="name $missing_fields"
  has_yaml_field "$agent_file" "description" || missing_fields="description $missing_fields"
  has_yaml_field "$agent_file" "model"       || missing_fields="model $missing_fields"
  if [[ -n "$missing_fields" ]]; then
    fail "agents/$agent missing frontmatter: ${missing_fields% }"
    AGENT_ERRORS=$((AGENT_ERRORS + 1))
  fi
done
if [[ $AGENT_ERRORS -eq 0 ]]; then
  TOTAL_AGENTS=$({ ls "$PLUGIN_ROOT/agents/"*.md 2>/dev/null || true; } | wc -l)
  pass "All $TOTAL_AGENTS agent files have required frontmatter fields"
fi

# ==============================================
# TEST 4: squad files have valid frontmatter
# ==============================================
section "Squad files — valid YAML frontmatter"
SQUAD_ERRORS=0
for squad_file in "$PLUGIN_ROOT/squads"/*/squad.md; do
  [[ -f "$squad_file" ]] || continue
  squad=$(basename "$(dirname "$squad_file")")
  if ! grep -q "^---" "$squad_file" 2>/dev/null; then
    fail "squads/$squad/squad.md has no YAML frontmatter"
    SQUAD_ERRORS=$((SQUAD_ERRORS + 1))
    continue
  fi
  missing_fields=""
  has_yaml_field "$squad_file" "name"        || missing_fields="name $missing_fields"
  has_yaml_field "$squad_file" "description" || missing_fields="description $missing_fields"
  if [[ -n "$missing_fields" ]]; then
    fail "squads/$squad/squad.md missing frontmatter: ${missing_fields% }"
    SQUAD_ERRORS=$((SQUAD_ERRORS + 1))
  fi
done
if [[ $SQUAD_ERRORS -eq 0 ]]; then
  TOTAL_SQUADS=$({ ls -d "$PLUGIN_ROOT/squads"/*/ 2>/dev/null || true; } | wc -l)
  pass "All $TOTAL_SQUADS squad directories have valid squad.md frontmatter"
fi

# ==============================================
# TEST 5: Hook scripts referenced in hooks.json exist and are executable
# ==============================================
section "Hook scripts — exist and executable (from hooks.json)"
HOOK_ERRORS=0
# Extract script paths from command values, strip variable prefix
HOOK_SCRIPTS=$(python3 -c "
import json, re, sys
with open('$PLUGIN_ROOT/hooks/hooks.json') as f:
    data = json.load(f)

def find_commands(obj):
    if isinstance(obj, dict):
        if 'command' in obj:
            yield obj['command']
        for v in obj.values():
            yield from find_commands(v)
    elif isinstance(obj, list):
        for item in obj:
            yield from find_commands(item)

seen = set()
for cmd in find_commands(data):
    # Strip \${CLAUDE_PLUGIN_ROOT}/hooks/ prefix
    script = re.sub(r'^\\\${CLAUDE_PLUGIN_ROOT}/hooks/', '', cmd)
    if script not in seen:
        seen.add(script)
        print(script)
" 2>/dev/null)

for script in $HOOK_SCRIPTS; do
  full_path="$PLUGIN_ROOT/hooks/$script"
  if [[ -x "$full_path" ]]; then
    pass "$script exists and is executable"
  elif [[ -f "$full_path" ]]; then
    fail "$script exists but is NOT executable (chmod +x needed)"
    HOOK_ERRORS=$((HOOK_ERRORS + 1))
  else
    fail "$script referenced in hooks.json but does NOT exist"
    HOOK_ERRORS=$((HOOK_ERRORS + 1))
  fi
done

# ==============================================
# TEST 6: All JSON files are valid
# ==============================================
section "JSON validity — all .json files in plugin"
JSON_ERRORS=0
JSON_FILES=(
  "$PLUGIN_ROOT/.claude-plugin/plugin.json"
  "$PLUGIN_ROOT/.claude-plugin/marketplace.json"
  "$PLUGIN_ROOT/plugins/maestro/.claude-plugin/plugin.json"
  "$PLUGIN_ROOT/hooks/hooks.json"
  "$PLUGIN_ROOT/plugins/maestro/hooks/hooks.json"
  "$PLUGIN_ROOT/.mcp.json"
)
for json in "${JSON_FILES[@]}"; do
  [[ -f "$json" ]] || continue
  label="${json#$PLUGIN_ROOT/}"
  if python3 -m json.tool "$json" > /dev/null 2>&1; then
    pass "$label"
  else
    fail "$label is INVALID JSON"
    JSON_ERRORS=$((JSON_ERRORS + 1))
  fi
done
if [[ $JSON_ERRORS -eq 0 ]]; then
  pass "All checked JSON files are valid"
fi

# ==============================================
# TEST 7: Root and plugins/maestro have matching file counts
# ==============================================
section "Mirror sync — root vs plugins/maestro (skills, commands, templates)"
SYNC_ERRORS=0

# Skills
ROOT_SKILLS=$({ ls -d "$PLUGIN_ROOT/skills"/*/ 2>/dev/null || true; } | wc -l)
MIRROR_SKILLS=$({ ls -d "$PLUGIN_ROOT/plugins/maestro/skills"/*/ 2>/dev/null || true; } | wc -l)
if [[ "$ROOT_SKILLS" -eq "$MIRROR_SKILLS" ]]; then
  pass "Skills: $ROOT_SKILLS directories in both locations"
else
  fail "Skills mismatch: root=$ROOT_SKILLS, mirror=$MIRROR_SKILLS"
  SYNC_ERRORS=$((SYNC_ERRORS + 1))
fi

# Commands
ROOT_CMDS=$({ ls "$PLUGIN_ROOT/commands/"*.md 2>/dev/null || true; } | wc -l)
MIRROR_CMDS=$({ ls "$PLUGIN_ROOT/plugins/maestro/commands/"*.md 2>/dev/null || true; } | wc -l)
if [[ "$ROOT_CMDS" -eq "$MIRROR_CMDS" ]]; then
  pass "Commands: $ROOT_CMDS files in both locations"
else
  fail "Commands mismatch: root=$ROOT_CMDS, mirror=$MIRROR_CMDS"
  SYNC_ERRORS=$((SYNC_ERRORS + 1))
fi

# Templates
ROOT_TMPLS=$({ ls "$PLUGIN_ROOT/templates/"*.md 2>/dev/null || true; } | wc -l)
MIRROR_TMPLS=$({ ls "$PLUGIN_ROOT/plugins/maestro/templates/"*.md 2>/dev/null || true; } | wc -l)
if [[ "$ROOT_TMPLS" -eq "$MIRROR_TMPLS" ]]; then
  pass "Templates: $ROOT_TMPLS files in both locations"
else
  fail "Templates mismatch: root=$ROOT_TMPLS, mirror=$MIRROR_TMPLS"
  SYNC_ERRORS=$((SYNC_ERRORS + 1))
fi

# ==============================================
# TEST 8: No skill < 50 lines (stub detection)
# ==============================================
section "Skill completeness — no SKILL.md under 50 lines (stub detection)"
THIN_COUNT=0
MISSING_COUNT=0
for dir in "$PLUGIN_ROOT/skills"/*/; do
  skill=$(basename "$dir")
  skill_file="$dir/SKILL.md"
  if [[ ! -f "$skill_file" ]]; then
    fail "skills/$skill/ has no SKILL.md"
    MISSING_COUNT=$((MISSING_COUNT + 1))
  else
    lines=$(wc -l < "$skill_file")
    if [[ $lines -lt 50 ]]; then
      fail "skills/$skill/SKILL.md is thin ($lines lines — minimum 50)"
      THIN_COUNT=$((THIN_COUNT + 1))
    fi
  fi
done
if [[ $THIN_COUNT -eq 0 && $MISSING_COUNT -eq 0 ]]; then
  TOTAL_SKILLS=$({ ls -d "$PLUGIN_ROOT/skills"/*/ 2>/dev/null || true; } | wc -l)
  pass "All $TOTAL_SKILLS skills have substantive SKILL.md (>=50 lines)"
fi

# ==============================================
# TEST 9: No [TODO] placeholders in templates or commands
# ==============================================
section "Placeholder markers — no [TODO] in templates or commands"
TODO_COUNT=$({ grep -rn "\[TODO" --include="*.md" "$PLUGIN_ROOT/templates/" "$PLUGIN_ROOT/commands/" 2>/dev/null || true; } | wc -l)
if [[ $TODO_COUNT -eq 0 ]]; then
  pass "No [TODO] markers found in templates or commands"
else
  fail "$TODO_COUNT [TODO] marker(s) found in templates/commands:"
  { grep -rn "\[TODO" --include="*.md" "$PLUGIN_ROOT/templates/" "$PLUGIN_ROOT/commands/" 2>/dev/null || true; } | while IFS= read -r line; do
    echo "    $line"
  done
fi

# ==============================================
# TEST 10: Version consistency across plugin.json, marketplace.json, CHANGELOG
# ==============================================
section "Version consistency — plugin.json, marketplace.json, CHANGELOG"
ROOT_VER=$(python3 -c "import json; d=json.load(open('$PLUGIN_ROOT/.claude-plugin/plugin.json')); print(d.get('version',''))" 2>/dev/null)
PLUGIN_VER=$(python3 -c "import json; d=json.load(open('$PLUGIN_ROOT/plugins/maestro/.claude-plugin/plugin.json')); print(d.get('version',''))" 2>/dev/null)
MARKET_VER=$(python3 -c "import json; d=json.load(open('$PLUGIN_ROOT/.claude-plugin/marketplace.json')); print(d.get('version',''))" 2>/dev/null || echo "")

CHANGELOG_VER=""
if [[ -f "$PLUGIN_ROOT/CHANGELOG.md" ]]; then
  CHANGELOG_VER=$({ grep -m1 "^## \[" "$PLUGIN_ROOT/CHANGELOG.md" || true; } | { grep -o '[0-9][0-9]*\.[0-9][0-9]*\.[0-9][0-9]*' || true; } | head -1)
fi

VER_ERRORS=0
if [[ "$ROOT_VER" != "$PLUGIN_VER" ]]; then
  fail "plugin.json version mismatch: root=$ROOT_VER, mirror=$PLUGIN_VER"
  VER_ERRORS=$((VER_ERRORS + 1))
fi
if [[ -n "$MARKET_VER" && "$ROOT_VER" != "$MARKET_VER" ]]; then
  fail "marketplace.json version ($MARKET_VER) != plugin.json ($ROOT_VER)"
  VER_ERRORS=$((VER_ERRORS + 1))
fi
if [[ -n "$CHANGELOG_VER" && "$ROOT_VER" != "$CHANGELOG_VER" ]]; then
  warn "CHANGELOG.md latest entry ($CHANGELOG_VER) != plugin.json ($ROOT_VER) — did you forget to add a changelog entry?"
fi
if [[ $VER_ERRORS -eq 0 ]]; then
  pass "All versions consistent: $ROOT_VER"
fi

# ==============================================
# TEST 11: Profile configs have required YAML fields
# ==============================================
section "Profile configs — required fields (name, description, mode, default_model)"
PROFILE_ERRORS=0
REQUIRED_PROFILE_FIELDS=("name" "description" "mode" "default_model")
for config_file in "$PLUGIN_ROOT/profiles/configs/"*.yaml; do
  [[ -f "$config_file" ]] || continue
  config=$(basename "$config_file")
  missing_fields=""
  for field in "${REQUIRED_PROFILE_FIELDS[@]}"; do
    if ! grep -q "^${field}:" "$config_file" 2>/dev/null; then
      missing_fields="$field $missing_fields"
    fi
  done
  if [[ -n "$missing_fields" ]]; then
    fail "profiles/configs/$config missing: ${missing_fields% }"
    PROFILE_ERRORS=$((PROFILE_ERRORS + 1))
  fi
done
if [[ $PROFILE_ERRORS -eq 0 ]]; then
  TOTAL_PROFILES=$({ ls "$PLUGIN_ROOT/profiles/configs/"*.yaml 2>/dev/null || true; } | wc -l)
  pass "All $TOTAL_PROFILES profile configs have required fields"
fi

# ==============================================
# TEST 12: CHANGELOG.md exists and has entry for current version
# ==============================================
section "CHANGELOG.md — exists and has entry for current version ($ROOT_VER)"
if [[ ! -f "$PLUGIN_ROOT/CHANGELOG.md" ]]; then
  fail "CHANGELOG.md does not exist"
else
  if { grep -q "^## \[$ROOT_VER\]" "$PLUGIN_ROOT/CHANGELOG.md" 2>/dev/null || false; }; then
    pass "CHANGELOG.md has an entry for v$ROOT_VER"
  else
    fail "CHANGELOG.md has no entry for v$ROOT_VER"
  fi
fi

# ==============================================
# SUMMARY
# ==============================================
echo ""
echo "========================================"
TOTAL_TESTS=12
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
  echo -e "  ${GREEN}ALL TESTS PASSED${RESET} — $TOTAL_TESTS/$TOTAL_TESTS tests, 0 warnings, 0 errors"
elif [[ $ERRORS -eq 0 ]]; then
  echo -e "  ${YELLOW}PASSED WITH WARNINGS${RESET} — $TOTAL_TESTS/$TOTAL_TESTS tests, $WARNINGS warning(s), 0 errors"
else
  PASSED=$((TOTAL_TESTS - ERRORS))
  echo -e "  ${RED}FAILED${RESET} — $PASSED/$TOTAL_TESTS passed, $ERRORS error(s), $WARNINGS warning(s)"
fi
echo "========================================"

exit $ERRORS
