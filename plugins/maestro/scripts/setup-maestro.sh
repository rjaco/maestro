#!/usr/bin/env bash
set -euo pipefail

# Maestro Setup Script
# Initializes the .maestro/ directory with default configuration files.
# Safe to run multiple times -- will not overwrite existing files.

MAESTRO_DIR=".maestro"
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "$0")/.." && pwd)}"
TEMPLATE_DIR="$PLUGIN_ROOT/templates"

# --- Colors (if terminal supports them) ---

if [[ -t 1 ]]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  YELLOW='\033[0;33m'
  CYAN='\033[0;36m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' YELLOW='' CYAN='' RESET=''
fi

info()    { printf "${GREEN}[maestro]${RESET} %s\n" "$1"; }
warn()    { printf "${YELLOW}[maestro]${RESET} %s\n" "$1"; }
created() { printf "${CYAN}  + created${RESET} %s\n" "$1"; }
skipped() { printf "${YELLOW}  - exists${RESET}  %s\n" "$1"; }

# --- Create .maestro/ directory ---

if [[ ! -d "$MAESTRO_DIR" ]]; then
  mkdir -p "$MAESTRO_DIR"
  info "Created $MAESTRO_DIR/ directory"
else
  info "$MAESTRO_DIR/ directory already exists"
fi

# --- state.md ---

if [[ ! -f "$MAESTRO_DIR/state.md" ]]; then
  cat > "$MAESTRO_DIR/state.md" << 'STATE_EOF'
# Maestro Project State

## Current Focus
(initialized — run /maestro to start building)

## Features Completed
(none yet)

## Tech Debt
(none identified)
STATE_EOF
  created "$MAESTRO_DIR/state.md"
else
  skipped "$MAESTRO_DIR/state.md"
fi

# --- config.yaml ---

if [[ ! -f "$MAESTRO_DIR/config.yaml" ]]; then
  cat > "$MAESTRO_DIR/config.yaml" << 'CONFIG_EOF'
# Maestro Configuration
# Customize Maestro behavior for this project.

# Cost tracking
cost_tracking:
  enabled: true
  warn_threshold_usd: 5.00
  hard_limit_usd: 50.00
  log_file: .maestro/cost.log

# Dev-loop defaults
dev_loop:
  default_mode: checkpoint      # checkpoint | yolo | careful
  max_qa_iterations: 5
  max_self_heal: 3
  max_consecutive_failures: 5

# Model routing
models:
  planning: opus               # Decomposition, architecture, roadmaps
  execution: sonnet            # Code generation, dev-loop
  review: sonnet               # Quality review
  simple: haiku                # Linting, formatting, simple tasks
  research: sonnet             # Web research, competitive analysis

# Opus (Magnum Opus) defaults
opus:
  default_token_budget: 0      # 0 = unlimited
  default_time_budget_hours: 0 # 0 = unlimited
  max_consecutive_failures: 5
  max_fix_cycles: 3
  auto_checkpoint_interval: 3  # Checkpoint every N stories

# Git behavior
git:
  auto_commit: true
  commit_prefix: "maestro:"
  branch_prefix: "maestro/"
  create_pr: true

# Quality gates
quality:
  run_tests: true
  run_typecheck: true
  run_lint: true
  require_all_pass: true

# Notifications (future)
notifications:
  on_checkpoint: true
  on_error: true
  on_completion: true
CONFIG_EOF
  created "$MAESTRO_DIR/config.yaml"
else
  skipped "$MAESTRO_DIR/config.yaml"
fi

# --- trust.yaml ---

if [[ ! -f "$MAESTRO_DIR/trust.yaml" ]]; then
  cat > "$MAESTRO_DIR/trust.yaml" << 'TRUST_EOF'
total_stories: 0
qa_first_pass_rate: 0.00
self_heal_success_rate: 0.00
average_qa_iterations: 0.0
trust_level: novice
stories_by_mode:
  yolo: 0
  checkpoint: 0
  careful: 0
TRUST_EOF
  created "$MAESTRO_DIR/trust.yaml"
else
  skipped "$MAESTRO_DIR/trust.yaml"
fi

# --- notes.md ---

if [[ ! -f "$MAESTRO_DIR/notes.md" ]]; then
  cat > "$MAESTRO_DIR/notes.md" << 'NOTES_EOF'
# Maestro Notes

Project-specific notes, learnings, and decisions captured during Maestro sessions.
This file is updated automatically and can also be edited manually.

---
NOTES_EOF
  created "$MAESTRO_DIR/notes.md"
else
  skipped "$MAESTRO_DIR/notes.md"
fi

# --- Ensure .gitignore includes local state files ---

GITIGNORE=".gitignore"
PATTERN=".maestro/*.local.md"

if [[ -f "$GITIGNORE" ]]; then
  if ! grep -qF "$PATTERN" "$GITIGNORE"; then
    printf '\n# Maestro local state (session-specific, not committed)\n%s\n' "$PATTERN" >> "$GITIGNORE"
    info "Added $PATTERN to $GITIGNORE"
  else
    info "$PATTERN already in $GITIGNORE"
  fi
else
  printf '# Maestro local state (session-specific, not committed)\n%s\n' "$PATTERN" > "$GITIGNORE"
  created "$GITIGNORE (with Maestro pattern)"
fi

# --- Summary ---

printf '\n'
info "Maestro initialized successfully."
printf '\n'
printf "  ${BOLD}Directory:${RESET}  %s/\n" "$MAESTRO_DIR"
printf "  ${BOLD}Files:${RESET}\n"
printf "    state.md     — Persistent project state (history, focus, tech debt)\n"
printf "    config.yaml  — Project configuration\n"
printf "    trust.yaml   — Progressive trust metrics\n"
printf "    notes.md     — Project notes and learnings\n"
printf '\n'
printf "  ${BOLD}Next steps:${RESET}\n"
printf "    Use ${CYAN}/maestro${RESET} to start building a feature.\n"
printf "    Use ${CYAN}/maestro opus${RESET} to start a Magnum Opus session.\n"
printf '\n'
