#!/usr/bin/env bash
set -euo pipefail

# SOPS Management Script for Homelab
#
# This script provides easy operations for SOPS-encrypted files in the homelab project.
# It handles proper encryption/decryption with the correct age key and regex patterns.
#
# Usage:
#   ./scripts/sops.sh [command] [file-path] [options]
#
# Commands:
#   decrypt <file>          - Decrypt a SOPS file to stdout
#   edit <file>             - Edit a SOPS file in place (opens editor)
#   encrypt <file>          - Encrypt a plain file to SOPS format
#   view <file>             - View decrypted content (same as decrypt)
#   validate <file>         - Validate that a SOPS file can be decrypted
#   reencrypt <file>        - Re-encrypt a SOPS file (useful after key rotation)
#   list-secrets [dir]      - List all .sops.yaml files in directory (default: current)
#   diff <file1> <file2>    - Show diff between two SOPS files (decrypted)
#   backup <file>           - Create timestamped backup of SOPS file
#   restore <backup-file>   - Restore from backup (removes .backup-TIMESTAMP suffix)
#   set-value <file> <key> <value> - Set a value in a SOPS file (key path like 'stringData.KEY')
#   set-value-from-file <file> <key> <value-file> - Set a multiline value from file content
#   delete-key <file> <key>        - Delete a key from a SOPS file
#   get-value <file> <key> - Get a value from a SOPS file

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGE_KEY="${SOPS_AGE_KEY:-}"
AGE_KEY_FILE="${SOPS_AGE_KEY_FILE:-}"
AGE_RECIPIENT="${AGE_RECIPIENT:-age1jjls7fqmd742cxu5pvuecvfg9hwxchpt2xxf5uuh72ypus9fzazqkzwk3y}"
ENCRYPTED_REGEX="^(data|stringData)$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO] $1${NC}" >&2
}

log_success() {
    echo -e "${GREEN}[OK] $1${NC}" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN] $1${NC}" >&2
}

log_error() {
    echo -e "${RED}[ERR] $1${NC}" >&2
}

# Encrypt a plaintext yaml file using explicit flags instead of creation rules.
# This avoids "no matching creation rules found" when working with temp files.
sops_encrypt_to_stdout() {
    local file="$1"
    SOPS_CONFIG=/dev/null sops --encrypt --age "$AGE_RECIPIENT" --encrypted-regex "$ENCRYPTED_REGEX" "$file"
}

# Check if AGE key is set
check_age_key() {
    # Prefer key file if available; fall back to inline key env var.
    if [[ -n "$AGE_KEY_FILE" ]]; then
        if [[ ! -f "$AGE_KEY_FILE" ]]; then
            log_error "SOPS_AGE_KEY_FILE is set but file not found: $AGE_KEY_FILE"
            exit 1
        fi
        export SOPS_AGE_KEY_FILE="$AGE_KEY_FILE"
        return 0
    fi

    # Common default location for age keys (sops will use this if SOPS_AGE_KEY_FILE is set).
    if [[ -z "$AGE_KEY" && -f "$HOME/.config/sops/age/keys.txt" ]]; then
        export SOPS_AGE_KEY_FILE="$HOME/.config/sops/age/keys.txt"
        return 0
    fi

    if [[ -z "$AGE_KEY" ]]; then
        log_error "No SOPS age key configured"
        echo "Set one of:" >&2
        echo "  export SOPS_AGE_KEY_FILE=\"$HOME/.config/sops/age/keys.txt\"" >&2
        echo "  export SOPS_AGE_KEY=\"AGE-SECRET-KEY-...\"" >&2
        exit 1
    fi
}

# Validate file exists
check_file() {
    local file="$1"
    if [[ ! -f "$file" ]]; then
        log_error "File not found: $file"
        exit 1
    fi
}

# Get absolute path relative to project root
get_rel_path() {
    local file="$1"
    if [[ "$file" = /* ]]; then
        echo "$file"
    else
        echo "$PROJECT_ROOT/$file"
    fi
}

# Commands
cmd_decrypt() {
    local file="$(get_rel_path "$1")"
    check_file "$file"
    check_age_key

    log_info "Decrypting $file"
    sops -d "$file"
}

cmd_edit() {
    local file="$(get_rel_path "$1")"
    check_file "$file"
    check_age_key

    log_info "Opening $file for editing"
    sops "$file"
}

cmd_encrypt() {
    local file="$(get_rel_path "$1")"
    check_file "$file"
    check_age_key

    # Check if file is already encrypted
    if grep -q "sops:" "$file" 2>/dev/null; then
        log_warning "File appears to already be encrypted"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 0
        fi
    fi

    log_info "Encrypting $file with age recipient $AGE_RECIPIENT"
    local temp_output
    temp_output=$(mktemp)
    trap "rm -f '$temp_output'" EXIT
    sops_encrypt_to_stdout "$file" > "$temp_output"
    mv "$temp_output" "$file"
    log_success "File encrypted successfully"
}

cmd_validate() {
    local file="$(get_rel_path "$1")"
    check_file "$file"
    check_age_key

    log_info "Validating $file"
    if sops -d "$file" >/dev/null 2>&1; then
        log_success "File is valid and can be decrypted"
    else
        log_error "File validation failed - cannot decrypt"
        exit 1
    fi
}

cmd_reencrypt() {
    local file="$(get_rel_path "$1")"
    check_file "$file"
    check_age_key

    log_info "Re-encrypting $file"

    # Create temporary file for decrypted content
    local temp_file=$(mktemp)
    trap "rm -f '$temp_file'" EXIT

    # Decrypt to temp file
    sops -d "$file" > "$temp_file"

    # Re-encrypt in place
    local temp_encrypted
    temp_encrypted=$(mktemp)
    sops_encrypt_to_stdout "$temp_file" > "$temp_encrypted"

    # Replace original
    mv "$temp_encrypted" "$file"
    log_success "File re-encrypted successfully"
}

cmd_list_secrets() {
    local dir="${1:-$PROJECT_ROOT}"
    dir="$(get_rel_path "$dir")"

    log_info "Finding SOPS files in $dir"
    find "$dir" -name "*.sops.yaml" -o -name "*.sops.yml" | sort | while read -r file; do
        # Get relative path from project root
        rel_path="${file#$PROJECT_ROOT/}"
        echo "$rel_path"
    done
}

cmd_search_all() {
    local pattern="$1"
    local case_flag="${2:-}"
    check_age_key

    log_info "Searching all SOPS files for pattern: $pattern"

    # Find all SOPS files
    local sops_files
    sops_files=$(find "$PROJECT_ROOT" -name "*.sops.yaml" -o -name "*.sops.yml" \
        -not -path "$PROJECT_ROOT/.git/*" \
        -not -path "$PROJECT_ROOT/test/*" \
        -not -path "$PROJECT_ROOT/tests/*" | sort)

    if [[ -z "$sops_files" ]]; then
        log_info "No SOPS files found"
        return 0
    fi

    local found_files=()
    local total_files=0
    local grep_flags="-n"

    # Add case insensitive flag if requested
    if [[ "$case_flag" == "-i" || "$case_flag" == "--ignore-case" ]]; then
        grep_flags="-ni"
    fi

    echo # Empty line for readability
    echo "=== SOPS Search Results ==="
    echo

    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            total_files=$((total_files + 1))
            local rel_path="${file#$PROJECT_ROOT/}"

            # Check if file can be decrypted
            if ! sops -d "$file" >/dev/null 2>&1; then
                log_error "Failed to decrypt $rel_path - skipping"
                continue
            fi

            # Decrypt and search for pattern
            local decrypted_content
            decrypted_content=$(sops -d "$file" 2>/dev/null)

            local matches
            matches=$(echo "$decrypted_content" | grep $grep_flags "$pattern" || true)

            if [[ -n "$matches" ]]; then
                found_files+=("$rel_path")
                echo "[FILE] $rel_path:"
                echo "$matches" | sed 's/^/    /'
                echo
            fi
        fi
    done <<< "$sops_files"

    echo "=== Summary ==="
    if [[ ${#found_files[@]} -gt 0 ]]; then
        log_warning "Pattern '$pattern' found in ${#found_files[@]} out of $total_files SOPS files:"
        for file in "${found_files[@]}"; do
            echo "  - $file"
        done
        return 1
    else
        log_success "Pattern '$pattern' not found in any of the $total_files SOPS files!"
        return 0
    fi
}

cmd_validate_all() {
    check_age_key

    log_info "Validating all SOPS files in repository"

    # Find all SOPS files
    local sops_files
    sops_files=$(find "$PROJECT_ROOT" -name "*.sops.yaml" -o -name "*.sops.yml" \
        -not -path "$PROJECT_ROOT/.git/*" \
        -not -path "$PROJECT_ROOT/test/*" \
        -not -path "$PROJECT_ROOT/tests/*" | sort)

    if [[ -z "$sops_files" ]]; then
        log_info "No SOPS files found"
        return 0
    fi

    local failed_files=()
    local total_files=0

    while IFS= read -r file; do
        if [[ -n "$file" ]]; then
            total_files=$((total_files + 1))
            local rel_path="${file#$PROJECT_ROOT/}"

            log_info "Validating $rel_path..."

            # Check if file can be decrypted
            if ! sops -d "$file" >/dev/null 2>&1; then
                failed_files+=("$rel_path (decryption failed)")
                log_error "Failed to decrypt $rel_path"
                continue
            fi

            # Check for hardcoded passwords or suspicious patterns
            local decrypted_content
            decrypted_content=$(sops -d "$file" 2>/dev/null)

            # Check for common hardcoded passwords
            if echo "$decrypted_content" | grep -qE "password.*123|admin.*admin|test.*test"; then
                failed_files+=("$rel_path (contains suspicious hardcoded passwords)")
                log_error "Found suspicious hardcoded passwords in $rel_path"
                continue
            fi

            # Check for bcrypt hashes that might be hardcoded (like the ones we removed)
            if echo "$decrypted_content" | grep -qE '\$2[ayb]\$[0-9]+\$[./A-Za-z0-9]{53}'; then
                failed_files+=("$rel_path (contains hardcoded bcrypt hashes)")
                log_error "Found hardcoded bcrypt password hashes in $rel_path"
                continue
            fi

            # Check for placeholder passwords that shouldn't be in production
            if echo "$decrypted_content" | grep -qE "CHANGE_ME|PLACEHOLDER|TODO|FIXME.*password"; then
                failed_files+=("$rel_path (contains placeholder passwords)")
                log_error "Found placeholder passwords in $rel_path"
                continue
            fi
        fi
    done <<< "$sops_files"

    echo # Empty line for readability

    if [[ ${#failed_files[@]} -gt 0 ]]; then
        log_error "SOPS validation failed for ${#failed_files[@]} out of $total_files files:"
        for file in "${failed_files[@]}"; do
            echo "  - $file"
        done
        return 1
    else
        log_success "All $total_files SOPS files validated successfully!"
        return 0
    fi
}

cmd_diff() {
    local file1="$(get_rel_path "$1")"
    local file2="$(get_rel_path "$2")"
    check_file "$file1"
    check_file "$file2"
    check_age_key

    log_info "Comparing $file1 and $file2 (decrypted)"

    # Create temp files
    local temp1=$(mktemp)
    local temp2=$(mktemp)
    trap "rm -f '$temp1' '$temp2'" EXIT

    # Decrypt both files
    sops -d "$file1" > "$temp1"
    sops -d "$file2" > "$temp2"

    # Show diff
    diff -u "$temp1" "$temp2" || true
}

cmd_backup() {
    local file="$(get_rel_path "$1")"
    check_file "$file"

    local timestamp=$(date +"%Y%m%d-%H%M%S")
    local backup_file="${file}.backup-${timestamp}"

    cp "$file" "$backup_file"
    log_success "Backup created: $backup_file"
}

cmd_restore() {
    local backup_file="$(get_rel_path "$1")"
    check_file "$backup_file"

    # Extract original filename by removing .backup-TIMESTAMP suffix
    local original_file="${backup_file%.backup-*}"

    if [[ "$original_file" == "$backup_file" ]]; then
        log_error "File doesn't appear to be a backup (no .backup-TIMESTAMP suffix)"
        exit 1
    fi

    log_info "Restoring $original_file from $backup_file"
    cp "$backup_file" "$original_file"
    log_success "File restored successfully"
}

cmd_set_value() {
    local file="$(get_rel_path "$1")"
    local key_path="$2"
    local value="$3"
    check_file "$file"
    check_age_key

    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for set-value command. Install with: brew install yq"
        exit 1
    fi

    log_info "Setting '$key_path' in $file"

    # Create temp file for the operation
    local temp_file=$(mktemp)
    local temp_sops_file="${temp_file}.sops.yaml"
    trap "rm -f '$temp_file' '$temp_sops_file'" EXIT

    # Decrypt to temp file
    sops -d "$file" > "$temp_file"

    # Use yq to set the value (convert dot notation to yq path)
    # e.g., "stringData.WEBUI_PASS" -> ".stringData.WEBUI_PASS"
    local yq_path=".${key_path}"
    yq -i "${yq_path} = \"${value}\"" "$temp_file"

    # Copy to .sops.yaml extension for SOPS config matching
    cp "$temp_file" "$temp_sops_file"

    # Re-encrypt
    sops_encrypt_to_stdout "$temp_sops_file" > "$file"

    log_success "Value set successfully"

    # Show the updated value (masked)
    local masked_value="${value:0:3}***"
    log_info "Set $key_path = $masked_value"
}

cmd_set_value_from_file() {
    local file="$(get_rel_path "$1")"
    local key_path="$2"
    local value_file="$(get_rel_path "$3")"
    check_file "$file"
    check_file "$value_file"
    check_age_key

    if ! command -v yq &> /dev/null; then
        log_error "yq is required for set-value-from-file command. Install with: brew install yq"
        exit 1
    fi

    log_info "Setting '$key_path' in $file from file $value_file"

    local temp_file
    temp_file=$(mktemp)
    local temp_sops_file="${temp_file}.sops.yaml"
    trap "rm -f '$temp_file' '$temp_sops_file'" EXIT

    sops -d "$file" > "$temp_file"

    local yq_path=".${key_path}"
    yq -i "${yq_path} = load_str(\"${value_file}\")" "$temp_file"

    cp "$temp_file" "$temp_sops_file"
    sops_encrypt_to_stdout "$temp_sops_file" > "$file"

    log_success "Value set successfully from file"
    log_info "Set $key_path from $value_file"
}

cmd_get_value() {
    local file="$(get_rel_path "$1")"
    local key_path="$2"
    check_file "$file"
    check_age_key

    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for get-value command. Install with: brew install yq"
        exit 1
    fi

    # Decrypt and extract value
    local yq_path=".${key_path}"
    sops -d "$file" | yq "$yq_path"
}

cmd_delete_key() {
    local file="$(get_rel_path "$1")"
    local key_path="$2"
    check_file "$file"
    check_age_key

    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for delete-key command. Install with: brew install yq"
        exit 1
    fi

    log_info "Deleting '$key_path' from $file"

    # Create temp files for the operation
    local temp_file=$(mktemp)
    local temp_sops_file="${temp_file}.sops.yaml"
    local temp_output=$(mktemp)
    trap "rm -f '$temp_file' '$temp_sops_file' '$temp_output'" EXIT

    # Decrypt to temp file
    sops -d "$file" > "$temp_file"

    # Check if key exists
    local yq_path=".${key_path}"
    if [[ "$(yq "$yq_path" "$temp_file")" == "null" ]]; then
        log_warning "Key '$key_path' does not exist in $file"
        return 0
    fi

    # Use yq to delete the key
    yq -i "del(${yq_path})" "$temp_file"

    # Copy to .sops.yaml extension for SOPS config matching
    cp "$temp_file" "$temp_sops_file"

    # Re-encrypt to temp output (don't overwrite original until success)
    if sops_encrypt_to_stdout "$temp_sops_file" > "$temp_output"; then
        mv "$temp_output" "$file"
        log_success "Key '$key_path' deleted successfully"
    else
        log_error "Failed to re-encrypt file"
        exit 1
    fi
}

cmd_set_annotation() {
    local file="$(get_rel_path "$1")"
    local annotation_key="$2"
    local annotation_value="$3"
    check_file "$file"
    check_age_key

    # Check if yq is installed
    if ! command -v yq &> /dev/null; then
        log_error "yq is required for set-annotation command. Install with: brew install yq"
        exit 1
    fi

    log_info "Setting annotation '$annotation_key' in $file"

    # Create temp file for the operation
    local temp_file=$(mktemp)
    local temp_sops_file="${temp_file}.sops.yaml"
    trap "rm -f '$temp_file' '$temp_sops_file'" EXIT

    # Decrypt to temp file
    sops -d "$file" > "$temp_file"

    # Use yq to set the annotation (annotation keys can have dots, so use bracket notation)
    yq -i ".metadata.annotations[\"${annotation_key}\"] = \"${annotation_value}\"" "$temp_file"

    # Copy to .sops.yaml extension for SOPS config matching
    cp "$temp_file" "$temp_sops_file"

    # Re-encrypt
    sops_encrypt_to_stdout "$temp_sops_file" > "$file"

    log_success "Annotation set successfully"
    log_info "Set $annotation_key = $annotation_value"
}

# Show usage
show_usage() {
    cat << EOF
SOPS Management Script for Homelab

Usage: $0 [command] [file-path] [options]

Commands:
  decrypt <file>          - Decrypt a SOPS file to stdout
  edit <file>             - Edit a SOPS file in place (opens editor)
  encrypt <file>          - Encrypt a plain file to SOPS format
  view <file>             - View decrypted content (same as decrypt)
  validate <file>         - Validate that a SOPS file can be decrypted
  validate-all            - Validate all SOPS files and check for security issues
  search-all <pattern>    - Search for pattern in all decrypted SOPS files
  reencrypt <file>        - Re-encrypt a SOPS file (useful after key rotation)
  list-secrets [dir]      - List all .sops.yaml files in directory (default: current)
  diff <file1> <file2>    - Show diff between two SOPS files (decrypted)
  backup <file>           - Create timestamped backup of SOPS file
  restore <backup-file>   - Restore from backup (removes .backup-TIMESTAMP suffix)
  set-value <file> <key> <value> - Set a value in a SOPS file
  set-value-from-file <file> <key> <value-file> - Set multiline value from file
  get-value <file> <key>  - Get a value from a SOPS file
  delete-key <file> <key> - Delete a key from a SOPS file
  set-annotation <file> <key> <value> - Set an annotation in a SOPS file

Environment Variables:
  SOPS_AGE_KEY           - AGE private key for decryption (required)
  SOPS_AGE_KEY_FILE      - Path to age keys file (recommended)
  AGE_RECIPIENT          - AGE public key for encryption (default: homelab key)

Examples:
  # View a secret
  $0 view apps/authelia/overlays/production/authelia-secret.sops.yaml

  # Edit a secret
  $0 edit apps/authelia/overlays/production/authelia-secret.sops.yaml

  # List all secrets
  $0 list-secrets

  # Search all secrets for a pattern
  $0 search-all "erauner\.app"

  # Compare two secrets
  $0 diff apps/authelia/overlays/production/authelia-secret.sops.yaml \\
          apps/authelia/overlays/staging/authelia-secret.sops.yaml

  # Create backup before editing
  $0 backup apps/authelia/overlays/production/authelia-secret.sops.yaml
  $0 edit apps/authelia/overlays/production/authelia-secret.sops.yaml

  # Set a value in a secret (requires yq)
  $0 set-value apps/media-stack/overlays/production/qbittorrent-secret.sops.yaml stringData.WEBUI_PASS mypassword

  # Set a multiline value from a local file
  $0 set-value-from-file apps/media-stack/overlays/production/qbittorrent-vpn-secret.sops.yaml stringData.wg0.conf ~/Downloads/us-dal-wg-001.conf

  # Get a value from a secret
  $0 get-value apps/media-stack/overlays/production/qbittorrent-secret.sops.yaml stringData.VPN_PROV

  # Delete a key from a secret
  $0 delete-key apps/openclaw/overlays/production/openclaw-secret.sops.yaml stringData.OLD_API_KEY

Note: Set the SOPS_AGE_KEY environment variable before using:
export SOPS_AGE_KEY="AGE-SECRET-KEY-<redacted>"
EOF
}

# Main command handler
main() {
    if [[ $# -eq 0 ]]; then
        show_usage
        exit 1
    fi

    local command="$1"
    shift

    case "$command" in
        decrypt|view)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 $command <file>"
                exit 1
            fi
            cmd_decrypt "$1"
            ;;
        edit)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 $command <file>"
                exit 1
            fi
            cmd_edit "$1"
            ;;
        encrypt)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 $command <file>"
                exit 1
            fi
            cmd_encrypt "$1"
            ;;
        validate)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 $command <file>"
                exit 1
            fi
            cmd_validate "$1"
            ;;
        validate-all)
            if [[ $# -ne 0 ]]; then
                log_error "Usage: $0 $command"
                exit 1
            fi
            cmd_validate_all
            ;;
        search-all)
            if [[ $# -lt 1 || $# -gt 2 ]]; then
                log_error "Usage: $0 $command <pattern> [--ignore-case|-i]"
                exit 1
            fi
            cmd_search_all "$1" "${2:-}"
            ;;
        reencrypt)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 $command <file>"
                exit 1
            fi
            cmd_reencrypt "$1"
            ;;
        list-secrets)
            cmd_list_secrets "${1:-}"
            ;;
        diff)
            if [[ $# -ne 2 ]]; then
                log_error "Usage: $0 $command <file1> <file2>"
                exit 1
            fi
            cmd_diff "$1" "$2"
            ;;
        backup)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 $command <file>"
                exit 1
            fi
            cmd_backup "$1"
            ;;
        restore)
            if [[ $# -ne 1 ]]; then
                log_error "Usage: $0 $command <backup-file>"
                exit 1
            fi
            cmd_restore "$1"
            ;;
        set-value)
            if [[ $# -ne 3 ]]; then
                log_error "Usage: $0 $command <file> <key-path> <value>"
                log_info "Example: $0 set-value path/to/secret.sops.yaml stringData.PASSWORD mypassword"
                exit 1
            fi
            cmd_set_value "$1" "$2" "$3"
            ;;
        set-value-from-file)
            if [[ $# -ne 3 ]]; then
                log_error "Usage: $0 $command <file> <key-path> <value-file>"
                log_info "Example: $0 set-value-from-file path/to/secret.sops.yaml stringData.wg0.conf ~/Downloads/wg0.conf"
                exit 1
            fi
            cmd_set_value_from_file "$1" "$2" "$3"
            ;;
        get-value)
            if [[ $# -ne 2 ]]; then
                log_error "Usage: $0 $command <file> <key-path>"
                log_info "Example: $0 get-value path/to/secret.sops.yaml stringData.PASSWORD"
                exit 1
            fi
            cmd_get_value "$1" "$2"
            ;;
        delete-key)
            if [[ $# -ne 2 ]]; then
                log_error "Usage: $0 $command <file> <key-path>"
                log_info "Example: $0 delete-key path/to/secret.sops.yaml stringData.OLD_KEY"
                exit 1
            fi
            cmd_delete_key "$1" "$2"
            ;;
        set-annotation)
            if [[ $# -ne 3 ]]; then
                log_error "Usage: $0 $command <file> <annotation-key> <value>"
                log_info "Example: $0 set-annotation path/to/secret.sops.yaml 'reflector.v1.k8s.emberstack.com/reflection-auto-namespaces' 'ns1,ns2'"
                exit 1
            fi
            cmd_set_annotation "$1" "$2" "$3"
            ;;
        --help|-h|help)
            show_usage
            ;;
        *)
            log_error "Unknown command: $command"
            show_usage
            exit 1
            ;;
    esac
}

# Run main function
main "$@"
