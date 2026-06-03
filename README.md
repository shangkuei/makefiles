# Shared Makefiles

> Reusable Makefile includes for standardized infrastructure operations with SOPS encryption

[![SOPS](https://img.shields.io/badge/SOPS-age_encryption-326CE5)](https://github.com/getsops/sops)
[![Terraform](https://img.shields.io/badge/Terraform-IaC-623CE4?logo=terraform)](https://www.terraform.io/)
[![Helm](https://img.shields.io/badge/Helm-Charts-0F1689?logo=helm)](https://helm.sh/)
[![Talos](https://img.shields.io/badge/Talos-Kubernetes-FF6600)](https://www.talos.dev/)

## Overview

This repository contains shared Makefile includes that provide standardized operations across infrastructure repositories. It is designed to be used as a **git submodule** for consistent tooling across projects.

## Available Includes

| Makefile | Dependencies | Purpose |
|----------|--------------|---------|
| `sops.mk` | None | Base SOPS operations, color definitions |
| `terraform.mk` | sops.mk | Terraform with SOPS integration |
| `helm.mk` | sops.mk | Helm chart management |
| `talos.mk` | sops.mk, terraform.mk | Talos cluster operations |
| `docker-compose.mk` | sops.mk | Docker Compose with SOPS |

## Usage

Include the shared makefiles in your domain Makefile. **sops.mk must always be included first** as it provides color definitions and base targets used by all other makefiles.

```makefile
# Set required variables
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := my-environment

# Include shared operations (order matters)
include ../../../makefiles/sops.mk           # Must be first
include ../../../makefiles/terraform.mk      # Depends on sops.mk
include ../../../makefiles/helm.mk           # Depends on sops.mk
include ../../../makefiles/talos.mk          # Depends on sops.mk + terraform.mk
include ../../../makefiles/docker-compose.mk # Depends on sops.mk

# Your domain-specific targets follow...
```

## sops.mk Reference

### SOPS Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SOPS_DOMAIN` | Domain identifier | `terraform`, `kubernetes`, `docker` |
| `SOPS_ENV_NAME` | Environment name (used for key naming) | `talos-cluster-dev` |

### SOPS Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `SOPS_KEY_STRATEGY` | `central` | Key location: `central` (~/.config/sops/age/) or `local` (./age-key.txt) |
| `SOPS_AGE_DIR` | `~/.config/sops/age` | Central key storage directory |
| `SOPS_LOCAL_KEY` | `age-key.txt` | Local key filename |
| `SOPS_CONFIG` | `.sops.yaml` | SOPS configuration filename |
| `SOPS_EDITOR` | `$EDITOR` or `code --wait` | Editor for `sops-edit` |
| `SOPS_COLOR` | `true` | Enable colored output |

### SOPS Targets

#### Tier 1: Universal (All Domains)

```bash
make sops-help          # Show help for SOPS operations
make sops-check-deps    # Verify sops and age are installed
make sops-check-config  # Verify .sops.yaml exists and is valid
make sops-info          # Display encryption configuration
make sops-validate      # Validate all encrypted files can be decrypted
```

#### Tier 2: Key Management

```bash
make sops-keygen                           # Generate new age key pair
make sops-init-config                      # Generate key + update .sops.yaml placeholder
make sops-import-key AGE_KEY_FILE=/path    # Import existing age key
make sops-export-public                    # Export public key for sharing
make sops-rotate-key                       # Show key rotation procedure
```

#### Tier 3: Encryption Operations

```bash
make sops-encrypt FILE=secrets.yaml    # Encrypt a file in-place
make sops-decrypt FILE=secrets.yaml    # Decrypt file to stdout
make sops-edit FILE=secrets.yaml       # Edit encrypted file
make sops-rekey FILE=secrets.yaml      # Re-encrypt with current config
make sops-clean                        # Remove temporary/decrypted files
```

### Key Strategies

#### Central Strategy (Terraform Default)

Keys stored in user's home directory:

```text
~/.config/sops/age/
├── talos-cluster.txt         # Private key (chmod 600)
├── talos-cluster.txt.pub     # Public key (chmod 644)
└── ...
```

Best for:

- Terraform environments with static `.sops.yaml`
- Shared development machines
- Keys that need to be reused across sessions

#### Local Strategy (Kubernetes/Docker Default)

Keys stored in the environment directory:

```text
kubernetes/overlays/flux-instance/dev/
├── age-key.txt               # Private key (gitignored)
├── .sops.yaml                # Generated config
└── *.yaml.enc                # Encrypted files
```

Best for:

- Environments with dynamically generated `.sops.yaml`
- CI/CD pipelines that inject keys
- Isolated per-environment keys

## terraform.mk Reference

### Terraform Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SOPS_DOMAIN` | Domain identifier | `terraform` |
| `SOPS_ENV_NAME` | Environment name | `talos-cluster-dev` |

### Terraform Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `TF_TFVARS_ENC` | `terraform.tfvars.enc` | Encrypted tfvars filename |
| `TF_TFVARS_PLAIN` | `terraform.tfvars` | Plain tfvars filename |
| `TF_TFVARS_EXAMPLE` | `terraform.tfvars.example` | Example tfvars filename |
| `TF_BACKEND_HCL` | `backend.hcl` | Plain backend config filename |
| `TF_BACKEND_ENC` | `backend.hcl.enc` | Encrypted backend config filename |
| `TF_BACKEND_EXAMPLE` | `backend.hcl.example` | Example backend config filename |
| `TF_AUTO_INIT` | `false` | Auto-run init before plan/apply |
| `TF_GENERATED_DIR` | `generated` | Directory for generated files |

### Terraform Targets

#### Core Terraform Operations

```bash
make tf-init             # Initialize Terraform with encrypted backend
make tf-plan             # Show plan using encrypted tfvars
make tf-apply            # Apply changes using encrypted tfvars
make tf-destroy          # Destroy resources using encrypted tfvars
make tf-validate         # Validate configuration
make tf-fmt              # Format Terraform files
make tf-lint             # Run validate + format
make tf-upgrade          # Upgrade providers
make tf-output           # Show Terraform outputs
make tf-clean            # Remove .terraform and lock files
make tf-workflow         # Show setup workflow guide
make tf-help             # Show Terraform operations help
```

#### SOPS Integration

```bash
make tf-encrypt-backend  # Encrypt backend.hcl
make tf-encrypt-tfvars   # Encrypt terraform.tfvars
make tf-edit-backend     # Edit encrypted backend.hcl
make tf-edit-tfvars      # Edit encrypted terraform.tfvars
make tf-sops-validate    # Validate encrypted Terraform files
```

### Terraform Usage Example

```makefile
# SOPS configuration
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := my-environment
SOPS_KEY_STRATEGY := central

# Optional: Override encrypted file names (legacy format)
TF_TFVARS_ENC := terraform.enc.tfvars
TF_BACKEND_ENC := backend.enc.hcl

# Include shared operations
include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# Environment-specific targets can be added below...
```

## helm.mk Reference

### Helm Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `KUBECONFIG` | Path to kubeconfig file | `generated/kubeconfig` |

### Helm Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HELM_DEFAULT_NS` | `default` | Default namespace for installations |
| `HELM_WAIT` | `true` | Wait for resources to be ready |
| `HELM_TIMEOUT` | `5m` | Timeout for Helm operations |
| `HELM_ATOMIC` | `false` | Rollback on failure |

### Helm Targets

#### Repository Management

```bash
make helm-repo-add repo=name url=https://...  # Add repository
make helm-repo-update                          # Update all repositories
make helm-repo-list                            # List configured repositories
```

#### Chart Operations

```bash
make helm-install chart=cilium values=values.yaml ns=kube-system [version=x.y.z]  # Install/upgrade
make helm-upgrade chart=cilium values=values.yaml ns=kube-system                   # Alias for install
make helm-uninstall release=cilium ns=kube-system                                  # Uninstall release
make helm-rollback release=cilium ns=kube-system [revision=n]                      # Rollback release
```

#### Status & Search

```bash
make helm-list [ns=namespace|all]        # List releases
make helm-status release=name [ns=ns]    # Show release status
make helm-history release=name [ns=ns]   # Show release history
make helm-values release=name [ns=ns]    # Show release values
make helm-search query=term              # Search for charts
make helm-show-values chart=repo/name    # Show chart default values
make helm-check-deps                     # Verify helm is installed
make helm-help                           # Show help
```

#### Pre-configured Repositories

cilium, jetstack, ingress-nginx, prometheus-community, grafana, bitnami, argo, openebs, longhorn, metallb, traefik, hashicorp, external-secrets

### Helm Usage Example

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-cluster-dev
KUBECONFIG := generated/kubeconfig

include ../../../makefiles/sops.mk
include ../../../makefiles/helm.mk

# Install with pre-configured repository auto-detection
# make helm-install chart=cilium values=cilium-values.yaml ns=kube-system
```

## talos.mk Reference

### Talos Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `GENERATED_DIR` | `generated` | Directory containing generated configs |
| `TALOSCONFIG` | `$(GENERATED_DIR)/talosconfig` | Path to talosconfig file |
| `KUBECONFIG` | `$(GENERATED_DIR)/kubeconfig` | Path to kubeconfig file |
| `TALOS_WAIT_TIMEOUT` | `10m` | Timeout for health checks |

### Talos Targets

#### Deployment

```bash
make talos-apply [NODE=name] [INSECURE=true] [MODE=auto|reboot|no-reboot|staged]  # Apply configs
make talos-bootstrap [NODE=ip]                                                      # Bootstrap Kubernetes
```

#### Access

```bash
make talos-kubeconfig [NODE=ip]   # Retrieve kubeconfig
make talos-talosconfig            # Export talosconfig path
make talos-env                    # Display all environment exports
```

#### Status

```bash
make talos-health       # Check cluster health
make talos-nodes        # List cluster nodes
make talos-pods         # List all pods
make talos-status       # Complete cluster status (health + nodes + pods)
make talos-help         # Show help
```

#### Maintenance

```bash
make talos-upgrade-k8s VERSION=v1.32.0                 # Upgrade Kubernetes
make talos-upgrade NODE=ip IMAGE=url                    # Upgrade Talos node
make talos-upgrade NODE=ip VERSION=v1.9.0               # Upgrade Talos node (auto image)
make talos-dashboard NODE=ip [INSECURE=true]            # Open dashboard
make talos-logs NODE=ip SERVICE=name [INSECURE=true]    # View node logs
make talos-reboot NODE=ip [INSECURE=true]               # Reboot node
make talos-reset NODE=ip [INSECURE=true]                # Reset node (destructive)
```

### Talos Usage Example

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-cluster-dev
SOPS_KEY_STRATEGY := central

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk
include ../../../makefiles/talos.mk

# Workflow: make tf-apply → make talos-apply → make talos-bootstrap → make talos-kubeconfig
```

## docker-compose.mk Reference

### Docker Compose Required Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `SERVICE_NAME` | Service identifier | `immich`, `gitea` |
| `BASE_DIR` | Path to base directory | `../../../base/$(SERVICE_NAME)` |
| `BASE_COMPOSE` | Path to base compose file | `$(BASE_DIR)/docker-compose.yml` |
| `ENV_ENC` | Encrypted environment file | `.enc.env` |

### Docker Compose Optional Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `COMPOSE_ENC_FILES` | *(empty)* | Space-separated encrypted compose files |
| `COMPOSE_RAW_FILES` | *(empty)* | Space-separated non-encrypted compose files |
| `DC_PROJECT_NAME` | `$(SERVICE_NAME)` | Docker compose project name |
| `DC_NO_INTERPOLATE` | `true` | Disable variable interpolation in config |

### Docker Compose Targets

```bash
make dc-env                        # Show decrypted .enc.env
make dc-config                     # Output merged docker-compose config
make dc-up                         # Start services
make dc-down                       # Stop services
make dc-restart                    # Restart services
make dc-logs                       # View logs (follow mode)
make dc-ps                         # Show running containers
make dc-pull                       # Pull latest images
make dc-exec SERVICE=svc CMD=cmd   # Execute command in container
make dc-help                       # Show help
```

Short aliases are also available: `env`, `config`, `up`, `down`, `logs`, `ps`, `restart`, `pull`.

### Docker Compose Usage Example

```makefile
SERVICE_NAME := immich
BASE_DIR := ../../../base/$(SERVICE_NAME)
BASE_COMPOSE := $(BASE_DIR)/docker-compose.yml
ENV_ENC := .enc.env
COMPOSE_ENC_FILES := docker-compose.enc.yml
SOPS_DOMAIN := docker
SOPS_ENV_NAME := immich-unraid
SOPS_KEY_STRATEGY := local

include ../../../../makefiles/sops.mk
include ../../../../makefiles/docker-compose.mk
```

## Domain-Specific Extensions

Each domain can extend the base includes with additional targets.

### Terraform with Talos Example

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := talos-cluster-dev
SOPS_KEY_STRATEGY := central

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# Talos-specific operations
.PHONY: kubeconfig
kubeconfig: ## Get kubeconfig for the cluster
	@terraform output -raw kubeconfig > kubeconfig
```

### Terraform with Flux Example

```makefile
SOPS_DOMAIN := terraform
SOPS_ENV_NAME := gitops-dev
SOPS_KEY_STRATEGY := central

# Flux uses separate key from Terraform
AGE_FLUX_PRIVATE_KEY := $(SOPS_AGE_DIR)/gitops-dev-flux.txt

include ../../../makefiles/sops.mk
include ../../../makefiles/terraform.mk

# Generate both Terraform and Flux keys
.PHONY: age-keygen
age-keygen: sops-keygen flux-keygen
	@echo "Both keys generated"

# Flux-specific key generation
.PHONY: flux-keygen
flux-keygen: sops-check-deps
	@age-keygen -o $(AGE_FLUX_PRIVATE_KEY)
```

### Kubernetes Example

```makefile
SOPS_DOMAIN := kubernetes
SOPS_ENV_NAME := flux-dev
SOPS_KEY_STRATEGY := local

include ../../../../makefiles/sops.mk

.PHONY: sops-secret-age
sops-secret-age: sops-check-deps
	@# Generate Kubernetes secret containing the age key
	@echo "apiVersion: v1" > secret-sops-age.yaml
	@# ... (create manifest)
	@SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops --encrypt --in-place secret-sops-age.yaml
```

### Docker Example

```makefile
SOPS_DOMAIN := docker
SOPS_ENV_NAME := gitea-unraid
SOPS_KEY_STRATEGY := local

include ../../../../makefiles/sops.mk

.PHONY: sops-edit-env
sops-edit-env: sops-check-deps
	@EDITOR="$(SOPS_EDITOR)" SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops .env
```

## Helper Functions

The sops.mk provides helper functions for domain Makefiles:

```makefile
# Check if file is encrypted
$(call sops_is_encrypted,filename)  # Returns: true or false

# Get public key from private key
$(call sops_get_public_key,keyfile)  # Returns: age1...

# Generate .sops.yaml header
$(call sops_config_header)

# Add creation rule to .sops.yaml
$(call sops_add_rule,path_regex,age_key,[encrypted_regex])
```

## Backward Compatibility

The following aliases are provided for compatibility with existing Makefiles:

| Old Target | New Target |
|------------|------------|
| `age-keygen` | `sops-keygen` |
| `age-info` | `sops-info` |

Domain Makefiles should define their own aliases for domain-specific targets (e.g., `encrypt-backend` → `sops-encrypt-backend`).

## Conventions

### Naming

| Scope | Prefix | Examples |
|-------|--------|----------|
| SOPS variables | `SOPS_*` | `SOPS_DOMAIN`, `SOPS_ENV_NAME` |
| Terraform variables | `TF_*` | `TF_TFVARS_ENC`, `TF_AUTO_INIT` |
| Helm variables | `HELM_*` | `HELM_WAIT`, `HELM_TIMEOUT` |
| Talos variables | `TALOS_*` | `TALOS_WAIT_TIMEOUT` |
| Docker Compose variables | `DC_*` | `DC_PROJECT_NAME` |
| Internal (private) | `_SOPS_*` | `_SOPS_RED`, `_SOPS_OK` (do not override) |
| SOPS targets | `sops-*` | `sops-keygen`, `sops-encrypt` |
| Terraform targets | `tf-*` | `tf-init`, `tf-plan` |
| Helm targets | `helm-*` | `helm-install`, `helm-list` |
| Talos targets | `talos-*` | `talos-apply`, `talos-health` |
| Docker Compose targets | `dc-*` | `dc-up`, `dc-down` |

Every makefile must provide a `<prefix>-help` target.

### Code Style

- Use `@` prefix to suppress command echo for clean output
- Use `$$(...)` for command substitution (not backticks)
- Use `$(if ...)` for conditional variable expansion
- Use color variables for formatted output: `_SOPS_BLUE` (info), `_SOPS_GREEN` (success), `_SOPS_YELLOW` (warning), `_SOPS_RED` (error)
- Use status indicators for check results: `_SOPS_OK`, `_SOPS_FAIL`, `_SOPS_WARN`
- Check required variables at the top of targets with helpful error messages
- Use `exit 1` for errors, `exit 0` for successful early returns

### Secure Patterns

Always clean up decrypted files using `trap`:

```makefile
.PHONY: secure-operation
secure-operation:
	@tmpdir=$$(mktemp -d); \
	trap "rm -rf $$tmpdir" EXIT; \
	SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -d secret.enc > "$$tmpdir/secret"; \
	# Use decrypted file...
```

## Security Notes

1. **Never commit private keys** - Only `.sops.yaml` (public keys) should be in Git
2. **Use `.gitignore`** - Ensure `age-key.txt` and `*.txt` in key directories are ignored
3. **Use `SOPS_AGE_KEY_FILE`** - Always reference keys via environment variable
4. **No plaintext secrets in output** - Avoid echoing sensitive values
5. **Temporary file cleanup** - Use `trap` to clean up decrypted files (see Secure Patterns above)
6. **Backup keys** - Store private keys in a password manager
7. **Rotate keys** - Follow the rotation procedure in the runbook

## Development Setup

### Pre-commit Hooks

This repository uses [pre-commit](https://pre-commit.com/) for automated validation before commits.

**Installation**:

```bash
# Install pre-commit (if not already installed)
pip install pre-commit
# or
brew install pre-commit

# Install the git hooks
pre-commit install
```

**Usage**:

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run on staged files only (happens automatically on commit)
pre-commit run
```

**Configured Hooks**:

- **trailing-whitespace**: Remove trailing whitespace
- **end-of-file-fixer**: Ensure files end with a newline
- **check-yaml**: Validate YAML syntax
- **check-merge-conflict**: Detect merge conflict markers
- **markdownlint**: Lint markdown files against configured rules

## Contributing

1. Read existing patterns in the target makefile before adding new ones
2. Follow naming conventions and code style documented above
3. Maintain include order dependencies (sops.mk first)
4. Update `-help` targets when adding new functionality
5. Update this README for user-facing changes
6. Test with `make -n <target>` dry-run
7. Run `pre-commit run --all-files` before committing

## Related Documentation

When used as a submodule in the infrastructure repository:

- [ADR-0008: Secret Management Strategy](https://github.com/shangkuei/infrastructure/blob/main/docs/decisions/0008-secret-management.md)
- [Runbook: SOPS Secret Management](https://github.com/shangkuei/infrastructure/blob/main/docs/runbooks/0008-sops-secret-management.md)
- [Spec: Unified SOPS Operations](https://github.com/shangkuei/infrastructure/blob/main/specs/security/unified-sops-operations.md)
