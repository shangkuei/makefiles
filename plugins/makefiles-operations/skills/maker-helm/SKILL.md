---
name: maker-helm
description: Scaffold or guide Helm chart management using the shared helm.mk Makefile include. Use when setting up Helm operations, installing charts, or managing releases in a project that uses the shared makefiles submodule.
---

# Helm Makefile Setup & Guide

You are helping the user work with the shared `helm.mk` Makefile include for Helm chart management with pre-configured repositories.

## Step 1: Read the reference

Find the makefiles submodule and read `helm.mk` to understand available targets, variables, and pre-configured repositories.

## Step 2: Detect current state

Check the current directory:
- Does a `Makefile` exist?
- If yes, does it include `sops.mk` AND `helm.mk`? (helm.mk depends on sops.mk for color definitions)
- Is `KUBECONFIG` set or defined?
- Are there values files (`*-values.yaml`, `values.yaml`)?

## Step 3: Act based on state

### If no Makefile exists: Scaffold

Ask the user for:
1. `SOPS_DOMAIN` and `SOPS_ENV_NAME` (for sops.mk)
2. `KUBECONFIG` path
3. Optional: `HELM_WAIT`, `HELM_TIMEOUT`, `HELM_ATOMIC` overrides

Then create a Makefile:

```makefile
SOPS_DOMAIN := <domain>
SOPS_ENV_NAME := <env-name>
KUBECONFIG := <path-to-kubeconfig>

include <relative-path>/makefiles/sops.mk
include <relative-path>/makefiles/helm.mk

# Chart-specific targets below...
```

**Include order is critical**: `sops.mk` MUST come before `helm.mk`.

### If Makefile exists with helm.mk: Guide

Show the user:
1. Current configuration (kubeconfig, wait, timeout, atomic)
2. Available targets grouped by category:
   - **Repos**: `helm-repo-add`, `helm-repo-update`, `helm-repo-list`
   - **Charts**: `helm-install`, `helm-upgrade`, `helm-uninstall`, `helm-rollback`
   - **Status**: `helm-list`, `helm-status`, `helm-history`, `helm-values`
   - **Search**: `helm-search`, `helm-show-values`
   - **Checks**: `helm-check-deps`, `helm-check-kubeconfig`, `helm-help`
3. Pre-configured repositories: cilium, jetstack, ingress-nginx, prometheus-community, grafana, bitnami, argo, openebs, longhorn, metallb, traefik, hashicorp, external-secrets
4. Example usage:
   - `make helm-install chart=cilium values=cilium-values.yaml ns=kube-system`
   - `make helm-install chart=jetstack/cert-manager values=cm.yaml ns=cert-manager version=1.14.0`
   - `make helm-list ns=all`

### If Makefile exists without helm.mk: Add includes

Help add both `sops.mk` and `helm.mk` includes (in correct order) with required variables.
