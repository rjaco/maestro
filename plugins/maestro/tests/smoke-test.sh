#!/usr/bin/env bash
# Maestro Smoke Test Suite
# Validates plugin structure, frontmatter, hooks, and mirror sync.
# Exit 0: all pass. Exit 1: failures found.
#
# Usage:
#   ./tests/smoke-test.sh [/path/to/maestro]
#
# If no path is given, uses the directory containing this script's parent.

set -euo pipefail

# ---------------------------------------------------------------------------
# Setup
# ---------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="${1:-"$(dirname "$SCRIPT_DIR")"}"

PASS=0
FAIL=0
FAILURES=()

pass() {
    local label="$1"
    local detail="$2"
    printf "[PASS] %s\n" "$label: $detail"
    PASS=$((PASS + 1))
}

fail() {
    local label="$1"
    local detail="$2"
    shift 2
    printf "[FAIL] %s\n" "$label: $detail"
    FAIL=$((FAIL + 1))
    # Remaining args are individual failure lines
    for line in "$@"; do
        printf "  FAIL: %s\n" "$line"
        FAILURES+=("$line")
    done
}

# ---------------------------------------------------------------------------
# 1. Hook scripts exist and are executable
# ---------------------------------------------------------------------------

check_hooks() {
    local hooks_json="$ROOT/hooks/hooks.json"
    local total=0
    local ok=0
    local errs=()

    if [ ! -f "$hooks_json" ]; then
        fail "hooks" "hooks/hooks.json not found"
        return
    fi

    # Extract command values from hooks.json using python3
    while IFS= read -r raw_cmd; do
        [ -z "$raw_cmd" ] && continue
        total=$((total + 1))
        # Resolve ${CLAUDE_PLUGIN_ROOT} to ROOT
        local cmd="${raw_cmd/\$\{CLAUDE_PLUGIN_ROOT\}/$ROOT}"
        if [ -f "$cmd" ] && [ -x "$cmd" ]; then
            ok=$((ok + 1))
        elif [ ! -f "$cmd" ]; then
            errs+=("$raw_cmd — file not found")
        else
            errs+=("$raw_cmd — not executable (+x missing)")
        fi
    done < <(python3 -c "
import json, sys
data = json.load(open('$hooks_json'))
hooks_section = data.get('hooks', {})
for event_hooks in hooks_section.values():
    for group in event_hooks:
        for h in group.get('hooks', []):
            if h.get('type') == 'command':
                print(h['command'])
")

    if [ ${#errs[@]} -eq 0 ]; then
        pass "hooks" "$ok/$total scripts exist and executable"
    else
        fail "hooks" "$ok/$total scripts exist and executable" "${errs[@]}"
    fi
}

# ---------------------------------------------------------------------------
# 2. All skills have valid SKILL.md
# ---------------------------------------------------------------------------

check_skills() {
    local skills_dir="$ROOT/skills"
    local total=0
    local ok=0
    local errs=()

    if [ ! -d "$skills_dir" ]; then
        fail "skills" "skills/ directory not found"
        return
    fi

    for skill_dir in "$skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill
        skill="$(basename "$skill_dir")"
        total=$((total + 1))
        local skill_md="$skill_dir/SKILL.md"

        if [ ! -f "$skill_md" ]; then
            errs+=("skills/$skill — SKILL.md missing")
            continue
        fi

        local first_line
        first_line="$(head -1 "$skill_md")"
        if [ "$first_line" != "---" ]; then
            errs+=("skills/$skill/SKILL.md — missing frontmatter (no leading ---)")
            continue
        fi

        local has_name has_desc
        has_name="$(grep -c "^name:" "$skill_md" || true)"
        has_desc="$(grep -c "^description:" "$skill_md" || true)"

        if [ "$has_name" -eq 0 ] && [ "$has_desc" -eq 0 ]; then
            errs+=("skills/$skill/SKILL.md — missing name: and description: fields")
        elif [ "$has_name" -eq 0 ]; then
            errs+=("skills/$skill/SKILL.md — missing name: field")
        elif [ "$has_desc" -eq 0 ]; then
            errs+=("skills/$skill/SKILL.md — missing description: field")
        else
            ok=$((ok + 1))
        fi
    done

    if [ ${#errs[@]} -eq 0 ]; then
        pass "skills" "$ok/$total have valid SKILL.md"
    else
        fail "skills" "$ok/$total have valid SKILL.md" "${errs[@]}"
    fi
}

# ---------------------------------------------------------------------------
# 3. Mirror sync — skills/ vs plugins/maestro/skills/
# ---------------------------------------------------------------------------

check_mirror() {
    local skills_dir="$ROOT/skills"
    local mirror_dir="$ROOT/plugins/maestro/skills"
    local total=0
    local ok=0
    local errs=()

    if [ ! -d "$skills_dir" ]; then
        fail "mirror" "skills/ directory not found"
        return
    fi

    if [ ! -d "$mirror_dir" ]; then
        fail "mirror" "plugins/maestro/skills/ directory not found"
        return
    fi

    for skill_dir in "$skills_dir"/*/; do
        [ -d "$skill_dir" ] || continue
        local skill
        skill="$(basename "$skill_dir")"
        total=$((total + 1))
        local mirror_md="$mirror_dir/$skill/SKILL.md"
        if [ -f "$mirror_md" ]; then
            ok=$((ok + 1))
        else
            errs+=("skills/$skill/SKILL.md — mirror not found at plugins/maestro/skills/$skill/SKILL.md")
        fi
    done

    if [ ${#errs[@]} -eq 0 ]; then
        pass "mirror" "$ok/$total synced"
    else
        fail "mirror" "$ok/$total synced" "${errs[@]}"
    fi
}

# ---------------------------------------------------------------------------
# 4. Commands have valid frontmatter
# ---------------------------------------------------------------------------

check_commands() {
    local commands_dir="$ROOT/commands"
    local total=0
    local ok=0
    local errs=()

    if [ ! -d "$commands_dir" ]; then
        fail "commands" "commands/ directory not found"
        return
    fi

    for cmd_file in "$commands_dir"/*.md; do
        [ -f "$cmd_file" ] || continue
        local name
        name="$(basename "$cmd_file")"
        total=$((total + 1))

        local first_line
        first_line="$(head -1 "$cmd_file")"
        if [ "$first_line" != "---" ]; then
            errs+=("commands/$name — missing frontmatter (no leading ---)")
            continue
        fi

        local has_name
        has_name="$(grep -c "^name:" "$cmd_file" || true)"
        if [ "$has_name" -eq 0 ]; then
            errs+=("commands/$name — missing name: field")
        else
            ok=$((ok + 1))
        fi
    done

    if [ ${#errs[@]} -eq 0 ]; then
        pass "commands" "$ok/$total have valid frontmatter"
    else
        fail "commands" "$ok/$total have valid frontmatter" "${errs[@]}"
    fi
}

# ---------------------------------------------------------------------------
# 5. Agent definitions valid
# ---------------------------------------------------------------------------

check_agents() {
    local agents_dir="$ROOT/agents"
    local total=0
    local ok=0
    local errs=()

    if [ ! -d "$agents_dir" ]; then
        fail "agents" "agents/ directory not found"
        return
    fi

    for agent_file in "$agents_dir"/*.md; do
        [ -f "$agent_file" ] || continue
        local name
        name="$(basename "$agent_file")"
        total=$((total + 1))

        local first_line
        first_line="$(head -1 "$agent_file")"
        if [ "$first_line" != "---" ]; then
            errs+=("agents/$name — missing frontmatter (no leading ---)")
            continue
        fi

        local has_name has_desc has_model
        has_name="$(grep -c "^name:" "$agent_file" || true)"
        has_desc="$(grep -c "^description:" "$agent_file" || true)"
        has_model="$(grep -c "^model:" "$agent_file" || true)"

        local missing=()
        [ "$has_name" -eq 0 ]  && missing+=("name:")
        [ "$has_desc" -eq 0 ]  && missing+=("description:")
        [ "$has_model" -eq 0 ] && missing+=("model:")

        if [ ${#missing[@]} -eq 0 ]; then
            ok=$((ok + 1))
        else
            local fields
            fields="$(printf "%s, " "${missing[@]}")"
            fields="${fields%, }"
            errs+=("agents/$name — missing field(s): $fields")
        fi
    done

    if [ ${#errs[@]} -eq 0 ]; then
        pass "agents" "$ok/$total have valid frontmatter"
    else
        fail "agents" "$ok/$total have valid frontmatter" "${errs[@]}"
    fi
}

# ---------------------------------------------------------------------------
# 6. JSON files parse
# ---------------------------------------------------------------------------

check_json() {
    local files=(
        "hooks/hooks.json"
        ".claude-plugin/plugin.json"
        ".claude-plugin/marketplace.json"
    )
    local total=${#files[@]}
    local ok=0
    local errs=()

    for rel in "${files[@]}"; do
        local path="$ROOT/$rel"
        if [ ! -f "$path" ]; then
            errs+=("$rel — file not found")
            continue
        fi
        if python3 -c "import json; json.load(open('$path'))" 2>/dev/null; then
            ok=$((ok + 1))
        else
            errs+=("$rel — invalid JSON")
        fi
    done

    if [ ${#errs[@]} -eq 0 ]; then
        pass "json" "$ok/$total files parse"
    else
        fail "json" "$ok/$total files parse" "${errs[@]}"
    fi
}

# ---------------------------------------------------------------------------
# 7. No broken symlinks
# ---------------------------------------------------------------------------

check_symlinks() {
    local broken=()

    while IFS= read -r link; do
        broken+=("$link")
    done < <(find "$ROOT" -maxdepth 4 -type l ! -exec test -e {} \; -print 2>/dev/null)

    local count=${#broken[@]}
    if [ "$count" -eq 0 ]; then
        pass "symlinks" "0 broken"
    else
        fail "symlinks" "$count broken" "${broken[@]}"
    fi
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

printf "Maestro Smoke Tests\n"
printf "====================\n"

check_hooks
check_skills
check_mirror
check_commands
check_agents
check_json
check_symlinks

total=$((PASS + FAIL))
printf "\n"
if [ "$FAIL" -eq 0 ]; then
    printf "Result: All %d/%d checks passed.\n" "$PASS" "$total"
    exit 0
else
    if [ "$FAIL" -eq 1 ]; then
        printf "Result: 1 FAIL. %d/%d checks passed.\n" "$PASS" "$total"
    else
        printf "Result: %d FAILs. %d/%d checks passed.\n" "$FAIL" "$PASS" "$total"
    fi
    exit 1
fi
