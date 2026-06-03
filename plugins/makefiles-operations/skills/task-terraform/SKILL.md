---
name: task-terraform
description: Scaffold or guide Terraform operations using the shared terraform.mk/terraform.just includes. Use when setting up Terraform with SOPS-encrypted backends and tfvars, or running Terraform operations in a project that uses the shared makefiles submodule.
---

# Terraform Setup & Guide

You are helping the user work with the shared `terraform.mk` / `terraform.just` includes for Terraform operations with SOPS-encrypted backends and tfvars.

## Step 1: Read the reference

Find the makefiles submodule and read `terraform.mk` or `terraform.just` to understand available targets, variables, and helper functions.

## Step 2: Detect current state

Check the current directory:

- Does a `justfile` exist? → use **just** format
- Does a `Makefile` exist? → use **make** format
- If the chosen file exists, does it include/import both `sops` AND `terraform` modules? (terraform requires sops)
- What are the current variable values?
- Do encrypted files exist? (`*.enc`, `backend.hcl.enc`, `terraform.tfvars.enc`)
- Does a `.terraform` directory exist? (already initialized?)

## Step 3: Act based on state

### If no Makefile/justfile exists: Scaffold

Ask the user for:

1. **Format preference**: `Makefile` or `justfile`
2. `SOPS_ENV_NAME` / `sops_env_name` (environment name)
3. Whether to override default encrypted filenames

Then create the appropriate file:

**Makefile format:**

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := <env-name>
SOPS_KEY_STRATEGY := central

include <relative-path>/makefiles/sops.mk
include <relative-path>/makefiles/terraform.mk

# Environment-specific targets below...
```

**Justfile format:**

```just
set shell := ["bash", "-euo", "pipefail", "-c"]

sops_domain := "terraform"
sops_env_name := "<env-name>"

import '<relative-path>/makefiles/sops.just'
import '<relative-path>/makefiles/terraform.just'

# Environment-specific recipes below...
```

**Import order is critical**: `sops` MUST come before `terraform`.

### If Makefile/justfile exists with terraform include: Guide

Show the user:

1. Current configuration
2. Available targets grouped by category:
   - **Core**: `tf-init`, `tf-plan`, `tf-apply`, `tf-destroy`, `tf-output`, `tf-clean`
   - **Validation**: `tf-validate`, `tf-fmt`, `tf-lint`
   - **SOPS**: `tf-encrypt-backend`, `tf-encrypt-tfvars`, `tf-edit-backend`, `tf-edit-tfvars`, `tf-sops-validate`
   - **Utilities**: `tf-upgrade`, `tf-workflow`
3. Command syntax based on detected format:
   - Make: `make tf-plan` (extra args not supported)
   - Just: `just tf-plan -target=module.foo` (supports extra args)
4. Suggest next actions:
   - No key? → keygen
   - No encrypted backend? → encrypt-backend
   - No encrypted tfvars? → encrypt-tfvars
   - Not initialized? → tf-init
   - Show tf-workflow for full setup guide

### If Makefile/justfile exists without terraform include: Add includes

Help add both `sops` and `terraform` includes (in correct order) with required variables.
