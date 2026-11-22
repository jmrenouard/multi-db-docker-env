# Index de la Documentation Multi-DB Docker Environment 📚

| MariaDB | MySQL | Percona | PostgreSQL | MongoDB | Traefik | Docker |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="44" height="44"> | <img src="https://static.cdnlogo.com/logos/p/6/percona.svg" alt="Percona" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" alt="MongoDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" alt="Docker" width="44" height="44"> |

Bienvenue dans la documentation de Multi-DB Docker Environment. Cet index fournit une vue d'ensemble structurée de tous les guides et références techniques disponibles.

> **Note** : Les guides opérationnels approfondis et les registres de gouvernance sont en anglais. Les guides principaux possèdent une version française dédiée.

---

## 📋 Table des Matières

1. [Documentation Centrale](#-documentation-centrale)
2. [Gouvernance & Orchestration](#-gouvernance--orchestration)
3. [PostgreSQL & Architectures HA](#-postgresql--architectures-ha)
4. [Matrice Standalone](#-matrice-standalone)
5. [Gestion & Automatisation](#-gestion--automatisation)
6. [Réplication & Galera](#-réplication--galera)
7. [Tests & Performance](#-tests--performance)

---

## 🚀 Documentation Centrale

| Document | Description |
| --- | --- |
| **[README Principal](../README_fr.md)** | Présentation, démarrage rapide unifié `./mdb` (`mdb.cmd`), configuration multi-OS et usage CLI. |
| **[Architecture](architecture.md)** | Topologie globale, routage unifié de l'orchestrateur, schéma réseau et schémas Mermaid. |

## 🏛️ Gouvernance & Orchestration

| Document | Description |
| --- | --- |
| **[Règles du Projet (AGENTS.md)](../AGENTS.md)** | Architecture, limite de diff PR (< 15K caractères) et workflow GitHub obligatoire. |
| **[Action Logbook & Roadmap](../docs/ACTION_LOGBOOK.md)** | Registre vivant des actions en cours/terminées et feuille de route stratégique. |
| **[RCA Register](../docs/RCA_REGISTER.md)** | Registre des analyses RCA, impasses (IMP), approximations (APP) et idées (IDEA). |
| **[Constitution](../.agent/rules/00_constitution.md)** | Source unique de vérité pour les principes du projet et l'autorité opérationnelle. |
| **[Super Manager](../.agent/workflows/go-agent.md)** | Protocole d'orchestration pour coordonner les compétences, règles et workflows. |

## 🐘 PostgreSQL & Architectures HA

| Document | Description |
| --- | --- |
| **[Support PostgreSQL](postgresql_support_fr.md)** | Guide complet : standalone (15/16/17/18), Patroni HA, et clusters PgPool-II. |
| **[PostgreSQL Multi-Maître & SQL Distribué](pg_multimaster_fr.md)** | Guide et benchmarks `pg17-baseline`, `pg-streaming`/`logical`/`birep`, `pg18-*`, `yt-cluster` 1.21.3, pgEdge Spock 5, Bucardo 5, Citus 14.2, YugabyteDB 2026.1 et CockroachDB v25.4. |
| **[Cluster Patroni](patroni_cluster.md)** | Cluster PostgreSQL 17 HA à 3 noeuds avec ETCD et failover automatique. |
| **[Cluster PgPool-II](pgpool_cluster.md)** | Pooling de connexions + load balancing avec réplication streaming. |

## 🐬 MySQL InnoDB Cluster

| Document | Description |
| --- | --- |
| **[InnoDB Cluster](innodb_cluster_fr.md)** | MySQL 8.4 LTS Group Replication avec HAProxy pour le routage transparent. |

## 🍃 MongoDB ReplicaSet

| Document | Description |
| --- | --- |
| **[MongoDB ReplicaSet](mongo_replicaset_fr.md)** | MongoDB 7.0 et 8.0 ReplicaSet avec HAProxy et TLS pour le routage des connexions. |

## 🐬 Matrice Standalone

| Document | Description |
| --- | --- |
| **[Environnements Standalone](tests_fr.md#00-matrice-standalone-niveau-t2)** | Aperçu des moteurs standalone supportés (MySQL, MariaDB, Percona, PostgreSQL). |

## 🛠️ Gestion & Automatisation

| Document | Description |
| --- | --- |
| **[Référence CLI & Makefile](makefile_fr.md)** | Commandes unifiées `./mdb` (`catalog`, `up`, `setup`, `lint`, `interactive`, `doctor`) et wrappers `Makefile`. |
| **[Scripts Utilitaires](scripts.md)** | Approfondissement des scripts de sauvegarde, restauration, sécurité (SSL) et setup. |

## 🔄 Réplication & Galera

| Document | Description |
| --- | --- |
| **[Bootstrap Galera](galera_bootstrap.md)** | Guide étape par étape pour initialiser les clusters Galera. |
| **[Configuration Réplication](replication_setup.md)** | Comment configurer et automatiser la réplication Maître/Esclave. |
| **[SSL & Sécurité](replication_ssl.md)** | Configuration SSL pour les connexions chiffrées. |
| **[Architecture TLS/SSL](tls_setup.md)** | Guide unifié TLS/SSL pour toutes les technologies de bases de données. |

## 🧪 Tests & Performance

| Document | Description |
| --- | --- |
| **[Cas de Test](tests_fr.md)** | Descriptions des suites de tests, résultats attendus et rapports. |
| **[Produits Supportés](supported_products_fr.md)** | Matrice complète de tous les moteurs BDD, versions, ports et modes HA. |

---

*Note : La version originale de cette documentation est en anglais. Voir [INDEX.md](INDEX.md).*
