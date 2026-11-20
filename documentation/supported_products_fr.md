# Produits Supportés

Référence complète de tous les moteurs de bases de données et composants d'infrastructure supportés par le projet.

## 🐬 MySQL

| Version | Image Docker | Port Standalone | TLS | Fenêtre de support / EOL | Statut |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 9.7 LTS | `mysql:9.7` | `3306` (via Traefik) | ❌ | 2031-04-30 (Ext. 2034-04-30) | ✅ Supporté |
| 8.4 LTS | `mysql:8.4` | `3306` (via Traefik) | ❌ | 2029-04-30 (Ext. 2032-04-30) | ✅ Vérifié |

**Mode HA** : InnoDB Cluster (3 nœuds MySQL 8.4 LTS Group Replication + HAProxy)

## 🐬 MariaDB

| Version | Image Docker | Port Standalone | TLS | EOL Communautaire | Statut |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 12.3 LTS | `mariadb:12.3` | `3306` (via Traefik) | ✅ (cluster) | 2029-06-12 | ✅ Supporté |
| 11.8 LTS | `mariadb:11.8` | `3306` (via Traefik) | ✅ (cluster) | 2028-06-04 | ✅ Vérifié |
| 11.4 LTS | `mariadb:11.4` | `3306` (via Traefik) | ✅ (cluster) | 2029-05-29 | ✅ Vérifié |
| 10.11 LTS | `mariadb:10.11` | `3306` (via Traefik) | ✅ (cluster) | 2028-02-16 | ✅ Vérifié |

**Modes HA** :
- Cluster Galera (3 nœuds, réplication synchrone, ports 3511-3513)
- Réplication Maître/Esclave (1 maître + 2 esclaves, ports 3411-3413)

## 🐬 Percona Server

| Version | Image Docker | Port Standalone | TLS | EOL Communautaire | Statut |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 8.4 LTS | `percona/percona-server:8.4` | `3306` (via Traefik) | ❌ | 2029-04-30 | ✅ Supporté |

## 🐘 PostgreSQL

| Version | Image Docker | Port Standalone | TLS | EOL Communautaire | Statut |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 18 | `postgres:18` | `5432` (via Traefik) | ❌ | 2030-11-14 | ✅ Supporté |
| 17 | `postgres:17` | `5432` (via Traefik) | ❌ | 2029-11-08 | ✅ Vérifié |
| 16 | `postgres:16` | `5432` (via Traefik) | ❌ | 2028-11-09 | ✅ Vérifié |
| 15 | `postgres:15` | `5432` (via Traefik) | ❌ | 2027-11-11 | ✅ Vérifié |

**Modes HA, Réplication & Multi-Maître** :
- Cluster Patroni (3 PG 17 + 3 ETCD + HAProxy, ports 5000/5001/7000)
- Cluster PgPool-II (3 PG 17 + PgPool 4.6 + HAProxy, ports 5100/5101/8406)
- Réplication & Multi-Maître (`v2.1.0`–`v2.3.0`) : `pg-streaming`, `pg-logical`, `pg-birep`, `pg18-streaming`, `pg18-logical`, `pg18-birep`, `pgedge` (Spock 5), `bucardo`, `citus` (14.2), `cockroach` (v25.4), `yugabyte` (2026.1) — voir [pg_multimaster_fr.md](pg_multimaster_fr.md).

## 🍃 MongoDB

| Version | Image Docker | Port Standalone | TLS | EOL Communautaire | Statut |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 8.0 LTS | `mongo:8.0` | — | ✅ (cluster) | 2029-10-31 | ✅ Vérifié |
| 7.0 | `mongo:7.0` | — | ✅ (cluster) | 2027-08-31 | ✅ Vérifié |

**Mode HA** : ReplicaSet (3 nœuds rs0 + HAProxy)
- MongoDB 7 : ports 27411-27413 / HAProxy 27100 / Stats 8408
- MongoDB 8 : ports 27511-27513 / HAProxy 27200 / Stats 8409

## 🔧 Composants d'Infrastructure

| Composant | Image | Rôle | Ports |
| :--- | :--- | :--- | :--- |
| Traefik | `traefik:v3` | Proxy inverse pour les BDD standalone | `3306`, `5432`, `8080` (dashboard) |
| HAProxy | `haproxy:lts` / `haproxy:lts-alpine` | Répartiteur de charge TCP pour les clusters HA | Par cluster (voir docs) |
| ETCD | `quay.io/coreos/etcd:v3.5.21` | Config distribuée pour Patroni | `2379`, `2380` |

## 🛑 Versions Décommissionnées (Fin de Vie / EOL)

Les versions suivantes ont atteint leur fin de vie officielle communautaire (End-of-Life) et ont été retirées des stacks Compose actifs et des menus CLI. Les anciennes cibles `Makefile` affichent un avis EOL avec la cible de remplacement recommandée.

| Produit | Version Décommissionnée | Date EOL Officielle | Note de Décommissionnement | Remplacement Recommandé |
| :--- | :--- | :--- | :--- | :--- |
| MySQL | `5.7` (`mysql:5.7`) | **2023-10-31** | Fin de support Premier 2023-10-31 (Extended 2026-10-31) ; retiré du stack standalone | `mysql:8.4` (`make mysql84`) ou `mysql:9.7` (`make mysql97`) |
| MySQL | `8.0` (`mysql:8.0`) | **2026-04-30** | Fin de vie communautaire Oracle atteinte ; standalone et InnoDB Cluster migrés en 8.4 LTS | `mysql:8.4` (`make mysql84` / `make innodb-up`) ou `mysql:9.7` (`make mysql97`) |
| MySQL | `9.6` (`mysql:9.6`) | **2026-04-21** | Version Innovation remplacée par MySQL 9.7 LTS | `mysql:9.7` (`make mysql97`) |
| MariaDB | `10.6` (`mariadb:10.6`) | **2026-07-06** | Fin de la maintenance communautaire ; retiré du stack standalone | `mariadb:10.11` (`make mariadb1011`), `mariadb:11.4` (`make mariadb114`) ou `mariadb:12.3` (`make mariadb123`) |
| Percona Server | `8.0` (`percona/percona-server:8.0`) | **2026-04-30** | Aligné sur l'EOL MySQL 8.0 ; fin des mises à jour communautaires | `percona/percona-server:8.4` (`make percona84`) |
| Traefik | `v2.11` (`traefik:v2.11`) | **2026-09-07** | Fin du support sécurité ; proxy inverse standalone migré vers v3 | `traefik:v3` |
| HAProxy | `2.9` (`haproxy:2.9-alpine`) | **2025-03-21** | Fin de vie Short-Term Support (STS) ; proxys des clusters PostgreSQL migrés vers LTS | `haproxy:lts-alpine` / `haproxy:lts` |

## 📊 Matrice Réseau

| Cluster | Sous-réseau | Nœuds | Routeur |
| :--- | :--- | :--- | :--- |
| Réplication | `10.5.0.0/24` | 3 MariaDB | — |
| Galera | `10.6.0.0/24` | 3 MariaDB | — |
| PgPool-II | `10.8.0.0/24` | 3 PG + PgPool + HAProxy | HAProxy |
| InnoDB Cluster | `10.9.0.0/24` | 3 MySQL + HAProxy | HAProxy |
| MongoDB RS (7.0) | `10.10.0.0/24` | 3 MongoDB + HAProxy | HAProxy |
| MongoDB RS (8.0) | `10.11.0.0/24` | 3 MongoDB + HAProxy | HAProxy |
| Patroni | Docker bridge | 3 PG + 3 ETCD + HAProxy | HAProxy |
