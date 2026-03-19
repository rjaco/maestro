#!/usr/bin/env bash
# Test suite for validate-hooks.sh
# Tests pass/fail/warn scenarios by creating temp fixtures.
# Exit 0: all tests passed. Exit 1: at least one test failed.
# Requires: jq

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VALIDATE_SCRIPT="${SCRIPT_DIR}/validate-hooks.sh"

# Dependency guard
if ! command -v jq &>/dev/null; then
  echo "SKIP: jq not found — install jq to run these tests"
  exit 0
fi

pass_count=0
fail_count=0

assert_exit() {
  local desc="$1"
  local expected="$2"
  shift 2
  local actual=0
  "$@" >/dev/null 2>&1 || actual=$?
  if [[ "$actual" -eq "$expected" ]]; then
    echo "[PASS] $desc"
    ((pass_count++))
  else
    echo "[FAIL] $desc (expected exit $expected, got $actual)"
    ((fail_count++))
  fi
}

assert_output_contains() {
  local desc="$1"
  local pattern="$2"
  shift 2
  local output actual=0
  output=$("$@" 2>&1) || actual=$?
  if echo "$output" | grep -qF "$pattern"; then
    echo "[PASS] $desc"
    ((pass_count++))
  else
    echo "[FAIL] $desc (pattern not found: '$pattern')"
    echo "  Output was: $output"
    ((fail_count++))
  fi
}

# ---------------------------------------------------------------------------
# Setup temp fixtures
# ---------------------------------------------------------------------------

TMPDIR_ROOT="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_ROOT"' EXIT

HOOKS_DIR="${TMPDIR_ROOT}/hooks"
mkdir -p "$HOOKS_DIR"

# Executable hook
cat > "${HOOKS_DIR}/good-hook.sh" <<'EOF'
#!/usr/bin/env bash
echo "good hook"
EOF
chmod +x "${HOOKS_DIR}/good-hook.sh"

# Non-executable hook (exists, no +x)
cat > "${HOOKS_DIR}/not-executable.sh" <<'EOF'
#!/usr/bin/env bash
echo "not executable"
EOF

# hooks.json: all pass
cat > "${TMPDIR_ROOT}/hooks-all-pass.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/good-hook.sh"
          }
        ]
      }
    ]
  }
}
EOF

# hooks.json: one missing file
cat > "${TMPDIR_ROOT}/hooks-missing.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/good-hook.sh"
          },
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/missing-hook.sh"
          }
        ]
      }
    ]
  }
}
EOF

# hooks.json: not executable (WARN only)
cat > "${TMPDIR_ROOT}/hooks-not-exec.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/not-executable.sh"
          }
        ]
      }
    ]
  }
}
EOF

# hooks.json: mixed event names (good + not-exec)
cat > "${TMPDIR_ROOT}/hooks-mixed.json" <<EOF
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/good-hook.sh"
          }
        ]
      }
    ],
    "Notification": [
      {
        "hooks": [
          {
            "type": "command",
            "command": "\${CLAUDE_PLUGIN_ROOT}/hooks/not-executable.sh"
          }
        ]
      }
    ]
  }
}
EOF

# ---------------------------------------------------------------------------
# Run tests
# ---------------------------------------------------------------------------

echo "Maestro Hook Validator — Test Suite"
echo "====================================="

# AC1: all valid hooks → exit 0
assert_exit \
  "All valid hooks → exit 0" 0 \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-all-pass.json"

# AC2: missing hook file → exit 1
assert_exit \
  "Missing hook file → exit 1" 1 \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-missing.json"

# AC3: not-executable hook → exit 0 (WARN is non-fatal)
assert_exit \
  "Not-executable hook → exit 0 (warn only)" 0 \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-not-exec.json"

# AC4: output shows [PASS] for good hook
assert_output_contains \
  "Output shows [PASS] for good hook" "[PASS]" \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-all-pass.json"

# AC5: output shows [FAIL] for missing hook
assert_output_contains \
  "Output shows [FAIL] for missing hook" "[FAIL]" \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-missing.json"

# AC6: output shows [WARN] for not-executable hook
assert_output_contains \
  "Output shows [WARN] for not-executable hook" "[WARN]" \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-not-exec.json"

# AC7: output contains "Result:" summary line
assert_output_contains \
  "Output shows Result: summary line" "Result:" \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-all-pass.json"

# AC8: output shows header
assert_output_contains \
  "Output shows Maestro Hook Validator header" "Maestro Hook Validator" \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "${TMPDIR_ROOT}/hooks-all-pass.json"

# AC9: missing hooks.json argument → exit 1
assert_exit \
  "Missing hooks.json file → exit 1" 1 \
  env CLAUDE_PLUGIN_ROOT="$TMPDIR_ROOT" "$VALIDATE_SCRIPT" "/nonexistent/path/hooks.json"

echo ""
echo "Results: ${pass_count} passed, ${fail_count} failed"
[[ "$fail_count" -eq 0 ]] && exit 0 || exit 1
