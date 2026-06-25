# ============================================================================
# talos.just - Unified Talos Cluster Operations
# ============================================================================
# Shared justfile include for standardized Talos cluster management operations.
#
# Usage:
#   Import this file in your domain justfile after sops.just and terraform.just:
#     import '../../../makefiles/sops.just'
#     import '../../../makefiles/terraform.just'
#     import '../../../makefiles/talos.just'
#
# Optional variables (override via environment):
#   GENERATED_DIR        - Directory containing generated configs (default: generated)
#   TALOSCONFIG          - Path to talosconfig file (default: generated/talosconfig)
#   KUBECONFIG           - Path to kubeconfig file (default: generated/kubeconfig)
#   TALOS_WAIT_TIMEOUT   - Timeout for health checks (default: 10m)
# ============================================================================

# ============================================================================
# Configuration
# ============================================================================

generated_dir := env("GENERATED_DIR", "generated")
talosconfig := env("TALOSCONFIG", generated_dir / "talosconfig")
kubeconfig := env("KUBECONFIG", generated_dir / "kubeconfig")
talos_wait_timeout := env("TALOS_WAIT_TIMEOUT", "10m")

# ============================================================================
# Cluster Deployment
# ============================================================================

# Apply Talos configs (node, comma-separated nodes, or "all"; extra flags like --insecure --mode=reboot pass through to talosctl)
[group("talos")]
talos-apply nodes="all" *flags:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d "{{ generated_dir }}" ]; then
        echo "{{ _sops_red }}Error: Configuration files not generated. Run 'just tf-apply' first.{{ _sops_nc }}"
        exit 1
    fi
    if [ ! -f "{{ talosconfig }}" ]; then
        echo "{{ _sops_red }}Error: talosconfig not found. Run 'just tf-apply' first.{{ _sops_nc }}"
        exit 1
    fi
    export TALOSCONFIG="{{ talosconfig }}"
    if [ -n "{{ flags }}" ]; then
        echo "{{ _sops_yellow }}==> Passing extra talosctl flags: {{ flags }}{{ _sops_nc }}"
    fi
    apply_node() {
        local node="$1"
        local NODE_TYPE BASE_CONFIG NODE_IP OUTPUT_KEY PATCH_FILES PATCH_ARGS patch
        if [ -f "{{ generated_dir }}/control-plane-$node.yaml" ]; then
            NODE_TYPE="control-plane"
            BASE_CONFIG="{{ generated_dir }}/control-plane-$node.yaml"
        elif [ -f "{{ generated_dir }}/worker-$node.yaml" ]; then
            NODE_TYPE="worker"
            BASE_CONFIG="{{ generated_dir }}/worker-$node.yaml"
        else
            echo "{{ _sops_red }}Error: No configuration found for node '$node'{{ _sops_nc }}"
            echo "{{ _sops_yellow }}Available nodes:{{ _sops_nc }}"
            ls -1 {{ generated_dir }}/*-*.yaml 2>/dev/null | grep -E '(control-plane|worker)-[^-]+\.yaml$' | sed 's/.*\/\(control-plane\|worker\)-\(.*\)\.yaml/  \2/' | sort -u
            return 1
        fi
        echo "{{ _sops_blue }}==> Node type: $NODE_TYPE{{ _sops_nc }}"
        OUTPUT_KEY=$(echo "$NODE_TYPE" | sed 's/-/_/g')
        NODE_IP=$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"$OUTPUT_KEY\"][\"$node\"].physical_ip // \"\"" || echo "")
        if [ -z "$NODE_IP" ] || [ "$NODE_IP" = "null" ]; then
            echo "{{ _sops_yellow }}==> Could not determine node IP from terraform output{{ _sops_nc }}"
            read -p "Enter node IP address for $node: " NODE_IP
        fi
        echo "{{ _sops_blue }}==> Applying to: $NODE_IP{{ _sops_nc }}"
        echo "{{ _sops_blue }}==> Base config: $BASE_CONFIG{{ _sops_nc }}"
        PATCH_FILES=$(find {{ generated_dir }} -name "$NODE_TYPE-$node-*.yaml" ! -name "$NODE_TYPE-$node.yaml" | sort)
        PATCH_ARGS=""
        if [ -n "$PATCH_FILES" ]; then
            echo "{{ _sops_blue }}==> Patch files:{{ _sops_nc }}"
            for patch in $PATCH_FILES; do
                echo "  - $patch"
                PATCH_ARGS="$PATCH_ARGS --config-patch @$patch"
            done
        else
            echo "{{ _sops_yellow }}==> No patch files found{{ _sops_nc }}"
        fi
        if talosctl apply-config {{ flags }} --nodes "$NODE_IP" --endpoints "$NODE_IP" \
            --file "$BASE_CONFIG" $PATCH_ARGS; then
            echo "{{ _sops_green }}Configuration applied to $node{{ _sops_nc }}"
        else
            echo "{{ _sops_red }}Failed to apply configuration to $node{{ _sops_nc }}"
            return 1
        fi
    }
    if [ -n "{{ nodes }}" ] && [ "{{ nodes }}" != "all" ]; then
        rc=0
        IFS=',' read -ra TALOS_NODES <<< "{{ nodes }}"
        for n in "${TALOS_NODES[@]}"; do
            n="$(echo "$n" | xargs)"
            [ -z "$n" ] && continue
            echo "{{ _sops_blue }}Applying configuration to node: $n{{ _sops_nc }}"
            apply_node "$n" || rc=1
        done
        exit $rc
    else
        echo "{{ _sops_blue }}Applying configurations to all nodes...{{ _sops_nc }}"
        for config in {{ generated_dir }}/control-plane-*.yaml; do
            if [ -f "$config" ]; then
                BASE_NAME=$(basename "$config")
                if echo "$BASE_NAME" | grep -q '^control-plane-[^-]\+\.yaml$'; then
                    NODE_NAME=$(echo "$BASE_NAME" | sed 's/control-plane-\(.*\)\.yaml/\1/')
                    NODE_IP=$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"control_plane\"][\"$NODE_NAME\"].physical_ip // \"\"" || echo "")
                    if [ -n "$NODE_IP" ] && [ "$NODE_IP" != "null" ]; then
                        echo "{{ _sops_blue }}==> Applying to control plane node $NODE_NAME ($NODE_IP){{ _sops_nc }}"
                        PATCH_FILES=$(find {{ generated_dir }} -name "control-plane-$NODE_NAME-*.yaml" | sort)
                        PATCH_ARGS=""
                        for patch in $PATCH_FILES; do
                            PATCH_ARGS="$PATCH_ARGS --config-patch @$patch"
                        done
                        talosctl apply-config {{ flags }} --nodes "$NODE_IP" --endpoints "$NODE_IP" \
                            --file "$config" \
                            $PATCH_ARGS && \
                        echo "{{ _sops_green }}Applied to $NODE_NAME{{ _sops_nc }}" || \
                        echo "{{ _sops_red }}Failed to apply to $NODE_NAME{{ _sops_nc }}"
                    fi
                fi
            fi
        done
        for config in {{ generated_dir }}/worker-*.yaml; do
            if [ -f "$config" ]; then
                BASE_NAME=$(basename "$config")
                if echo "$BASE_NAME" | grep -q '^worker-[^-]\+\.yaml$'; then
                    NODE_NAME=$(echo "$BASE_NAME" | sed 's/worker-\(.*\)\.yaml/\1/')
                    NODE_IP=$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"worker\"][\"$NODE_NAME\"].physical_ip // \"\"" || echo "")
                    if [ -n "$NODE_IP" ] && [ "$NODE_IP" != "null" ]; then
                        echo "{{ _sops_blue }}==> Applying to worker node $NODE_NAME ($NODE_IP){{ _sops_nc }}"
                        PATCH_FILES=$(find {{ generated_dir }} -name "worker-$NODE_NAME-*.yaml" | sort)
                        PATCH_ARGS=""
                        for patch in $PATCH_FILES; do
                            PATCH_ARGS="$PATCH_ARGS --config-patch @$patch"
                        done
                        talosctl apply-config {{ flags }} --nodes "$NODE_IP" --endpoints "$NODE_IP" \
                            --file "$config" \
                            $PATCH_ARGS && \
                        echo "{{ _sops_green }}Applied to $NODE_NAME{{ _sops_nc }}" || \
                        echo "{{ _sops_red }}Failed to apply to $NODE_NAME{{ _sops_nc }}"
                    fi
                fi
            fi
        done
        echo "{{ _sops_green }}All configurations applied{{ _sops_nc }}"
    fi

# Bootstrap Kubernetes ([node])
[group("talos")]
talos-bootstrap node="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ talosconfig }}" ]; then
        echo "{{ _sops_red }}Error: talosconfig not found. Run 'just tf-apply' first.{{ _sops_nc }}"
        exit 1
    fi
    export TALOSCONFIG="{{ talosconfig }}"
    if [ -n "{{ node }}" ]; then
        BOOTSTRAP_NODE="{{ node }}"
    else
        FIRST_CP=$(terraform output -json generated_configs 2>/dev/null | jq -r '.control_plane | keys[0]' || echo "")
        if [ -z "$FIRST_CP" ]; then
            echo "{{ _sops_red }}Error: Could not determine bootstrap node{{ _sops_nc }}"
            echo "{{ _sops_yellow }}Specify manually: just talos-bootstrap <node-ip>{{ _sops_nc }}"
            exit 1
        fi
        BOOTSTRAP_NODE=$(terraform output -json generated_configs 2>/dev/null | jq -r ".control_plane[\"$FIRST_CP\"].physical_ip // \"\"" || echo "")
        if [ -z "$BOOTSTRAP_NODE" ] || [ "$BOOTSTRAP_NODE" = "null" ]; then
            echo "{{ _sops_red }}Error: Could not determine bootstrap node IP{{ _sops_nc }}"
            echo "{{ _sops_yellow }}Specify manually: just talos-bootstrap <node-ip>{{ _sops_nc }}"
            exit 1
        fi
        echo "{{ _sops_blue }}==> Using first control plane node: $FIRST_CP ($BOOTSTRAP_NODE){{ _sops_nc }}"
    fi
    echo "{{ _sops_blue }}Bootstrapping Kubernetes cluster on $BOOTSTRAP_NODE...{{ _sops_nc }}"
    talosctl bootstrap --nodes "$BOOTSTRAP_NODE" --endpoints "$BOOTSTRAP_NODE" && \
    echo "{{ _sops_green }}Cluster bootstrapped successfully{{ _sops_nc }}" || \
    (echo "{{ _sops_red }}Bootstrap failed{{ _sops_nc }}"; exit 1)

# ============================================================================
# Cluster Access
# ============================================================================

# Retrieve kubeconfig ([node])
[group("talos")]
talos-kubeconfig node="":
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ talosconfig }}" ]; then
        echo "{{ _sops_red }}Error: talosconfig not found. Run 'just tf-apply' first.{{ _sops_nc }}"
        exit 1
    fi
    export TALOSCONFIG="{{ talosconfig }}"
    if [ -n "{{ node }}" ]; then
        KUBECONFIG_NODE="{{ node }}"
    else
        FIRST_CP=$(terraform output -json generated_configs 2>/dev/null | jq -r '.control_plane | keys[0]' || echo "")
        if [ -z "$FIRST_CP" ]; then
            echo "{{ _sops_red }}Error: Could not determine control plane node{{ _sops_nc }}"
            echo "{{ _sops_yellow }}Specify manually: just talos-kubeconfig <node-ip>{{ _sops_nc }}"
            exit 1
        fi
        KUBECONFIG_NODE=$(terraform output -json generated_configs 2>/dev/null | jq -r ".control_plane[\"$FIRST_CP\"].physical_ip // \"\"" || echo "")
        if [ -z "$KUBECONFIG_NODE" ] || [ "$KUBECONFIG_NODE" = "null" ]; then
            echo "{{ _sops_red }}Error: Could not determine control plane node IP{{ _sops_nc }}"
            echo "{{ _sops_yellow }}Specify manually: just talos-kubeconfig <node-ip>{{ _sops_nc }}"
            exit 1
        fi
        echo "{{ _sops_blue }}==> Using control plane node: $FIRST_CP ($KUBECONFIG_NODE){{ _sops_nc }}"
    fi
    echo "{{ _sops_blue }}Retrieving kubeconfig from $KUBECONFIG_NODE...{{ _sops_nc }}"
    mkdir -p "$(dirname "{{ kubeconfig }}")"
    talosctl kubeconfig --nodes "$KUBECONFIG_NODE" --endpoints "$KUBECONFIG_NODE" --force "{{ kubeconfig }}" && \
    echo "{{ _sops_green }}Kubeconfig retrieved{{ _sops_nc }}" && \
    echo "" && \
    echo "export KUBECONFIG=$(pwd)/{{ kubeconfig }}" || \
    (echo "{{ _sops_red }}Failed to retrieve kubeconfig{{ _sops_nc }}"; exit 1)

# Export talosconfig path
[group("talos")]
talos-talosconfig:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ talosconfig }}" ]; then
        echo "{{ _sops_red }}Error: talosconfig not found. Run 'just tf-apply' first.{{ _sops_nc }}"
        exit 1
    fi
    echo "export TALOSCONFIG=$(pwd)/{{ talosconfig }}"

# Display environment exports
[group("talos")]
talos-env: talos-kubeconfig talos-talosconfig

# ============================================================================
# Cluster Status
# ============================================================================

# Check cluster health
[group("talos")]
talos-health:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ talosconfig }}" ]; then
        echo "{{ _sops_red }}Error: talosconfig not found.{{ _sops_nc }}"
        exit 1
    fi
    echo "{{ _sops_blue }}Checking cluster health...{{ _sops_nc }}"
    export TALOSCONFIG="{{ talosconfig }}" && talosctl health --wait-timeout="{{ talos_wait_timeout }}"

# List cluster nodes
[group("talos")]
talos-nodes:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ kubeconfig }}" ]; then
        echo "{{ _sops_red }}Error: kubeconfig not found.{{ _sops_nc }}"
        exit 1
    fi
    echo "{{ _sops_blue }}Cluster nodes:{{ _sops_nc }}"
    export KUBECONFIG="{{ kubeconfig }}" && kubectl get nodes -o wide

# List all pods
[group("talos")]
talos-pods:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ kubeconfig }}" ]; then
        echo "{{ _sops_red }}Error: kubeconfig not found.{{ _sops_nc }}"
        exit 1
    fi
    echo "{{ _sops_blue }}All pods:{{ _sops_nc }}"
    export KUBECONFIG="{{ kubeconfig }}" && kubectl get pods -A

# Complete cluster status (health + nodes + pods)
[group("talos")]
talos-status: talos-health talos-nodes talos-pods

# ============================================================================
# Maintenance
# ============================================================================

# Upgrade Kubernetes (version; extra flags pass through to talosctl)
[group("talos")]
talos-upgrade-k8s version *flags:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_yellow }}Upgrading Kubernetes to {{ version }}...{{ _sops_nc }}"
    export TALOSCONFIG="{{ talosconfig }}" && talosctl upgrade-k8s --to "{{ version }}" {{ flags }}

# Upgrade Talos node(s) (short names or IPs, comma-separated; + flags, e.g. --image factory.talos.dev/metal-installer/<id>:v1.9.0)
[group("talos")]
talos-upgrade nodes *flags:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{ flags }}" ]; then
        echo "{{ _sops_red }}Error: flags required (e.g. --image <installer-url>){{ _sops_nc }}"
        echo "{{ _sops_yellow }}Usage: just talos-upgrade <nodes> --image factory.talos.dev/metal-installer/<id>:v1.9.0{{ _sops_nc }}"
        echo "{{ _sops_yellow }}Tip: kexec reboots can be unreliable on some hardware; add --reboot-mode=powercycle if the node does not restart.{{ _sops_nc }}"
        exit 1
    fi
    export TALOSCONFIG="{{ talosconfig }}"
    # Resolve a node short name to its Tailscale IP via terraform output.
    # Literal IPv4/IPv6 addresses are passed through unchanged. Workers cannot
    # forward requests for other nodes, so each node is targeted directly with
    # its own address as both endpoint and node.
    resolve_ip() {
        local node="$1" ip key
        if echo "$node" | grep -qE '^([0-9]{1,3}\.){3}[0-9]{1,3}$|:'; then
            echo "$node"; return 0
        fi
        for key in worker control_plane; do
            ip=$(terraform output -json generated_configs 2>/dev/null | jq -r ".[\"$key\"][\"$node\"].tailscale_ipv4 // empty" 2>/dev/null || true)
            if [ -n "$ip" ]; then echo "$ip"; return 0; fi
        done
        return 1
    }
    rc=0
    IFS=',' read -ra TALOS_NODES <<< "{{ nodes }}"
    for n in "${TALOS_NODES[@]}"; do
        n="$(echo "$n" | xargs)"
        [ -z "$n" ] && continue
        if ! NODE_IP="$(resolve_ip "$n")"; then
            echo "{{ _sops_red }}Error: could not resolve Tailscale IP for node '$n'{{ _sops_nc }}"
            echo "{{ _sops_yellow }}Available nodes:{{ _sops_nc }}"
            terraform output -json generated_configs 2>/dev/null | jq -r '(.control_plane // {}), (.worker // {}) | keys[]' 2>/dev/null | sort -u | sed 's/^/  /'
            rc=1; continue
        fi
        echo "{{ _sops_yellow }}Upgrading Talos on $n ($NODE_IP) ({{ flags }})...{{ _sops_nc }}"
        if talosctl upgrade -e "$NODE_IP" -n "$NODE_IP" {{ flags }} --preserve; then
            echo "{{ _sops_green }}Upgrade triggered on $n{{ _sops_nc }}"
        else
            echo "{{ _sops_red }}Upgrade failed on $n{{ _sops_nc }}"
            rc=1
        fi
    done
    exit $rc

# Open Talos dashboard (nodes, comma-separated; + flags, e.g. --insecure)
[group("talos")]
talos-dashboard nodes *flags:
    #!/usr/bin/env bash
    set -euo pipefail
    export TALOSCONFIG="{{ talosconfig }}" && talosctl {{ flags }} -n "{{ nodes }}" dashboard

# View node logs (nodes, comma-separated; service; + flags, e.g. --insecure)
[group("talos")]
talos-logs nodes service *flags:
    #!/usr/bin/env bash
    set -euo pipefail
    export TALOSCONFIG="{{ talosconfig }}" && talosctl {{ flags }} -n "{{ nodes }}" logs "{{ service }}"

# Reboot Talos node(s) (nodes, comma-separated; + flags, e.g. --insecure)
[group("talos")]
talos-reboot nodes *flags:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_yellow }}Rebooting node(s) {{ nodes }}...{{ _sops_nc }}"
    export TALOSCONFIG="{{ talosconfig }}" && talosctl {{ flags }} -n "{{ nodes }}" reboot

# Reset Talos node(s) (destructive; nodes, comma-separated; + flags, e.g. --insecure)
[group("talos")]
talos-reset nodes *flags:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "{{ _sops_red }}WARNING: This will wipe the node(s) at {{ nodes }}!{{ _sops_nc }}"
    printf "Press Enter to continue or Ctrl+C to cancel: "
    read -r confirm
    export TALOSCONFIG="{{ talosconfig }}" && talosctl {{ flags }} -n "{{ nodes }}" reset --graceful=false --reboot
