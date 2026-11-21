# PostgreSQL Replication, Multi-Master & Distributed SQL Topologies

This guide documents all 13 PostgreSQL Compose stacks (`pg17-baseline`, `pg-streaming`, `pg-logical`, `pg-birep`, `pg18-streaming`, `pg18-logical`, `pg18-birep`, `yt-cluster`, `pgedge`, `bucardo`, `citus`, `yugabyte`, `cockroach`) available in `multi-db-docker-env` (`v2.5.0`), along with their unified `./mdb` CLI commands (31 active environments in `mdb catalog`), `Makefile` compatibility targets, V1/V2/PG18/YT empirical benchmark results, extended `T11`–`T18` test matrix, and verified failure modes.

*Companion deep-dive study, Log10 charts, and interactive HTML benchmark explorer: [jmrenouard/ClusterPostgreSQL-Series](https://github.com/jmrenouard/ClusterPostgreSQL-Series).*

*Version française : [pg_multimaster_fr.md](pg_multimaster_fr.md).*

## Architecture Matrix

| Topology | Engine / Image | Nodes & Routing | CAP / PACELC | Localhost Ports |
| :--- | :--- | :--- | :--- | :--- |
| **`pg-streaming`** | `postgres:17` (`wal_level=replica`) | 1 Primary RW + 1 Standby RO (`async` / `sync`) | `AP` (`async`) / `CP` (`sync`) | `15434` (pri), `15435` (stb) |
| **`pg-logical`** | `postgres:17` (`wal_level=logical`) | 1 Publisher + 1 Subscriber (`pub_logical` -> `sub_logical`) | `AP` / `PA-EL` | `15436` (pub), `15437` (sub) |
| **`pg-birep`** | `postgres:17` (`17.11`) + `haproxy:lts-alpine` | 2 active-active nodes + HAProxy RR | `AP` / `PA-EL` | `15440` (LB), `15441`–`15442`, `15449` (stats) |
| **`pg18-streaming`** | `postgres:18` (`18.6`, AIO `worker`, checksums `on`) | 1 Standalone + 1 Primary RW + 1 Standby RO (`async`/`sync`) | `AP` (`async`) / `CP` (`sync`) | `15531` (std), `15534` (pri), `15535` (stb) |
| **`pg18-logical`** | `postgres:18` (`18.6`, `substream=p`, `pubgencols=s`) | 1 Publisher + 1 Subscriber (`pub_pg18_logical` -> `sub_pg18_logical`) | `AP` / `PA-EL` | `15536` (pub), `15537` (sub) |
| **`pg18-birep`** | `postgres:18` (`18.6`, `uuidv7()`) + `haproxy:lts-alpine` | 2 active-active nodes (`origin=none`) + HAProxy RR | `AP` / `PA-EL` | `15540` (LB), `15541`–`15542`, `15549` (stats) |
| **`yt-cluster`** | `dbinvent/yt:1.21.3` (PG `18.7` + `yt_cluster 1.21` / `ytserv`) | 3 active-active nodes (default `cc=half` 2-of-3 XA 2PC; optional async `cc=nodes>=0`) | `CP` / `PC-EC` (default) · `AP` (async) | `5491`–`5493` (`127.0.0.1`) |
| **`pgedge`** | `ghcr.io/pgedge/pgedge-postgres:17-spock5-minimal` | 3-node Spock 5.0.14 + Snowflake 2.6.1 mesh | `AP` / `PA-EL` | `15450` (LB), `15451`–`15453` |
| **`bucardo`** | Custom `postgres:17` (`plperl`) + Bucardo `5.6.0` | 2 PG 17 sources + Perl async daemon | `AP` / `PA-EL` | `15461`–`15462` |
| **`citus`** | `citusdata/citus:14.2.0-pg17` | 1 Coordinator + 2 Workers (8 shards) | `CP` (Coord SPOF / 2PC) | `15490` (coord), `15491`–`15492` |
| **`yugabyte`** | `yugabytedb/yugabyte:2026.1.3.0-b100` | 3 YSQL/DocDB Raft nodes (`RF=3`) | `CP` / `PC-EC` | `15471`–`15473` (YSQL), `17001` (UI) |
| **`cockroach`** | `cockroachdb/cockroach:latest-v25.4` | 3 Pebble Raft nodes (`RF=3`, `SERIALIZABLE`) | `CP` / `PC-EC` | `15481`–`15483` (SQL), `18081` (UI) |
| **`pg17-baseline`** | `postgres:17` | Standalone (`15431`) + Sync Streaming HA (`15432`–`15433`) | `CA` / `PC-EC` | `15431`–`15433` |

## Quick Start (`./mdb` Unified CLI & `Makefile` Wrappers)

```bash
# Unified ./mdb CLI (v2.5.0, 31 active environments incl. all 13 PG Compose stacks)
./mdb catalog --category cluster --engine postgres
./mdb up yt-cluster && ./mdb setup yt-cluster && ./mdb test yt-cluster --suite && ./mdb down yt-cluster
./mdb up pg17-baseline && ./mdb test pg17-baseline && ./mdb down pg17-baseline
./mdb lint   # bash -n on tracked .sh scripts + docker compose config -q on all 21 stacks

# Uniform Makefile wrappers across all 13 PG Compose stacks (up-/setup-/test-/down-)
make up-yt-cluster && make setup-yt-cluster && make test-yt-cluster && make down-yt-cluster
make pg17-baseline-up && make test-pg17-baseline && make pg17-baseline-down
make lint && make test   # Makefile validation aliases

# Extended empirical test matrix (T11-T18) & sequential cross-engine benchmarks
make test-pg-extended
make bench-pg-multimaster
make bench-pg-v2
make bench-pg18
make bench-yt-cluster
make clean-pg18
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

## PostgreSQL 18.6 Native Stacks & Benchmark Highlights (`v2.3.0`)

`make bench-pg18` executes all 18 suites (`A`–`H`, WAN `10/25/50 ms`, concurrency `c1..c32`) across all 5 native PG 18.6 topologies (`PG_SCALE=2`):

| Topology | `A_rw` TPS | `C_ro` TPS | `E_sb_rw` TPS | `E2_ro` TPS | `E3_wo` TPS | `E4_pt` QPS | `H_append` TPS | `F_wan25` TPS | `T11` rows/s |
| :--- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| `pg18-standalone` | `784.43` | `42,373.67` | `1,046.67` | `2,000.88` | `1,382.15` | `130,850.73` | `1,956.76` | N/A | `80,108` |
| `pg18-async-streaming` | `558.34` | `47,548.05` | `980.72` | `1,706.90` | `1,809.82` | `126,416.90` | `1,423.07` | `554.93` | `87,903` |
| `pg18-sync-streaming` | `497.94` | `32,258.16` | `767.63` | `1,869.54` | `1,184.57` | `122,246.91` | `1,760.26` | `41.56` | `75,629` |
| `pg18-logical` | `314.26` | `45,862.68` | `1,027.84` | `1,517.26` | `1,582.39` | `131,542.35` | `3,518.49` | `844.10` | `69,827` |
| `pg18-birep` (`uuidv7`) | `514.28` | `42,190.66` | `1,055.55` | `2,053.07` | `1,492.99` | `146,907.74` | `2,066.70` | `747.42` | `70,470` |

- **Docker `PGDATA` layout**: `postgres:18` moved `PGDATA` to `/var/lib/postgresql/18/docker` (`VOLUME /var/lib/postgresql`); all three PG 18 compose stacks mount `/var/lib/postgresql` and target `${PGDATA:-/var/lib/postgresql/18/docker}`.
- **AIO `io_method` & Checksums**: Defaults are `io_method=worker` (`io_workers=3`) and `data_checksums=on`. `io_method=io_uring` fails with `Operation not permitted` under default Docker seccomp; `worker` cut cold post-checkpoint seq-scan latency by `-18.5%` (`829.4 ms` vs `1018.3 ms` on `sync`).
- **Native `uuidv7()` & 7 `confl_*` Counters**: `id UUID PRIMARY KEY DEFAULT uuidv7()` achieved `50/50` collision-free dual-node writes (`0` `23505`, `0` B-tree inversions) and `2,066.70 TPS` on `H_append_only_insert` (`3.30x` vs PG 17 `pg-birep`). All 7 `pg_stat_subscription_stats` counters — including `confl_multiple_unique_conflicts` — are verified in `tests/test_pg18_birep.sh`.
- **Logical Sequence Sync Deferred to PG 19**: `CREATE SUBSCRIPTION` defaults to `substream=p` and `publish_generated_columns=stored` works (`pubgencols=s`), but `FOR ALL SEQUENCES` and `REFRESH SEQUENCES` still return `SQLSTATE 42601` in PG 18.6 (subscriber sequences remain `1|false` -> `23505` on failover).

## YT Cluster 1.21.3 (PostgreSQL 18.7) Active-Active Stack (`v2.4.1`–`v2.5.0`)

`docker-compose-yt-cluster.yml` deploys a 3-node [`dbinvent/yt:1.21.3`](https://hub.docker.com/r/dbinvent/yt) cluster (`yt1`/`yt2`/`yt3` on `127.0.0.1:5491-5493:5432`) combining unmodified PostgreSQL 18.7 (`io_method=worker`, `data_checksums=on`) with the `yt_cluster 1.21` extension and local `ytserv` Rust coordinator ([YT Overview](https://dbinvent.com/30p) · [`dbinvent.com/agent.md`](https://dbinvent.com/agent.md)).

- **Licensing & Jepsen Caveat**: [`DBinvent/yt-cluster-lite`](https://github.com/DBinvent/yt-cluster-lite) is MIT-licensed (embedded single-DB leaf rejecting multi-DB writes with `SQLSTATE 0A000`), whereas `ytserv` + `ytctl` inside `dbinvent/yt:1.21.3` are **PolyForm Noncommercial 1.0.0 / Commercial**; published [Jepsen report](https://dbinvent.com/cluster/articles/jepsen) results are vendor-executed against `1.20.1` (`cursor-stability`, `51` initial findings -> `49/49` retested).

- **Sync-2PC (`cc=half`) vs Async (`cc=nodes>=0`) Full 18-Suite Matrix**: `yt_info('d')` defaults to `def_cluster_commit={"at_least":0,"mode":1}` (`half` = 2-of-3 synchronous XA 2PC, `NO_SC`, `min_cluster_size=2`). Under `PG_SCALE=2` (`make bench-yt-cluster`), default `yt-cluster` achieved `A_rw=20.63`, `B1=36.14`, `B2_overlap=10.69`, `C_ro=48,787.74`, `D_hot=67.76` (`0` drift), `E_sb=28.48`, `E2=2,122.68`, `E3=26.43`, `E4_pt=165,472.75`, `H_append=110.53` (`uuidv7()`), `F_wan=4.81/2.25/1.41`, and `G_conc=28.07..4.60 TPS` (`T11=86 rows/s`). Switching per-table config to async `cc=nodes>=0` (`yt-cluster-async`) raised write throughput across all 18 suites: `A_rw=41.45`, `B1=88.19`, `B2_overlap=55.03`, `C_ro=40,774.49`, `D_hot=163.01` (`0` drift), `E_sb=124.05`, `E2=2,083.85`, `E3=133.55`, `E4_pt=177,442.88`, `H_append=224.93`, non-Leader `F_wan=8.47/4.78/2.90`, and `G_conc=53.94..91.68..44.20 TPS`.
- **Verified Limits, `recon` Quarantine & Reversibility (`make yt-cluster-test`)**: Conflict arbitration enforces `0` balance drift (`55409` on lost updates / `SERIAL`, `40001` on `UNIQUE`); in async mode (`cc=nodes>=0`), reusing `sbtest1..4` immediately after concurrent conflicting writes can trigger `SQLSTATE 55000` (`yt_synchronize: recon: row [...] is blocked` pending audit), so the runner isolates `sbtest` preparation per destructive suite; `SAVEPOINT` rollback over writes fails at `COMMIT` with `0A000`; `2/3` node outage halts writes with `57P03` (`min_cluster_size=2`, `YT-E1852`); `T16` `SIGKILL` preserves `RPO=0` (`20/20`, with stale `.s.YT.5432.pid` `YT-E1104` caveat on PID reuse); `T_REVERT` confirms `DROP EXTENSION yt_cluster CASCADE;` removes extension and triggers cleanly while keeping all user data intact (`5/5` -> `6/6` plain PG write).

## Durable Production-Tuned Stacks & 18-Topology Harness (`v2.6.0`, `make bench-pg-optimized`)

`v2.6.0` parameterizes durable, production-tuned PostgreSQL and Distributed SQL defaults across all 13 PG/Multi-Master Docker Compose files (`fsync=on`, `full_page_writes=on`, preserving `RPO=0` on synchronous/Raft/Citus/`yt-cluster` `cc=half` configurations) alongside a unified 18-topology benchmark harness (`make bench-pg-optimized`, `./scripts/bench_pg_optimized_runner.sh --resume` -> `reports/benchmark_optimized.csv`, `318` canonical rows at `PG_SCALE=20`):

- **PostgreSQL 17 & 18 Compose Tunings**: Parameterized env-var defaults for `shared_buffers=512MB`, `effective_cache_size=2GB`, `work_mem=16MB`, `maintenance_work_mem=128MB`, `max_connections=200`, `wal_compression=lz4`, `checkpoint_completion_target=0.9`, `random_page_cost=1.1`, `effective_io_concurrency=16`, `jit=off`, `logical_decoding_work_mem=256MB`, and `max_parallel_apply_workers_per_subscription=4`. PG 18 stacks and `yt-cluster` additionally expose `io_method=worker` and `io_workers=4` (never applied to PG 17).
- **15 GiB Host Memory Caps & HAProxy Load Balancers**: Cluster `mem_limit` caps protect host stability (`citus` `2048m` x3, `yugabyte` `3072m` x3, `cockroach` `3072m` x3; run 1 stack at a time). Dedicated HAProxy LBs (`haproxy_yugabyte` on `127.0.0.1:15470` + `:15479/stats`, `haproxy_cockroach` on `127.0.0.1:15480` + `:15489/stats`) balance single-endpoint/sysbench/concurrency workloads (`A`, `E*`, `G*`) across all 3 cluster nodes with `resolvers docker` (`127.0.0.11:53`) and `init-addr last,libc,none`.
- **Engine-Specific Optimizations in `bench_pg_optimized_lib.py`**:
  - **PG Heap & Hot Updates**: `WITH (fillfactor=90)` on `pgbench_{branches,tellers,accounts}`, `pgbench -M prepared --max-tries=200`, `5s` warmup (`WARMUP_S=5`), and `sysbench` `4x25000` with `/tmp/sb_wrap.lua` retrying `55409`, `40001`, and `40P01`.
  - **`pgedge` & `bucardo`**: `pgedge` configures `spock.delta_apply` (`log_old_value=true`) on balance columns and drains peer replication before resetting `hs[0]`; `bucardo` configures `quick_delta_check=1`, `ctl_sleep=0.1`, `kid_sleep=0.1`, and `autokick=1`/`stayalive=1`/`kidsalive=1`.
  - **`citus` (`shard_count=32`)**: Separates autocommit `DROP TABLE`s to avoid distributed deadlocks and uses 1-shard-per-statement routing (`branches(bid)`, `tellers(tid)`, `accounts(aid)`, `history(aid, colocate_with=>'pgbench_accounts')`).
  - **`yugabyte`, `cockroach` & `cockroach-rc`**: YugabyteDB enables Read Committed (`yb_enable_read_committed_isolation=true`), wait queues, packed rows, CBO, `CACHE 1000` on `BIGSERIAL` sequences, and chunked `50k`-row `INSERT` loading (preventing `COPY` OOM at `PG_SCALE=20`). `cockroach-rc` enables `sql.txn.read_committed_isolation.enabled = true` with a dedicated non-root admin role (`bench`, `ALTER ROLE bench SET default_transaction_isolation = 'read committed'`), bypassing `root`'s `42501` restriction (`--cache=1GiB --max-sql-memory=1GiB`).
  - **`yt-cluster` & `yt-cluster-async`**: Sets `YT_MAX_PREPARED=300` without overriding `shared_preload_libraries`, enforces Raft Leader affinity on `A`/`E*`/`G*`, non-Leader WAN netem on `F`, `uuidv7()`, `CgPIAQE=`/`CgcSAhACyAEB` parallel apply settings, `psycopg` `55409` retries on `B2`/`D`, and `E3` `sbtest` re-preparation on async runs.

