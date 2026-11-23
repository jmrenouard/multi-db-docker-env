# Transparent Data Encryption (TDE) and Data-at-Rest Guide

This reference covers Transparent Data Encryption (TDE) and data-at-rest storage across all five engine families in `multi-db-docker-env`. See [tls_setup.md](tls_setup.md) for transport TLS and [supported_products.md](supported_products.md) for active versions.

*Version francaise : [tde_encryption_fr.md](tde_encryption_fr.md).*

## 1. Encryption Layers and Threat Model

Database encryption separates network transport, storage engine TDE, and host block encryption into three layers.

| Layer | Scope | Key Model | Threat Mitigated | Lab Default |
| :--- | :--- | :--- | :--- | :--- |
| **Transport TLS** | Client and node links | X.509 CA and leaf keys | Network sniffing, MITM | Local PKI (`make gen-ssl-all`) |
| **Storage TDE** | Tablespaces, WAL/redo, backups | `DEK` wrapped by `KEK` | Stolen files, snapshots | Off (no external KMS) |
| **OS / Block** | Host disk or volume | `dm-crypt`/LUKS, ZFS, cloud KMS | Physical disk theft | Host OS dependent |

TDE uses a two-tier envelope hierarchy. Each engine encrypts pages and logs with Data Encryption Keys (`DEK`). A master Key Encryption Key (`KEK`) inside an external KMS (`OpenBao`, `KMIP`, `AWS KMS`, `GCP Cloud KMS`, `Azure KMS`, `OCI KMS`, or `HSM`) wraps every `DEK`.

> **Note**: Default Compose stacks run without an external KMS on plain Docker volumes. Run `make gen-ssl-all` to enable local transport TLS.

## 2. Engine Overview

| Family | Active Images | Community TDE | Enterprise / Open-Source Path | Key Backends |
| :--- | :--- | :--- | :--- | :--- |
| **MySQL** | `mysql:8.4`, `9.7` | Local file only | Enterprise Keyring Components | `component_keyring_file`, `KMIP`, `AWS`/`OCI` KMS |
| **MariaDB** | `mariadb:10.11`–`12.3` | Yes (InnoDB, Aria) | Community + Enterprise KMS | `file_key_management`, `AWS KMS`, external KMS |
| **Percona MySQL** | `percona/percona-server:8.4` | Yes (open source) | Keyring Components (`mysqld.my`) | `component_keyring_file`, `KMIP`, `OpenBao` |
| **PostgreSQL** | `postgres:15`–`18` | No (LUKS / ZFS) | Percona PG + `pg_tde` 2.1 | `KMIP`, `OpenBao`, local keyfile |
| **Distributed SQL** | `yugabyte:2026.1.3`, `cockroach:v25.4` | YB yes / CRDB Ent. | YB DocDB KMS / CRDB CMEK | `KMIP`, `AWS`/`GCP`/`Azure` KMS |
| **MongoDB** | `mongo:7.0`, `8.0` | No (LUKS / `CSFLE`) | MongoDB Ent. / Percona MongoDB | `KMIP`, `AWS KMS`, `Azure KMS` |

## 3. MySQL 8.4 and 9.7 LTS

MySQL 8.4 removed legacy keyring plugins and enforces **Keyring Components** (`mysqld.my` manifest). InnoDB encrypts tablespaces (`ENCRYPTION='Y'`), redo logs (`innodb_redo_log_encrypt`), and undo logs (`innodb_undo_log_encrypt`).

- **Community Edition (`mysql:8.4`, `mysql:9.7`)**: Ships only `component_keyring_file` for local single-host key files without centralized KMS custody.
- **Enterprise Edition**: Adds `component_keyring_encrypted_file`, `component_keyring_kmip`, `AWS KMS`, `OCI KMS`, and external KMS components.

```json
{"components": "file://component_keyring_file"}
```

## 4. MariaDB 10.11, 11.4, 11.8, and 12.3 LTS

MariaDB includes native InnoDB and Aria Data-at-Rest Encryption across Community and Enterprise editions. Load `file_key_management` with a plain or encrypted keyfile to encrypt tablespaces, Aria tables, redo logs, and binary logs.

- **MariaDB 11.8 and 12.3 LTS**: Add online file key rotation (`file_key_management`) alongside Enterprise `AWS KMS` and external KMS plugins.

```ini
[mariadb]
plugin_load_add = file_key_management
file_key_management_filename = /etc/mysql/encryption/keyfile.enc
innodb_encrypt_tables = ON
innodb_encrypt_log = ON
aria_encrypt_tables = ON
```

## 5. Percona Server for MySQL 8.4 LTS

Percona Server for MySQL (`percona/percona-server:8.4`) delivers full open-source InnoDB TDE without paid license restrictions. It uses the MySQL Keyring Component model (`mysqld.my`) and supports `component_keyring_file`, `component_keyring_kmip`, `OpenBao`, and external KMS backends.

## 6. PostgreSQL 15–18 and 13 HA / Multi-Master Stacks

Community `postgres:15`–`18` lacks core storage TDE. All upstream PG Compose stacks in [pg_multimaster.md](pg_multimaster.md) (`pg17-baseline`, `pg-streaming`, `pg-logical`, `pg-birep`, `pg18-*`, `patroni`, `pgpool`, `pgedge`, `bucardo`, `citus`, `yt-cluster`) rely on OS encryption (`dm-crypt`/`LUKS`, ZFS, or cloud block KMS).

- **Percona Server for PostgreSQL + `pg_tde` 2.1**: Provides open-source engine TDE. Version `2.1` reaches GA for PostgreSQL 17 and PostgreSQL 18.1+ with AIO support.
- **Storage and WAL TDE**: Uses `tde_heap` (`AES-256-GCM`) and GA WAL encryption (`pg_tde.wal_encrypt = on`) backed by `KMIP` or `OpenBao`.
- **Backup and Upgrade Tools**: Encrypted clusters require `pg_tde_basebackup`, `pg_tde_waldump`, and `pg_tde_upgrade` instead of standard community tools.
- **YugabyteDB (`2026.1.3`)**: Uses DocDB envelope encryption with a universe key and per-tablet `DEK`s under an external KMS.
- **CockroachDB (`v25.4`)**: Requires CockroachDB Enterprise (`--enterprise-encryption`) or CockroachDB Cloud CMEK for Pebble store encryption.

## 7. MongoDB 7.0 and 8.0 LTS

Community `mongo:7.0` and `mongo:8.0` omit WiredTiger storage encryption at rest.

- **Community Mitigation**: Encrypt host volumes with `dm-crypt`/`LUKS` or encrypt sensitive fields in clients with `CSFLE`.
- **Native WiredTiger AES-256 TDE**: Available in MongoDB Enterprise and open-source **Percona Server for MongoDB** (`--enableEncryption` with `KMIP`, `AWS KMS`, or `Azure KMS`).

## 8. Key Management and Operations

1. Keep `KEK` custody outside containers with `OpenBao`, `KMIP`, `AWS KMS`, `GCP Cloud KMS`, `Azure KMS`, `OCI KMS`, or `HSM`.
2. Pair storage TDE with TLS ([tls_setup.md](tls_setup.md)) so wire traffic stays encrypted.
3. Verify backups (`pg_tde_basebackup`, encrypted `mariabackup`) with KMS access before production cutover.
4. See [INDEX.md](INDEX.md) for all runbooks and reference tables.
