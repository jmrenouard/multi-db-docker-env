# Support PostgreSQL 🐘

Ce document décrit l'intégration de PostgreSQL dans l'environnement multi-db-docker-env, incluant les instances standalone et les architectures haute disponibilité.

## Versions Supportées

- **PostgreSQL 17** (Dernière version stable)
- **PostgreSQL 16**
- **PostgreSQL 15**

## Vue d'Ensemble des Architectures

```
┌─────────────────────────────────────────────────────────────────┐
│                   Architectures PostgreSQL                      │
├──────────────────┬──────────────────────┬───────────────────────┤
│   Standalone     │  Patroni + ETCD      │  PgPool-II + HAProxy  │
│   (Noeud Unique) │  (Cluster HA)        │  (Pool + LB)          │
├──────────────────┼──────────────────────┼───────────────────────┤
│ postgres15       │ 3 noeuds ETCD        │ 3 noeuds PostgreSQL   │
│ postgres16       │ 3 noeuds PostgreSQL  │ PgPool-II 4.4         │
│ postgres17       │ HAProxy (RW/RO)      │ HAProxy (RW/RO)       │
├──────────────────┼──────────────────────┼───────────────────────┤
│ make postgres17  │ make patroni-up      │ make pgpool-up         │
│ make test-all    │ make test-patroni    │ make test-pgpool       │
└──────────────────┴──────────────────────┴───────────────────────┘
```

---

## 1. Instances Standalone

### Démarrage Rapide

```bash
make postgres17    # PostgreSQL 17
make postgres16    # PostgreSQL 16
make postgres15    # PostgreSQL 15
```

### Détails de Connexion

| Paramètre | Valeur |
| :--- | :--- |
| Hôte | `127.0.0.1` |
| Port (Traefik) | `5432` |
| Utilisateur | `postgres` |
| Mot de passe | Défini par `DB_ROOT_PASSWORD` dans `.env` |

### Commandes Makefile

| Commande | Description |
| :--- | :--- |
| `make pgpass` | Génère `~/.pgpass` pour les connexions sans mot de passe. |
| `make pgclient` | Ouvre une session `psql` interactive. |
| `make status` | Vérifie l'état des conteneurs. |

---

## 2. Cluster Patroni (RHEL 8)

Cluster PostgreSQL 17 haute disponibilité avec Patroni et ETCD (failover automatique).

Voir [patroni_cluster.md](patroni_cluster.md) pour les détails complets.

### Architecture

- **ETCD** : 3 noeuds pour le consensus distribué.
- **PostgreSQL** : 3 noeuds gérés par Patroni.
- **HAProxy** : RW (port `5000`) / RO (port `5001`) / Stats (port `7000`).

### Démarrage

```bash
make patroni-up        # Démarrer le cluster
make patroni-status    # Vérifier le statut
make test-patroni      # Exécuter les tests
make patroni-down      # Arrêter le cluster
```

---

## 3. Cluster PgPool-II

Pooling de connexions et répartition de charge avec PgPool-II et réplication streaming.

Voir [pgpool_cluster.md](pgpool_cluster.md) pour les détails complets.

### Architecture

- **PostgreSQL** : 3 noeuds (1 primaire + 2 standbys) avec réplication streaming.
- **PgPool-II 4.4** : Pooling de connexions, load balancing, séparation lecture/écriture.
- **HAProxy** : RW (port `5100`) / RO (port `5101`) / Stats (port `8406`).

### Démarrage

```bash
make pgpool-up         # Démarrer le cluster (configure la réplication auto)
make pgpool-status     # Afficher le statut PgPool
make test-pgpool       # Exécuter les tests (20 tests)
make pgpool-down       # Arrêter le cluster
```

---

## Matrice de Comparaison

| Fonctionnalité | Standalone | Patroni | PgPool-II |
| :--- | :--- | :--- | :--- |
| **Noeuds** | 1 | 3 PG + 3 ETCD | 3 PG |
| **Failover Auto** | ❌ | ✅ | ❌ |
| **Pool Connexions** | ❌ | ❌ | ✅ |
| **Load Balancing** | ❌ | ✅ (HAProxy) | ✅ (PgPool + HAProxy) |
| **Réplication** | ❌ | Synchrone | Async Streaming |
| **TLS/SSL** | ❌ | ✅ Mutual TLS | ❌ (trust en lab) |
| **Cas d'usage** | Dev/Test | Production HA | Pool + Scale Lecture |

---

## Persistence des Données

Les données PostgreSQL sont stockées dans des volumes Docker nommés :

- Standalone : `postgres_17_data`, `postgres_16_data`, `postgres_15_data`
- PgPool-II : `pg_pgpool_data1`, `pg_pgpool_data2`, `pg_pgpool_data3`
- Patroni : `node1_data`, `node2_data`, `node3_data`

Pour réinitialiser, supprimez ces volumes (`docker volume rm ...`) ou utilisez `make pgpool-down` / `make patroni-down` qui suppriment les volumes automatiquement.
