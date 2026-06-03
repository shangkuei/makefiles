---
name: task-docker-compose
description: Scaffold or guide Docker Compose operations using the shared docker-compose.mk/docker-compose.just includes. Use when setting up Docker Compose with SOPS-encrypted secrets, managing container services, or working with encrypted environment files in a project that uses the shared makefiles submodule.
---

# Docker Compose Setup & Guide

You are helping the user work with the shared `docker-compose.mk` / `docker-compose.just` includes for Docker Compose operations with SOPS-encrypted secrets.

## Step 1: Read the reference

Find the makefiles submodule and read `docker-compose.mk` or `docker-compose.just` to understand available targets, variables, and helpers.

## Step 2: Detect current state

Check the current directory:

- Does a `justfile` exist? → use **just** format
- Does a `Makefile` exist? → use **make** format
- If the chosen file exists, does it include/import both `sops` AND `docker-compose` modules?
- Are required variables set? (`SERVICE_NAME`/`service_name`, `BASE_COMPOSE`/`base_compose`, `ENV_ENC`/`env_enc`)
- Does the encrypted env file exist?
- Does the base compose file exist?

## Step 3: Act based on state

### If no Makefile/justfile exists: Scaffold

Ask the user for:

1. **Format preference**: `Makefile` or `justfile`
2. Service name (e.g., `immich`, `gitea`)
3. Base directory path (with the compose file)
4. Encrypted env filename (default: `.enc.env`)
5. Optional: encrypted/raw compose overlay files

Then create the appropriate file:

**Makefile format:**

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

**Justfile format:**

```just
set shell := ["bash", "-euo", "pipefail", "-c"]

sops_domain := "docker"
sops_env_name := "<service>-<host>"
service_name := "<service>"
base_compose := "<base-path>/docker-compose.yml"
env_enc := ".enc.env"

import '<relative-path>/makefiles/sops.just'
import '<relative-path>/makefiles/docker-compose.just'

# Service-specific recipes below...
```

Note: For justfile, `sops_key_strategy` defaults to `"central"`. For docker, override via env: `SOPS_KEY_STRATEGY=local just <recipe>`, or set in a `.env` file with `set dotenv-load`.

**Import order is critical**: `sops` MUST come before `docker-compose`.

### If Makefile/justfile exists with docker-compose include: Guide

Show the user:

1. Current configuration (service name, base compose, env file, encrypted files)
2. Available targets:
   - **View**: `dc-env`, `dc-config`
   - **Lifecycle**: `dc-up`, `dc-down`, `dc-restart`, `dc-logs`, `dc-ps`, `dc-pull`
   - **Execute**: exec command in container
3. Command syntax based on detected format:
   - Make: `make dc-exec SERVICE=app CMD=bash`, aliases: `make up`, `make down`, `make logs`
   - Just: `just dc-exec app bash`, aliases: `just up`, `just down`, `just logs`
4. Common workflows:
   - First time: import key → `dc-up`
   - View config: `dc-config`
   - Update secrets: edit encrypted env file
   - Restart: `dc-restart` or `dc-down` then `dc-up`

### If Makefile/justfile exists without docker-compose include: Add includes

Help add both `sops` and `docker-compose` includes (in correct order) with required variables.
