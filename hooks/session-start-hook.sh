#!/usr/bin/env bash
<<<<<<< HEAD
set -euo pipefail

# Maestro SessionStart Hook
# Detects Maestro state and injects context at session start.
# After context compaction in an Opus session, injects full orchestration context
# so the autonomous loop can resume without interruption.
=======
# Maestro Session Start Hook
# Fires when a new Claude session starts in a Maestro project.
# If a DNA file exists, outputs context to prime the session.
# If no DNA file, exits silently.

set -euo pipefail

DNA_FILE=".maestro/dna.md"
STATE_FILE=".maestro/state.local.md"
>>>>>>> worktree-agent-ab0f24c1

# Read hook input from stdin
HOOK_INPUT=""
if [[ ! -t 0 ]]; then
<<<<<<< HEAD
  HOOK_INPUT=$(cat 2>/dev/null || true)
fi

# Get working directory
CWD=""
if [[ -n "$HOOK_INPUT" ]]; then
  CWD=$(printf '%s' "$HOOK_INPUT" | jq -r '.cwd // empty' 2>/dev/null || true)
fi
CWD="${CWD:-$(pwd)}"

DNA_FILE="$CWD/.maestro/dna.md"
STATE_FILE="$CWD/.maestro/state.local.md"

# No Maestro initialization? Silent exit.
=======
  HOOK_INPUT=$(cat)
fi

# No DNA file? Exit silently.
>>>>>>> worktree-agent-ab0f24c1
if [[ ! -f "$DNA_FILE" ]]; then
  exit 0
fi

<<<<<<< HEAD
# Build context message
MSG=""

# Check for active session
if [[ -f "$STATE_FILE" ]]; then
  FRONTMATTER=$(sed -n '/^---$/,/^---$/{ /^---$/d; p; }' "$STATE_FILE" 2>/dev/null || true)

  yaml_val() {
    local key="$1"
    local line
    line=$(printf '%s\n' "$FRONTMATTER" | grep -E "^${key}:" | head -1)
    [[ -z "$line" ]] && echo "" && return
    local val="${line#*:}"
    val="${val#"${val%%[![:space:]]*}"}"
    val="${val%\"}" ; val="${val#\"}"
    val="${val%\'}" ; val="${val#\'}"
    printf '%s' "$val"
  }

  ACTIVE=$(yaml_val "active")
  FEATURE=$(yaml_val "feature")
  PHASE=$(yaml_val "phase")
  LAYER=$(yaml_val "layer")
  CURRENT_STORY=$(yaml_val "current_story")
  TOTAL_STORIES=$(yaml_val "total_stories")
  CURRENT_MILESTONE=$(yaml_val "current_milestone")
  TOTAL_MILESTONES=$(yaml_val "total_milestones")
  OPUS_MODE=$(yaml_val "opus_mode")

  if [[ "$ACTIVE" == "true" ]]; then

    if [[ "$LAYER" == "opus" ]]; then
      # -------------------------------------------------------
      # Full Opus recovery context after compaction
      # -------------------------------------------------------
      MSG="[MAESTRO OPUS RECOVERY] Context compaction detected. Restoring Magnum Opus orchestration state."
      MSG="${MSG}

== CURRENT STATE ==
Feature:   ${FEATURE:-unknown}
Phase:     ${PHASE:-unknown}
Mode:      ${OPUS_MODE:-full_auto}
Milestone: ${CURRENT_MILESTONE:-?}/${TOTAL_MILESTONES:-?}
Story:     ${CURRENT_STORY:-?}/${TOTAL_STORIES:-?}"

      # -- North Star from vision.md --
      VISION_FILE="$CWD/.maestro/vision.md"
      if [[ -f "$VISION_FILE" ]]; then
        VISION_LINES=""
        in_frontmatter=1
        count=0
        while IFS= read -r vline || [[ -n "$vline" ]]; do
          # Skip frontmatter block (between first and second ---)
          if [[ $in_frontmatter -eq 1 ]]; then
            if [[ "$vline" == "---" ]]; then
              in_frontmatter=2
            fi
            continue
          fi
          if [[ $in_frontmatter -eq 2 ]]; then
            if [[ "$vline" == "---" ]]; then
              in_frontmatter=0
            fi
            continue
          fi
          # Skip blank lines
          [[ -z "${vline// }" ]] && continue
          if [[ $count -eq 0 ]]; then
            VISION_LINES="${vline}"
          else
            VISION_LINES="${VISION_LINES}
${vline}"
          fi
          count=$((count + 1))
          [[ $count -ge 5 ]] && break
        done < "$VISION_FILE"

        if [[ -n "$VISION_LINES" ]]; then
          MSG="${MSG}

== NORTH STAR (vision.md) ==
${VISION_LINES}"
        fi
      fi

      # -- Milestone scope --
      MILESTONE_DIR="$CWD/.maestro/milestones"
      if [[ -d "$MILESTONE_DIR" ]] && [[ -n "$CURRENT_MILESTONE" ]]; then
        MILESTONE_FILE=""
        # Find a file whose name starts with M${CURRENT_MILESTONE}
        for f in "$MILESTONE_DIR"/M"${CURRENT_MILESTONE}"-*.md "$MILESTONE_DIR"/M"${CURRENT_MILESTONE}".md; do
          if [[ -f "$f" ]]; then
            MILESTONE_FILE="$f"
            break
          fi
        done

        if [[ -n "$MILESTONE_FILE" ]]; then
          MILESTONE_SCOPE=""
          past_title=0
          scope_count=0
          while IFS= read -r mline || [[ -n "$mline" ]]; do
            # Find the title line (first # heading)
            if [[ $past_title -eq 0 ]]; then
              if [[ "$mline" =~ ^#[[:space:]] ]]; then
                past_title=1
              fi
              continue
            fi
            # Skip blank lines after title
            [[ -z "${mline// }" ]] && continue
            if [[ $scope_count -eq 0 ]]; then
              MILESTONE_SCOPE="${mline}"
            else
              MILESTONE_SCOPE="${MILESTONE_SCOPE}
${mline}"
            fi
            scope_count=$((scope_count + 1))
            [[ $scope_count -ge 3 ]] && break
          done < "$MILESTONE_FILE"

          if [[ -n "$MILESTONE_SCOPE" ]]; then
            MILESTONE_NAME=$(basename "$MILESTONE_FILE" .md)
            MSG="${MSG}

== CURRENT MILESTONE SCOPE (${MILESTONE_NAME}) ==
${MILESTONE_SCOPE}"
          fi
        fi
      fi

      # -- Story list for current milestone --
      STORIES_DIR="$CWD/.maestro/stories"
      if [[ -d "$STORIES_DIR" ]] && [[ -n "$CURRENT_MILESTONE" ]]; then
        STORY_LIST=""
        while IFS= read -r -d '' sfile; do
          sname=$(basename "$sfile")
          # Extract status from frontmatter if present
          sstatus=$(grep -m1 "^[Ss]tatus:" "$sfile" 2>/dev/null | head -1 || true)
          sstatus="${sstatus#*:}"
          sstatus="${sstatus#"${sstatus%%[![:space:]]*}"}"
          sstatus="${sstatus%\"}" ; sstatus="${sstatus#\"}"
          if [[ -z "$sstatus" ]]; then
            sstatus="pending"
          fi
          entry="  - ${sname} [${sstatus}]"
          if [[ -z "$STORY_LIST" ]]; then
            STORY_LIST="${entry}"
          else
            STORY_LIST="${STORY_LIST}
${entry}"
          fi
        done < <(find "$STORIES_DIR" -maxdepth 1 -name "M${CURRENT_MILESTONE}-*.md" -print0 2>/dev/null | sort -z)

        if [[ -n "$STORY_LIST" ]]; then
          MSG="${MSG}

== STORIES FOR MILESTONE ${CURRENT_MILESTONE} ==
${STORY_LIST}"
        fi
      fi

      # -- Explicit continuation directive --
      MSG="${MSG}

== DIRECTIVE ==
CONTINUE the Magnum Opus autonomous loop. Execute the next story by dispatching an Agent with isolation: worktree. Do NOT stop. Do NOT write plan documents."

    else
      # Non-opus active session
      MSG="Maestro has an ACTIVE session."
      MSG="${MSG} Feature: ${FEATURE:-unknown}."
      MSG="${MSG} Phase: ${PHASE:-unknown}."

      if [[ -n "$TOTAL_STORIES" ]] && [[ "$TOTAL_STORIES" != "0" ]]; then
        MSG="${MSG} Story: ${CURRENT_STORY:-?}/${TOTAL_STORIES}."
      fi

      MSG="${MSG} Use /maestro status for details."
    fi

  elif [[ "$PHASE" == "completed" ]]; then
    MSG="Maestro: last session completed (${FEATURE:-unknown}). Run /maestro for a new task."
  elif [[ "$PHASE" == "paused" ]]; then
    MSG="Maestro: PAUSED session (${FEATURE:-unknown})."
    if [[ "$LAYER" == "opus" ]]; then
      MSG="${MSG} Resume with /maestro opus --resume."
    else
      MSG="${MSG} Resume with /maestro status."
    fi
  fi
else
  # DNA file exists but state file is missing — Maestro is installed but not initialized for this project
  echo "[MAESTRO] State file not found at .maestro/state.local.md" >&2
  echo "  -> Cause: Maestro is installed but has not been initialized in this project" >&2
  echo "  -> Fix: Run /maestro init to set up Maestro for this project" >&2
  MSG="Maestro is installed but not yet initialized. Run /maestro init to begin."
fi

# Only output if we have something to say
if [[ -n "$MSG" ]]; then
  # SessionStart hooks output is injected as a system message
  printf '%s' "$MSG"
=======
# Extract CWD from hook input if provided
CWD=""
if [[ -n "$HOOK_INPUT" ]]; then
  CWD=$(printf '%s' "$HOOK_INPUT" | grep -o '"cwd":"[^"]*"' | sed 's/"cwd":"//;s/"//' 2>/dev/null || true)
fi

# Build context message from DNA file
DNA_CONTENT=$(head -50 "$DNA_FILE" 2>/dev/null || true)

# Check for active state
ACTIVE_SESSION=""
if [[ -f "$STATE_FILE" ]]; then
  ACTIVE_SESSION=$(grep '^active:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/active:[[:space:]]*//' | xargs 2>/dev/null || true)
fi

# Output context message to stdout
printf 'Maestro project context loaded from %s\n' "$DNA_FILE"
if [[ -n "$ACTIVE_SESSION" && "$ACTIVE_SESSION" == "true" ]]; then
  FEATURE=$(grep '^feature:' "$STATE_FILE" 2>/dev/null | head -1 | sed 's/feature:[[:space:]]*//' | sed 's/^"\(.*\)"$/\1/' | xargs 2>/dev/null || true)
  printf 'Active Maestro session detected. Feature: %s\n' "${FEATURE:-unknown}"
>>>>>>> worktree-agent-ab0f24c1
fi

exit 0
