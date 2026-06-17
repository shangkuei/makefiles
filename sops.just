# ============================================================================
# sops.just - Unified SOPS Operations
# ============================================================================
# Shared justfile include for standardized SOPS secret management operations
# across Terraform, Kubernetes, and Docker domains.
#
# Usage:
#   Import this file in your domain justfile:
#     import '../../../makefiles/sops.just'
#
# Required variables (define in consumer justfile before import):
#   sops_env_name   - Environment name for key naming
#
# Optional variables (override via environment):
#   SOPS_KEY_STRATEGY  - Key location strategy: central|local (default: central)
#   SOPS_AGE_DIR       - Central key directory (default: ~/.config/sops/age)
#   SOPS_LOCAL_KEY     - Local key filename (default: age-key.txt)
#   SOPS_CONFIG        - SOPS config filename (default: .sops.yaml)
#   SOPS_EDITOR        - Editor for sops edit (default: $EDITOR or code --wait)
# ============================================================================

# ============================================================================
# Configuration
# ============================================================================

sops_key_strategy := env("SOPS_KEY_STRATEGY", "central")
sops_age_dir := env("SOPS_AGE_DIR", env("HOME") / ".config/sops/age")
sops_local_key := env("SOPS_LOCAL_KEY", "age-key.txt")
sops_config := env("SOPS_CONFIG", ".sops.yaml")
sops_editor := env("SOPS_EDITOR", env("EDITOR", "code --wait"))

# ============================================================================
# Computed Variables
# ============================================================================

sops_age_key_file := if sops_key_strategy == "central" { sops_age_dir / (sops_env_name + ".txt") } else if sops_key_strategy == "local" { sops_local_key } else { error("SOPS_KEY_STRATEGY must be 'central' or 'local', got '" + sops_key_strategy + "'") }

sops_age_pub_file := if sops_key_strategy == "central" { sops_age_key_file + ".pub" } else { "" }

# ============================================================================
# Colors
# ============================================================================

[private]
_sops_bold := `tput bold 2>/dev/null || true`
[private]
_sops_red := `tput setaf 1 2>/dev/null || true`
[private]
_sops_green := `tput setaf 2 2>/dev/null || true`
[private]
_sops_yellow := `tput setaf 3 2>/dev/null || true`
[private]
_sops_blue := `tput setaf 4 2>/dev/null || true`
[private]
_sops_cyan := `tput setaf 6 2>/dev/null || true`
[private]
_sops_nc := `tput sgr0 2>/dev/null || true`

[private]
_sops_ok := _sops_green + "OK" + _sops_nc
[private]
_sops_fail := _sops_red + "FAIL" + _sops_nc
[private]
_sops_warn := _sops_yellow + "WARN" + _sops_nc
[private]
_sops_info := _sops_cyan + "INFO" + _sops_nc

# ============================================================================
# Tier 1: Universal Targets
# ============================================================================

# Verify sops and age are installed
[group("sops")]
sops-check-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Checking dependencies...{{ _sops_nc }}"
    ok=true
    if command -v sops >/dev/null 2>&1; then
        echo "  [{{ _sops_ok }}] sops: $(sops --version 2>&1 | head -1 | sed 's/sops //')"
    else
        echo "  [{{ _sops_fail }}] sops: not installed"
        echo "       Install: brew install sops"
        ok=false
    fi
    if command -v age >/dev/null 2>&1; then
        echo "  [{{ _sops_ok }}] age:  $(age --version 2>&1 | head -1)"
    else
        echo "  [{{ _sops_fail }}] age:  not installed"
        echo "       Install: brew install age"
        ok=false
    fi
    if command -v age-keygen >/dev/null 2>&1; then
        echo "  [{{ _sops_ok }}] age-keygen: available"
    else
        echo "  [{{ _sops_fail }}] age-keygen: not installed"
        ok=false
    fi
    if [ "$ok" = "false" ]; then
        echo ""
        echo "{{ _sops_red }}Missing dependencies. Please install and retry.{{ _sops_nc }}"
        exit 1
    fi
    echo "{{ _sops_green }}All dependencies satisfied{{ _sops_nc }}"

# Verify .sops.yaml configuration exists
[group("sops")]
sops-check-config:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Checking SOPS configuration...{{ _sops_nc }}"
    if [ ! -f "{{ sops_config }}" ]; then
        echo "  [{{ _sops_fail }}] {{ sops_config }} not found"
        echo ""
        echo "To create configuration:"
        if [ "{{ sops_key_strategy }}" = "central" ]; then
            echo "  just sops-keygen"
            echo "  (Then manually create {{ sops_config }} with public key)"
        else
            echo "  just sops-import-key /path/to/key.txt"
        fi
        exit 1
    fi
    echo "  [{{ _sops_ok }}] Config: {{ sops_config }}"
    echo ""
    echo "Creation rules:"
    grep -E "path_regex:|age:|encrypted_regex:" "{{ sops_config }}" 2>/dev/null | sed 's/^/  /' || echo "  (none found)"
    echo ""
    echo "{{ _sops_green }}Configuration valid{{ _sops_nc }}"

# Display encryption configuration
[group("sops")]
sops-info: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    echo ""
    echo "{{ _sops_bold }}SOPS Configuration{{ _sops_nc }}"
    echo "==============================================="
    echo "Environment:    {{ sops_env_name }}"
    echo "Key Strategy:   {{ sops_key_strategy }}"
    echo "Key File:       {{ sops_age_key_file }}"
    echo "Config File:    {{ sops_config }}"
    echo "==============================================="
    echo ""
    echo "{{ _sops_bold }}Key Status:{{ _sops_nc }}"
    if [ -f "{{ sops_age_key_file }}" ]; then
        echo "  [{{ _sops_ok }}] Private key exists"
        echo ""
        echo "  Public key:"
        age-keygen -y "{{ sops_age_key_file }}" 2>/dev/null | sed 's/^/    /'
    else
        echo "  [{{ _sops_warn }}] Private key not found"
        echo "       Expected: {{ sops_age_key_file }}"
        if [ "{{ sops_key_strategy }}" = "central" ]; then
            echo "       Run: just sops-keygen"
        else
            echo "       Run: just sops-import-key /path/to/key.txt"
        fi
    fi
    echo ""
    echo "{{ _sops_bold }}Config Status:{{ _sops_nc }}"
    if [ -f "{{ sops_config }}" ]; then
        echo "  [{{ _sops_ok }}] {{ sops_config }} exists"
        echo ""
        echo "  Public key(s) in config:"
        grep -oE "age1[a-z0-9]+" "{{ sops_config }}" 2>/dev/null | sort -u | sed 's/^/    /' || echo "    (none found)"
    else
        echo "  [{{ _sops_warn }}] {{ sops_config }} not found"
    fi
    echo ""

# Validate all encrypted files can be decrypted
[group("sops")]
sops-validate: sops-check-deps sops-check-config
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Validating encrypted files...{{ _sops_nc }}"
    if [ ! -f "{{ sops_age_key_file }}" ]; then
        echo "{{ _sops_red }}Error: Private key not found: {{ sops_age_key_file }}{{ _sops_nc }}"
        exit 1
    fi
    failed=0
    count=0
    for file in $(find . -maxdepth 2 \( -name "*.enc" -o -name "*.enc.*" -o -name "*.yaml.enc" -o -name "*.yml.enc" -o -name "*.json.enc" \) -type f 2>/dev/null | sort); do
        count=$((count + 1))
        if SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops -d "$file" > /dev/null 2>&1; then
            echo "  [{{ _sops_ok }}] $file"
        else
            echo "  [{{ _sops_fail }}] $file"
            failed=$((failed + 1))
        fi
    done
    echo ""
    if [ $count -eq 0 ]; then
        echo "{{ _sops_yellow }}No encrypted files found{{ _sops_nc }}"
    elif [ $failed -gt 0 ]; then
        echo "{{ _sops_red }}Validation failed: $failed/$count files{{ _sops_nc }}"
        exit 1
    else
        echo "{{ _sops_green }}All $count file(s) validated successfully{{ _sops_nc }}"
    fi

# ============================================================================
# Tier 2: Key Management Targets
# ============================================================================

# Generate new age key pair
[group("sops")]
sops-keygen: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Generating age key pair...{{ _sops_nc }}"
    echo "Strategy: {{ sops_key_strategy }}"
    echo "Environment: {{ sops_env_name }}"
    echo ""
    if [ "{{ sops_key_strategy }}" != "central" ]; then
        echo "{{ _sops_yellow }}Local strategy uses import, not keygen{{ _sops_nc }}"
        echo "Run: just sops-import-key /path/to/key.txt"
        exit 0
    fi
    mkdir -p "{{ sops_age_dir }}"
    if [ -f "{{ sops_age_key_file }}" ]; then
        echo "{{ _sops_yellow }}Warning: Key already exists: {{ sops_age_key_file }}{{ _sops_nc }}"
        printf "Overwrite? [y/N] "
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Aborted."
            exit 0
        fi
    fi
    age-keygen -o "{{ sops_age_key_file }}" 2>&1
    chmod 600 "{{ sops_age_key_file }}"
    age-keygen -y "{{ sops_age_key_file }}" > "{{ sops_age_pub_file }}"
    chmod 644 "{{ sops_age_pub_file }}"
    echo ""
    echo "{{ _sops_green }}Key generated successfully{{ _sops_nc }}"
    echo ""
    echo "Files created:"
    echo "  Private key: {{ sops_age_key_file }}"
    echo "  Public key:  {{ sops_age_pub_file }}"
    echo ""
    echo "Public key value:"
    cat "{{ sops_age_pub_file }}" | sed 's/^/  /'
    echo ""
    echo "{{ _sops_yellow }}IMPORTANT - Next steps:{{ _sops_nc }}"
    echo "  1. {{ _sops_bold }}Backup{{ _sops_nc }} private key to password manager"
    echo "  2. {{ _sops_bold }}Update{{ _sops_nc }} {{ sops_config }} with public key above"
    echo "  3. {{ _sops_bold }}Never{{ _sops_nc }} commit private key to Git"
    echo ""

# Generate key (if needed) and update .sops.yaml with public key
[group("sops")]
sops-init-config: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Initializing SOPS configuration...{{ _sops_nc }}"
    echo "Strategy: {{ sops_key_strategy }}"
    echo "Environment: {{ sops_env_name }}"
    echo ""
    if [ "{{ sops_key_strategy }}" != "central" ]; then
        echo "{{ _sops_yellow }}Local strategy: use sops-import-key instead{{ _sops_nc }}"
        echo "Run: just sops-import-key /path/to/key.txt"
        exit 0
    fi
    # Step 1: Generate key if it doesn't exist
    if [ ! -f "{{ sops_age_key_file }}" ]; then
        echo "{{ _sops_yellow }}==> No key found, generating new key...{{ _sops_nc }}"
        mkdir -p "{{ sops_age_dir }}"
        age-keygen -o "{{ sops_age_key_file }}" 2>&1
        chmod 600 "{{ sops_age_key_file }}"
        age-keygen -y "{{ sops_age_key_file }}" > "{{ sops_age_pub_file }}"
        chmod 644 "{{ sops_age_pub_file }}"
        echo "  [{{ _sops_ok }}] Key generated: {{ sops_age_key_file }}"
    else
        echo "  [{{ _sops_ok }}] Key exists: {{ sops_age_key_file }}"
    fi
    # Step 2: Get public key and update config
    pubkey=$(age-keygen -y "{{ sops_age_key_file }}")
    echo "  [{{ _sops_info }}] Public key: $pubkey"
    echo ""
    if [ ! -f "{{ sops_config }}" ]; then
        echo "{{ _sops_red }}Error: {{ sops_config }} not found{{ _sops_nc }}"
        echo "Create {{ sops_config }} first with placeholder REPLACE_WITH_YOUR_AGE_PUBLIC_KEY"
        exit 1
    fi
    if grep -q "REPLACE_WITH_YOUR_AGE_PUBLIC_KEY" "{{ sops_config }}"; then
        echo "{{ _sops_blue }}==> Updating {{ sops_config }} with public key...{{ _sops_nc }}"
        sed -i.bak "s/REPLACE_WITH_YOUR_AGE_PUBLIC_KEY/$pubkey/g" "{{ sops_config }}"
        rm -f "{{ sops_config }}.bak"
        echo "  [{{ _sops_ok }}] {{ sops_config }} updated"
    elif grep -q "$pubkey" "{{ sops_config }}"; then
        echo "  [{{ _sops_ok }}] {{ sops_config }} already has correct key"
    else
        echo "{{ _sops_yellow }}Warning: {{ sops_config }} has different key configured{{ _sops_nc }}"
        echo "Current key in config:"
        grep -oE "age1[a-z0-9]+" "{{ sops_config }}" 2>/dev/null | head -1 | sed 's/^/  /'
        echo ""
        echo "Expected key:"
        echo "  $pubkey"
        echo ""
        echo "To force update, manually replace the key in {{ sops_config }}"
    fi
    echo ""
    echo "{{ _sops_green }}SOPS configuration initialized{{ _sops_nc }}"
    echo ""
    echo "{{ _sops_yellow }}IMPORTANT:{{ _sops_nc }}"
    echo "  1. {{ _sops_bold }}Backup{{ _sops_nc }} private key to password manager"
    echo "  2. {{ _sops_bold }}Never{{ _sops_nc }} commit private key to Git"

# Import existing age key
[arg('age_key_file', long='age_key_file')]
[group("sops")]
sops-import-key age_key_file: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Importing age key...{{ _sops_nc }}"
    if [ ! -f "{{ age_key_file }}" ]; then
        echo "{{ _sops_red }}Error: Key file not found: {{ age_key_file }}{{ _sops_nc }}"
        exit 1
    fi
    # Validate age key format
    if ! grep -q "AGE-SECRET-KEY" "{{ age_key_file }}"; then
        echo "{{ _sops_red }}Error: Invalid age key format{{ _sops_nc }}"
        echo "Expected file containing AGE-SECRET-KEY"
        exit 1
    fi
    if [ "{{ sops_key_strategy }}" = "local" ]; then
        if [ -f "{{ sops_local_key }}" ]; then
            echo "{{ _sops_yellow }}Warning: {{ sops_local_key }} already exists{{ _sops_nc }}"
            printf "Overwrite? [y/N] "
            read -r confirm
            if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
                echo "Aborted."
                exit 0
            fi
        fi
        cp "{{ age_key_file }}" "{{ sops_local_key }}"
        chmod 600 "{{ sops_local_key }}"
        echo "  [{{ _sops_ok }}] Key copied to {{ sops_local_key }}"
        pubkey=$(age-keygen -y "{{ sops_local_key }}")
        echo "  [{{ _sops_info }}] Public key: $pubkey"
        echo ""
        echo "{{ _sops_green }}Key imported successfully{{ _sops_nc }}"
        echo ""
        echo "{{ _sops_yellow }}Next step:{{ _sops_nc }} Create or update {{ sops_config }}"
        echo "You may need to run a domain-specific target to generate the config."
    else
        mkdir -p "{{ sops_age_dir }}"
        cp "{{ age_key_file }}" "{{ sops_age_key_file }}"
        chmod 600 "{{ sops_age_key_file }}"
        age-keygen -y "{{ sops_age_key_file }}" > "{{ sops_age_pub_file }}"
        chmod 644 "{{ sops_age_pub_file }}"
        echo "  [{{ _sops_ok }}] Key imported to {{ sops_age_key_file }}"
        echo "  [{{ _sops_ok }}] Public key: {{ sops_age_pub_file }}"
        echo ""
        echo "{{ _sops_green }}Key imported successfully{{ _sops_nc }}"
    fi

# Export public key for sharing
[group("sops")]
sops-export-public: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ sops_age_key_file }}" ]; then
        echo "{{ _sops_red }}Error: Private key not found: {{ sops_age_key_file }}{{ _sops_nc }}"
        exit 1
    fi
    age-keygen -y "{{ sops_age_key_file }}"

# Show key rotation procedure
[group("sops")]
sops-rotate-key: sops-check-deps sops-check-config
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Key Rotation Procedure{{ _sops_nc }}"
    echo ""
    echo "This is a multi-step manual process:"
    echo ""
    echo "1. Generate new key:"
    echo "   SOPS_ENV_NAME={{ sops_env_name }}-new just sops-keygen"
    echo ""
    echo "2. Update {{ sops_config }} with BOTH keys (old + new)"
    echo "   This allows decryption during transition"
    echo ""
    echo "3. Re-encrypt all files with new key:"
    echo "   sops updatekeys <file>"
    echo "   (or use: just sops-rekey <file>)"
    echo ""
    echo "4. Verify decryption with new key only"
    echo ""
    echo "5. Remove old key from {{ sops_config }}"
    echo ""
    echo "6. Update GitHub Secrets with new key"
    echo ""
    echo "7. Securely delete old key file"
    echo ""
    echo "See: docs/runbooks/0008-sops-secret-management.md"

# ============================================================================
# Tier 3: Encryption Operations
# ============================================================================

# Encrypt file in-place
[arg('file', long='file')]
[group("sops")]
sops-encrypt file: sops-check-deps sops-check-config
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ file }}" ]; then
        echo "{{ _sops_red }}Error: File not found: {{ file }}{{ _sops_nc }}"
        exit 1
    fi
    # Check if already encrypted
    if head -5 "{{ file }}" | grep -q "sops:" 2>/dev/null; then
        echo "{{ _sops_yellow }}Warning: File appears to be already encrypted{{ _sops_nc }}"
        printf "Continue anyway? [y/N] "
        read -r confirm
        if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
            echo "Aborted."
            exit 0
        fi
    fi
    SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops --encrypt --in-place "{{ file }}"
    echo "{{ _sops_green }}Encrypted: {{ file }}{{ _sops_nc }}"

# Decrypt file to stdout
[arg('file', long='file')]
[group("sops")]
sops-decrypt file: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ file }}" ]; then
        echo "{{ _sops_red }}Error: File not found: {{ file }}{{ _sops_nc }}"
        exit 1
    fi
    SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops --decrypt "{{ file }}"

# Edit encrypted file
[arg('editor', long='editor')]
[arg('file', long='file')]
[group("sops")]
sops-edit file editor=sops_editor: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ file }}" ]; then
        echo "{{ _sops_red }}Error: File not found: {{ file }}{{ _sops_nc }}"
        exit 1
    fi
    EDITOR="{{ editor }}" SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops "{{ file }}"

# Re-encrypt file with current config
[arg('file', long='file')]
[group("sops")]
sops-rekey file: sops-check-deps sops-check-config
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ file }}" ]; then
        echo "{{ _sops_red }}Error: File not found: {{ file }}{{ _sops_nc }}"
        exit 1
    fi
    SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops updatekeys -y "{{ file }}"
    echo "{{ _sops_green }}Re-keyed: {{ file }}{{ _sops_nc }}"

# Remove decrypted/temporary files
[group("sops")]
sops-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Cleaning temporary files...{{ _sops_nc }}"
    count=0
    for pattern in "*.decrypted" "*.decrypted.*" "*.plaintext" "*.plain"; do
        for file in $(find . -maxdepth 2 -name "$pattern" -type f 2>/dev/null); do
            rm -f "$file"
            echo "  Removed: $file"
            count=$((count + 1))
        done
    done
    if [ $count -eq 0 ]; then
        echo "  No temporary files found"
    else
        echo ""
        echo "{{ _sops_green }}Removed $count file(s){{ _sops_nc }}"
    fi
