# AGENTS.md

See [README.md](README.md) for project overview, makefile references, conventions, and security guidelines.

## AI Assistant Principles

- **Evidence-Based**: Reference existing patterns in the codebase before suggesting changes
- **Security-First**: Never expose secrets; use SOPS encryption patterns
- **Test Before Commit**: Validate with `make -n <target>`, `just --fmt --check --justfile <file>`, and `pre-commit run --all-files`
- **Documentation**: Update README.md and `-help` targets when adding new functionality
- **Dual Format**: Both `.mk` (Makefile) and `.just` (justfile) formats coexist during migration. Changes to one should be reflected in the other
