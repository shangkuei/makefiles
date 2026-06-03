---
name: maker-talos
description: Scaffold or guide Talos cluster operations using the shared talos.mk Makefile include. Use when deploying, managing, or troubleshooting Talos Linux Kubernetes clusters in a project that uses the shared makefiles submodule.
---

# Talos Makefile Setup & Guide

You are helping the user work with the shared `talos.mk` Makefile include for Talos Linux cluster deployment and operations.

## Step 1: Read the reference

Find the makefiles submodule and read `talos.mk` to understand available targets and variables.

## Step 2: Detect current state

Check the current directory:
- Does a `Makefile` exist?
- If yes, does it include `sops.mk`, `terraform.mk`, AND `talos.mk`? (talos.mk requires both)
- Does a `generated/` directory exist with talosconfig/kubeconfig?
- Is there Terraform state? (already deployed?)

## Step 3: Act based on state

### If no Makefile exists: Scaffold

Ask the user for:
1. `SOPS_ENV_NAME` (environment name, e.g., `talos-cluster-dev`)
2. `SOPS_KEY_STRATEGY` (default: `central`)
3. Optional: `TALOS_WAIT_TIMEOUT` override

Then create a Makefile:

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := <env-name>
SOPS_KEY_STRATEGY := central

include <relative-path>/makefiles/sops.mk
include <relative-path>/makefiles/terraform.mk
include <relative-path>/makefiles/talos.mk

# Cluster-specific targets below...
```

**Include order is critical**: `sops.mk` → `terraform.mk` → `talos.mk`.

### If Makefile exists with talos.mk: Guide

Show the user:
1. Current configuration (generated dir, talosconfig, kubeconfig, timeout)
2. Available targets grouped by category:
   - **Deployment**: `talos-apply`, `talos-bootstrap`
   - **Access**: `talos-kubeconfig`, `talos-talosconfig`, `talos-env`
   - **Status**: `talos-health`, `talos-nodes`, `talos-pods`, `talos-status`
   - **Maintenance**: `talos-upgrade-k8s`, `talos-upgrade`, `talos-dashboard`, `talos-logs`, `talos-reboot`, `talos-reset`
   - **Help**: `talos-help`
3. Typical deployment workflow:
   1. `make tf-init` → `make tf-plan` → `make tf-apply`
   2. `make talos-apply INSECURE=true` (initial setup)
   3. `make talos-bootstrap`
   4. `make talos-kubeconfig`
   5. `make talos-health`
4. Suggest next actions based on state

### If Makefile exists without talos.mk: Add includes

Help add `sops.mk`, `terraform.mk`, and `talos.mk` includes (in correct order) with required variables.
