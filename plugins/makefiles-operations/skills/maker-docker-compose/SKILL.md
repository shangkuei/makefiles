---
name: maker-docker-compose
description: Scaffold or guide Docker Compose operations using the shared docker-compose.mk Makefile include. Use when setting up Docker Compose with SOPS-encrypted secrets, managing container services, or working with encrypted environment files in a project that uses the shared makefiles submodule.
---

# Docker Compose Makefile Setup & Guide

You are helping the user work with the shared `docker-compose.mk` Makefile include for Docker Compose operations with SOPS-encrypted secrets.

## Step 1: Read the reference

Find the makefiles submodule and read `docker-compose.mk` to understand available targets, variables, and the `dc_run` helper function.

## Step 2: Detect current state

Check the current directory:
- Does a `Makefile` exist?
- If yes, does it include `sops.mk` AND `docker-compose.mk`? (docker-compose.mk depends on sops.mk)
- Are required variables set? (`SERVICE_NAME`, `BASE_COMPOSE`, `ENV_ENC`)
- Does the encrypted env file exist?
- Does the base compose file exist?

## Step 3: Act based on state

### If no Makefile exists: Scaffold

Ask the user for:
1. `SERVICE_NAME` (service identifier, e.g., `immich`, `gitea`)
2. `BASE_DIR` (path to base directory with the compose file)
3. `ENV_ENC` (encrypted env filename, default: `.enc.env`)
4. `SOPS_KEY_STRATEGY` (default: `local` for docker)
5. Optional: `COMPOSE_ENC_FILES`, `COMPOSE_RAW_FILES`

Then create a Makefile:

```makefile
SERVICE_NAME := <service>
BASE_DIR := <base-path>
BASE_COMPOSE := $(BASE_DIR)/docker-compose.yml
ENV_ENC := .enc.env
SOPS_DOMAIN := docker
SOPS_ENV_NAME := <service>-<host>
SOPS_KEY_STRATEGY := local

include <relative-path>/makefiles/sops.mk
include <relative-path>/makefiles/docker-compose.mk

# Service-specific targets below...
```

**Include order is critical**: `sops.mk` MUST come before `docker-compose.mk`.

### If Makefile exists with docker-compose.mk: Guide

Show the user:
1. Current configuration (service name, base compose, env file, encrypted files)
2. Available targets:
   - **View**: `dc-env`, `dc-config`
   - **Lifecycle**: `dc-up`, `dc-down`, `dc-restart`, `dc-logs`, `dc-ps`, `dc-pull`
   - **Execute**: `dc-exec SERVICE=<s> CMD=<c>`
   - **Help**: `dc-help`
   - **Aliases**: `env`, `config`, `up`, `down`, `logs`, `ps`, `restart`, `pull`
3. Common workflows:
   - First time: `make sops-import-key AGE_KEY_FILE=...` → `make dc-up`
   - View config: `make dc-config`
   - Update secrets: `make sops-edit FILE=.enc.env`
   - Restart: `make dc-restart` or `make dc-down && make dc-up`

### If Makefile exists without docker-compose.mk: Add includes

Help add both `sops.mk` and `docker-compose.mk` includes (in correct order) with required variables.
