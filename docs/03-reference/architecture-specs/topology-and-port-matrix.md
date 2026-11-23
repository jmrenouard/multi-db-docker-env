# Topology and Port Matrix

Source: [catalog.go](../../../pkg/catalog/catalog.go).

## Standalone (Traefik UI `:8088`)

| IDs | Images | Port |
|---|---|---|
| `mysql97`, `mysql84` | `mysql:9.7`, `8.4` | `3306` |
| `mariadb123`..`1011` | `mariadb:12.3`, `11.8`, `11.4`, `10.11` | `3306` |
| `percona84` | `percona/percona-server:8.4` | `3306` |
| `postgres18`..`15` | `postgres:18`, `17`, `16`, `15` | `5432` |

## HA and NoSQL Clusters

| ID | Subnet | LB / Entry Ports | Node Ports | TLS Dir |
|---|---|---|---|---|
| `galera` | `10.6.0.0/24` | `3306`, `8404` | `3511`–`3513` | `ssl/` |
| `repli` | `10.5.0.0/24` | `3406`, `3407`, `8405` | `3411`–`3413` | `ssl/` |
| `innodb` | `10.9.0.0/24` | `6446`, `6447`, `8407` | `4411`–`4413` | `ssl/innodb/` |
| `patroni` | Bridge | `5000`, `5001`, `7000` | `8008`, `2379` | `certs_patroni/` |
| `pgpool` | `10.8.0.0/24` | `9999`, `5100`, `5101`, `8406` | `5611`–`5613` | `ssl/pgpool/` |
| `mongo` | `10.10.0.0/24` | `27100`, `8408` | `27411`–`27413` | `ssl/mongo/` |
| `mongo8` | `10.11.0.0/24` | `27200`, `8409` | `27511`–`27513` | `ssl/certs/mongo8/` |

## PG Distributed Stacks

| ID | Engine / Version | Ports |
|---|---|---|
| `pg17-baseline` | PG `17` standalone + sync | `15431`–`15433` |
| `pg-streaming` / `pg18-streaming` | PG `17` / `18.6` streaming | `15434`–`15435` / `15531`, `15534`–`15535` |
| `pg-logical` / `pg18-logical` | PG `17` / `18.6` logical | `15436`–`15437` / `15536`–`15537` |
| `pg-birep` / `pg18-birep` | PG `17` / `18.6` birep + LB | `15440`–`15442`, `15449` / `15540`–`15542`, `15549` |
| `pgedge` / `bucardo` / `citus` | Spock 5 / Bucardo 5 / Citus 14.2 | `15450`–`15453` / `15461`–`15462` / `15490`–`15492` |
| `cockroach` / `yugabyte` / `yt-cluster` | CRDB `25.4` / YB `2026.1.3` / YT `1.21.3` | `15481`–`15483` (`18081`) / `15471`–`15473` (`17001`) / `5491`–`5493` |

EOL (exit `1`): `mysql57`, `mysql80`, `mysql96`, `mariadb106`, `percona80` ([Supported Products](../../../documentation/supported_products.md)).
