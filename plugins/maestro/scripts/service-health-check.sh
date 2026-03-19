#!/usr/bin/env bash
set -euo pipefail

# Service health check script
# Reads .maestro/services.yaml and runs health checks for each service
# Usage: service-health-check.sh [service-name]
# If no service name given, checks all services
#
# Output format (one line per service, machine-parseable):
#   service|auth|status|details
#
# Exit codes:
#   0 — all checked services are connected
#   1 — one or more services failed or errored

MAESTRO_DIR="${MAESTRO_DIR:-.maestro}"
SERVICES_FILE="$MAESTRO_DIR/services.yaml"

# --- Colors (only when writing to a terminal) ---

if [[ -t 1 ]]; then
  BOLD='\033[1m'
  GREEN='\033[0;32m'
  RED='\033[0;31m'
  YELLOW='\033[0;33m'
  DIM='\033[2m'
  RESET='\033[0m'
else
  BOLD='' GREEN='' RED='' YELLOW='' DIM='' RESET=''
fi

# --- Helpers ---

die()  { printf '%s\n' "ERROR: $*" >&2; exit 1; }
warn() { printf '%s\n' "WARN: $*" >&2; }

require_python3() {
  if ! command -v python3 >/dev/null 2>&1; then
    die "python3 is required but not found in PATH"
  fi
}

require_services_file() {
  if [[ ! -f "$SERVICES_FILE" ]]; then
    die "No services file found at $SERVICES_FILE. Run /maestro connect <service> to register a service."
  fi
}

# mask_value <string>
# Replace any value that looks like a credential with ***.
mask_value() {
  local val="$1"
  # If the string is longer than 6 chars and matches credential keywords, mask it
  if [[ ${#val} -gt 6 ]] && printf '%s' "$val" | grep -qiE '(key|token|secret|password|pass|credential|auth)'; then
    printf '***'
  else
    printf '%s' "$val"
  fi
}

# run_health_check <command> <timeout_seconds>
# Runs the health check command.
# Sets global HC_EXIT, HC_STDOUT, HC_STDERR.
HC_EXIT=0
HC_STDOUT=""
HC_STDERR=""

run_health_check() {
  local cmd="$1"
  local timeout_secs="${2:-30}"
  HC_EXIT=0

  local tmp_out tmp_err
  tmp_out=$(mktemp)
  tmp_err=$(mktemp)

  # Run with a timeout to prevent hanging
  if command -v timeout >/dev/null 2>&1; then
    timeout "$timeout_secs" bash -c "$cmd" > "$tmp_out" 2> "$tmp_err" || HC_EXIT=$?
  else
    bash -c "$cmd" > "$tmp_out" 2> "$tmp_err" || HC_EXIT=$?
  fi

  HC_STDOUT=$(cat "$tmp_out")
  HC_STDERR=$(cat "$tmp_err")
  rm -f "$tmp_out" "$tmp_err"
}

# update_service_status <service> <status> <details>
# Writes status, last_checked, and details back into services.yaml via python3.
update_service_status() {
  local service="$1"
  local status="$2"
  local details="$3"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  python3 - "$SERVICES_FILE" "$service" "$status" "$details" "$timestamp" << 'PYEOF'
import sys

try:
    import yaml
except ImportError:
    # Minimal fallback: skip writing if PyYAML unavailable
    sys.exit(0)

filepath   = sys.argv[1]
svc_name   = sys.argv[2]
new_status = sys.argv[3]
new_detail = sys.argv[4]
timestamp  = sys.argv[5]

with open(filepath, 'r') as f:
    data = yaml.safe_load(f) or {}

services = data.get('services') or {}
if svc_name not in services:
    sys.exit(0)

services[svc_name]['status']       = new_status
services[svc_name]['last_checked'] = timestamp
services[svc_name]['details']      = new_detail

with open(filepath, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True, sort_keys=False)
PYEOF
}

# --- Single service check ---

# check_service <service_name> <auth_method> <env_vars_newline_list> <mcp_prefix> <health_check_cmd>
# Prints one machine-parseable line: service|auth|status|details
check_service() {
  local service="$1"
  local auth="$2"
  local env_vars="$3"
  local mcp_prefix="$4"
  local health_cmd="$5"

  local status="unknown"
  local details=""

  # ---- Credential check ----

  case "$auth" in
    env)
      local varname missing_names=""
      while IFS= read -r varname; do
        [[ -z "$varname" ]] && continue
        if ! printenv "$varname" > /dev/null 2>&1; then
          if [[ -z "$missing_names" ]]; then
            missing_names="$varname"
          else
            missing_names="$missing_names $varname"
          fi
        fi
      done < <(printf '%s\n' "$env_vars")

      if [[ -n "$missing_names" ]]; then
        status="error"
        details="Missing credentials: $missing_names"
        printf '%s|%s|%s|%s\n' "$service" "$auth" "$status" "$details"
        update_service_status "$service" "$status" "$details"
        return 0
      fi
      ;;

    vault)
      local vault_script="scripts/vault-manage.sh"
      if [[ ! -x "$vault_script" ]]; then
        status="error"
        details="scripts/vault-manage.sh not found or not executable"
        printf '%s|%s|%s|%s\n' "$service" "$auth" "$status" "$details"
        update_service_status "$service" "$status" "$details"
        return 0
      fi
      local vault_out vault_exit=0
      vault_out=$("$vault_script" verify "$service" 2>&1) || vault_exit=$?
      if [[ "$vault_exit" -ne 0 ]]; then
        status="error"
        local vault_first_line
        vault_first_line=$(printf '%s\n' "$vault_out" | head -1 || true)
        details="vault verify failed: $vault_first_line"
        printf '%s|%s|%s|%s\n' "$service" "$auth" "$status" "$details"
        update_service_status "$service" "$status" "$details"
        return 0
      fi
      ;;

    mcp)
      # MCP availability cannot be checked from a shell script — always treated as
      # credential-present here. The AI-driven health check (SKILL.md) uses ToolSearch.
      : # fall through to health_check
      ;;

    none|"")
      : # No credential check needed
      ;;

    *)
      warn "Unknown auth_method '$auth' for service '$service'. Skipping credential check."
      ;;
  esac

  # ---- Health check ----

  if [[ -z "$health_cmd" ]]; then
    status="disconnected"
    details="no health check defined"
    printf '%s|%s|%s|%s\n' "$service" "$auth" "$status" "$details"
    update_service_status "$service" "$status" "$details"
    return 0
  fi

  run_health_check "$health_cmd" 30

  if [[ "$HC_EXIT" -eq 0 ]]; then
    status="connected"
    # Use first non-empty stdout line as details, mask potential credential strings
    local first_line=""
    first_line=$(printf '%s\n' "$HC_STDOUT" | grep -v '^[[:space:]]*$' | head -1 || true)
    details=$(mask_value "$first_line")
  elif [[ "$HC_EXIT" -eq 124 ]]; then
    status="error"
    details="health check timed out after 30s"
  else
    status="error"
    # Prefer stderr for error details, fall back to stdout
    local err_line=""
    err_line=$(printf '%s\n' "$HC_STDERR" | grep -v '^[[:space:]]*$' | head -1 || true)
    if [[ -z "$err_line" ]]; then
      err_line=$(printf '%s\n' "$HC_STDOUT" | grep -v '^[[:space:]]*$' | head -1 || true)
    fi
    details=$(mask_value "$err_line")
    if [[ -z "$details" ]]; then
      details="exit code $HC_EXIT"
    fi
  fi

  printf '%s|%s|%s|%s\n' "$service" "$auth" "$status" "$details"
  update_service_status "$service" "$status" "$details"
}

# --- Parse services.yaml ---

# Returns lines of: service\x1fauth\x1fenv_vars_newline\x1fmcp_prefix\x1fhealth_cmd
parse_services() {
  python3 - "$SERVICES_FILE" << 'PYEOF'
import sys

try:
    import yaml
except ImportError:
    print("ERROR: python3-yaml (PyYAML) is required. Install with: pip3 install pyyaml", file=sys.stderr)
    sys.exit(1)

with open(sys.argv[1], 'r') as f:
    data = yaml.safe_load(f) or {}

services = data.get('services') or {}

for name, cfg in services.items():
    if not isinstance(cfg, dict):
        continue
    auth        = cfg.get('auth_method', 'none') or 'none'
    env_vars    = '\n'.join(cfg.get('env_vars', []) or [])
    mcp_prefix  = cfg.get('mcp_prefix', '') or ''
    health_cmd  = cfg.get('health_check', '') or ''
    # Delimit fields with ASCII unit separator (0x1F) to avoid pipe conflicts in commands
    print('\x1f'.join([name, auth, env_vars, mcp_prefix, health_cmd]))
PYEOF
}

# safe_increment <varname>
# Increment a counter variable without triggering set -e on zero-value arithmetic.
safe_increment() {
  local -n _ref="$1"
  _ref=$(( _ref + 1 ))
}

# max_of <a> <b> — prints the larger integer
max_of() {
  if [[ "$1" -ge "$2" ]]; then printf '%d' "$1"; else printf '%d' "$2"; fi
}

# --- Main ---

main() {
  require_python3
  require_services_file

  local target_service="${1:-}"

  # Collect results into arrays for summary table
  local col_service=() col_auth=() col_status=() col_details=()
  local connected=0 errors=0 disconnected=0 any_failure=0 row_count=0

  while IFS=$'\x1f' read -r svc_name auth env_vars mcp_prefix health_cmd; do
    [[ -z "$svc_name" ]] && continue

    # If a specific service was requested, skip others
    if [[ -n "$target_service" && "$svc_name" != "$target_service" ]]; then
      continue
    fi

    local result=""
    result=$(check_service "$svc_name" "$auth" "$env_vars" "$mcp_prefix" "$health_cmd")

    # Parse result line: service|auth|status|details
    local r_svc="" r_auth="" r_status="" r_details=""
    IFS='|' read -r r_svc r_auth r_status r_details <<< "$result"

    col_service+=("$r_svc")
    col_auth+=("$r_auth")
    col_status+=("$r_status")
    col_details+=("$r_details")
    safe_increment row_count

    case "$r_status" in
      connected)    safe_increment connected ;;
      error)        safe_increment errors; any_failure=1 ;;
      disconnected) safe_increment disconnected ;;
    esac

  done < <(parse_services)

  # Check if we found the requested service
  if [[ -n "$target_service" && "$row_count" -eq 0 ]]; then
    die "Service '$target_service' not found in $SERVICES_FILE"
  fi

  # --- Display summary table ---

  # Calculate column widths (start from header lengths as minimums)
  local w_svc=14 w_auth=8 w_status=13 w_details=20
  local i
  for (( i=0; i<row_count; i++ )); do
    w_svc=$(    max_of "$w_svc"    "${#col_service[$i]}")
    w_auth=$(   max_of "$w_auth"   "${#col_auth[$i]}")
    w_status=$( max_of "$w_status" "${#col_status[$i]}")
    w_details=$(max_of "$w_details" "${#col_details[$i]}")
  done

  local sep_width
  sep_width=$(( w_svc + w_auth + w_status + w_details + 9 ))
  local sep_line
  sep_line=$(python3 -c "print('─' * $sep_width)")
  local dbl_line
  dbl_line=$(python3 -c "print('═' * $sep_width)")

  printf '\n'
  printf '%bService Health Report%b\n' "$BOLD" "$RESET"
  printf '%s\n' "$dbl_line"
  printf "%-${w_svc}s  %-${w_auth}s  %-${w_status}s  %s\n" "Service" "Auth" "Status" "Details"
  printf '%s\n' "$sep_line"

  for (( i=0; i<row_count; i++ )); do
    local status_clr=""
    case "${col_status[$i]}" in
      connected)    status_clr="$GREEN"  ;;
      error)        status_clr="$RED"    ;;
      disconnected) status_clr="$DIM"    ;;
    esac
    printf "%-${w_svc}s  %-${w_auth}s  %b%-${w_status}s%b  %s\n" \
      "${col_service[$i]}" \
      "${col_auth[$i]}" \
      "$status_clr" "${col_status[$i]}" "$RESET" \
      "${col_details[$i]}"
  done

  printf '%s\n' "$sep_line"
  printf '%bConnected: %d%b  |  %bError: %d%b  |  %bDisconnected: %d%b\n' \
    "$GREEN" "$connected"    "$RESET" \
    "$RED"   "$errors"       "$RESET" \
    "$DIM"   "$disconnected" "$RESET"
  printf '\n'

  return "$any_failure"
}

main "${1:-}"
