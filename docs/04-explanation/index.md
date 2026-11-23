# Explanation

Architecture decisions, trade-offs, and system internals.

| Area | Document | Scope |
|---|---|---|
| Architecture | [Global Topology and Routing](architecture-overview/global-topology-and-routing.md) | Traefik vs HAProxy TCP routing. |
| Decisions | [ADR-001: Unified `./mdb` CLI](design-decisions/adr-001-unified-mdb-cli.md) | Go CLI and isolated stacks. |
| Decisions | [ADR-002: Diataxis and Versioned MkDocs](design-decisions/adr-002-diataxis-versioned-mkdocs.md) | Quadrants, virtual docs, IONOS SFTP. |
| Deep Dives | [Quorum, Replication, and TLS](deep-dives/quorum-replication-and-tls.md) | `RPO=0` trade-offs and TDE/KMS limits. |

Legacy: [Global Architecture](../../documentation/architecture.md), [TDE Guide](../../documentation/tde_encryption.md).
