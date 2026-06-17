# ============================================================================
# terraform.just - Unified Terraform Operations
# ============================================================================
# Shared justfile include for standardized Terraform operations with SOPS
# encryption integration.
#
# Usage:
#   Import this file in your domain justfile after sops.just:
#     import '../../../makefiles/sops.just'
#     import '../../../makefiles/terraform.just'
#
# Required (from sops.just):
#   sops_env_name, sops_age_key_file
#
# Optional variables (override via environment):
#   TF_TFVARS_ENC      - Encrypted tfvars filename (default: terraform.tfvars.enc)
#   TF_TFVARS_PLAIN    - Plaintext tfvars filename (default: terraform.tfvars)
#   TF_TFVARS_EXAMPLE  - Example tfvars filename (default: terraform.tfvars.example)
#   TF_BACKEND_HCL     - Plaintext backend config (default: backend.hcl)
#   TF_BACKEND_ENC     - Encrypted backend config (default: backend.hcl.enc)
#   TF_BACKEND_EXAMPLE - Example backend config (default: backend.hcl.example)
#   TF_AUTO_INIT       - Auto-run init before plan/apply (default: false)
#   TF_GENERATED_DIR   - Directory for generated files (default: generated)
# ============================================================================

# ============================================================================
# Configuration
# ============================================================================

tf_tfvars_enc := env("TF_TFVARS_ENC", "terraform.tfvars.enc")
tf_tfvars_plain := env("TF_TFVARS_PLAIN", "terraform.tfvars")
tf_tfvars_example := env("TF_TFVARS_EXAMPLE", "terraform.tfvars.example")
tf_backend_hcl := env("TF_BACKEND_HCL", "backend.hcl")
tf_backend_enc := env("TF_BACKEND_ENC", "backend.hcl.enc")
tf_backend_example := env("TF_BACKEND_EXAMPLE", "backend.hcl.example")
tf_auto_init := env("TF_AUTO_INIT", "false")
tf_generated_dir := env("TF_GENERATED_DIR", "generated")

# ============================================================================
# Core Terraform Operations
# ============================================================================

# Initialize Terraform with encrypted backend support
[group("terraform")]
tf-init *args:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}==> Initializing Terraform{{ _sops_nc }}"
    if [ -f "{{ tf_backend_enc }}" ]; then
        echo "{{ _sops_blue }}==> Using encrypted backend: {{ tf_backend_enc }}{{ _sops_nc }}"
        SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops exec-file "{{ tf_backend_enc }}" 'terraform init {{ args }} -backend-config={}'
    elif [ -f "{{ tf_backend_hcl }}" ]; then
        echo "{{ _sops_yellow }}==> Using plaintext backend: {{ tf_backend_hcl }}{{ _sops_nc }}"
        terraform init {{ args }} -backend-config="{{ tf_backend_hcl }}"
    else
        echo "{{ _sops_yellow }}==> No backend config, using local state{{ _sops_nc }}"
        terraform init {{ args }}
    fi

# Generate Terraform execution plan
[group("terraform")]
tf-plan *args:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{ tf_auto_init }}" = "true" ]; then
        just tf-init
    fi
    echo "{{ _sops_blue }}==> Generating Terraform plan{{ _sops_nc }}"
    if [ -f "{{ tf_tfvars_enc }}" ]; then
        SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops exec-file "{{ tf_tfvars_enc }}" 'terraform plan {{ args }} -var-file={}'
    elif [ -f "{{ tf_tfvars_plain }}" ]; then
        terraform plan {{ args }} -var-file="{{ tf_tfvars_plain }}"
    else
        terraform plan {{ args }}
    fi

# Apply Terraform changes
[group("terraform")]
tf-apply *args:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{ tf_auto_init }}" = "true" ]; then
        just tf-init
    fi
    echo "{{ _sops_blue }}==> Applying Terraform changes{{ _sops_nc }}"
    if [ -f "{{ tf_tfvars_enc }}" ]; then
        SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops exec-file "{{ tf_tfvars_enc }}" 'terraform apply {{ args }} -var-file={}'
    elif [ -f "{{ tf_tfvars_plain }}" ]; then
        terraform apply {{ args }} -var-file="{{ tf_tfvars_plain }}"
    else
        terraform apply {{ args }}
    fi

# Destroy Terraform-managed infrastructure
[group("terraform")]
tf-destroy:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_red }}==> WARNING: This will destroy infrastructure{{ _sops_nc }}"
    printf "Type 'yes' to confirm: "
    read -r confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    if [ -f "{{ tf_tfvars_enc }}" ]; then
        SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops exec-file "{{ tf_tfvars_enc }}" 'terraform destroy -var-file={}'
    elif [ -f "{{ tf_tfvars_plain }}" ]; then
        terraform destroy -var-file="{{ tf_tfvars_plain }}"
    else
        terraform destroy
    fi

# ============================================================================
# Validation Operations
# ============================================================================

# Validate Terraform configuration
[group("terraform")]
tf-validate:
    @echo "{{ _sops_blue }}==> Validating Terraform configuration{{ _sops_nc }}"
    @terraform validate

# Format Terraform files
[group("terraform")]
tf-fmt:
    @echo "{{ _sops_blue }}==> Formatting Terraform files{{ _sops_nc }}"
    @terraform fmt -recursive

# Run validate + format
[group("terraform")]
tf-lint: tf-validate tf-fmt
    @echo "{{ _sops_green }}==> All checks passed{{ _sops_nc }}"

# ============================================================================
# SOPS Encryption Operations
# ============================================================================

# Encrypt backend.hcl
[group("terraform")]
tf-encrypt-backend: sops-check-deps sops-check-config
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ tf_backend_hcl }}" ]; then
        echo "{{ _sops_red }}Error: {{ tf_backend_hcl }} not found{{ _sops_nc }}"
        echo ""
        if [ -f "{{ tf_backend_example }}" ]; then
            echo "Create from example: cp {{ tf_backend_example }} {{ tf_backend_hcl }}"
        fi
        exit 1
    fi
    echo "{{ _sops_blue }}==> Encrypting {{ tf_backend_hcl }}{{ _sops_nc }}"
    SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops -e "{{ tf_backend_hcl }}" > "{{ tf_backend_enc }}"
    echo "{{ _sops_green }}==> Encrypted to {{ tf_backend_enc }}{{ _sops_nc }}"
    echo ""
    echo "{{ _sops_yellow }}Next:{{ _sops_nc }} rm {{ tf_backend_hcl }}"

# Encrypt terraform.tfvars
[group("terraform")]
tf-encrypt-tfvars: sops-check-deps sops-check-config
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ tf_tfvars_plain }}" ]; then
        echo "{{ _sops_red }}Error: {{ tf_tfvars_plain }} not found{{ _sops_nc }}"
        echo ""
        if [ -f "{{ tf_tfvars_example }}" ]; then
            echo "Create from example: cp {{ tf_tfvars_example }} {{ tf_tfvars_plain }}"
        fi
        exit 1
    fi
    echo "{{ _sops_blue }}==> Encrypting {{ tf_tfvars_plain }}{{ _sops_nc }}"
    SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops -e "{{ tf_tfvars_plain }}" > "{{ tf_tfvars_enc }}"
    echo "{{ _sops_green }}==> Encrypted to {{ tf_tfvars_enc }}{{ _sops_nc }}"
    echo ""
    echo "{{ _sops_yellow }}Next:{{ _sops_nc }} rm {{ tf_tfvars_plain }}"

# Edit encrypted backend.hcl
[arg('editor', long='editor')]
[group("terraform")]
tf-edit-backend editor=sops_editor: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ tf_backend_enc }}" ]; then
        echo "{{ _sops_red }}Error: {{ tf_backend_enc }} not found{{ _sops_nc }}"
        echo ""
        echo "Create and encrypt first: just tf-encrypt-backend"
        exit 1
    fi
    echo "{{ _sops_blue }}==> Editing {{ tf_backend_enc }}{{ _sops_nc }}"
    EDITOR="{{ editor }}" SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops "{{ tf_backend_enc }}"

# Edit encrypted terraform.tfvars
[arg('editor', long='editor')]
[group("terraform")]
tf-edit-tfvars editor=sops_editor: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ tf_tfvars_enc }}" ]; then
        echo "{{ _sops_red }}Error: {{ tf_tfvars_enc }} not found{{ _sops_nc }}"
        echo ""
        echo "Create and encrypt first: just tf-encrypt-tfvars"
        exit 1
    fi
    echo "{{ _sops_blue }}==> Editing {{ tf_tfvars_enc }}{{ _sops_nc }}"
    EDITOR="{{ editor }}" SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops "{{ tf_tfvars_enc }}"

# Validate encrypted Terraform files
[group("terraform")]
tf-sops-validate: sops-check-deps sops-check-config
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Validating Terraform encrypted files...{{ _sops_nc }}"
    if [ ! -f "{{ sops_age_key_file }}" ]; then
        echo "{{ _sops_red }}Error: Private key not found: {{ sops_age_key_file }}{{ _sops_nc }}"
        exit 1
    fi
    failed=0
    count=0
    for file in "{{ tf_backend_enc }}" "{{ tf_tfvars_enc }}"; do
        if [ -f "$file" ]; then
            count=$((count + 1))
            if SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops -d "$file" > /dev/null 2>&1; then
                echo "  [{{ _sops_ok }}] $file"
            else
                echo "  [{{ _sops_fail }}] $file"
                failed=$((failed + 1))
            fi
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
# Utility Operations
# ============================================================================

# Show Terraform outputs
[group("terraform")]
tf-output:
    @echo "{{ _sops_blue }}==> Terraform Outputs{{ _sops_nc }}"
    @terraform output

# Remove .terraform directory and local state
[group("terraform")]
tf-clean:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_yellow }}==> Cleaning Terraform files{{ _sops_nc }}"
    rm -rf .terraform .terraform.lock.hcl
    rm -f terraform.tfstate terraform.tfstate.backup
    if [ -d "{{ tf_generated_dir }}" ]; then
        rm -rf "{{ tf_generated_dir }}"
        echo "  Removed: {{ tf_generated_dir }}/"
    fi
    echo "{{ _sops_green }}==> Clean complete{{ _sops_nc }}"

# Upgrade Terraform providers
[group("terraform")]
tf-upgrade:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}==> Upgrading Terraform providers{{ _sops_nc }}"
    if [ -f "{{ tf_backend_enc }}" ]; then
        echo "{{ _sops_blue }}==> Using encrypted backend: {{ tf_backend_enc }}{{ _sops_nc }}"
        SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops exec-file "{{ tf_backend_enc }}" 'terraform init -upgrade -backend-config={}'
    elif [ -f "{{ tf_backend_hcl }}" ]; then
        echo "{{ _sops_yellow }}==> Using plaintext backend: {{ tf_backend_hcl }}{{ _sops_nc }}"
        terraform init -upgrade -backend-config="{{ tf_backend_hcl }}"
    else
        echo "{{ _sops_yellow }}==> No backend config, using local state{{ _sops_nc }}"
        terraform init -upgrade
    fi

# Show Terraform + SOPS setup workflow
[group("terraform")]
tf-workflow:
    #!/usr/bin/env bash
    set -euo pipefail
    echo ""
    echo "{{ _sops_bold }}Terraform + SOPS Setup Workflow{{ _sops_nc }}"
    echo "========================================"
    echo ""
    echo "{{ _sops_yellow }}1. Initial Setup:{{ _sops_nc }}"
    echo "   just sops-keygen          # Generate age key"
    echo "   # Update .sops.yaml with public key"
    echo ""
    echo "{{ _sops_yellow }}2. Backend Configuration:{{ _sops_nc }}"
    echo "   cp {{ tf_backend_example }} {{ tf_backend_hcl }}"
    echo "   # Edit {{ tf_backend_hcl }} with credentials"
    echo "   just tf-encrypt-backend"
    echo "   rm {{ tf_backend_hcl }}"
    echo ""
    echo "{{ _sops_yellow }}3. Variables Configuration:{{ _sops_nc }}"
    echo "   cp {{ tf_tfvars_example }} {{ tf_tfvars_plain }}"
    echo "   # Edit {{ tf_tfvars_plain }} with secrets"
    echo "   just tf-encrypt-tfvars"
    echo "   rm {{ tf_tfvars_plain }}"
    echo ""
    echo "{{ _sops_yellow }}4. Daily Usage:{{ _sops_nc }}"
    echo "   just tf-init     # Auto-decrypts backend"
    echo "   just tf-plan     # Auto-decrypts tfvars"
    echo "   just tf-apply    # Auto-decrypts tfvars"
    echo ""
