# Index de la Documentation MariaDB 📚

<p align="center">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="50" height="50">
  <img src="https://static.cdnlogo.com/logos/p/6/percona.svg" alt="Percona" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" alt="MongoDB" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik" width="50" height="50">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" alt="Docker" width="50" height="50">
</p>

Bienvenue dans la documentation de l'environnement Docker MariaDB. Cet index fournit une vue d'ensemble structurée de tous les guides et références techniques disponibles.

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
| **[README Principal](../README_fr.md)** | Présentation, démarrage rapide, instructions de build et utilisation de base. |
| **[Architecture](architecture.md)** | Topologie globale, schéma réseau et schémas Mermaid détaillés. |

## 🏛️ Gouvernance & Orchestration

| Document | Description |
| --- | ---|
| **[Constitution](../.agent/rules/00_constitution.md)** | Source unique de vérité pour les principes du projet et l'autorité opérationnelle. |
| **[Super Manager](../.agent/workflows/go-agent.md)** | Protocole d'orchestration pour coordonner les compétences, règles et workflows. |

## 🐘 PostgreSQL & Architectures HA

| Document | Description |
| --- | --- |
| **[Support PostgreSQL](postgresql_support_fr.md)** | Guide complet : standalone (15/16/17), Patroni HA, et clusters PgPool-II. |
| **[PostgreSQL Multi-Maître & SQL Distribué](pg_multimaster_fr.md)** | Guide et benchmarks pg-birep, pgEdge Spock 5, Bucardo 5, Citus 14.2, YugabyteDB 2026.1 et CockroachDB v24.3. |
| **[Cluster Patroni](patroni_cluster.md)** | Cluster PostgreSQL 17 HA à 3 noeuds avec ETCD et failover automatique. |
| **[Cluster PgPool-II](pgpool_cluster.md)** | Pooling de connexions + load balancing avec réplication streaming. |

## 🐬 MySQL InnoDB Cluster

| Document | Description |
| --- | --- |
| **[InnoDB Cluster](innodb_cluster_fr.md)** | MySQL 8.0 Group Replication avec HAProxy pour le routage transparent. |

## 🍃 MongoDB ReplicaSet

| Document | Description |
| --- | --- |
| **[MongoDB ReplicaSet](mongo_replicaset_fr.md)** | MongoDB 7.0 ReplicaSet avec HAProxy pour le routage des connexions. |

## 🐬 Matrice Standalone

| Document | Description |
| --- | --- |
| **[Environnements Standalone](tests_fr.md#-00-matrice-standalone-niveau-t2)** | Aperçu des moteurs standalone supportés (MySQL, MariaDB, Percona, PostgreSQL). |

## 🛠️ Gestion & Automatisation

| Document | Description |
| --- | --- |
| **[Référence Makefile](makefile_fr.md)** | Détail de toutes les commandes `make` pour le déploiement et la maintenance. |
| **[Scripts Utilitaires](scripts.md)** | Approfondissement des scripts de sauvegarde, restauration, sécurité (SSL) et setup. |

## 🔄 Réplication & Galera

| Document | Description |
| --- | --- |
| **[Bootstrap Galera](galera_bootstrap.md)** | Guide étape par étape pour initialiser les clusters Galera. |
| **[Configuration Réplication](replication_setup.md)** | Comment configurer et automatiser la réplication Maître/Esclave. |
| **[SSL & Sécurité](replication_ssl.md)** | Configuration SSL pour les connexions chiffrées. |

## 🧪 Tests & Performance

| Document | Description |
| --- | --- |
| **[Cas de Test](tests_fr.md)** | Descriptions des suites de tests, résultats attendus et rapports. |
| **[Produits Supportés](supported_products_fr.md)** | Matrice complète de tous les moteurs BDD, versions, ports et modes HA. |

---

*Note : La version originale de cette documentation est en anglais. Voir [INDEX.md](INDEX.md).*
