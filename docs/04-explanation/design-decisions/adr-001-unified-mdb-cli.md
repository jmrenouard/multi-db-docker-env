# ADR-001: Unified `./mdb` CLI and Isolated Compose Stacks

| Attribute | Value |
|---|---|
| **Status** | Accepted |
| **Deciders** | Multi-DB Engineering |

## Context

Supporting 31 environments across Linux, macOS, and Windows caused drift across `Makefile` snippets, `interactive_runner.py`, and scripts. Standalone profiles share `3306`/`5432`, while HA clusters need readiness polling and PKI setup.

## Options and Trade-Offs

| Option | Cross-Platform | Type Safety & EOL Guard | Verdict |
|---|---|---|---|
| Pure-Go `./mdb` + isolated `docker-compose-*.yml` | High (`mdb.cmd` + POSIX) | Strong (`pkg/catalog`, `pkg/pki`) | **Selected** |
| `Makefile` + Bash scripts only | Low (Windows friction) | Weak | Wrappers only |
| Python-only runner | Medium (venv drift) | Medium | Legacy fallback |

## Decision

Adopt zero-dependency Go `./mdb` (`cmd/mdb/`) as the single CLI entry point backed by per-topology `docker-compose-*.yml` stacks and `pkg/catalog`. `Makefile` remains a thin compatibility wrapper.

## Consequences

- **Positive**: Native Go PKI (`pkg/pki`), uniform EOL guards (`mysql57`–`percona80`), and 21 isolated stacks prevent cross-stack interference.
- **Negative**: New topologies must register in both `pkg/catalog/catalog.go` and a `docker-compose-<id>.yml` file.

## Related Reference and Procedures

- CLI reference: [MDB CLI and Makefile Reference](../../03-reference/cli-and-scripts/mdb-cli-and-makefile-reference.md)
- Deployment guide: [Deploy Standalone and Clusters](../../02-how-to-guides/deployment/deploy-standalone-and-clusters.md)
