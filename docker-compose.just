# ============================================================================
# docker-compose.just - Unified Docker Compose Operations
# ============================================================================
# Shared justfile include for standardized Docker Compose operations
# with SOPS-encrypted secrets across docker overlay environments.
#
# Usage:
#   Import this file in your overlay justfile after sops.just:
#     import '../../../../makefiles/sops.just'
#     import '../../../../makefiles/docker-compose.just'
#
# Required variables (define in consumer justfile before import):
#   service_name       - Service identifier (e.g., immich, gitea)
#   base_compose       - Path to base compose file
#   env_enc            - Encrypted environment file (e.g., .enc.env)
#
# Optional variables (override via environment):
#   COMPOSE_ENC_FILES  - Space-separated encrypted compose files (default: "")
#   COMPOSE_RAW_FILES  - Space-separated non-encrypted compose files (default: "")
#   DC_PROJECT_NAME    - Docker compose project name (default: service_name)
#   DC_NO_INTERPOLATE  - Disable variable interpolation (default: true)
# ============================================================================

# ============================================================================
# Configuration
# ============================================================================

compose_enc_files := env("COMPOSE_ENC_FILES", "")
compose_raw_files := env("COMPOSE_RAW_FILES", "")
dc_project_name := env("DC_PROJECT_NAME", service_name)
dc_no_interpolate := env("DC_NO_INTERPOLATE", "true")

# ============================================================================
# Internal Helper
# ============================================================================

# Run a docker compose command with decrypted files
[private]
_dc-run *cmd:
    #!/usr/bin/env bash
    set -euo pipefail
    export SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}"
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" EXIT
    compose_files="-f {{ base_compose }}"
    env_file=""
    if [ -f "{{ env_enc }}" ]; then
        sops -d "{{ env_enc }}" > "$tmpdir/.env"
        env_file="--env-file $tmpdir/.env"
    fi
    for file in {{ compose_enc_files }}; do
        if [ -f "$file" ]; then
            base=$(basename "$file" .enc.yml)
            sops -d "$file" > "$tmpdir/${base}.yml"
            compose_files="$compose_files -f $tmpdir/${base}.yml"
        fi
    done
    for file in {{ compose_raw_files }}; do
        if [ -f "$file" ]; then
            compose_files="$compose_files -f $file"
        fi
    done
    eval docker compose --project-directory . $compose_files $env_file {{ cmd }}

# ============================================================================
# Docker Compose Operations
# ============================================================================

# Show decrypted .enc.env file
[group("docker-compose")]
dc-env: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f "{{ env_enc }}" ]; then
        echo "{{ _sops_red }}Error: {{ env_enc }} not found{{ _sops_nc }}"
        exit 1
    fi
    SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}" sops -d "{{ env_enc }}"

# Output merged docker-compose configuration
[group("docker-compose")]
dc-config: sops-check-deps
    #!/usr/bin/env bash
    set -euo pipefail
    export SOPS_AGE_KEY_FILE="{{ sops_age_key_file }}"
    tmpdir=$(mktemp -d)
    trap "rm -rf $tmpdir" EXIT
    compose_files="-f {{ base_compose }}"
    for file in {{ compose_enc_files }}; do
        if [ -f "$file" ]; then
            base=$(basename "$file" .enc.yml)
            sops -d "$file" > "$tmpdir/${base}.yml"
            compose_files="$compose_files -f $tmpdir/${base}.yml"
        fi
    done
    for file in {{ compose_raw_files }}; do
        if [ -f "$file" ]; then
            compose_files="$compose_files -f $file"
        fi
    done
    if [ "{{ dc_no_interpolate }}" = "true" ]; then
        eval docker compose --project-directory . $compose_files config --no-interpolate
    else
        eval docker compose --project-directory . $compose_files config
    fi

# Start services (decrypts and runs)
[group("docker-compose")]
dc-up: sops-check-deps
    @just _dc-run up -d

alias up := dc-up

# Stop services
[group("docker-compose")]
dc-down: sops-check-deps
    @just _dc-run down

alias down := dc-down

# View service logs (follow mode)
[group("docker-compose")]
dc-logs: sops-check-deps
    @just _dc-run logs -f

alias logs := dc-logs

# Show running containers
[group("docker-compose")]
dc-ps: sops-check-deps
    @just _dc-run ps

alias ps := dc-ps

# Restart services
[group("docker-compose")]
dc-restart: sops-check-deps
    @just _dc-run restart

alias restart := dc-restart

# Pull latest images
[group("docker-compose")]
dc-pull: sops-check-deps
    @just _dc-run pull

alias pull := dc-pull

# Execute command in container
[group("docker-compose")]
dc-exec service cmd: sops-check-deps
    @just _dc-run exec "{{ service }}" {{ cmd }}
