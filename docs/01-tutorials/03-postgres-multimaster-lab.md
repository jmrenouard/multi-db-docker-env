# Tutorial 3: PostgreSQL Multi-Master Lab

> **Learning Goal:** Start PostgreSQL 18.6 bidirectional logical replication (`pg18-birep`), verify replication health, run benchmarks, and clean up.
>
> **Sandbox Scope:** Run this lab only in an isolated local Docker host.

## Prerequisites

- Docker Compose v2 and Bash installed
- Free localhost ports `15540`–`15542` and `15549`
- Helper image `multi-db-pgbench-sysbench:latest` (`./mdb images build bench`)

## Step 1: Launch `pg18-birep`

Start both PostgreSQL 18.6 active-active nodes and initialize bidirectional subscriptions:

```bash
./mdb up pg18-birep
./mdb status pg18-birep
```

Expected output:

```text
Environment pg18-birep up successful
```

## Step 2: Verify Functional Replication

Run the Go verifier and full `tests/test_pg18_birep.sh` suite:

```bash
./mdb test pg18-birep --suite
```

Expected output includes `"status": "HEALTHY"` followed by all `test_pg18_birep.sh` assertions passing.

## Step 3: Stop Stack and Run Automated Benchmark

Tear down `pg18-birep` first (`bench_pg18_runner.sh` starts and cleans its own containers), then launch the benchmark runner:

```bash
./mdb down pg18-birep
./mdb bench pg18-birep
```

Expected output:

```text
Routing PG 18 benchmark for pg18-birep (pg18-birep)
=== Running PG 18 benchmark suite for pg18-birep ===
=== Completed pg18-birep ===
```

Results append to `reports/pg18_benchmarks/benchmark_pg18.csv`.

## Step 4: Verify Clean State

Confirm no `pg18` containers remain active:

```bash
./mdb status all
```

## Next Steps

- Operate engine switches and backups: [How-To Guides](../02-how-to-guides/index.md)
- Compare all 13 PostgreSQL stacks: [Reference](../03-reference/index.md)
- Understand `RPO=0` vs async multi-master trade-offs: [Explanation](../04-explanation/index.md)
