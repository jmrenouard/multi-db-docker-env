# Produits Supportés

Référence complète de tous les moteurs de bases de données et composants d'infrastructure supportés par le projet.

## 🐬 MySQL

| Version | Image Docker | Port Standalone | TLS | Statut |
| :--- | :--- | :--- | :--- | :--- |
| 9.6 | `mysql:9.6` | `3306` (via Traefik) | ❌ | ✅ Vérifié |
| 8.4 | `mysql:8.4` | `3306` (via Traefik) | ❌ | ✅ Vérifié |
| 8.0 | `mysql:8.0` | `3306` (via Traefik) | ❌ | ✅ Vérifié |
| 5.7 | `mysql:5.7` | `3306` (via Traefik) | ❌ | ✅ Vérifié |

**Mode HA** : InnoDB Cluster (3 nœuds Group Replication + HAProxy)

## 🐬 MariaDB

| Version | Image Docker | Port Standalone | TLS | Statut |
| :--- | :--- | :--- | :--- | :--- |
| 11.8 | `mariadb:11.8` | `3306` (via Traefik) | ✅ (cluster) | ✅ Vérifié |
| 11.4 | `mariadb:11.4` | `3306` (via Traefik) | ✅ (cluster) | ✅ Vérifié |
| 10.11 | `mariadb:10.11` | `3306` (via Traefik) | ✅ (cluster) | ✅ Vérifié |
| 10.6 | `mariadb:10.6` | `3306` (via Traefik) | ✅ (cluster) | ✅ Vérifié |

**Modes HA** :
- Cluster Galera (3 nœuds, réplication synchrone, ports 3511-3513)
- Réplication Maître/Esclave (1 maître + 2 esclaves, ports 3611-3613)

## 🐬 Percona Server

| Version | Image Docker | Port Standalone | TLS | Statut |
| :--- | :--- | :--- | :--- | :--- |
| 8.4 | `percona:8.4` | `3306` (via Traefik) | ❌ | ✅ Vérifié |
| 8.0 | `percona:8.0` | `3306` (via Traefik) | ❌ | ✅ Vérifié |

## 🐘 PostgreSQL

| Version | Image Docker | Port Standalone | TLS | Statut |
| :--- | :--- | :--- | :--- | :--- |
| 17 | `postgres:17` | `5432` (via Traefik) | ❌ | ✅ Vérifié |
| 16 | `postgres:16` | `5432` (via Traefik) | ❌ | ✅ Vérifié |
| 15 | `postgres:15` | `5432` (via Traefik) | ❌ | ✅ Vérifié |

**Modes HA** :
- Cluster Patroni (3 PG 17 + 3 ETCD + HAProxy, ports 5000/5001/7000)
- Cluster PgPool-II (3 PG 17 + PgPool + HAProxy, ports 5100/5101/8406)

## 🍃 MongoDB

| Version | Image Docker | Port Standalone | TLS | Statut |
| :--- | :--- | :--- | :--- | :--- |
| 8.0 | `mongo:8.0` | — | ❌ | ✅ Vérifié |
| 7.0 | `mongo:7.0` | — | ❌ | ✅ Vérifié |

**Mode HA** : ReplicaSet (3 nœuds rs0 + HAProxy)
- MongoDB 7 : ports 27411-27413 / HAProxy 27100 / Stats 8408
- MongoDB 8 : ports 27511-27513 / HAProxy 27200 / Stats 8409

## 🔧 Composants d'Infrastructure

| Composant | Image | Rôle | Ports |
| :--- | :--- | :--- | :--- |
| Traefik | `traefik:v2.10` | Proxy inverse pour les BDD standalone | `3306`, `5432`, `8080` (dashboard) |
| HAProxy | `haproxy:lts` | Répartiteur de charge TCP pour les clusters HA | Par cluster (voir docs) |
| ETCD | `quay.io/coreos/etcd:v3.5.21` | Config distribuée pour Patroni | `2379`, `2380` |

## 📊 Matrice Réseau

| Cluster | Sous-réseau | Nœuds | Routeur |
| :--- | :--- | :--- | :--- |
| Réplication | `10.5.0.0/24` | 3 MariaDB | — |
| Galera | `10.6.0.0/24` | 3 MariaDB | — |
| PgPool-II | `10.8.0.0/24` | 3 PG + PgPool + HAProxy | HAProxy |
| InnoDB Cluster | `10.9.0.0/24` | 3 MySQL + HAProxy | HAProxy |
| MongoDB RS | `10.10.0.0/24` | 3 MongoDB + HAProxy | HAProxy |
| Patroni | Docker bridge | 3 PG + 3 ETCD + HAProxy | HAProxy |
