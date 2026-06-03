# ============================================================================
# helm.just - Unified Helm Operations
# ============================================================================
# Shared justfile include for standardized Helm chart management operations.
#
# Usage:
#   Import this file in your domain justfile after sops.just:
#     import '../../../makefiles/sops.just'
#     import '../../../makefiles/helm.just'
#
# Required variables (from consumer justfile):
#   kubeconfig       - Path to kubeconfig file
#
# Optional variables (override via environment):
#   HELM_DEFAULT_NS  - Default namespace (default: default)
#   HELM_WAIT        - Wait for resources (default: true)
#   HELM_TIMEOUT     - Operation timeout (default: 5m)
#   HELM_ATOMIC      - Rollback on failure (default: false)
# ============================================================================

# ============================================================================
# Configuration
# ============================================================================

helm_default_ns := env("HELM_DEFAULT_NS", "default")
helm_wait := env("HELM_WAIT", "true")
helm_timeout := env("HELM_TIMEOUT", "5m")
helm_atomic := env("HELM_ATOMIC", "false")

# Pre-configured chart repositories (prefix|name|url)
[private]
helm_known_repos := "cilium|cilium|https://helm.cilium.io/ jetstack|jetstack|https://charts.jetstack.io ingress-nginx|ingress-nginx|https://kubernetes.github.io/ingress-nginx prometheus-community|prometheus-community|https://prometheus-community.github.io/helm-charts grafana|grafana|https://grafana.github.io/helm-charts bitnami|bitnami|https://charts.bitnami.com/bitnami argo|argo|https://argoproj.github.io/argo-helm openebs|openebs|https://openebs.github.io/openebs longhorn|longhorn|https://charts.longhorn.io metallb|metallb|https://metallb.github.io/metallb traefik|traefik|https://traefik.github.io/charts hashicorp|hashicorp|https://helm.releases.hashicorp.com external-secrets|external-secrets|https://charts.external-secrets.io"

# ============================================================================
# Validation
# ============================================================================

# Verify helm is installed
[group("helm")]
helm-check-deps:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v helm >/dev/null 2>&1; then
        echo "{{ _sops_red }}Error: helm is not installed{{ _sops_nc }}"
        echo "Install: brew install helm"
        exit 1
    fi
    echo "  [{{ _sops_ok }}] helm: $(helm version --short)"

# ============================================================================
# Repository Management
# ============================================================================

# Add a Helm repository
[group("helm")]
helm-repo-add repo url: helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Adding Helm repository: {{ repo }}{{ _sops_nc }}"
    helm repo add {{ repo }} {{ url }}
    helm repo update
    echo "{{ _sops_green }}Repository {{ repo }} added{{ _sops_nc }}"

# Update all Helm repositories
[group("helm")]
helm-repo-update: helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_blue }}Updating Helm repositories...{{ _sops_nc }}"
    helm repo update
    echo "{{ _sops_green }}Repositories updated{{ _sops_nc }}"

# List configured Helm repositories
[group("helm")]
helm-repo-list: helm-check-deps
    @echo "{{ _sops_blue }}Configured Helm repositories:{{ _sops_nc }}"
    @helm repo list

# ============================================================================
# Chart Operations
# ============================================================================

# Install/upgrade a Helm chart (chart values [ns] [version])
[group("helm")]
helm-install chart values ns="" version="": helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ values }}" ]; then
        echo "{{ _sops_red }}Error: values file not found: {{ values }}{{ _sops_nc }}"
        exit 1
    fi
    export KUBECONFIG={{ kubeconfig }}
    NAMESPACE="{{ if ns != "" { ns } else { helm_default_ns } }}"
    CHART_NAME="{{ chart }}"
    REPO_NAME=""
    CHART_REF=""
    RELEASE_NAME=""
    if echo "$CHART_NAME" | grep -q "/"; then
        REPO_NAME=$(echo "$CHART_NAME" | cut -d'/' -f1)
        RELEASE_NAME=$(echo "$CHART_NAME" | cut -d'/' -f2)
        CHART_REF="$CHART_NAME"
    else
        REPO_NAME="$CHART_NAME"
        RELEASE_NAME="$CHART_NAME"
        CHART_REF="$CHART_NAME/$CHART_NAME"
    fi
    REPO_URL=$(echo "{{ helm_known_repos }}" | tr ' ' '\n' | grep "^$REPO_NAME|" | cut -d'|' -f3 || true)
    if [ -n "$REPO_URL" ]; then
        echo "{{ _sops_blue }}==> Adding repository: $REPO_NAME{{ _sops_nc }}"
        helm repo add "$REPO_NAME" "$REPO_URL" 2>/dev/null || true
        helm repo update "$REPO_NAME"
    else
        echo "{{ _sops_yellow }}==> Repository $REPO_NAME not pre-configured, assuming already added{{ _sops_nc }}"
    fi
    VERSION_FLAG=""
    if [ -n "{{ version }}" ]; then
        VERSION_FLAG="--version {{ version }}"
    fi
    WAIT_FLAG=""
    if [ "{{ helm_wait }}" = "true" ]; then
        WAIT_FLAG="--wait --timeout {{ helm_timeout }}"
    fi
    ATOMIC_FLAG=""
    if [ "{{ helm_atomic }}" = "true" ]; then
        ATOMIC_FLAG="--atomic"
    fi
    echo "{{ _sops_blue }}Installing Helm chart...{{ _sops_nc }}"
    echo "  Chart:     $CHART_REF"
    echo "  Release:   $RELEASE_NAME"
    echo "  Namespace: $NAMESPACE"
    echo "  Values:    {{ values }}"
    if [ -n "{{ version }}" ]; then echo "  Version:   {{ version }}"; fi
    echo ""
    helm upgrade --install "$RELEASE_NAME" "$CHART_REF" \
        --namespace "$NAMESPACE" \
        --create-namespace \
        --values "{{ values }}" \
        $VERSION_FLAG \
        $WAIT_FLAG \
        $ATOMIC_FLAG && \
    echo "{{ _sops_green }}Chart $RELEASE_NAME installed in $NAMESPACE{{ _sops_nc }}" || \
    (echo "{{ _sops_red }}Chart installation failed{{ _sops_nc }}"; exit 1)

# Upgrade a Helm release (alias for helm-install)
[group("helm")]
helm-upgrade chart values ns="" version="": helm-check-deps
    @just helm-install "{{ chart }}" "{{ values }}" "{{ ns }}" "{{ version }}"

# Uninstall a Helm release
[group("helm")]
helm-uninstall release ns="": helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    export KUBECONFIG={{ kubeconfig }}
    NAMESPACE="{{ if ns != "" { ns } else { helm_default_ns } }}"
    echo "{{ _sops_yellow }}Uninstalling Helm release: {{ release }} from $NAMESPACE{{ _sops_nc }}"
    helm uninstall "{{ release }}" --namespace "$NAMESPACE" && \
    echo "{{ _sops_green }}Release {{ release }} uninstalled{{ _sops_nc }}" || \
    (echo "{{ _sops_red }}Uninstall failed{{ _sops_nc }}"; exit 1)

# Rollback a Helm release
[group("helm")]
helm-rollback release ns="" revision="0": helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    export KUBECONFIG={{ kubeconfig }}
    NAMESPACE="{{ if ns != "" { ns } else { helm_default_ns } }}"
    echo "{{ _sops_yellow }}Rolling back Helm release: {{ release }} in $NAMESPACE{{ _sops_nc }}"
    helm rollback "{{ release }}" "{{ revision }}" --namespace "$NAMESPACE" && \
    echo "{{ _sops_green }}Release {{ release }} rolled back{{ _sops_nc }}" || \
    (echo "{{ _sops_red }}Rollback failed{{ _sops_nc }}"; exit 1)

# ============================================================================
# Status & Information
# ============================================================================

# List installed Helm releases ([ns])
[group("helm")]
helm-list ns="all": helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    export KUBECONFIG={{ kubeconfig }}
    if [ "{{ ns }}" = "all" ]; then
        echo "{{ _sops_blue }}All Helm releases:{{ _sops_nc }}"
        helm list --all-namespaces
    else
        echo "{{ _sops_blue }}Helm releases in {{ ns }}:{{ _sops_nc }}"
        helm list --namespace "{{ ns }}"
    fi

# Show status of a Helm release
[group("helm")]
helm-status release ns="": helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    export KUBECONFIG={{ kubeconfig }}
    NAMESPACE="{{ if ns != "" { ns } else { helm_default_ns } }}"
    echo "{{ _sops_blue }}Status of {{ release }} in $NAMESPACE:{{ _sops_nc }}"
    helm status "{{ release }}" --namespace "$NAMESPACE"

# Show release history
[group("helm")]
helm-history release ns="": helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    export KUBECONFIG={{ kubeconfig }}
    NAMESPACE="{{ if ns != "" { ns } else { helm_default_ns } }}"
    echo "{{ _sops_blue }}History of {{ release }} in $NAMESPACE:{{ _sops_nc }}"
    helm history "{{ release }}" --namespace "$NAMESPACE"

# Show values of a Helm release
[group("helm")]
helm-values release ns="": helm-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    export KUBECONFIG={{ kubeconfig }}
    NAMESPACE="{{ if ns != "" { ns } else { helm_default_ns } }}"
    helm get values "{{ release }}" --namespace "$NAMESPACE"

# ============================================================================
# Search & Discovery
# ============================================================================

# Search for Helm charts
[group("helm")]
helm-search query: helm-check-deps
    @echo "{{ _sops_blue }}Searching for: {{ query }}{{ _sops_nc }}"
    @helm search repo "{{ query }}"

# Show default values for a chart
[group("helm")]
helm-show-values chart: helm-check-deps
    @helm show values "{{ chart }}"
