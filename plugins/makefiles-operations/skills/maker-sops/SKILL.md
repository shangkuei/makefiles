---
name: maker-sops
description: Scaffold or guide SOPS secret management using the shared sops.mk Makefile include. Use when setting up SOPS encryption, managing age keys, or working with encrypted secrets in a project that uses the shared makefiles submodule.
---

# SOPS Makefile Setup & Guide

You are helping the user work with the shared `sops.mk` Makefile include for SOPS secret management with age encryption.

## Step 1: Read the reference

- Find the makefiles submodule (look for `sops.mk` via common paths: `makefiles/`, `../makefiles/`, `../../makefiles/`, `../../../makefiles/`)
- Read `sops.mk` to understand available targets and variables
- Read the sops.mk Reference section from the makefiles `README.md`

## Step 2: Detect current state

Check the current directory:
- Does a `Makefile` exist?
- If yes, does it already include `sops.mk`?
- What are the current `SOPS_DOMAIN` and `SOPS_ENV_NAME` values?
- Does a `.sops.yaml` exist?
- Does an age key exist?

## Step 3: Act based on state

### If no Makefile exists: Scaffold

Ask the user for:
1. `SOPS_DOMAIN` (terraform, kubernetes, or docker)
2. `SOPS_ENV_NAME` (environment name for key naming)
3. `SOPS_KEY_STRATEGY` (central or local)

Then create a Makefile:

```makefile
SOPS_DOMAIN := <domain>
SOPS_ENV_NAME := <env-name>
SOPS_KEY_STRATEGY := <strategy>

include <relative-path>/makefiles/sops.mk

# Domain-specific targets below...
```

Determine the correct relative include path based on the directory depth from the makefiles submodule.

### If Makefile exists with sops.mk: Guide

Show the user:
1. Current configuration (domain, env name, strategy, key file path)
2. Available targets grouped by tier:
   - **Universal**: `sops-help`, `sops-check-deps`, `sops-check-config`, `sops-info`, `sops-validate`
   - **Key Management**: `sops-keygen`, `sops-init-config`, `sops-import-key`, `sops-export-public`, `sops-rotate-key`
   - **Operations**: `sops-encrypt FILE=`, `sops-decrypt FILE=`, `sops-edit FILE=`, `sops-rekey FILE=`, `sops-clean`
3. Suggest next actions based on what's missing (no key? suggest keygen. no .sops.yaml? suggest init-config)

### If Makefile exists without sops.mk: Add include

Help add the sops.mk include to the existing Makefile with required variables.
