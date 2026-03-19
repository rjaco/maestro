#!/usr/bin/env bash
set -euo pipefail

# vault-manage.sh — Maestro credential vault management
# Uses age encryption (https://github.com/FiloSottile/age)
#
# Vault layout:
#   .maestro/vault.age          — encrypted vault (safe to commit)
#   .maestro/vault.yaml         — plaintext vault (NEVER commit — gitignored)
#   ~/.maestro/age-identity     — private key (NEVER commit)
#   ~/.maestro/age-identity.pub — public key (safe to share)

VAULT_DIR="${MAESTRO_DIR:-.maestro}"
VAULT_FILE="$VAULT_DIR/vault.age"
IDENTITY_FILE="$HOME/.maestro/age-identity"
IDENTITY_PUB="$HOME/.maestro/age-identity.pub"
EDITOR="${EDITOR:-nano}"

# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

info()  { printf '[vault] %s\n' "$1"; }
error() { printf '[vault] ERROR: %s\n' "$1" >&2; }
die()   { error "$1"; exit 1; }

# ---------------------------------------------------------------------------
# Dependency check
# ---------------------------------------------------------------------------

check_age() {
  if ! command -v age &>/dev/null; then
    die "age not installed. Install: brew install age (macOS) or apt install age (Linux)"
  fi
  if ! command -v age-keygen &>/dev/null; then
    die "age-keygen not found. It ships with age — reinstall if missing."
  fi
}

check_python() {
  if ! command -v python3 &>/dev/null; then
    die "python3 not found. Required for YAML parsing."
  fi
  if ! python3 -c "import yaml" 2>/dev/null; then
    die "python3 'yaml' module not found. Install: pip3 install pyyaml"
  fi
}

# ---------------------------------------------------------------------------
# Core operations
# ---------------------------------------------------------------------------

# Decrypt the vault to stdout. Caller is responsible for handling output safely.
decrypt_vault() {
  check_age
  [ -f "$VAULT_FILE" ] || die "No vault found at $VAULT_FILE. Run: $(basename "$0") init"
  [ -f "$IDENTITY_FILE" ] || die "No identity file at $IDENTITY_FILE. Run: $(basename "$0") init"
  age -d -i "$IDENTITY_FILE" "$VAULT_FILE"
}

# Encrypt stdin to the vault file using the public key.
encrypt_to_vault() {
  check_age
  [ -f "$IDENTITY_PUB" ] || die "No public key at $IDENTITY_PUB. Run: $(basename "$0") init"
  local pubkey
  pubkey=$(cat "$IDENTITY_PUB")
  age -r "$pubkey" -o "$VAULT_FILE" -
}

# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

cmd_usage() {
  cat <<'EOF'
Usage: vault-manage.sh <command> [args]

Commands:
  init                         Generate age identity and create empty vault
  edit                         Decrypt vault, open $EDITOR, re-encrypt on save
  get <service>                Extract credentials for a service (JSON output)
  set <service> <key> <value>  Add or update a single credential
  list                         List services and key names (no values shown)
  verify                       Check that the vault decrypts successfully

Environment:
  MAESTRO_DIR   Override the .maestro directory (default: .maestro)
  EDITOR        Editor used by the edit command (default: nano)

Security notes:
  - vault.age  is the encrypted vault — safe to commit
  - vault.yaml is the plaintext vault — NEVER commit (gitignored)
  - age-identity is the private key — NEVER commit or share
EOF
}

cmd_init() {
  check_age

  # Create directories
  mkdir -p "$HOME/.maestro"
  mkdir -p "$VAULT_DIR"

  # Generate identity if not present
  if [ -f "$IDENTITY_FILE" ]; then
    info "Identity already exists at $IDENTITY_FILE"
  else
    # age-keygen writes the public key to stdout and the private key to -o
    # We capture the public key from stdout and also save it to .pub
    age-keygen -o "$IDENTITY_FILE" 2>/dev/null
    chmod 600 "$IDENTITY_FILE"

    # Extract the public key from the identity file (comment line has it)
    grep '^# public key:' "$IDENTITY_FILE" | sed 's/# public key: //' > "$IDENTITY_PUB"

    info "Created age identity: $IDENTITY_FILE"
    info "Public key: $(cat "$IDENTITY_PUB")"
    info "IMPORTANT: Never commit or share $IDENTITY_FILE"
  fi

  # Create empty vault if not present
  if [ -f "$VAULT_FILE" ]; then
    info "Vault already exists at $VAULT_FILE"
  else
    printf 'secrets: {}\n' | encrypt_to_vault
    info "Created empty vault: $VAULT_FILE"
  fi

  # Add gitignore safety for plaintext vault
  local gitignore="$VAULT_DIR/../.gitignore"
  if [ -f "$gitignore" ]; then
    if ! grep -qF '.maestro/vault.yaml' "$gitignore" 2>/dev/null; then
      printf '\n# Maestro vault plaintext — NEVER commit\n.maestro/vault.yaml\n' >> "$gitignore"
      info "Added .maestro/vault.yaml to .gitignore"
    fi
  fi
}

cmd_edit() {
  check_age
  check_python

  # Decrypt to a temp file, open editor, re-encrypt, clean up
  local tmpfile
  tmpfile=$(mktemp --suffix=".vault.yaml")
  # Guarantee cleanup on exit, interrupt, or error
  trap 'rm -f "$tmpfile"' EXIT INT TERM

  decrypt_vault > "$tmpfile"
  chmod 600 "$tmpfile"

  info "Opening vault in $EDITOR (temp file: $tmpfile)"
  "$EDITOR" "$tmpfile"

  # Validate the edited YAML before re-encrypting
  if ! python3 -c "
import sys, yaml
with open('$tmpfile') as f:
    data = yaml.safe_load(f)
if not isinstance(data, dict):
    sys.exit(1)
if 'secrets' not in data:
    sys.exit(1)
" 2>/dev/null; then
    die "Edited file is not valid YAML with a 'secrets' key. Vault not updated."
  fi

  encrypt_to_vault < "$tmpfile"
  info "Vault saved and re-encrypted."

  # Explicit cleanup (trap also fires on exit, belt-and-suspenders)
  rm -f "$tmpfile"
  trap - EXIT INT TERM
}

cmd_get() {
  local service="${1:?Service name required. Usage: $(basename "$0") get <service>}"
  check_age
  check_python

  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' EXIT INT TERM

  decrypt_vault > "$tmpfile"

  python3 - "$service" "$tmpfile" <<'PYEOF'
import sys, yaml, json

service = sys.argv[1]
vault_file = sys.argv[2]

with open(vault_file) as f:
    data = yaml.safe_load(f)

secrets = (data or {}).get('secrets', {}).get(service)
if not secrets:
    sys.stderr.write(f"[vault] No credentials found for service: {service}\n")
    sys.exit(1)

json.dump(secrets, sys.stdout, indent=2)
PYEOF

  rm -f "$tmpfile"
  trap - EXIT INT TERM
}

cmd_set() {
  local service="${1:?Service name required. Usage: $(basename "$0") set <service> <key> <value>}"
  local key="${2:?Key name required.}"
  local value="${3:?Value required.}"
  check_age
  check_python

  local tmpfile newfile
  tmpfile=$(mktemp)
  newfile=$(mktemp)
  trap 'rm -f "$tmpfile" "$newfile"' EXIT INT TERM

  decrypt_vault > "$tmpfile"

  python3 - "$service" "$key" "$value" "$tmpfile" "$newfile" <<'PYEOF'
import sys, yaml

service  = sys.argv[1]
key      = sys.argv[2]
value    = sys.argv[3]
infile   = sys.argv[4]
outfile  = sys.argv[5]

with open(infile) as f:
    data = yaml.safe_load(f) or {}

if 'secrets' not in data or data['secrets'] is None:
    data['secrets'] = {}

if service not in data['secrets'] or data['secrets'][service] is None:
    data['secrets'][service] = {}

data['secrets'][service][key] = value

with open(outfile, 'w') as f:
    yaml.dump(data, f, default_flow_style=False, allow_unicode=True)

print(f"[vault] Set {service}.{key}")
PYEOF

  encrypt_to_vault < "$newfile"

  rm -f "$tmpfile" "$newfile"
  trap - EXIT INT TERM
}

cmd_list() {
  check_age
  check_python

  local tmpfile
  tmpfile=$(mktemp)
  trap 'rm -f "$tmpfile"' EXIT INT TERM

  decrypt_vault > "$tmpfile"

  python3 - "$tmpfile" <<'PYEOF'
import sys, yaml

with open(sys.argv[1]) as f:
    data = yaml.safe_load(f) or {}

services = (data or {}).get('secrets') or {}
if not services:
    print("  (no services in vault)")
else:
    for svc, creds in sorted(services.items()):
        keys = sorted(creds.keys()) if isinstance(creds, dict) else []
        print(f"  {svc}: {len(keys)} credential(s) — {', '.join(keys)}")
PYEOF

  rm -f "$tmpfile"
  trap - EXIT INT TERM
}

cmd_verify() {
  if decrypt_vault > /dev/null 2>&1; then
    info "OK: Vault decrypts successfully"
  else
    die "Cannot decrypt vault. Check that $IDENTITY_FILE matches the key used to encrypt $VAULT_FILE"
  fi
}

# ---------------------------------------------------------------------------
# Dispatch
# ---------------------------------------------------------------------------

case "${1:-}" in
  init)    cmd_init ;;
  edit)    cmd_edit ;;
  get)     cmd_get "${2:-}" ;;
  set)     cmd_set "${2:-}" "${3:-}" "${4:-}" ;;
  list)    cmd_list ;;
  verify)  cmd_verify ;;
  help|-h|--help) cmd_usage ;;
  "")      cmd_usage; exit 1 ;;
  *)       error "Unknown command: $1"; cmd_usage; exit 1 ;;
esac
