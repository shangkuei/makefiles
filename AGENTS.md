# AGENTS.md - AI Assistant Guidance for Shared Makefiles

This document provides guidance to AI assistants (Claude Code, GitHub Copilot, Cursor, etc.)
when working with this shared Makefiles repository.
This is the **primary reference** designed to prevent vendor lock-in.

## Documentation Philosophy

**CRITICAL**: Avoid duplication between documentation files:

- **README.md**: Human-readable project overview, usage examples, and configuration reference
- **AGENTS.md** (this file): AI-specific workflows, mandatory rules, and automation guidance
- **CLAUDE.md**: Claude Code-specific tool integration (references AGENTS.md)

**Guideline**: When content is suitable for human users, place it in README.md and reference it from AGENTS.md. Do not duplicate.

## Repository Overview

See [README.md](README.md) for:

- Complete overview of available makefiles
- Configuration variables and usage examples
- Include order and dependencies
- Security notes and best practices

**Key Technologies**: GNU Make, SOPS (age encryption), Terraform, Helm, Talos, Docker Compose

## AI Assistant Principles

### Makefile Development Fundamentals

- **DRY Principle**: Reusable targets and functions across domains
- **Composability**: Modular includes with clear dependencies
- **Consistency**: Unified naming conventions and output formatting
- **Security First**: Never expose secrets; use SOPS encryption patterns
- **Portability**: POSIX-compatible shell commands where possible

### AI Development Approach

- **Evidence-Based Decisions**: Reference existing patterns before suggesting changes
- **Test Before Commit**: Validate Makefile syntax and target functionality
- **Security-First Mindset**: Never compromise on secret management
- **Documentation First**: Update README.md when adding new targets or variables

## AI Assistant Mandatory Rules

**CRITICAL**: These rules must be followed for all Makefile changes:

### Rule 1: Include Order Dependencies

**Always maintain correct include order**:

```makefile
# CORRECT: sops.mk provides color definitions and base targets
include ../../../makefiles/sops.mk      # Must be first
include ../../../makefiles/terraform.mk  # Depends on sops.mk
include ../../../makefiles/helm.mk       # Depends on sops.mk
include ../../../makefiles/talos.mk      # Depends on sops.mk + terraform.mk
include ../../../makefiles/docker-compose.mk  # Depends on sops.mk

# WRONG: Including without sops.mk first
include ../../../makefiles/terraform.mk  # Will fail - needs sops.mk
```

**Rationale**: sops.mk provides color definitions (`_SOPS_*`), status indicators, and base SOPS targets that other makefiles depend on.

### Rule 2: Variable Naming Conventions

**Follow established naming patterns**:

- **SOPS_*** - SOPS configuration variables (defined in sops.mk)
- **TF_*** - Terraform configuration variables (defined in terraform.mk)
- **HELM_*** - Helm configuration variables (defined in helm.mk)
- **TALOS_*** - Talos configuration variables (defined in talos.mk)
- **DC_*** - Docker Compose configuration variables (defined in docker-compose.mk)
- **_SOPS_*** - Internal color/formatting variables (private, don't override)

### Rule 3: Target Naming Conventions

**Use consistent target prefixes**:

- **sops-*** - SOPS secret management targets
- **tf-*** - Terraform operation targets
- **helm-*** - Helm chart management targets
- **talos-*** - Talos cluster operation targets
- **dc-*** - Docker Compose operation targets

**Help targets**: Every makefile must provide a `-help` target (e.g., `sops-help`, `tf-help`).

### Rule 4: Security Rules

**Never compromise on security**:

- **Never commit private keys** - Only `.sops.yaml` (public keys) should be in Git
- **Use SOPS_AGE_KEY_FILE** - Always reference keys via environment variable
- **Temporary file cleanup** - Use `trap` to clean up decrypted files
- **No plaintext secrets in output** - Avoid echoing sensitive values

**Example secure pattern**:

```makefile
.PHONY: secure-operation
secure-operation:
    @tmpdir=$$(mktemp -d); \
    trap "rm -rf $$tmpdir" EXIT; \
    SOPS_AGE_KEY_FILE="$(SOPS_AGE_KEY_FILE)" sops -d secret.enc > "$$tmpdir/secret"; \
    # Use decrypted file...
```

### Rule 5: Documentation Requirements

Before any PR or commit, verify:

1. **README.md updated** if new targets or variables added
2. **Help target updated** with new target documentation
3. **Comments in code** explain non-obvious logic
4. **Examples provided** for complex targets

## Key Workflows and Commands

### Validation Before Changes

**Always validate Makefile syntax**:

```bash
# Check Makefile syntax
make -n <target>  # Dry-run to verify target exists

# Verify includes work
make -f Makefile -n help
```

### Testing Targets

**Test targets before committing**:

```bash
# Test help targets
make sops-help
make tf-help
make helm-help
make talos-help
make dc-help

# Test check targets
make sops-check-deps
make helm-check-deps
```

### Pre-commit Validation

**Run pre-commit hooks before committing**:

```bash
# Run all hooks on all files
pre-commit run --all-files

# Run on staged files only
pre-commit run
```

**IMPORTANT**: Pre-commit hooks are configured to validate:

- Trailing whitespace and line endings
- YAML syntax
- Markdown linting (via markdownlint)

If pre-commit hooks fail, fix the issues before committing. The `.markdownlint.yaml` configuration defines the markdown rules.

### Adding New Targets

**Workflow for new functionality**:

1. Identify which makefile the target belongs in
2. Follow existing patterns for similar targets
3. Add help documentation in the `-help` target
4. Update README.md with usage examples
5. Test with `make -n <target>` dry-run

## Available Makefiles

### sops.mk - Secret Management

**Purpose**: SOPS encryption with age keys for secret management.

**Key Targets**:

- `sops-keygen` - Generate new age key pair
- `sops-encrypt` - Encrypt a file
- `sops-decrypt` - Decrypt a file
- `sops-edit` - Edit encrypted file
- `sops-validate` - Validate encrypted files

**Required Variables**: `SOPS_DOMAIN`, `SOPS_ENV_NAME`

### terraform.mk - Infrastructure as Code

**Purpose**: Terraform operations with SOPS-encrypted backends and tfvars.

**Key Targets**:

- `tf-init` - Initialize with encrypted backend
- `tf-plan` - Generate plan with encrypted tfvars
- `tf-apply` - Apply with encrypted tfvars
- `tf-encrypt-backend` - Encrypt backend.hcl
- `tf-encrypt-tfvars` - Encrypt terraform.tfvars

**Requires**: sops.mk

### helm.mk - Kubernetes Package Management

**Purpose**: Helm chart management with pre-configured repositories.

**Key Targets**:

- `helm-install` - Install/upgrade charts
- `helm-uninstall` - Remove releases
- `helm-list` - List installed releases
- `helm-repo-add` - Add repositories

**Requires**: sops.mk (for color definitions)

### talos.mk - Kubernetes Cluster Management

**Purpose**: Talos Linux cluster deployment and operations.

**Key Targets**:

- `talos-apply` - Apply Talos configurations
- `talos-bootstrap` - Bootstrap Kubernetes
- `talos-kubeconfig` - Retrieve kubeconfig
- `talos-health` - Check cluster health

**Requires**: sops.mk, terraform.mk

### docker-compose.mk - Container Orchestration

**Purpose**: Docker Compose operations with SOPS-encrypted secrets.

**Key Targets**:

- `dc-up` - Start services
- `dc-down` - Stop services
- `dc-config` - Show merged configuration
- `dc-env` - Show decrypted environment

**Requires**: sops.mk

## Development Guidelines

### Code Style

- Use `@` prefix to suppress command echo for clean output
- Use color variables for consistent formatting
- Prefer `$$(...)` over backticks for command substitution
- Use `$(if ...)` for conditional variable expansion

### Error Handling

- Always check for required variables at the top of operations
- Provide helpful error messages with suggested fixes
- Use `exit 1` for errors, `exit 0` for successful early returns

### Output Formatting

- Use `_SOPS_BLUE` for informational messages
- Use `_SOPS_GREEN` for success messages
- Use `_SOPS_YELLOW` for warnings
- Use `_SOPS_RED` for errors
- Use `_SOPS_OK`, `_SOPS_FAIL`, `_SOPS_WARN` for status indicators

## Quick Reference

### Documentation Locations

- **Project overview and usage**: [README.md](README.md)
- **AI assistant guidance**: [AGENTS.md](AGENTS.md) (this file)
- **Claude Code integration**: [CLAUDE.md](CLAUDE.md)

### Essential Commands

```bash
# Validate Makefile
make -n <target>

# Show help
make sops-help
make tf-help
make helm-help
make talos-help
make dc-help

# Check dependencies
make sops-check-deps
make helm-check-deps
```

### Related Documentation

When used as a submodule in the infrastructure repository:

- [ADR-0008: Secret Management Strategy](https://github.com/shangkuei/infrastructure/blob/main/docs/decisions/0008-secret-management.md)
- [Runbook: SOPS Secret Management](https://github.com/shangkuei/infrastructure/blob/main/docs/runbooks/0008-sops-secret-management.md)
- [Spec: Unified SOPS Operations](https://github.com/shangkuei/infrastructure/blob/main/specs/security/unified-sops-operations.md)

## Contributing

1. **Read existing patterns** - Review similar targets before adding new ones
2. **Follow naming conventions** - Use established prefixes and variable names
3. **Update documentation** - README.md and help targets
4. **Test thoroughly** - Verify with dry-run and actual execution
5. **Security review** - Ensure no secrets are exposed
