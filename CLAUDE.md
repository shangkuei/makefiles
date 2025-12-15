# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with this shared Makefiles repository.

## Primary Reference

**IMPORTANT**: See [AGENTS.md](AGENTS.md) for the primary, vendor-neutral AI assistant guidance. This document only contains Claude Code-specific extensions.

## Claude Code-Specific Features

### File References

When referencing files or code locations in responses, use markdown link syntax for clickable references:

- Files: `[sops.mk](sops.mk)`
- Lines: `[terraform.mk:95](terraform.mk#L95)`
- Ranges: `[helm.mk:50-80](helm.mk#L50-L80)`

### Tool Usage Patterns

**Makefile Analysis**:

1. **Read** for examining makefile content and patterns
2. **Grep** for searching target definitions: `^\.PHONY:`, `^[a-z-]+:`
3. **Glob** for finding makefiles: `**/*.mk`, `**/Makefile`
4. **Task** (subagent_type=Explore) for understanding usage across projects

**Making Changes**:

1. **Always Read before Edit/Write** - Required for existing files
2. **TodoWrite** - Structure multi-step changes across multiple makefiles
3. **Bash** - Validate with `make -n <target>` dry-run
4. **Bash** - Test targets: `make sops-help`, `make tf-help`

### Task Management for Makefile Changes

Use TodoWrite for complex makefile modifications:

```text
1. Analyze existing patterns in target makefile
2. Identify dependencies (which .mk files are required)
3. Implement new targets following naming conventions
4. Update help target with new documentation
5. Update README.md with usage examples
6. Test with dry-run and actual execution
```

### Workflow Integration

For mandatory rules, naming conventions, and security guidelines, see [AGENTS.md - AI Assistant Mandatory Rules](AGENTS.md#ai-assistant-mandatory-rules).

**Claude Code Specific**: Use TodoWrite tool to track multi-step makefile modifications.

### Makefile Include Hierarchy

| Makefile | Dependencies | Primary Purpose |
|----------|--------------|-----------------|
| `sops.mk` | None | Base SOPS operations, color definitions |
| `terraform.mk` | sops.mk | Terraform with SOPS integration |
| `helm.mk` | sops.mk | Helm chart management |
| `talos.mk` | sops.mk, terraform.mk | Talos cluster operations |
| `docker-compose.mk` | sops.mk | Docker Compose with SOPS |

### Quick Reference

For complete documentation on:

- **Include order dependencies**: See [AGENTS.md - Rule 1](AGENTS.md#rule-1-include-order-dependencies)
- **Variable naming conventions**: See [AGENTS.md - Rule 2](AGENTS.md#rule-2-variable-naming-conventions)
- **Target naming conventions**: See [AGENTS.md - Rule 3](AGENTS.md#rule-3-target-naming-conventions)
- **Security rules**: See [AGENTS.md - Rule 4](AGENTS.md#rule-4-security-rules)
- **Documentation requirements**: See [AGENTS.md - Rule 5](AGENTS.md#rule-5-documentation-requirements)
- **Available makefiles**: See [AGENTS.md - Available Makefiles](AGENTS.md#available-makefiles)
- **Development guidelines**: See [AGENTS.md - Development Guidelines](AGENTS.md#development-guidelines)

### Additional Context

- **Project overview**: [README.md](README.md)
- **AI guidance (vendor-neutral)**: [AGENTS.md](AGENTS.md)
