# Quorum, Replication, and TLS Boundaries

Consensus quorum, `RPO=0` durability, and security boundaries between transport TLS and storage TDE.

## Synchronous Quorum vs Asynchronous Replication

| Model | Stacks | Consistency / `RPO` | Trade-Off |
|---|---|---|---|
| Consensus / Sync (`CP` / `PC-EC`) | `galera`, `patroni` (sync), `cockroach`, `yugabyte`, `yt-cluster` (`cc=half`) | `RPO=0` under `2/3` majority | Halts on `2/3` loss; high WAN RTT tax |
| Async / Mesh (`AP` / `PA-EL`) | `repli`, `pg-streaming` (async), `pg-logical`, `pg-birep`, `pgedge`, `bucardo` | `~1–5 ms` lag; crash tail-loss risk | Low WAN latency; concurrent conflicts |

Sync certification (`galera`) and Raft/2PC (`cockroach`, `yugabyte`, `yt-cluster`) enforce `fsync` plus majority ack before commit. Async stacks optimize local latency and rely on resolvers (`pgedge` `delta_apply`, stepped keys).

## Transport TLS vs Storage TDE and KMS Boundaries

The lab isolates three encryption layers:

1. **Transport TLS**: Local OpenSSL/Go PKI (`ssl/`, `certs_patroni/`) protects links with `0600` keys.
2. **Engine TDE**: Encrypts pages and WAL/redo logs with `DEK`s wrapped by an external `KEK` (`OpenBao`, `KMIP`, cloud KMS).
3. **Host Block**: OS `dm-crypt`/LUKS or ZFS below Docker volumes.

Default Compose stacks enable local transport TLS without an external KMS, keeping volumes strictly for ephemeral lab use.

## Related Documentation

- Engine TDE matrix: [TDE and Data-at-Rest Guide](../../../documentation/tde_encryption.md)
- Ports and TLS dirs: [Topology and Port Matrix](../../03-reference/architecture-specs/topology-and-port-matrix.md)
