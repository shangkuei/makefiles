---
name: task-helm
description: Scaffold or guide Helm chart management using the shared helm.mk/helm.just includes. Use when setting up Helm operations, installing charts, or managing releases in a project that uses the shared makefiles submodule.
---

# Helm Setup & Guide

You are helping the user work with the shared `helm.mk` / `helm.just` includes for Helm chart management with pre-configured repositories.

## Step 1: Read the reference

Find the makefiles submodule and read `helm.mk` or `helm.just` to understand available targets, variables, and pre-configured repositories.

## Step 2: Detect current state

Check the current directory:

- Does a `justfile` exist? → use **just** format
- Does a `Makefile` exist? → use **make** format
- If the chosen file exists, does it include/import both `sops` AND `helm` modules? (helm depends on sops for color definitions)
- Is `KUBECONFIG` / `kubeconfig` set or defined?
- Are there values files (`*-values.yaml`, `values.yaml`)?

## Step 3: Act based on state

### If no Makefile/justfile exists: Scaffold

Ask the user for:

1. **Format preference**: `Makefile` or `justfile`
2. `SOPS_DOMAIN` / `sops_domain` and `SOPS_ENV_NAME` / `sops_env_name` (for sops module)
3. `KUBECONFIG` / `kubeconfig` path

Then create the appropriate file:

**Makefile format:**

```makefile
SOPS_DOMAIN := <domain>
SOPS_ENV_NAME := <env-name>
KUBECONFIG := <path-to-kubeconfig>

include <relative-path>/makefiles/sops.mk
include <relative-path>/makefiles/helm.mk

# Chart-specific targets below...
```

**Justfile format:**

```just
set shell := ["bash", "-euo", "pipefail", "-c"]

sops_domain := "<domain>"
sops_env_name := "<env-name>"
kubeconfig := "<path-to-kubeconfig>"

import '<relative-path>/makefiles/sops.just'
import '<relative-path>/makefiles/helm.just'

# Chart-specific recipes below...
```

**Import order is critical**: `sops` MUST come before `helm`.

### If Makefile/justfile exists with helm include: Guide

Show the user:

1. Current configuration (kubeconfig, wait, timeout, atomic)
2. Available targets grouped by category:
   - **Repos**: `helm-repo-add`, `helm-repo-update`, `helm-repo-list`
   - **Charts**: `helm-install`, `helm-upgrade`, `helm-uninstall`, `helm-rollback`
   - **Status**: `helm-list`, `helm-status`, `helm-history`, `helm-values`
   - **Search**: `helm-search`, `helm-show-values`
   - **Checks**: `helm-check-deps`
3. Command syntax based on detected format:
   - Make: `make helm-install chart=cilium values=v.yaml ns=kube-system version=1.16.0`
   - Just: `just helm-install cilium v.yaml kube-system 1.16.0`
4. Pre-configured repositories: cilium, jetstack, ingress-nginx, prometheus-community, grafana, bitnami, argo, openebs, longhorn, metallb, traefik, hashicorp, external-secrets

### If Makefile/justfile exists without helm include: Add includes

Help add both `sops` and `helm` includes (in correct order) with required variables.
