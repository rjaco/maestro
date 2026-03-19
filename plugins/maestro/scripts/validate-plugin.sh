#!/usr/bin/env bash
# Maestro Plugin Validator
# Runs structural checks on the plugin to catch issues before release.
# Usage: bash scripts/validate-plugin.sh

set -euo pipefail

PLUGIN_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ERRORS=0
WARNINGS=0

# Colors
RED='\033[31m'
GREEN='\033[32m'
YELLOW='\033[33m'
RESET='\033[0m'

pass() { echo -e "  ${GREEN}(ok)${RESET} $1"; }
warn() { echo -e "  ${YELLOW}(!)${RESET} $1"; WARNINGS=$((WARNINGS + 1)); }
fail() { echo -e "  ${RED}(x)${RESET} $1"; ERRORS=$((ERRORS + 1)); }

echo "========================================"
echo "  Maestro Plugin Validator"
echo "========================================"
echo ""

# --- 1. Version consistency ---
echo "Version Consistency:"
ROOT_VER=$(grep '"version"' "$PLUGIN_ROOT/.claude-plugin/plugin.json" 2>/dev/null | head -1 | grep -o '"[0-9.]*"' | tr -d '"')
PLUGIN_VER=$(grep '"version"' "$PLUGIN_ROOT/plugins/maestro/.claude-plugin/plugin.json" 2>/dev/null | head -1 | grep -o '"[0-9.]*"' | tr -d '"')
MARKET_VER=$(grep '"version"' "$PLUGIN_ROOT/.claude-plugin/marketplace.json" 2>/dev/null | head -1 | grep -o '"[0-9.]*"' | tr -d '"')

if [[ "$ROOT_VER" == "$PLUGIN_VER" ]] && [[ "$PLUGIN_VER" == "$MARKET_VER" ]]; then
  pass "All versions match: $ROOT_VER"
else
  fail "Version mismatch: root=$ROOT_VER, plugin=$PLUGIN_VER, marketplace=$MARKET_VER"
fi

# --- 2. Mirror sync ---
echo ""
echo "Mirror Sync (root ↔ plugins/maestro):"

# Skills
ROOT_SKILLS=$(ls -d "$PLUGIN_ROOT/skills"/*/ 2>/dev/null | wc -l)
MIRROR_SKILLS=$(ls -d "$PLUGIN_ROOT/plugins/maestro/skills"/*/ 2>/dev/null | wc -l)
if [[ "$ROOT_SKILLS" -eq "$MIRROR_SKILLS" ]]; then
  pass "Skills: $ROOT_SKILLS directories in both locations"
else
  fail "Skills mismatch: root=$ROOT_SKILLS, mirror=$MIRROR_SKILLS"
fi

# Commands
ROOT_CMDS=$(ls "$PLUGIN_ROOT/commands/"*.md 2>/dev/null | wc -l)
MIRROR_CMDS=$(ls "$PLUGIN_ROOT/plugins/maestro/commands/"*.md 2>/dev/null | wc -l)
if [[ "$ROOT_CMDS" -eq "$MIRROR_CMDS" ]]; then
  pass "Commands: $ROOT_CMDS files in both locations"
else
  fail "Commands mismatch: root=$ROOT_CMDS, mirror=$MIRROR_CMDS"
fi

# Hooks
if diff -q "$PLUGIN_ROOT/hooks/hooks.json" "$PLUGIN_ROOT/plugins/maestro/hooks/hooks.json" > /dev/null 2>&1; then
  pass "hooks.json identical in both locations"
else
  fail "hooks.json differs between root and plugins/maestro"
fi

# --- 3. Hook scripts exist ---
echo ""
echo "Hook Script Integrity:"
HOOK_SCRIPTS=$(grep -o '"command": "[^"]*"' "$PLUGIN_ROOT/hooks/hooks.json" | sed 's|.*hooks/||;s|"||g' | sort -u)
for script in $HOOK_SCRIPTS; do
  if [[ -x "$PLUGIN_ROOT/hooks/$script" ]]; then
    pass "$script exists and is executable"
  elif [[ -f "$PLUGIN_ROOT/hooks/$script" ]]; then
    warn "$script exists but is NOT executable (chmod +x needed)"
  else
    fail "$script referenced in hooks.json but does NOT exist"
  fi
done

# --- 4. Skills have SKILL.md ---
echo ""
echo "Skill Completeness:"
EMPTY_SKILLS=0
for dir in "$PLUGIN_ROOT/skills"/*/; do
  skill=$(basename "$dir")
  if [[ ! -f "$dir/SKILL.md" ]]; then
    fail "skills/$skill/ has no SKILL.md"
  else
    lines=$(wc -l < "$dir/SKILL.md")
    if [[ $lines -lt 50 ]]; then
      warn "skills/$skill/SKILL.md is thin ($lines lines)"
      EMPTY_SKILLS=$((EMPTY_SKILLS + 1))
    fi
  fi
done
if [[ $EMPTY_SKILLS -eq 0 ]]; then
  pass "All $ROOT_SKILLS skills have substantive SKILL.md files (>=50 lines)"
fi

# --- 5. JSON validity ---
echo ""
echo "JSON Validity:"
for json in "$PLUGIN_ROOT/.claude-plugin/plugin.json" "$PLUGIN_ROOT/.claude-plugin/marketplace.json" "$PLUGIN_ROOT/plugins/maestro/.claude-plugin/plugin.json" "$PLUGIN_ROOT/hooks/hooks.json" "$PLUGIN_ROOT/.mcp.json"; do
  if [[ -f "$json" ]]; then
    if python3 -m json.tool "$json" > /dev/null 2>&1; then
      pass "$(basename "$json") is valid JSON"
    else
      fail "$(basename "$json") is INVALID JSON"
    fi
  fi
done

# --- 6. No hardcoded paths ---
echo ""
echo "Hardcoded Paths:"
HARDCODED=$(grep -rn "~/.claude/plugins/cache" --include="*.sh" --include="*.json" "$PLUGIN_ROOT/hooks/" "$PLUGIN_ROOT/scripts/" "$PLUGIN_ROOT/plugins/maestro/hooks/" "$PLUGIN_ROOT/plugins/maestro/scripts/" 2>/dev/null | grep -v ".git/" | wc -l)
if [[ $HARDCODED -eq 0 ]]; then
  pass "No hardcoded cache paths in hooks or scripts"
else
  fail "$HARDCODED hardcoded cache paths found"
fi

# --- 7. No TODO/placeholder markers in templates ---
echo ""
echo "Placeholder Markers:"
TODOS=$(grep -rn "\[TODO" --include="*.md" "$PLUGIN_ROOT/templates/" "$PLUGIN_ROOT/commands/init.md" 2>/dev/null | wc -l)
if [[ $TODOS -eq 0 ]]; then
  pass "No [TODO] markers in templates or init command"
else
  warn "$TODOS [TODO] markers found in templates/init"
fi

# --- 8. Summary ---
echo ""
echo "========================================"
if [[ $ERRORS -eq 0 ]]; then
  echo -e "  ${GREEN}PASSED${RESET} — $WARNINGS warnings, 0 errors"
else
  echo -e "  ${RED}FAILED${RESET} — $ERRORS errors, $WARNINGS warnings"
fi
echo "========================================"

exit $ERRORS
