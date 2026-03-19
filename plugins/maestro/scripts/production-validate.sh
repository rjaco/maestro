#!/usr/bin/env bash
# Production Validator — blocks shipping if mock/stub/debug code detected
# Usage: ./scripts/production-validate.sh [--strict] [path]
# Exit code 0: all checks pass
# Exit code 1: one or more checks failed (details on stderr)

set -euo pipefail

# --- Argument parsing ---
STRICT=false
SCAN_PATH="."

while [[ $# -gt 0 ]]; do
  case "$1" in
    --strict)
      STRICT=true
      shift
      ;;
    -*)
      printf 'Unknown flag: %s\n' "$1" >&2
      printf 'Usage: %s [--strict] [path]\n' "$0" >&2
      exit 2
      ;;
    *)
      SCAN_PATH="$1"
      shift
      ;;
  esac
done

# --- Colors ---
RESET='\033[0m'
BOLD='\033[1m'
GREEN='\033[32m'
RED='\033[31m'
YELLOW='\033[33m'
DIM='\033[2m'

# --- State ---
FAILURES=0
WARNINGS=0
LOG_ENTRIES=""
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%S)"

# --- Ignore file support ---
IGNORE_FILE=".production-validate-ignore"

# Build a list of ignored paths from the ignore file
build_ignore_args() {
  if [[ ! -f "$IGNORE_FILE" ]]; then
    return
  fi
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip blank lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    printf -- '--exclude=%s ' "$line"
    printf -- '--exclude-dir=%s ' "$line"
  done < "$IGNORE_FILE"
}

IGNORE_ARGS="$(build_ignore_args)"

# --- Helper: run a grep check ---
# Arguments:
#   $1 description
#   $2 severity: FAIL or WARN
#   $3 regex pattern (extended regex)
#   $4 extra grep flags (optional)
#   $5 extra --exclude/--exclude-dir args (optional)
run_check() {
  local description="$1"
  local severity="$2"
  local pattern="$3"
  local extra_flags="${4:-}"
  local extra_excludes="${5:-}"

  # shellcheck disable=SC2086
  local results
  results=$(grep -rn -E \
    --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
    --include="*.py" --include="*.rb" --include="*.go" --include="*.rs" \
    --include="*.java" --include="*.cs" --include="*.php" --include="*.sh" \
    --include="*.yaml" --include="*.yml" --include="*.json" --include="*.env" \
    --exclude-dir=".git" --exclude-dir="node_modules" --exclude-dir=".maestro" \
    --exclude-dir="vendor" --exclude-dir="dist" --exclude-dir="build" \
    --exclude-dir=".next" --exclude-dir="target" --exclude-dir="__pycache__" \
    $IGNORE_ARGS \
    $extra_excludes \
    $extra_flags \
    -e "$pattern" \
    "$SCAN_PATH" 2>/dev/null \
    | grep -v "production-validate: ignore" \
    || true)

  if [[ -n "$results" ]]; then
    if [[ "$severity" == "FAIL" ]]; then
      printf "[${RED}FAIL${RESET}] %s\n" "$description"
      while IFS= read -r line; do
        printf "  ${DIM}%s${RESET}\n" "$line"
      done <<< "$results"
      FAILURES=$(( FAILURES + 1 ))
      LOG_ENTRIES="${LOG_ENTRIES}  ${description}:"$'\n'
      while IFS= read -r line; do
        LOG_ENTRIES="${LOG_ENTRIES}    ${line}"$'\n'
      done <<< "$results"
    else
      # WARN
      if [[ "$STRICT" == "true" ]]; then
        printf "[${RED}FAIL${RESET}] %s ${DIM}(strict)${RESET}\n" "$description"
        FAILURES=$(( FAILURES + 1 ))
        LOG_ENTRIES="${LOG_ENTRIES}  ${description} (strict):"$'\n'
      else
        printf "[${YELLOW}WARN${RESET}] %s\n" "$description"
        WARNINGS=$(( WARNINGS + 1 ))
        LOG_ENTRIES="${LOG_ENTRIES}  ${description} (warning):"$'\n'
      fi
      while IFS= read -r line; do
        printf "  ${DIM}%s${RESET}\n" "$line"
        LOG_ENTRIES="${LOG_ENTRIES}    ${line}"$'\n'
      done <<< "$results"
    fi
  else
    printf "[${GREEN}PASS${RESET}] %s\n" "$description"
  fi
}

# --- Header ---
printf "\n${BOLD}Production Validator Results${RESET}\n"
printf '============================\n'
printf "${DIM}Scanning: %s%s${RESET}\n\n" "$SCAN_PATH" \
  "$( [[ "$STRICT" == "true" ]] && printf ' (strict mode)' || true)"

# --- Check 1: Mock/Stub detection ---
# Matches variable/function names that start with mock/fake/stub/dummy followed by uppercase or underscore.
# Excludes test files and test directories.
run_check \
  "Mock/Stub detection" \
  "FAIL" \
  '(const|let|var|function|def|fn|func)\s+(mock|fake|stub|dummy)[A-Z_]' \
  "-i" \
  "--exclude=*.test.* --exclude=*.spec.* --exclude=*_test.* --exclude=*_spec.* --exclude-dir=__tests__ --exclude-dir=__mocks__ --exclude-dir=tests --exclude-dir=test --exclude-dir=spec"

# --- Check 2: TODO/FIXME detection ---
# Excludes docs, changelogs, and markdown files.
run_check \
  "TODO/FIXME detection" \
  "WARN" \
  '\b(TODO|FIXME|HACK|XXX)\b' \
  "" \
  "--exclude=*.md --exclude=*.txt --exclude=CHANGELOG* --exclude=HISTORY* --exclude=CHANGES* --exclude=*.rst"

# --- Check 3: Debug artifact detection ---
# Excludes test files.
run_check \
  "Debug artifact detection" \
  "FAIL" \
  '(console\.(log|debug|trace|warn|error)\(|debugger;|binding\.pry|import pdb|pdb\.set_trace\(\)|byebug)' \
  "" \
  "--exclude=*.test.* --exclude=*.spec.* --exclude=*_test.* --exclude=*_spec.* --exclude-dir=__tests__ --exclude-dir=tests --exclude-dir=test --exclude-dir=spec"

# --- Check 4: Hardcoded credentials ---
# Matches common credential variable names assigned to literal string values.
# Excludes test files, example/sample files, and docs.
run_check \
  "Hardcoded credentials" \
  "FAIL" \
  '(password|passwd|api_key|apikey|secret|token|auth_token|access_token|private_key)\s*[=:]\s*["'"'"'][^"'"'"']{4,}["'"'"']' \
  "-i" \
  "--exclude=*.example --exclude=*.sample --exclude=*.test.* --exclude=*.spec.* --exclude-dir=__tests__ --exclude-dir=tests --exclude-dir=test --exclude-dir=spec --exclude=*.md"

# --- Check 5: Placeholder detection ---
# Detects example domains, lorem ipsum, and common placeholder values.
# Excludes docs, changelogs, and test files.
run_check \
  "Placeholder detection" \
  "WARN" \
  '(example\.com|lorem ipsum|Lorem Ipsum|test@test\.com|foo@bar\.com|REPLACE_ME|INSERT_HERE|your[-_]?api[-_]?key|changeme|CHANGEME)' \
  "" \
  "--exclude=*.md --exclude=*.txt --exclude=CHANGELOG* --exclude=*.test.* --exclude=*.spec.* --exclude-dir=__tests__ --exclude-dir=tests --exclude-dir=test --exclude-dir=spec"

# --- Check 6: Unimplemented code ---
# Detects not-implemented throws/panics across multiple languages.
# Excludes test files.
run_check \
  "Unimplemented code" \
  "FAIL" \
  '(throw new Error\(["'"'"']not implemented|throw new Error\(["'"'"']TODO|raise NotImplementedError|todo!\(\)|unimplemented!\(\))' \
  "-i" \
  "--exclude=*.test.* --exclude=*.spec.* --exclude=*_test.* --exclude=*_spec.* --exclude-dir=__tests__ --exclude-dir=tests --exclude-dir=test --exclude-dir=spec"

# --- Summary ---
printf '\n'
if [[ $FAILURES -gt 0 ]]; then
  printf "${RED}${BOLD}Result: %d check%s FAILED. Fix before shipping.${RESET}\n" \
    "$FAILURES" "$( [[ $FAILURES -eq 1 ]] && printf '' || printf 's')"
elif [[ $WARNINGS -gt 0 ]]; then
  printf "${YELLOW}${BOLD}Result: All checks passed with %d warning%s.${RESET}\n" \
    "$WARNINGS" "$( [[ $WARNINGS -eq 1 ]] && printf '' || printf 's')"
  printf "${DIM}Run with --strict to treat warnings as failures.${RESET}\n"
else
  printf "${GREEN}${BOLD}Result: All checks passed. Ready to ship.${RESET}\n"
fi
printf '\n'

# --- Log results ---
LOG_DIR=".maestro/logs"
LOG_FILE="$LOG_DIR/production-validate.log"

if mkdir -p "$LOG_DIR" 2>/dev/null; then
  if [[ $FAILURES -gt 0 ]]; then
    STATUS_TAG="FAIL ${FAILURES}-checks"
  elif [[ $WARNINGS -gt 0 ]]; then
    STATUS_TAG="WARN ${WARNINGS}-warnings"
  else
    STATUS_TAG="PASS all-checks"
  fi

  LOG_LINE="[$TIMESTAMP] $STATUS_TAG | path: $SCAN_PATH | strict: $STRICT"
  printf '%s\n' "$LOG_LINE" >> "$LOG_FILE"
  if [[ -n "$LOG_ENTRIES" ]]; then
    printf '%s' "$LOG_ENTRIES" >> "$LOG_FILE"
  fi
fi

# --- Exit code ---
if [[ $FAILURES -gt 0 ]]; then
  exit 1
fi
exit 0
