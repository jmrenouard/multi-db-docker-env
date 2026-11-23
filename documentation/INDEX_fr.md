# Index de la Documentation Multi-DB Docker Environment 📚

| MariaDB | MySQL | Percona | PostgreSQL | MongoDB | Traefik | Docker |
| :---: | :---: | :---: | :---: | :---: | :---: | :---: |
| <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="44" height="44"> | <img src="https://static.cdnlogo.com/logos/p/6/percona.svg" alt="Percona" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" alt="MongoDB" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik" width="44" height="44"> | <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" alt="Docker" width="44" height="44"> |

Bienvenue dans la documentation de Multi-DB Docker Environment. Cet index classe tous les guides selon les quatre quadrants Diataxis.

> **Note** : Les guides opérationnels approfondis et les registres de gouvernance sont en anglais (`[en anglais]`). Les guides principaux possèdent une version française dédiée.

---

## 📋 Table des Matières

- [📋 Table des Matières](#-table-des-matières)
- [🚀 Tutoriels & Démarrage Rapide](#-tutoriels--démarrage-rapide)
- [🔧 Guides Pratiques](#-guides-pratiques)
- [📖 Référence](#-référence)
- [💡 Explication & Architecture](#-explication--architecture)

---

## 🚀 Tutoriels & Démarrage Rapide

Commencez ici pour installer les outils et lancer vos premières bases standalone.

| Document | Description |
| --- | --- |
| **[README Principal](../README_fr.md)** | Présentation, démarrage rapide unifié `./mdb` (`mdb.cmd`), configuration multi-OS et usage CLI. |
| **[Environnements Standalone](tests_fr.md#00-matrice-standalone-niveau-t2)** | Démarrage rapide et suite T2 pour MySQL, MariaDB, Percona et PostgreSQL. |

---

## 🔧 Guides Pratiques

Suivez ces procédures pas à pas pour déployer, sécuriser et exploiter chaque topologie.

| Document | Description |
| --- | --- |
| **[Support PostgreSQL](postgresql_support_fr.md)** | Déploiement standalone (15/16/17/18), Patroni HA et PgPool-II. |
| **[PostgreSQL Multi-Maître & SQL Distribué](pg_multimaster_fr.md)** | Déploiement et benchmarks des 13 piles PostgreSQL Compose. |
| **[InnoDB Cluster](innodb_cluster_fr.md)** | MySQL 8.4 LTS Group Replication avec routage HAProxy. |
| **[MongoDB ReplicaSet](mongo_replicaset_fr.md)** | MongoDB 7.0 et 8.0 ReplicaSet avec HAProxy et TLS. |
| **[Bootstrap Galera](galera_bootstrap.md)** `[en anglais]` | Guide étape par étape pour initialiser et réparer les clusters Galera. |
| **[Configuration Réplication](replication_setup.md)** `[en anglais]` | Procédure pour configurer et vérifier la réplication Maître/Esclave. |
| **[SSL & Sécurité](replication_ssl.md)** `[en anglais]` | Activation du chiffrement TLS sur la réplication MariaDB. |
| **[Architecture TLS/SSL](tls_setup.md)** `[en anglais]` | Guide unifié des certificats X.509 sur tous les clusters. |
| **[Cluster Patroni](patroni_cluster.md)** `[en anglais]` | Cluster PostgreSQL 17 HA à 3 nœuds avec etcd et bascule automatique. |
| **[Cluster PgPool-II](pgpool_cluster.md)** `[en anglais]` | Pooling de connexions et répartition de charge avec réplication streaming. |

---

## 📖 Référence

Consultez ces tables de commandes, matrices de versions, suites de tests et règles de gouvernance.

| Document | Description |
| --- | --- |
| **[Référence CLI & Makefile](makefile_fr.md)** | Commandes unifiées `./mdb` (`catalog`, `up`, `setup`, `lint`, `interactive`, `doctor`) et cibles `Makefile`. |
| **[Cas de Test](tests_fr.md)** | Descriptions des suites de tests, résultats attendus et rapports. |
| **[Produits Supportés](supported_products_fr.md)** | Matrice complète des moteurs BDD actifs, versions EOL, ports et sous-réseaux. |
| **[Guide TDE & Données au Repos](tde_encryption_fr.md)** | Couches de chiffrement, Keyring Components, `pg_tde` 2.1 et matrice KMS par moteur. |
| **[Scripts Utilitaires](scripts.md)** `[en anglais]` | Référence des scripts de sauvegarde, restauration, PKI, Go CLI et tests. |
| **[Règles du Projet (AGENTS.md)](../AGENTS.md)** `[en anglais]` | Architecture, limite de diff PR (< 15K caractères) et workflow GitHub obligatoire. |
| **[Action Logbook & Roadmap](../docs/ACTION_LOGBOOK.md)** `[en anglais]` | Registre vivant des actions en cours et terminées (`ACT-XXX`). |
| **[RCA Register](../docs/RCA_REGISTER.md)** `[en anglais]` | Registre des analyses RCA, impasses (`IMP`), approximations (`APP`) et idées (`IDEA`). |
| **[Constitution](../.agent/rules/00_constitution.md)** `[en anglais]` | Source unique de vérité pour les principes du projet et l'autorité opérationnelle. |
| **[Super Manager](../.agent/workflows/go-agent.md)** `[en anglais]` | Protocole d'orchestration des compétences, règles et workflows. |

---

## 💡 Explication & Architecture

Consultez cette section pour comprendre la topologie globale et le routage réseau.

| Document | Description |
| --- | --- |
| **[Architecture](architecture.md)** `[en anglais]` | Topologie globale, routage Traefik/HAProxy, observabilité et diagrammes Mermaid. |

---

*Note : La version originale de cette documentation est en anglais. Voir [INDEX.md](INDEX.md).*
