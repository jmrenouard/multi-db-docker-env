# PostgreSQL Replication, Multi-Master & Distributed SQL Topologies

This guide documents the eight PostgreSQL replication, multi-master, and distributed SQL topologies (`pg-streaming`, `pg-logical`, `pg-birep`, `pgedge`, `bucardo`, `citus`, `yugabyte`, `cockroach`) plus the PostgreSQL 17 baseline (`docker-compose-pg17-baseline.yml`) available in `multi-db-docker-env` (`v2.2.0`), along with their Makefile targets, Go `mdb` CLI commands (16 registered topologies), V1/V2 empirical benchmark results, extended `T11`–`T18` test matrix, and verified failure modes.

*Companion deep-dive study, Log10 charts, and interactive HTML benchmark explorer: [jmrenouard/ClusterPostgreSQL-Series](https://github.com/jmrenouard/ClusterPostgreSQL-Series).*

*Version française : [pg_multimaster_fr.md](pg_multimaster_fr.md).*

## Architecture Matrix

| Topology | Engine / Image | Nodes & Routing | CAP / PACELC | Localhost Ports |
| :--- | :--- | :--- | :--- | :--- |
| **`pg-streaming`** | `postgres:17` (`wal_level=replica`) | 1 Primary RW + 1 Standby RO (`async` / `sync`) | `AP` (`async`) / `CP` (`sync`) | `15434` (pri), `15435` (stb) |
| **`pg-logical`** | `postgres:17` (`wal_level=logical`) | 1 Publisher + 1 Subscriber (`pub_logical` -> `sub_logical`) | `AP` / `PA-EL` | `15436` (pub), `15437` (sub) |
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
make pg-streaming-up && make test-pg-streaming && make pg-streaming-down
make pg-logical-up   && make test-pg-logical   && make pg-logical-down
make pg-birep-up     && make test-pg-birep     && make pg-birep-down
make pgedge-up       && make test-pgedge       && make pgedge-down
make bucardo-up      && make test-bucardo      && make bucardo-down
make citus-up        && make test-citus        && make citus-down
make cockroach-up    && make test-cockroach    && make cockroach-down
make yugabyte-up     && make test-yugabyte     && make yugabyte-down

# Extended empirical test matrix (T11-T18 across all 10 PostgreSQL topologies)
make test-pg-extended

# Sequential cross-engine benchmark suites (V1 Suites A-F and V2 Suites A-H + WAN + Concurrency)
make bench-pg-multimaster
make bench-pg-v2

# Or via Go mdb CLI (v2.2.0, 16 registered topologies)
./bin/mdb topologies
./bin/mdb up pg-streaming && ./bin/mdb status pg-streaming && ./bin/mdb down pg-streaming
./bin/mdb up pg-logical   && ./bin/mdb status pg-logical   && ./bin/mdb down pg-logical
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
| `pg17-async-streaming` | `610.15` / `13.09` | `627.39` / `0` | `584.80` / `0` | `45,358.52` | `2,081.26` / `0` | `962.84` / `107` | `599.61` / `34.38` |
| `pg17-sync-streaming` | `409.48` / `19.52` | `407.41` / `0` | `465.22` / `0` | `54,483.07` | `1,370.10` / `0` | `819.36` / `118` | `57.00` / `353.49` |
| `pg17-logical` | `532.38` / `14.99` | `251.63` / `0` | `355.57` / `0` | `42,302.43` | `2,386.93` / `0` | `595.81` / `65` | `654.11` / `30.58` |
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

## V2 Extended Matrix (`T11`–`T18`) & V2 Benchmarks (`bench-pg-v2`)

Running `make test-pg-extended` executes 8 deep empirical probes across all 10 topologies:
- **`T11` Bulk 10k Catch-Up**: `pgedge` (`67,406 rows/s`), `pg-birep` (`65,881 rows/s`), `pg17-logical` (`52,816 rows/s`), `cockroach` (`22,079 rows/s`); peer catch-up `105–417 ms`.
- **`T12` UPDATE vs DELETE Tombstone Race**: `pg17-logical` diverged (`pub=upd_n1`, `sub=DELETED`, missing-row `UPDATE` ignored); async multi-master silently let `DELETE` win; physical streaming rejected standby writes (`25006`); Raft consensus serialized deterministically.
- **`T13` Cross-Node FK Race**: `bucardo` failed `0/10` (`23503x10`) due to async polling lag (`p50=548.74 ms`); physical standby rejected writes (`25006x10`); logical/mesh/Raft passed `10/10`.
- **`T14` Rich-Data MD5 Fidelity (`64 KiB` BYTEA / JSONB / UTF-8)**: `pgedge` Rocky UBI defaulted to `SQL_ASCII` (`chr()` raised `SQLSTATE 54000`; escaped UTF-8 converged `3/3`); all other engines converged identically (`md5=00493e3a`).
- **`T15` Raw Visibility Lag (`n=30`)**: `pgedge` `p50=1.16 ms` (`p95=1.63`), `pg-birep` `1.47/2.28 ms`, `pg17-logical` `1.68/2.14 ms`, `pg17-sync-streaming` `1.88/2.74 ms`, `yugabyte` `2.01/2.83 ms`, `cockroach` `4.09/4.98 ms`, `bucardo` `548.74/1275.25 ms`.
- **`T16` `SIGKILL` Crash RPO & `T17` Long Open TX**: `RPO=0` across 9/10 engines; `citus` worker2 `SIGKILL` raised `08006` until restart; `bucardo` metadata-node `SIGKILL` left the outage peer write un-replicated (`post_restart=20/21`); zero dirty reads in `T17` (`cockroach` `serializable_intent_wait=2.1s`).
- **`T18` Sequence Sync after 50 Inserts**: Physical streaming preserved sequence state across `pg_promote()` (`last_value=66|true`, zero `23505`); Raft global sequences passed; `pg17-logical`, `pg-birep`, `pgedge`, and `bucardo` left peer sequences at `1|false` -> **`SQLSTATE 23505`** unless using `setval()`, stepped sequences, or `snowflake.nextval()`.

Running `make bench-pg-v2` adds extended sysbench workloads (`E2` read-only, `E3` write-only, `E4` point-select peaking at `148,022 TPS` on `pg17-async-streaming`), `H_append_only_insert` (`3,108 TPS` standalone, `2,987 TPS` 2-node YugabyteDB, `2,207 TPS` 2-node pgEdge), concurrency scaling (`G_conc_c1..c32`), and WAN latency sweeps (`10 / 25 / 50 ms`, collapsing `pg17-sync-streaming` `121.75 -> 57.00 -> 25.79 TPS` and `yugabyte` `15.38 -> 5.78 -> 3.06 TPS`). See [ClusterPostgreSQL-Series](https://github.com/jmrenouard/ClusterPostgreSQL-Series) for full CSV datasets, Log10 charts, and interactive dashboard.
