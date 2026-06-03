---
name: maker-terraform
description: Scaffold or guide Terraform operations using the shared terraform.mk Makefile include. Use when setting up Terraform with SOPS-encrypted backends and tfvars, or running Terraform operations in a project that uses the shared makefiles submodule.
---

# Terraform Makefile Setup & Guide

You are helping the user work with the shared `terraform.mk` Makefile include for Terraform operations with SOPS-encrypted backends and tfvars.

## Step 1: Read the reference

Find the makefiles submodule and read `terraform.mk` to understand available targets, variables, and helper functions.

## Step 2: Detect current state

Check the current directory:
- Does a `Makefile` exist?
- If yes, does it include `sops.mk` AND `terraform.mk`? (terraform.mk requires sops.mk)
- What are the current variable values?
- Do encrypted files exist? (`*.enc`, `backend.hcl.enc`, `terraform.tfvars.enc`)
- Does a `.terraform` directory exist? (already initialized?)

## Step 3: Act based on state

### If no Makefile exists: Scaffold

Ask the user for:
1. `SOPS_DOMAIN` (default: `terraform`)
2. `SOPS_ENV_NAME` (environment name)
3. `SOPS_KEY_STRATEGY` (default: `central`)
4. Whether to override default encrypted filenames

Then create a Makefile:

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := <env-name>
SOPS_KEY_STRATEGY := central

include <relative-path>/makefiles/sops.mk
include <relative-path>/makefiles/terraform.mk

# Environment-specific targets below...
```

**Include order is critical**: `sops.mk` MUST come before `terraform.mk`.

### If Makefile exists with terraform.mk: Guide

Show the user:
1. Current configuration
2. Available targets grouped by category:
   - **Core**: `tf-init`, `tf-plan`, `tf-apply`, `tf-destroy`, `tf-output`, `tf-clean`
   - **Validation**: `tf-validate`, `tf-fmt`, `tf-lint`
   - **SOPS**: `tf-encrypt-backend`, `tf-encrypt-tfvars`, `tf-edit-backend`, `tf-edit-tfvars`, `tf-sops-validate`
   - **Utilities**: `tf-upgrade`, `tf-workflow`, `tf-help`
3. Suggest next actions:
   - No key? → `make sops-keygen`
   - No encrypted backend? → `make tf-encrypt-backend`
   - No encrypted tfvars? → `make tf-encrypt-tfvars`
   - Not initialized? → `make tf-init`
   - Show `make tf-workflow` for full setup guide

### If Makefile exists without terraform.mk: Add includes

Help add both `sops.mk` and `terraform.mk` includes (in correct order) with required variables.
