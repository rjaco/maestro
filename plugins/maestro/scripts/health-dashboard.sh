#!/usr/bin/env bash
# Maestro Health Dashboard — terminal health summary for a Maestro project.
# Usage: health-dashboard.sh [--compact | --json]

set -uo pipefail

MODE="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MAESTRO_DIR="$PROJECT_ROOT/.maestro"

if [[ -t 1 || "${FORCE_COLOR:-}" == "1" ]]; then
  R='\033[0m' BOLD='\033[1m' DIM='\033[2m'
  GREEN='\033[32m' YELLOW='\033[33m' RED='\033[31m' CYAN='\033[36m' BLUE='\033[34m'
else
  R='' BOLD='' DIM='' GREEN='' YELLOW='' RED='' CYAN='' BLUE=''
fi

cmd_exists() { command -v "$1" >/dev/null 2>&1; }
color_num() {
  # color_num val ok warn  — 0=green, <=warn=yellow, >warn=red
  local v="$1" ok="${2:-0}" w="${3:-0}"
  [[ "$v" -le "$ok" ]] 2>/dev/null && { printf '%s' "$GREEN"; return; }
  [[ "$v" -le "$w"  ]] 2>/dev/null && { printf '%s' "$YELLOW"; return; }
  printf '%s' "$RED"
}

# --- Git ---
git_branch="unknown" git_ahead=0 git_behind=0 git_dirty=0 git_last_date="" git_last_msg=""
if cmd_exists git && git -C "$PROJECT_ROOT" rev-parse --git-dir >/dev/null 2>&1; then
  git_branch=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
  git_last_date=$(git -C "$PROJECT_ROOT" log -1 --format="%ar" 2>/dev/null || echo "")
  git_last_msg=$(git -C "$PROJECT_ROOT" log -1 --format="%s" 2>/dev/null | cut -c1-60 || echo "")
  upstream=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref "@{u}" 2>/dev/null || echo "")
  if [[ -n "$upstream" ]]; then
    git_ahead=$(git -C "$PROJECT_ROOT" rev-list --count "@{u}..HEAD" 2>/dev/null || echo 0)
    git_behind=$(git -C "$PROJECT_ROOT" rev-list --count "HEAD..@{u}" 2>/dev/null || echo 0)
  fi
  git_dirty=$(git -C "$PROJECT_ROOT" status --porcelain 2>/dev/null | wc -l | tr -d ' ')
fi

# --- Code Quality ---
tsc_errors=0 lint_errors=0 todo_count=0 test_status="skip"
if cmd_exists tsc; then
  tsc_errors=$(tsc --noEmit 2>&1 | tail -1 | grep -oE '[0-9]+ error' | grep -oE '[0-9]+' || echo 0)
  tsc_errors="${tsc_errors:-0}"
fi
if cmd_exists eslint && ls "$PROJECT_ROOT"/.eslintrc* "$PROJECT_ROOT"/eslint.config* >/dev/null 2>&1; then
  lint_errors=$(eslint --quiet "$PROJECT_ROOT/src" 2>/dev/null | grep -c "error" || echo 0)
elif cmd_exists biome && [[ -f "$PROJECT_ROOT/biome.json" ]]; then
  lint_errors=$(biome check "$PROJECT_ROOT/src" 2>/dev/null | grep -c "error" || echo 0)
fi
todo_count=$(grep -rn --include="*.ts" --include="*.js" --include="*.sh" \
  "TODO\|FIXME" "$PROJECT_ROOT" 2>/dev/null | grep -v "\.git" | wc -l | tr -d ' ')
if [[ -f "$PROJECT_ROOT/package.json" ]] && cmd_exists npm; then
  tres=$(cd "$PROJECT_ROOT" && timeout 60 npm test --silent 2>&1; echo "EXIT:$?")
  printf '%s' "$tres" | grep -q "EXIT:0" && test_status="pass" || test_status="fail"
fi

# --- Maestro Status ---
maestro_active="no" maestro_stories_done=0 skills_count=0 last_build_log="unknown"
if [[ -f "$MAESTRO_DIR/state.local.md" ]]; then
  av=$(grep -E "^active:" "$MAESTRO_DIR/state.local.md" 2>/dev/null | head -1 | sed 's/active:[[:space:]]*//' || echo "")
  [[ "$av" == "true" ]] && maestro_active="yes"
  maestro_stories_done=$(grep -E "^current_story:" "$MAESTRO_DIR/state.local.md" 2>/dev/null | head -1 | grep -oE '[0-9]+' || echo 0)
fi
[[ -d "$PROJECT_ROOT/skills" ]] && skills_count=$(ls -1 "$PROJECT_ROOT/skills/" 2>/dev/null | wc -l | tr -d ' ')
blog_dir="$MAESTRO_DIR/logs"
[[ -d "$blog_dir" ]] && last_build_log=$(ls -t "$blog_dir"/*.log 2>/dev/null | head -1 | xargs stat -c "%y" 2>/dev/null | cut -d' ' -f1 || echo "unknown")

# --- Dependencies ---
deps_outdated=0 deps_advisories=0 deps_last_update="unknown"
if [[ -f "$PROJECT_ROOT/package.json" ]] && cmd_exists npm; then
  deps_outdated=$(cd "$PROJECT_ROOT" && timeout 30 npm outdated 2>/dev/null | tail -n +2 | wc -l | tr -d ' ' || echo 0)
  deps_advisories=$(cd "$PROJECT_ROOT" && timeout 30 npm audit --json 2>/dev/null | \
    python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('metadata',{}).get('vulnerabilities',{}).get('total',0))" 2>/dev/null || echo 0)
  [[ -f "$PROJECT_ROOT/package-lock.json" ]] && \
    deps_last_update=$(stat -c "%y" "$PROJECT_ROOT/package-lock.json" 2>/dev/null | cut -d' ' -f1 || echo "unknown")
fi

# --- System ---
node_ver=$(node --version 2>/dev/null || echo "n/a")
claude_ver=$(claude --version 2>/dev/null | head -1 || echo "n/a")
disk_avail=$(df -h "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $4}' || echo "n/a")
mem_info="n/a"
if [[ -f /proc/meminfo ]]; then
  mt=$(awk '/MemTotal/{print int($2/1024)}' /proc/meminfo)
  ma=$(awk '/MemAvailable/{print int($2/1024)}' /proc/meminfo)
  mem_info="${ma}MB free / ${mt}MB total"
fi

NOW=$(date -u "+%Y-%m-%d %H:%M UTC" 2>/dev/null || date "+%Y-%m-%d %H:%M UTC")
PROJECT_NAME=$(basename "$PROJECT_ROOT")

# --- JSON ---
if [[ "$MODE" == "--json" ]]; then
  python3 - <<PYEOF
import json
msg = "$git_last_msg".replace('"', '\\"')
print(json.dumps({
  "generated": "$NOW", "project": "$PROJECT_NAME",
  "git": {"branch": "$git_branch", "ahead": $git_ahead, "behind": $git_behind,
          "dirty_files": $git_dirty, "last_commit_date": "$git_last_date", "last_commit_msg": msg},
  "code_quality": {"tsc_errors": $tsc_errors, "lint_errors": $lint_errors,
                   "todo_count": $todo_count, "test_status": "$test_status"},
  "maestro": {"active": "$maestro_active", "skills_count": $skills_count,
              "stories_done": $maestro_stories_done, "last_build_log": "$last_build_log"},
  "dependencies": {"outdated": $deps_outdated, "advisories": $deps_advisories,
                   "last_update": "$deps_last_update"},
  "system": {"node_version": "$node_ver", "claude_version": "$claude_ver",
             "disk_available": "$disk_avail", "memory": "$mem_info"}
}, indent=2))
PYEOF
  exit 0
fi

# --- Compact ---
if [[ "$MODE" == "--compact" ]]; then
  bi="${git_branch}"
  [[ $git_ahead  -gt 0 ]] && bi="${bi}↑${git_ahead}"
  [[ $git_behind -gt 0 ]] && bi="${bi}↓${git_behind}"
  tc="${GREEN}tsc:0${R}";   [[ $tsc_errors  -gt 0 ]] && tc="${RED}tsc:${tsc_errors}${R}"
  lc="${GREEN}lint:0${R}";  [[ $lint_errors -gt 0 ]] && lc="${RED}lint:${lint_errors}${R}"
  tx="${GREEN}test:ok${R}"; [[ "$test_status" == "fail" ]] && tx="${RED}test:fail${R}"
                            [[ "$test_status" == "skip" ]] && tx="${DIM}test:n/a${R}"
  dc="${GREEN}deps:ok${R}"; [[ $deps_outdated   -gt 0 ]] && dc="${YELLOW}deps:${deps_outdated}old${R}"
                            [[ $deps_advisories -gt 0 ]] && dc="${RED}deps:${deps_advisories}vuln${R}"
  printf "${BOLD}%s${R} | ${CYAN}%s${R} | %s %s %s | ${BLUE}%s skills${R} | %s\n" \
    "$PROJECT_NAME" "$bi" "$tc" "$lc" "$tx" "$skills_count" "$dc"
  exit 0
fi

# --- Full Dashboard ---
row() { printf "  %-22s %s\n" "$1" "$2"; }
sec() { printf "\n${BOLD}${CYAN}── %s${R}\n" "$1"; }

printf "${BOLD}"
printf "╔══════════════════════════════════════════════════╗\n"
printf "║  %-48s║\n" "MAESTRO HEALTH DASHBOARD"
printf "║  %-48s║\n" "Project: ${PROJECT_NAME} | Branch: ${git_branch}"
printf "║  %-48s║\n" "Generated: ${NOW}"
printf "╚══════════════════════════════════════════════════╝${R}\n"

sec "GIT STATUS"
row "Branch:"            "${CYAN}${git_branch}${R}"
row "Ahead / Behind:"    "${git_ahead} / ${git_behind}"
row "Uncommitted files:" "$(color_num $git_dirty 0 5)${git_dirty}${R}"
row "Last commit:"       "${DIM}${git_last_date}${R} — ${git_last_msg}"

sec "CODE QUALITY"
row "TypeScript errors:" "$(color_num $tsc_errors 0 0)${tsc_errors}${R}"
row "Lint errors:"       "$(color_num $lint_errors 0 0)${lint_errors}${R}"
row "TODO / FIXME:"      "$(color_num $todo_count 5 20)${todo_count}${R}"
case "$test_status" in
  pass) row "Tests:" "${GREEN}passing${R}" ;;
  fail) row "Tests:" "${RED}failing${R}" ;;
  skip) row "Tests:" "${DIM}n/a${R}" ;;
esac

sec "MAESTRO STATUS"
ma="${RED}no${R}"; [[ "$maestro_active" == "yes" ]] && ma="${GREEN}yes${R}"
row "Active session:"   "$ma"
row "Skills:"           "${BLUE}${skills_count}${R}"
row "Stories done:"     "${maestro_stories_done}"
row "Last build log:"   "${DIM}${last_build_log}${R}"

sec "DEPENDENCIES"
row "Outdated packages:"    "$(color_num $deps_outdated 0 10)${deps_outdated}${R}"
row "Security advisories:"  "$(color_num $deps_advisories 0 0)${deps_advisories}${R}"
row "Last update:"          "${DIM}${deps_last_update}${R}"

sec "SYSTEM"
row "Node.js:"          "${node_ver}"
row "Claude CLI:"       "${DIM}${claude_ver}${R}"
row "Disk available:"   "${disk_avail}"
row "Memory:"          "${mem_info}"
printf "\n"
