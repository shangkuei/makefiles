# CLAUDE.md

See [README.md](README.md) for project overview, usage, and configuration.
See [AGENTS.md](AGENTS.md) for AI assistant rules and conventions.

## Validation

```bash
make -n <target>        # Dry-run
make <prefix>-help      # Help per makefile (sops, tf, helm, talos, dc)
pre-commit run --all-files
```
