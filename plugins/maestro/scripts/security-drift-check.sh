#!/usr/bin/env bash
# Maestro Security Drift Check
# Generates and verifies SHA-256 hashes of critical files.
# Detects unauthorized modifications to skill files, hooks, and config.
#
# Usage:
#   ./scripts/security-drift-check.sh          # Check against baseline
#   ./scripts/security-drift-check.sh --init   # Generate baseline
#   ./scripts/security-drift-check.sh --update # Update baseline after legitimate changes

set -euo pipefail

BASELINE_FILE=".maestro/security/baseline.json"
ACTION="${1:---check}"

# Critical files to monitor
get_critical_files() {
  local files=()

  # CLAUDE.md files
  for f in CLAUDE.md .claude/CLAUDE.md; do
    [[ -f "$f" ]] && files+=("$f")
  done

  # Skill files
  while IFS= read -r f; do
    files+=("$f")
  done < <(find skills -name "SKILL.md" -type f 2>/dev/null || true)

  # Agent definitions
  while IFS= read -r f; do
    files+=("$f")
  done < <(find agents -name "*.md" -type f 2>/dev/null || true)

  # Hook scripts
  while IFS= read -r f; do
    files+=("$f")
  done < <(find hooks -name "*.sh" -type f 2>/dev/null || true)

  # Plugin manifest
  for f in .claude-plugin/plugin.json; do
    [[ -f "$f" ]] && files+=("$f")
  done

  # DNA
  [[ -f ".maestro/dna.md" ]] && files+=(".maestro/dna.md")

  printf '%s\n' "${files[@]}" | sort
}

generate_baseline() {
  mkdir -p "$(dirname "$BASELINE_FILE")"

  local timestamp
  timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

  echo "Generating security baseline..."

  # Build JSON
  local json='{'
  json+="\"generated_at\":\"$timestamp\","
  json+='"files":{'

  local first=true
  while IFS= read -r file; do
    local hash
    hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)
    if [[ -n "$hash" ]]; then
      if [[ "$first" == "true" ]]; then
        first=false
      else
        json+=","
      fi
      json+="\"$file\":\"sha256:$hash\""
    fi
  done < <(get_critical_files)

  json+='}}'

  echo "$json" | python3 -m json.tool > "$BASELINE_FILE" 2>/dev/null || echo "$json" > "$BASELINE_FILE"

  local count
  count=$(get_critical_files | wc -l)
  echo "Baseline generated: $count files hashed → $BASELINE_FILE"
}

check_drift() {
  if [[ ! -f "$BASELINE_FILE" ]]; then
    echo "No baseline found. Run with --init first."
    echo "  ./scripts/security-drift-check.sh --init"
    exit 1
  fi

  local drifted=0
  local checked=0
  local missing=0
  local new_files=0

  echo "Security Drift Check:"
  echo ""

  while IFS= read -r file; do
    checked=$((checked + 1))

    # Get current hash
    local current_hash
    current_hash=$(sha256sum "$file" 2>/dev/null | cut -d' ' -f1)

    # Get baseline hash
    local baseline_hash
    baseline_hash=$(python3 -c "
import json,sys
try:
  bf=sys.argv[1]
  fk=sys.argv[2]
  d=json.load(open(bf))
  h=d.get('files',{}).get(fk,'')
  print(h.replace('sha256:','') if h else '')
except: print('')
" "$BASELINE_FILE" "$file" 2>/dev/null || echo "")

    if [[ -z "$baseline_hash" ]]; then
      printf "  %-50s ⚠️  NEW (not in baseline)\n" "$file"
      new_files=$((new_files + 1))
    elif [[ "$current_hash" == "$baseline_hash" ]]; then
      printf "  %-50s ✅ unchanged\n" "$file"
    else
      printf "  %-50s ❌ MODIFIED (hash mismatch)\n" "$file"
      drifted=$((drifted + 1))
    fi
  done < <(get_critical_files)

  echo ""
  echo "Checked: $checked files | Drifted: $drifted | New: $new_files"

  if [[ $drifted -gt 0 ]]; then
    echo ""
    echo "⚠️  Security drift detected! Review changes and run --update if legitimate."
    exit 2
  else
    echo "✅ No drift detected."
    exit 0
  fi
}

case "$ACTION" in
  --init|--update)
    generate_baseline
    ;;
  --check|*)
    check_drift
    ;;
esac
