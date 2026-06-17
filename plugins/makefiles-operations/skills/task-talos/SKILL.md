---
name: task-talos
description: Scaffold or guide Talos cluster operations using the shared talos.mk/talos.just includes. Use when deploying, managing, or troubleshooting Talos Linux Kubernetes clusters in a project that uses the shared makefiles submodule.
---

# Talos Setup & Guide

You are helping the user work with the shared `talos.mk` / `talos.just` includes for Talos Linux cluster deployment and operations.

## Step 1: Read the reference

Find the makefiles submodule and read `talos.mk` or `talos.just` to understand available targets and variables.

## Step 2: Detect current state

Check the current directory:

- Does a `justfile` exist? → use **just** format
- Does a `Makefile` exist? → use **make** format
- If the chosen file exists, does it include/import `sops`, `terraform`, AND `talos` modules? (talos requires both)
- Does a `generated/` directory exist with talosconfig/kubeconfig?
- Is there Terraform state? (already deployed?)

## Step 3: Act based on state

### If no Makefile/justfile exists: Scaffold

Ask the user for:

1. **Format preference**: `Makefile` or `justfile`
2. `SOPS_ENV_NAME` / `sops_env_name` (e.g., `talos-cluster-dev`)

Then create the appropriate file:

**Makefile format:**

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := <env-name>
SOPS_KEY_STRATEGY := central

include <relative-path>/makefiles/sops.mk
include <relative-path>/makefiles/terraform.mk
include <relative-path>/makefiles/talos.mk

# Cluster-specific targets below...
```

**Justfile format:**

```just
set shell := ["bash", "-euo", "pipefail", "-c"]

sops_domain := "terraform"
sops_env_name := "<env-name>"

import '<relative-path>/makefiles/sops.just'
import '<relative-path>/makefiles/terraform.just'
import '<relative-path>/makefiles/talos.just'

# Cluster-specific recipes below...
```

**Import order is critical**: `sops` → `terraform` → `talos`.

### If Makefile/justfile exists with talos include: Guide

Show the user:

1. Current configuration (generated dir, talosconfig, kubeconfig, timeout)
2. Available targets grouped by category:
   - **Deployment**: `talos-apply`, `talos-bootstrap`
   - **Access**: `talos-kubeconfig`, `talos-talosconfig`, `talos-env`
   - **Status**: `talos-health`, `talos-nodes`, `talos-pods`, `talos-status`
   - **Maintenance**: `talos-upgrade-k8s`, `talos-upgrade`, `talos-dashboard`, `talos-logs`, `talos-reboot`, `talos-reset`
3. Command syntax based on detected format:
   - Make: `make talos-apply NODE=foo INSECURE=true MODE=auto`
   - Just: `just talos-apply foo --insecure --mode=auto` (node positional; extra flags pass through to talosctl)
4. Typical deployment workflow:
   1. `tf-init` → `tf-plan` → `tf-apply`
   2. `talos-apply` with insecure for initial setup
   3. `talos-bootstrap`
   4. `talos-kubeconfig`
   5. `talos-health`
5. Suggest next actions based on state

### If Makefile/justfile exists without talos include: Add includes

Help add `sops`, `terraform`, and `talos` includes (in correct order) with required variables.
