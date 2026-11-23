# Chiffrement Transparent des Données (TDE) et Données au Repos

Ce guide couvre le chiffrement transparent des données (TDE) pour les cinq familles de moteurs de `multi-db-docker-env`. Voir [tls_setup.md](tls_setup.md) pour TLS et [supported_products_fr.md](supported_products_fr.md) pour les versions actives.

*English version: [tde_encryption.md](tde_encryption.md).*

## 1. Couches de Chiffrement et Modèle de Menaces

La sécurité base de données sépare trois couches entre le réseau, le moteur de stockage et le disque hôte.

| Couche | Périmètre | Modèle de clés | Menace couverte | Défaut du labo |
| :--- | :--- | :--- | :--- | :--- |
| **Transport TLS** | Flux clients et inter-nœuds | AC X.509 et clés | Écoute réseau et MITM | PKI locale (`make gen-ssl-all`) |
| **Stockage TDE** | Tablespaces, WAL/redo, backups | `DEK` protégée par `KEK` | Vol de fichiers ou backups | Inactif (sans KMS externe) |
| **OS / Bloc** | Volume ou disque hôte | `dm-crypt`/LUKS, ZFS, KMS cloud | Vol de disque ou snapshot | Dépend du système hôte |

Le TDE suit une hiérarchie à deux niveaux. Le moteur chiffre les pages et journaux avec des clés locales (`DEK`). Une clé maître (`KEK`) dans un KMS externe (`OpenBao`, `KMIP`, `AWS KMS`, `GCP Cloud KMS`, `Azure KMS`, `OCI KMS` ou `HSM`) protège chaque `DEK`.

> **Note** : Les piles Compose par défaut tournent sans KMS externe sur des volumes non chiffrés. Exécutez `make gen-ssl-all` pour TLS.

## 2. Vue d'Ensemble par Moteur

| Famille | Images actives | TDE communautaire | Voie TDE Enterprise / Open-Source | Backends KMS |
| :--- | :--- | :--- | :--- | :--- |
| **MySQL** | `mysql:8.4`, `9.7` | Fichier local seul | Composants Keyring Enterprise | `component_keyring_file`, `KMIP`, `AWS`/`OCI` KMS |
| **MariaDB** | `mariadb:10.11`–`12.3` | Oui (InnoDB, Aria) | Plugins Community + Enterprise KMS | `file_key_management`, `AWS KMS`, KMS externe |
| **Percona MySQL** | `percona/percona-server:8.4` | Oui (open-source) | Keyring Components (`mysqld.my`) | `component_keyring_file`, `KMIP`, `OpenBao` |
| **PostgreSQL** | `postgres:15`–`18` | Non (LUKS / ZFS) | Percona PG + `pg_tde` 2.1 | `KMIP`, `OpenBao`, fichier local |
| **SQL Distribué** | `yugabyte:2026.1.3`, `cockroach:v25.4` | YB oui / CRDB Ent. | KMS DocDB YB / CRDB CMEK | `KMIP`, `AWS`/`GCP`/`Azure` KMS |
| **MongoDB** | `mongo:7.0`, `8.0` | Non (LUKS / `CSFLE`) | MongoDB Ent. / Percona MongoDB | `KMIP`, `AWS KMS`, `Azure KMS` |

## 3. MySQL 8.4 et 9.7 LTS

MySQL 8.4 supprime les anciens plugins keyring et impose les **Keyring Components** (`mysqld.my`). InnoDB chiffre les tablespaces (`ENCRYPTION='Y'`), journaux redo (`innodb_redo_log_encrypt`) et undo (`innodb_undo_log_encrypt`).

- **Édition Community (`mysql:8.4`, `mysql:9.7`)** : Inclut seulement `component_keyring_file` sur disque local sans KMS centralisé.
- **Édition Enterprise** : Ajoute `component_keyring_encrypted_file`, `component_keyring_kmip`, `AWS KMS`, `OCI KMS` et les composants KMS externes.

```json
{"components": "file://component_keyring_file"}
```

## 4. MariaDB 10.11, 11.4, 11.8 et 12.3 LTS

MariaDB intègre le chiffrement au repos InnoDB et Aria en éditions Community et Enterprise. Le plugin `file_key_management` lit un fichier de clés clair ou chiffré pour tablespaces, tables Aria, journaux redo et binlogs.

- **MariaDB 11.8 et 12.3 LTS** : Améliorent la rotation des clés (`file_key_management`) et ajoutent les plugins Enterprise `AWS KMS` et KMS externes.

```ini
[mariadb]
plugin_load_add = file_key_management
file_key_management_filename = /etc/mysql/encryption/keyfile.enc
innodb_encrypt_tables = ON
innodb_encrypt_log = ON
aria_encrypt_tables = ON
```

## 5. Percona Server for MySQL 8.4 LTS

Percona Server for MySQL (`percona/percona-server:8.4`) fournit un TDE InnoDB complet en open-source sans licence payante. Le serveur utilise les Keyring Components (`mysqld.my`) avec support `component_keyring_file`, `component_keyring_kmip`, `OpenBao` et KMS externes.

## 6. PostgreSQL 15–18 et les 13 Piles HA / Multi-Maître

PostgreSQL communautaire (`postgres:15` à `18`) ne possède pas de TDE natif. Les piles de [pg_multimaster_fr.md](pg_multimaster_fr.md) (`pg17-baseline`, `pg-streaming`, `pg-logical`, `pg-birep`, `pg18-*`, `patroni`, `pgpool`, `pgedge`, `bucardo`, `citus`, `yt-cluster`) utilisent le chiffrement OS/bloc (`dm-crypt`/LUKS, ZFS ou KMS cloud).

- **Percona Server for PostgreSQL + `pg_tde` 2.1** : Fournit un TDE moteur open-source. La version `2.1` est GA pour PostgreSQL 17 et PostgreSQL 18.1+ avec AIO.
- **Stockage et WAL** : Utilise la méthode `tde_heap` (`AES-256-GCM`) et le chiffrement WAL GA (`pg_tde.wal_encrypt = on`) avec `KMIP` ou `OpenBao`.
- **Outils requis** : Les clusters `pg_tde` exigent `pg_tde_basebackup`, `pg_tde_waldump` et `pg_tde_upgrade` à la place des binaires standards.
- **YugabyteDB (`2026.1.3`)** : Utilise le chiffrement par enveloppe DocDB avec clé d'univers et `DEK` par tablette sous KMS.
- **CockroachDB (`v25.4`)** : Exige CockroachDB Enterprise (`--enterprise-encryption`) ou CockroachDB Cloud CMEK pour chiffrer le stockage Pebble.

## 7. MongoDB 7.0 et 8.0 LTS

MongoDB communautaire (`mongo:7.0` et `mongo:8.0`) n'inclut pas le chiffrement WiredTiger au repos.

- **Options communautaires** : Protégez les volumes hôtes avec `dm-crypt`/LUKS ou chiffrez les champs sensibles avec `CSFLE`.
- **TDE WiredTiger AES-256 natif** : Disponible dans MongoDB Enterprise et **Percona Server for MongoDB** (`--enableEncryption` avec `KMIP`, `AWS KMS` ou `Azure KMS`).

## 8. Gestion des Clés et Exploitation

1. Stockez les `KEK` hors conteneurs dans `OpenBao`, `KMIP`, `AWS KMS`, `GCP Cloud KMS`, `Azure KMS`, `OCI KMS` ou `HSM`.
2. Associez TDE stockage et TLS réseau ([tls_setup.md](tls_setup.md)) pour protéger le trafic.
3. Testez sauvegardes et restaurations TDE (`pg_tde_basebackup`, `mariabackup` chiffré) avant la production.
4. Voir [INDEX_fr.md](INDEX_fr.md) pour tous les guides et matrices de référence.
