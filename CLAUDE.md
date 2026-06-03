# CLAUDE.md

See [README.md](README.md) for project overview, usage, and configuration.
See [AGENTS.md](AGENTS.md) for AI assistant rules and conventions.

## Validation

```bash
make -n <target>                          # Dry-run (Makefile)
make <prefix>-help                        # Help per makefile (sops, tf, helm, talos, dc)
just --fmt --check --justfile <file>      # Format check (justfile)
just --list --justfile <file>             # List recipes (justfile)
pre-commit run --all-files
```
