---
name: task-sops
description: Scaffold or guide SOPS secret management using the shared sops.mk/sops.just includes. Use when setting up SOPS encryption, managing age keys, or working with encrypted secrets in a project that uses the shared makefiles submodule.
---

# SOPS Setup & Guide

You are helping the user work with the shared `sops.mk` / `sops.just` includes for SOPS secret management with age encryption.

## Step 1: Read the reference

- Find the makefiles submodule (look for `sops.mk` or `sops.just` via common paths: `makefiles/`, `../makefiles/`, `../../makefiles/`, `../../../makefiles/`)
- Read the appropriate file (`sops.mk` or `sops.just`) to understand available targets and variables
- Read the sops.mk Reference section from the makefiles `README.md`

## Step 2: Detect current state

Check the current directory:

- Does a `justfile` exist? → use **just** format
- Does a `Makefile` exist? → use **make** format
- If the chosen file exists, does it already include/import `sops.mk` / `sops.just`?
- What are the current `SOPS_DOMAIN` / `sops_domain` and `SOPS_ENV_NAME` / `sops_env_name` values?
- Does a `.sops.yaml` exist?
- Does an age key exist?

## Step 3: Act based on state

### If no Makefile/justfile exists: Scaffold

Ask the user for:

1. **Format preference**: `Makefile` or `justfile`
2. `SOPS_DOMAIN` / `sops_domain` (terraform, kubernetes, or docker)
3. `SOPS_ENV_NAME` / `sops_env_name` (environment name for key naming)
4. `SOPS_KEY_STRATEGY` / `sops_key_strategy` (central or local)

Then create the appropriate file:

**Makefile format:**

```makefile
SOPS_DOMAIN := <domain>
SOPS_ENV_NAME := <env-name>
SOPS_KEY_STRATEGY := <strategy>

include <relative-path>/makefiles/sops.mk

# Domain-specific targets below...
```

**Justfile format:**

```just
set shell := ["bash", "-euo", "pipefail", "-c"]

sops_domain := "<domain>"
sops_env_name := "<env-name>"

import '<relative-path>/makefiles/sops.just'

# Domain-specific recipes below...
```

Note: For justfile, `sops_key_strategy` defaults to `"central"`. Override via env: `SOPS_KEY_STRATEGY=local just <recipe>`.

Determine the correct relative path based on the directory depth from the makefiles submodule.

### If Makefile/justfile exists with sops include: Guide

Show the user:

1. Current configuration (domain, env name, strategy, key file path)
2. Available targets grouped by tier:
   - **Universal**: `sops-check-deps`, `sops-check-config`, `sops-info`, `sops-validate`
   - **Key Management**: `sops-keygen`, `sops-init-config`, `sops-import-key`, `sops-export-public`, `sops-rotate-key`
   - **Operations**: encrypt, decrypt, edit, rekey, clean
3. Command syntax based on detected format:
   - Make: `make sops-encrypt FILE=path`
   - Just: `just sops-encrypt path`
4. Suggest next actions based on what's missing (no key? suggest keygen. no .sops.yaml? suggest init-config)

### If Makefile/justfile exists without sops include: Add include

Help add the sops include to the existing file with required variables, using the appropriate format.
