---
trigger: always_on
description: Manage the lifecycle of database containers using the Makefile orchestrator.
category: skill
---
# Lifecycle Management

## 🧠 Rationale

Consistent environment states are critical for reproducible database laboratory results. This skill ensures all containers are managed through the central Makefile to maintain architectural sanity.

## 🛠️ Implementation

- **Start Service**: `make <service_name>` (e.g., `make mariadb118`).
- **Stop All**: `make stop`.
- **Check Status**: `make status` or `make info`.
- **View Logs**: `make logs service=<service_name>`.

## ✅ Verification

- Verify running containers with `docker ps`.
- Confirm Traefik status at `http://localhost:8080`.
