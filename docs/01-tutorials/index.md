# Tutorials

Hands-on guided labs for `multi-db-docker-env`.

| Lab | Focus | Commands Covered |
|---|---|---|
| [1. Local Sandbox Setup](01-local-sandbox-setup.md) | Standalone MySQL 8.4 via Traefik v3 | `doctor`, `up`, `client`, `down` |
| [2. First HA Failover Lab](02-first-ha-failover-lab.md) | 3-node Patroni PG 17 HA + failover | `up patroni`, `patronictl`, `test_failover.sh` |
| [3. PG Multi-Master Lab](03-postgres-multimaster-lab.md) | PG 18.6 bidirectional + benchmarks | `up pg18-birep`, `test`, `bench`, `down` |

Next: [How-To Guides](../02-how-to-guides/index.md), [Reference](../03-reference/index.md), and [Explanation](../04-explanation/index.md).
