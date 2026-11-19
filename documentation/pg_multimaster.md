# PostgreSQL Multi-Master & Distributed SQL Topologies

This guide documents the six PostgreSQL multi-master and distributed SQL topologies plus the PostgreSQL 17 baseline (`docker-compose-pg17-baseline.yml`) available in `multi-db-docker-env` (`v2.1.0`), along with their Makefile targets, Go `mdb` CLI commands, empirical benchmark results, and verified failure modes.

*Version française : [pg_multimaster_fr.md](pg_multimaster_fr.md).*

## Architecture Matrix

| Topology | Engine / Image | Nodes & Routing | CAP / PACELC | Localhost Ports |
| :--- | :--- | :--- | :--- | :--- |
| **`pg-birep`** | `postgres:17` (`17.11`) + `haproxy:2.9-alpine` | 2 active-active nodes + HAProxy RR | `AP` / `PA-EL` | `15440` (LB), `15441`–`15442`, `15449` (stats) |
| **`pgedge`** | `ghcr.io/pgedge/pgedge-postgres:17-spock5-minimal` | 3-node Spock 5.0.14 + Snowflake 2.6.1 mesh | `AP` / `PA-EL` | `15450` (LB), `15451`–`15453` |
| **`bucardo`** | Custom `postgres:17` (`plperl`) + Bucardo `5.6.0` | 2 PG 17 sources + Perl async daemon | `AP` / `PA-EL` | `15461`–`15462` |
| **`citus`** | `citusdata/citus:14.2.0-pg17` | 1 Coordinator + 2 Workers (8 shards) | `CP` (Coord SPOF / 2PC) | `15490` (coord), `15491`–`15492` |
| **`yugabyte`** | `yugabytedb/yugabyte:2026.1.3.0-b100` | 3 YSQL/DocDB Raft nodes (`RF=3`) | `CP` / `PC-EC` | `15471`–`15473` (YSQL), `17001` (UI) |
| **`cockroach`** | `cockroachdb/cockroach:v24.3.0` | 3 Pebble Raft nodes (`RF=3`, `SERIALIZABLE`) | `CP` / `PC-EC` | `15481`–`15483` (SQL), `18081` (UI) |
| **`pg17-baseline`** | `postgres:17` | Standalone (`15431`) + Sync Streaming HA (`15432`–`15433`) | `CA` / `PC-EC` | `15431`–`15433` |

## Quick Start (`Makefile` & `mdb` CLI)

```bash
# Lifecycle via Makefile
make pg-birep-up && make test-pg-birep && make pg-birep-down
make pgedge-up   && make test-pgedge   && make pgedge-down
make bucardo-up  && make test-bucardo  && make bucardo-down
make citus-up    && make test-citus    && make citus-down
make cockroach-up && make test-cockroach && make cockroach-down
make yugabyte-up && make test-yugabyte && make yugabyte-down

# Sequential cross-engine benchmark suite (Suites A-F, PG_SCALE=2)
make bench-pg-multimaster

# Or via Go mdb CLI (v2.1.0)
./bin/mdb topologies
./bin/mdb up pgedge && ./bin/mdb status pgedge && ./bin/mdb down pgedge
```

## Empirical Benchmark Summary (`PG_SCALE=2`)

All benchmarks executed sequentially inside the Docker bridge network (`multi-db-pgbench-sysbench:latest`, `200,000` `pgbench_accounts` rows, explicit surrogate PK `hid` on `pgbench_history`) across:
- **Suite A**: Single-node `pgbench` RW (`8` clients, `20 s`)
- **Suite B1**: Multi-node disjoint RW (`2x4` clients, `20 s`)
- **Suite B2**: Multi-node overlapping RW (`2x4` clients, `20 s`)
- **Suite C**: Read-only scale-out (`16` clients, `20 s`)
- **Suite D**: Hot-row contention (`50` hot accounts, `8` clients, `15 s`)
- **Suite E**: `sysbench oltp_read_write` (`4` tables x `10,000` rows, `8` threads, `20 s`)
- **Suite F**: WAN emulation (`tc qdisc replace dev eth0 root netem delay 25ms`, `~50 ms` RTT, `15 s`)

| Topology | A Single RW (TPS / ms) | B1 Disjoint (TPS / drift) | B2 Overlap (TPS / drift) | C RO 16c (TPS) | D Hot Conflict (TPS / drift) | E Sysbench (TPS / err) | F WAN `25ms` (TPS / p95 ms) |
| :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| `pg17-standalone` | `866.82` / `9.22` | `920.07` / `0` | `879.01` / `0` | `55,614.16` | `3,128.63` / `0` | `1,129.51` / `112` | N/A |
| `pg17-sync-streaming` | `409.48` / `19.52` | `407.41` / `0` | `465.22` / `0` | `54,483.07` | `1,370.10` / `0` | `819.36` / `118` | `57.00` / `353.49` |
| `pg-birep` | `875.91` / `9.12` | `820.09` / `0` | `1,228.60` / `-4,567` (DIV) | `53,072.52` | `1,231.15` / `-71,063` (DIV) | `1,105.32` / `96` | `824.04` / `24.95` |
| `pgedge` (LWW) | `556.06` / `14.37` | `346.95` / `0` | `818.65` / `-66,328` (LU) | `54,124.99` | `2,280.11` / `-278,698` (LU) | `888.56` / `114` | `646.77` / `32.40` |
| `pgedge-delta-apply` | — | — | — | — | `1,837.64` / **`0`** (CONV) | — | — |
| `bucardo` | `735.38` / `10.86` | `1,078.90` / `0` | `1,267.77` / `+123,679` (LU) | `53,731.92` | `1,378.79` / `-531,620` (LU) | `1,232.84` / `112` | `763.23` / `27.26` |
| `citus` | `309.04` / `25.85` | `265.29` / `0` | `312.98` / `0` | `21,324.70` | `1,691.45` / `0` | `189.44` / `9` | `21.67` / `633.96` |
| `yugabyte` | `173.64` / `45.88` | `194.75` / `0` | `170.19` / `0` | `17,150.58` | `832.65` / `0` | `128.24` / `0` | `5.78` / `3,401.33` |
| `cockroach` | `42.08` / `187.60` | `60.35` / `0` (`87` ret) | `74.17` / `0` (`96` ret) | `13,185.54` | `471.61` / `0` | `44.84` / `685` | `10.06` / `2,930.54` |

### Key Takeaways

1. **Disjoint vs Overlapping Writes**: Asynchronous multi-master stacks (`pg-birep`, `pgedge`, `bucardo`) converged cleanly with `0` drift on disjoint keys (`B1`), but silently lost updates or diverged on overlapping hot updates (`B2`, `D`). Enabling `spock.delta_apply` (`log_old_value=true`) on `pgedge` maintained `1,837.64 TPS` with **`0` balance drift**.
2. **WAN RTT Tax**: Adding `25 ms` one-way delay (`tc netem`) collapsed `PC/EC` engines (`pg17-sync-streaming` `-86.1%`, `citus` `-93.0%`, `yugabyte` `-96.7%`, `cockroach` `-76.1%`) while `PA/EL` async engines committed locally near `~10 ms`.

## Verified Empirical Limits & Observed `SQLSTATE`s

- **Keyless Tables (`pgbench_history`)**: `pg-birep` raised `SQLSTATE 55000` on `UPDATE`/`DELETE`; `pgedge` placed keyless tables in `default_insert_only` (local `UPDATE` silently omitted from replication); `bucardo` rejected `validate_sync` (`must specify a primary key`); `citus` blocked post-distribution `ADD PRIMARY KEY` / `SERIAL` with `0A000`; `cockroach` auto-injected hidden `rowid`.
- **Uncoordinated `SERIAL` PKs**: `pg-birep` halted subscription apply (`23505`, `apply_error_count=1`), whereas `pgedge` (`spock.resolutions=1`) and `bucardo` (`Conflicts=1`) silently overwrote node 1's insert. Always use stepped sequences, `snowflake`, or `unique_rowid()`.
- **Secondary `UNIQUE(email)` Collisions**: `pg-birep` and `bucardo` halted (`23505`, Bucardo `sync_mm` state `Bad`); `pgedge` (`transdiscard`) logged `23505` to `spock.exception_log` and left nodes diverged; `citus` blocked non-distribution-key `UNIQUE` indexes (`0A000`); `yugabyte` and `cockroach` enforced global `23505`.
- **PostgreSQL Features & Extensions**:
  - `pg_advisory_lock` and `LISTEN`/`NOTIFY` are strictly node-local on `pg-birep`, `pgedge`, and `bucardo`.
  - `yugabyte`: `pg_trgm`, `uuid-ossp`, `vector`, and `TEMP TABLE` work; `LISTEN`/`NOTIFY` returns `0A000` (disabled).
  - `cockroach`: `CREATE TEMP TABLE` returns `XCEXF` unless `experimental_enable_temp_tables='on'`; `LISTEN` returns `42601`; `40001` (`WriteTooOldError`) requires client retry loops (shown by `685` ignored errors in `sysbench`).
  - `citus`: `vector` extension absent (`0A000`) in standard `14.2.0-pg17` image.
- **Quorum & Container Quirks**:
  - `yugabyte` & `cockroach` (`RF=3`) survived `1/3` node loss (`RPO=0`) and halted completely on `2/3` node loss (`cockroach` `57014`, `yugabyte` timeout) until quorum returned.
  - `pgedge` Rocky UBI minimal image required overriding `output_plugin_libraries=pgoutput,spock_output` (`42501` fix), `listen_addresses=*`, and `host replication` `scram-sha-256`.
  - `bucardo` required a custom `Dockerfile.pg` installing `postgresql-plperl-17`, `libdbi-perl`, and `libdbd-pg-perl` on the PostgreSQL nodes for `db_getconn` (`PL/PerlU`).
