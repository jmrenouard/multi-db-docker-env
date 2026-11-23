# Error and Alert Matrix

Observed failures and runbooks.

| Symptom / Error | Scope | Cause | Runbook |
|---|---|---|---|
| `decommissioned ... reached EOL` (exit `1`) | `./mdb up`, `Makefile` | EOL (`mysql57`, `mysql80`, `mysql96`, `mariadb106`, `percona80`). | [Deploy](../../02-how-to-guides/deployment/deploy-standalone-and-clusters.md) |
| Port `3306` or `5432` collision | Standalone | Active standalone container holds port. | [Backup / Switch](../../02-how-to-guides/operations/backup-restore-and-switch-engines.md) |
| `suite tests/test_<env>.sh not found` | `./mdb test --suite` | No suite script on standalone or `pg17-baseline`. | [Deploy](../../02-how-to-guides/deployment/deploy-standalone-and-clusters.md) |
| `wsrep_cluster_status=Non-Primary` | `galera` | Full shutdown or split lost quorum. | [Failover / Quorum](../../02-how-to-guides/incident-response/remediate-cluster-failover-and-quorum.md) |
| Missing `Leader` in `patronictl list` | `patroni` | Leader stopped or etcd lease expired. | [Failover / Quorum](../../02-how-to-guides/incident-response/remediate-cluster-failover-and-quorum.md) |
| `SQLSTATE 57014` / write timeout | `cockroach`, `yugabyte`, `mongo` | 2/3 `RF=3` node loss blocks writes. | [Failover / Quorum](../../02-how-to-guides/incident-response/remediate-cluster-failover-and-quorum.md) |
| `SQLSTATE 23505` / `23503` / `55000` | `pg-birep`, `bucardo`, `pgedge` | PK collision, FK race, or keyless update. | [Failover / Quorum](../../02-how-to-guides/incident-response/remediate-cluster-failover-and-quorum.md) |
| `mdb pki verify` / `openssl verify` fail | `ssl/`, `certs_patroni/` | Expired cert, bad SAN, or key mode not `0600`. | [TLS / TDE](../../02-how-to-guides/security/configure-tls-pki-and-tde-boundaries.md) |
| Unencrypted Docker volumes | All stacks | No external KMS (`OpenBao`/`KMIP`) or TDE. | [TLS / TDE](../../02-how-to-guides/security/configure-tls-pki-and-tde-boundaries.md) |

See [PG Multi-Master](../../../documentation/pg_multimaster.md) for `SQLSTATE` data.
