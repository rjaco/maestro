#!/usr/bin/env bash
# Maestro Index Health Check
# Validates Maestro's indexed state files for staleness and integrity.
# Quick shell-based check complementing the full index-health skill.
#
# Usage: ./scripts/index-health-check.sh

set -euo pipefail

echo "Index Health Check:"
echo ""

ISSUES=0

# Check DNA freshness
if [[ -f ".maestro/dna.md" ]]; then
  DNA_AGE=$(( ($(date +%s) - $(stat -c %Y ".maestro/dna.md" 2>/dev/null || stat -f %m ".maestro/dna.md" 2>/dev/null || echo 0)) / 3600 ))
  if [[ $DNA_AGE -gt 168 ]]; then  # 7 days
    printf "  %-35s ⚠️  stale (%d hours old)\n" ".maestro/dna.md" "$DNA_AGE"
    ISSUES=$((ISSUES + 1))
  else
    printf "  %-35s ✅ valid (%dh old)\n" ".maestro/dna.md" "$DNA_AGE"
  fi
else
  printf "  %-35s ❌ missing\n" ".maestro/dna.md"
  ISSUES=$((ISSUES + 1))
fi

# Check repo map freshness
if [[ -f ".maestro/repo-map.md" ]]; then
  MAP_AGE=$(( ($(date +%s) - $(stat -c %Y ".maestro/repo-map.md" 2>/dev/null || stat -f %m ".maestro/repo-map.md" 2>/dev/null || echo 0)) / 3600 ))
  # Check if >20% of mapped files changed
  TOTAL_FILES=$(grep -c "^-" ".maestro/repo-map.md" 2>/dev/null || echo 0)
  if [[ $MAP_AGE -gt 24 ]]; then
    printf "  %-35s ⚠️  stale (%dh old)\n" ".maestro/repo-map.md" "$MAP_AGE"
    ISSUES=$((ISSUES + 1))
  else
    printf "  %-35s ✅ valid (%dh old)\n" ".maestro/repo-map.md" "$MAP_AGE"
  fi
else
  printf "  %-35s ⚠️  not generated\n" ".maestro/repo-map.md"
fi

# Check state file integrity
if [[ -f ".maestro/state.local.md" ]]; then
  # Verify frontmatter
  if head -1 ".maestro/state.local.md" | grep -q "^---$"; then
    # Check for impossible states
    ACTIVE=$(sed -n '/^---$/,/^---$/p' ".maestro/state.local.md" | grep '^active:' | head -1 | sed 's/active:[[:space:]]*//' | xargs 2>/dev/null || echo "")
    PHASE=$(sed -n '/^---$/,/^---$/p' ".maestro/state.local.md" | grep '^phase:' | head -1 | sed 's/phase:[[:space:]]*//' | xargs 2>/dev/null || echo "")

    if [[ "$ACTIVE" == "true" && "$PHASE" == "completed" ]]; then
      printf "  %-35s ⚠️  inconsistent (active=true but completed)\n" ".maestro/state.local.md"
      ISSUES=$((ISSUES + 1))
    else
      printf "  %-35s ✅ valid\n" ".maestro/state.local.md"
    fi
  else
    printf "  %-35s ❌ invalid frontmatter\n" ".maestro/state.local.md"
    ISSUES=$((ISSUES + 1))
  fi
else
  printf "  %-35s ⚠️  no active session\n" ".maestro/state.local.md"
fi

# Check memory files
for mem in ".maestro/memory/semantic.md" ".maestro/memory/episodic.md"; do
  if [[ -f "$mem" ]]; then
    LINES=$(wc -l < "$mem")
    if [[ $LINES -gt 500 ]]; then
      printf "  %-35s ⚠️  large (%d lines, consider cleanup)\n" "$mem" "$LINES"
      ISSUES=$((ISSUES + 1))
    else
      printf "  %-35s ✅ valid (%d lines)\n" "$mem" "$LINES"
    fi
  else
    printf "  %-35s ⚠️  not initialized\n" "$mem"
  fi
done

# Check registry
if [[ -f ".maestro/registry.json" ]]; then
  if python3 -c "import json; json.load(open('.maestro/registry.json'))" 2>/dev/null; then
    REQ_COUNT=$(python3 -c "import json; d=json.load(open('.maestro/registry.json')); print(len(d.get('requirements',[])))" 2>/dev/null || echo "?")
    printf "  %-35s ✅ valid (%s requirements)\n" ".maestro/registry.json" "$REQ_COUNT"
  else
    printf "  %-35s ❌ invalid JSON\n" ".maestro/registry.json"
    ISSUES=$((ISSUES + 1))
  fi
else
  printf "  %-35s ⚠️  not initialized\n" ".maestro/registry.json"
fi

echo ""
if [[ $ISSUES -gt 0 ]]; then
  echo "Found $ISSUES issue(s). Run /maestro doctor for full diagnostics."
  exit 1
else
  echo "All indexes healthy."
  exit 0
fi
