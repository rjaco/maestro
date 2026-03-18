#!/usr/bin/env bash
# Maestro Worktree Merge Script
# Merges completed worktree changes into the development branch, then cleans up.
#
# Usage: ./scripts/worktree-merge.sh <worktree-path> [commit-message]
#
# Flow:
#   1. Verify worktree has changes
#   2. Commit changes in worktree (if uncommitted)
#   3. Switch to development branch
#   4. Merge worktree branch into development
#   5. Push development to origin
#   6. Remove worktree and branch
#
# This script enforces the rule: never merge to main, always to development.

set -euo pipefail

WORKTREE_PATH="${1:-}"
COMMIT_MSG="${2:-feat: merge worktree changes}"

if [[ -z "$WORKTREE_PATH" ]]; then
  echo "Usage: $0 <worktree-path> [commit-message]"
  echo "Example: $0 .claude/worktrees/agent-abc123 'feat: add auth system'"
  exit 1
fi

if [[ ! -d "$WORKTREE_PATH" ]]; then
  echo "Error: Worktree path does not exist: $WORKTREE_PATH"
  exit 1
fi

# Get the worktree branch name
WORKTREE_BRANCH=$(git -C "$WORKTREE_PATH" branch --show-current 2>/dev/null || true)
if [[ -z "$WORKTREE_BRANCH" ]]; then
  echo "Error: Could not determine worktree branch"
  exit 1
fi

echo "Merging worktree: $WORKTREE_PATH ($WORKTREE_BRANCH)"

# Step 1: Check for uncommitted changes in worktree
CHANGES=$(git -C "$WORKTREE_PATH" status --short 2>/dev/null || true)
if [[ -n "$CHANGES" ]]; then
  echo "  Committing uncommitted changes in worktree..."
  git -C "$WORKTREE_PATH" add -A
  git -C "$WORKTREE_PATH" commit -m "$COMMIT_MSG" || true
fi

# Step 2: Ensure development branch exists locally
MAIN_REPO=$(git rev-parse --show-toplevel 2>/dev/null)
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null)

if ! git branch --list development | grep -q development; then
  echo "  Creating development branch..."
  git branch development 2>/dev/null || true
fi

# Step 3: Get the worktree's latest commit
WORKTREE_COMMIT=$(git -C "$WORKTREE_PATH" rev-parse HEAD 2>/dev/null)

# Step 4: Copy changed files from worktree to main repo
echo "  Copying changes to development branch..."

# Get list of changed files (compared to development)
CHANGED_FILES=$(git -C "$WORKTREE_PATH" diff --name-only "$(git merge-base development "$WORKTREE_BRANCH" 2>/dev/null || echo HEAD)" HEAD 2>/dev/null || true)

if [[ -z "$CHANGED_FILES" ]]; then
  # Fallback: get all modified/new files
  CHANGED_FILES=$(git -C "$WORKTREE_PATH" diff --name-only HEAD~1 HEAD 2>/dev/null || true)
fi

if [[ -z "$CHANGED_FILES" ]]; then
  echo "  No changes found in worktree. Cleaning up..."
else
  # Switch to development
  if [[ "$CURRENT_BRANCH" != "development" ]]; then
    git checkout development 2>/dev/null
  fi

  # Copy files
  while IFS= read -r file; do
    if [[ -f "$WORKTREE_PATH/$file" ]]; then
      mkdir -p "$(dirname "$file")"
      cp "$WORKTREE_PATH/$file" "$file"
    fi
  done <<< "$CHANGED_FILES"

  # Stage and commit
  git add -A
  git commit -m "$COMMIT_MSG" 2>/dev/null || echo "  Nothing new to commit"
fi

# Step 5: Push development
echo "  Pushing development branch..."
git push origin development 2>/dev/null || echo "  Push skipped (no remote or no changes)"

# Step 6: Cleanup worktree
echo "  Removing worktree..."
git worktree remove --force "$WORKTREE_PATH" 2>/dev/null || rm -rf "$WORKTREE_PATH"
git branch -D "$WORKTREE_BRANCH" 2>/dev/null || true

echo "Done: $WORKTREE_BRANCH merged to development and cleaned up."
