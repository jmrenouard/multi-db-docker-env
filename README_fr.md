![multi-db-docker-env](logo.png)

<p align="center">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="60" height="60">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="60" height="60">
  <img src="https://static.cdnlogo.com/logos/p/6/percona.svg" alt="Percona" width="60" height="60">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="60" height="60">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mongodb/mongodb-original.svg" alt="MongoDB" width="60" height="60">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefikproxy/traefikproxy-original.svg" alt="Traefik" width="60" height="60">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/docker/docker-original.svg" alt="Docker" width="60" height="60">
</p>

[!["Buy Us A Coffee"](https://www.buymeacoffee.com/assets/img/custom_images/orange_img.png)](https://www.buymeacoffee.com/jmrenouard)

<p align="center">
  <a href="https://github.com/jmrenouard/multi-db-docker-env/releases/latest"><img src="https://img.shields.io/github/v/release/jmrenouard/multi-db-docker-env?style=flat-square&logo=github" alt="GitHub Release"></a>
  <a href="https://hub.docker.com/r/jmrenouard/multi-db-docker-env"><img src="https://img.shields.io/docker/v/jmrenouard/multi-db-docker-env?sort=semver&style=flat-square&logo=docker&logoColor=white" alt="Docker Image Version"></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0-blue.svg?style=flat-square" alt="License"></a>
</p>

Une fonctionnalité clé est le **proxy inverse Traefik**, qui garantit que toutes les instances de base de données sont accessibles via des ports stables sur votre machine hôte (`localhost:3306` pour MySQL/MariaDB et `localhost:5432` pour PostgreSQL), quelle que soit la version spécifique de la base de données que vous choisissez d'exécuter.

> [!IMPORTANT]
> **Politique d'Anglais Uniquement** : Tous les commentaires techniques dans le code, les fichiers de configuration et la documentation de ce projet DOIVENT être en anglais UNIQUEMENT.

## 🛰️ État de Vérification

| Niveau | Nom du Niveau | Dernière Vérification | État |
| :--- | :--- | :--- | :--- |
| **T2** | **Matrice Standalone** | 2026-11-19 | ✅ 100% Réussi |
| **T3** | **Cluster, HA & Multi-Maître (`v2.3.0`)** | 2026-11-20 | ✅ 19 Topologies Vérifiées |

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir installé les outils suivants :

* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/) (généralement inclus avec Docker Desktop)
* `make` (disponible sur la plupart des systèmes Linux/macOS. Pour Windows, vous pouvez utiliser Chocolatey : `choco install make`)
* Liste complète des outils clients recommandés : voir [`PREREQUISITES.txt`](PREREQUISITES.txt).

## ⚙️ Configuration Initiale

La seule étape de configuration requise est de définir le mot de passe root pour vos bases de données.

1. Créez un fichier nommé `.env` dans le répertoire racine du projet.
2. Ajoutez la ligne suivante, en remplaçant `your_super_secret_password` par un mot de passe fort de votre choix (ne mettez pas de guillemets autour du mot de passe) :

    ```env
    # Fichier : .env
    DB_ROOT_PASSWORD=your_super_secret_password
    ```

⚠️ **Important** : Ce `DB_ROOT_PASSWORD` est crucial pour le bon fonctionnement des commandes `make mycnf` et `make client`.

## ✨ Utilisation avec Makefile

Le `Makefile` est le point d'entrée principal pour la gestion de l'environnement. Il simplifie toutes les opérations en commandes courtes et mémorisables.

### Commandes Générales

Ces commandes vous aident à gérer et à interagir avec l'ensemble de l'environnement.

| Command                         | Icon | Description                                                                 | Exemple d'utilisation           |
| :------------------------------ | :--- | :-------------------------------------------------------------------------- | :------------------------------ |
| `make help`                     | 📜   | Affiche la liste complète de toutes les commandes disponibles.              | `make help`                     |
| `make start`                    | 🚀   | Démarre le service de base de données par défaut (`mariadb114`).            | `make start`                    |
| `make stop`                     | 🛑   | Arrête et supprime correctement tous les conteneurs et réseaux du projet.   | `make stop`                     |
| `make status`                   | 📊   | Affiche l'état des conteneurs actifs du projet (Traefik + DB).              | `make status`                   |
| `make info`                     | ℹ️   | Fournit des informations sur le service DB actif et les logs récents.       | `make info`                     |
| `make logs`                     | 📄   | Affiche les logs du service de base de données actuellement actif.          | `make logs`                     |
| `make mycnf`                    | 🔑   | Génère un fichier `~/.my.cnf` pour des connexions MySQL sans mot de passe.  | `make mycnf`                    |
| `make client`                   | 💻   | Démarre un client MySQL connecté à la base de données active.               | `make client`                   |
| `make verify`                   | ✅   | Exécute une validation complète de l'environnement (`test-config`).         | `make verify`                   |
| `make build-go`                 | 🔨   | Compile le binaire Go natif `mdb` dans `bin/mdb` (`v2.3.0`, 19 topologies). | `make build-go`                 |
| `make test-go`                  | 🧪   | Exécute la suite complète de tests unitaires Go.                            | `make test-go`                  |
| `python3 interactive_runner.py` | 🚀   | Lance le coureur de tests interactif pour une configuration guidée.         | `python3 interactive_runner.py` |

### Gestion des Données

Ces commandes permettent d'injecter des exemples de bases de données ou d'exécuter une suite de tests complète.

| Command                 | Icon | Description                                                                                                          | Exemple d'utilisation                            |
| :---------------------- | :--- | :------------------------------------------------------------------------------------------------------------------- | :----------------------------------------------- |
| `make inject`           | 💉   | Alias pour `inject-employees` sur l'environnement actif. Détecte Galera ou Réplication.                              | `make inject`                                   |
| `make inject-employees` | 💉   | Injecte la base `employees` avec auto-détection de l'environnement.                                                 | `make inject-employees`                         |
| `make inject-sakila`    | 💉   | Injecte la base `sakila` avec auto-détection de l'environnement.                                                    | `make inject-sakila`                            |
| `make inject-data`      | 💉   | Injecte une base (`employees` ou `sakila`) dans un service spécifique en cours d'exécution.                         | `make inject-data service=mysql84 db=employees` |
| `make sync-test-db`     | 🔄   | Synchronise le sous-module `test_db` avec la branche master distante.                                               | `make sync-test-db`                             |
| `make test-all`         | 🧪   | Exécute une suite de tests complète : démarre chaque service (MySQL, MariaDB, Percona, PostgreSQL), vérifie la disponibilité et la connectivité. | `make test-all`                                 |

### Démarrage d'une Instance de Base de Données

Pour démarrer une version spécifique, utilisez `make <version_db>`. Le Makefile arrêtera automatiquement toute instance en cours avant de lancer la nouvelle.

### <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mysql/mysql-original.svg" alt="MySQL" width="25" height="25"> MySQL

| Command        | Icon | Description           |
| :------------- | :--- | :-------------------- |
| `make mysql97` | 🐬   | Démarre MySQL 9.7 LTS |
| `make mysql84` | 🐬   | Démarre MySQL 8.4 LTS |

### <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="25" height="25"> MariaDB

| Command            | Icon | Description               |
| :----------------- | :--- | :------------------------ |
| `make mariadb123`  | 🐧   | Démarre MariaDB 12.3 LTS  |
| `make mariadb118`  | 🐧   | Démarre MariaDB 11.8 LTS  |
| `make mariadb114`  | 🐧   | Démarre MariaDB 11.4 LTS  |
| `make mariadb1011` | 🐧   | Démarre MariaDB 10.11 LTS |

### <img src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/percona.svg" alt="Percona" width="25" height="25"> Percona Server

| Command          | Icon | Description                 |
| :--------------- | :--- | :-------------------------- |
| `make percona84` | ⚡   | Démarre Percona 8.4 LTS     |

### <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="25" height="25"> PostgreSQL

| Command            | Icon | Description             |
| :----------------- | :--- | :---------------------- |
| `make postgres18`  | 🐘   | Démarre PostgreSQL 18   |
| `make postgres17`  | 🐘   | Démarre PostgreSQL 17   |
| `make postgres16`  | 🐘   | Démarre PostgreSQL 16   |
| `make postgres15`  | 🐘   | Démarre PostgreSQL 15   |

> [!NOTE]
> **Décommissionnement Fin de Vie (EOL)** : MySQL 5.7, MySQL 8.0, MySQL 9.6, MariaDB 10.6, Percona Server 8.0, Traefik v2.11 et HAProxy 2.9 ont atteint leur fin de vie officielle communautaire et ont été décommissionnés. Consultez la [Matrice des Produits Supportés & Versions Décommissionnées](documentation/supported_products_fr.md#versions-décommissionnées-fin-de-vie--eol) pour les dates EOL exactes et les remplacements recommandés.

## 🏗️ Environnement Technique

### 🌐 Réseautage

Le projet utilise des sous-réseaux privés standardisés pour l'isolation des clusters :

* **Cluster Galera** : `10.6.0.0/24`
* **Cluster de Réplication** : `10.5.0.0/24`
* **Cluster PgPool-II** : `10.8.0.0/24`
* **InnoDB Cluster** : `10.9.0.0/24`
* **MongoDB ReplicaSet** : `10.10.0.0/24`
* **Cluster Patroni** : Docker bridge (auto-assigné)

Ces plages sont cohérentes entre les configurations `docker-compose` et les scripts d'orchestration internes.

### 🔐 Identifiants

Les identifiants par défaut sont centralisés dans le fichier `.env` via `DB_ROOT_PASSWORD`.

* **Utilisateur par défaut** : `root`
* **Base de données par défaut** : `employees` (après injection)

### Clusters MariaDB (Galera & Réplication)

Architectures MariaDB avancées avec clustering synchrone ou réplication maître/esclave.

| Command            | Icon | Description                                    |
| :----------------- | :--- | :--------------------------------------------- |
| `make up-galera`   | 🌐   | Démarre le cluster Galera (3 nœuds)            |
| `make up-repli`    | 🔄   | Démarre le cluster de Réplication (3 nœuds)    |
| `make test-galera` | 🧪   | Exécute les tests fonctionnels sur Galera      |
| `make test-repli`  | 🧪   | Exécute les tests fonctionnels sur Réplication |

> [!NOTE]
> Les clusters MariaDB utilisent une image personnalisée `mariadb_ssh` et ont des ports dédiés (ex: 3511-3513 pour Galera).

### Clusters PostgreSQL HA (Patroni & PgPool-II)

Architectures PostgreSQL avancées avec failover automatique ou pooling de connexions.

| Commande             | Icon | Description                                            |
| :------------------- | :--- | :----------------------------------------------------- |
| `make patroni-up`    | 🐘   | Démarre le cluster Patroni HA (3 PG + 3 ETCD + HAProxy) |
| `make patroni-status`| 📊   | Affiche le statut du cluster Patroni                    |
| `make test-patroni`  | 🧪   | Exécute les tests fonctionnels Patroni                  |
| `make patroni-down`  | 🛑   | Arrête le cluster Patroni                               |
| `make pgpool-up`     | 🐘   | Démarre le cluster PgPool-II (3 PG + PgPool + HAProxy)  |
| `make pgpool-status` | 📊   | Affiche le statut des nœuds PgPool-II                   |
| `make test-pgpool`   | 🧪   | Exécute les tests PgPool-II (20 tests)                  |
| `make pgpool-down`   | 🛑   | Arrête le cluster PgPool-II                             |

> [!NOTE]
> Patroni utilise les ports 5000 (RW) / 5001 (RO) / 7000 (Stats). PgPool-II utilise les ports 5100 (RW) / 5101 (RO) / 8406 (Stats).

### MySQL InnoDB Cluster (Group Replication & HAProxy)

Architecture MySQL avancée avec Group Replication et routage transparent.

| Commande             | Icon | Description                                            |
| :------------------- | :--- | :----------------------------------------------------- |
| `make innodb-up`     | 🐬   | Démarre InnoDB Cluster (3 MySQL + HAProxy)              |
| `make innodb-status` | 📊   | Affiche le statut Group Replication                    |
| `make test-innodb`   | 🧪   | Exécute les tests InnoDB Cluster                        |
| `make innodb-down`   | 🛑   | Arrête InnoDB Cluster                                   |

> [!NOTE]
> InnoDB Cluster utilise les ports 6446 (RW) / 6447 (RO) via HAProxy. Stats : 8407. Accès direct : 4411-4413.

### MongoDB ReplicaSet

Architecture MongoDB avec ReplicaSet et routage HAProxy.

| Commande             | Icon | Description                                            |
| :------------------- | :--- | :----------------------------------------------------- |
| `make mongo-up`      | 🍃   | Démarre MongoDB 7.0 ReplicaSet (3 nœuds + HAProxy)     |
| `make mongo-status`  | 📊   | Affiche le statut du ReplicaSet MongoDB 7.0            |
| `make test-mongo`    | 🧪   | Exécute les tests MongoDB 7.0 ReplicaSet               |
| `make mongo-down`    | 🛑   | Arrête MongoDB 7.0 ReplicaSet                          |
| `make mongo8-up`     | 🍃   | Démarre MongoDB 8.0 ReplicaSet (3 nœuds + HAProxy)     |
| `make test-mongo8`   | 🧪   | Exécute les tests MongoDB 8.0 ReplicaSet               |
| `make mongo8-down`   | 🛑   | Arrête MongoDB 8.0 ReplicaSet                          |

> [!NOTE]
> MongoDB 7.0 utilise le port 27100 (HAProxy), stats 8408, accès direct 27411-27413 (`10.10.0.0/24`). MongoDB 8.0 utilise le port 27200 (HAProxy), stats 8409, accès direct 27511-27513 (`10.11.0.0/24`). Les deux imposent TLS (`requireTLS`).

### PostgreSQL Réplication, Multi-Maître & SQL Distribué (`v2.1.0`–`v2.2.0`)

Huit topologies PostgreSQL supplémentaires (`pg-streaming`, `pg-logical`, `pg-birep`, `pgedge`, `bucardo`, `citus`, `cockroach`, `yugabyte`) exposent chacune `<topo>-up`, `<topo>-down`, `<topo>-status`, `<topo>-logs`, `<topo>-ps` et `<topo>-test`, ainsi que `make test-pg-extended` (T11–T18) et `make bench-pg-v2`. Voir [PostgreSQL Multi-Maître & SQL Distribué](documentation/pg_multimaster_fr.md).

**Exemple : Changer de Base de Données**

```bash
# 1. Vous travaillez avec MySQL 8.4 LTS
make mysql84

# 2. Vous voulez passer à Percona 8.4 LTS. Pas besoin d'arrêter manuellement.
make percona84
# Cela arrêtera mysql84 puis démarrera percona84.

# 3. Vérifier l'environnement
make verify
```

## 🏛️ Architecture

Le système utilise un **proxy inverse Traefik** comme routeur intelligent. C'est le seul service exposé sur le port `3306` de votre hôte et il redirige automatiquement le trafic vers l'instance de base de données active.

<p align="center">
  <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/traefik/traefik-original.svg" alt="Traefik" width="100">
</p>

```mermaid
graph TD
    subgraph "💻 Votre Machine Hôte"
        App[Votre App / Client SQL]
    end

    subgraph "🐳 Moteur Docker"
        direction LR
        subgraph "🚪 Points d'Entrée (Proxy)"
            Traefik[traefik-db-proxy<br/>Écoute sur localhost:3306 et 5432]
        end
        subgraph "🚀 Conteneur DB à la Demande"
            ActiveDB["Instance Active<br/>Port Docker Interne"]
        end
    end

    App -- "Connexion à 3306 (MySQL) ou 5432 (PostgreSQL)" --> Traefik
    Traefik -- "Route dynamiquement vers" --> ActiveDB
```

✨ **Tableau de Bord Traefik** : Pour voir ce routage en action, ouvrez votre navigateur sur [http://localhost:8080](http://localhost:8080).

## 📁 Structure du Projet

```
.
├── 📜 .env                 # Fichier des secrets (mot de passe), à créer par vous
├── 🐳 docker-compose.yml  # Définit les services mono-instance (Traefik, DBs)
├── 🐳 docker-compose-galera.yml # Définition du Cluster MariaDB Galera
├── 🐳 docker-compose-repli.yml  # Définition du Cluster MariaDB Réplication
├── 🐳 docker-compose-patroni.yml # Cluster PostgreSQL HA Patroni
├── 🐳 docker-compose-pgpool.yml  # Cluster PostgreSQL PgPool-II
├── 🛠️ Makefile             # Gestion unifiée des instances et clusters
├── 📂 documentation/      # Guides détaillés pour les clusters et scripts
├── 📂 reports/            # Rapports de performance et de tests
├── 📚 [INDEX.md](documentation/INDEX.md) # Index de la documentation
├── 📖 README.md           # Ce fichier (Documentation en anglais)
└── 📖 README_fr.md        # Version française de ce fichier
```

## 📚 Documentation

Pour des informations détaillées, veuillez vous référer aux guides suivants :

* **[Index de la Documentation](documentation/INDEX_fr.md)** : Point d'entrée principal.
* **[Architecture](documentation/architecture.md)** : Schéma réseau et topologie.
* **[Référence Makefile](documentation/makefile_fr.md)** : Liste des commandes `make` (version complète : [makefile.md](documentation/makefile.md)).
* **[Scripts Utilitaires](documentation/scripts.md)** : Détails sur les scripts de backup, restauration, setup et CLI Go `mdb`.
* **[Support PostgreSQL](documentation/postgresql_support_fr.md)** : Standalone, Patroni HA, et clusters PgPool-II.
* **[PostgreSQL Multi-Maître & SQL Distribué](documentation/pg_multimaster_fr.md)** : `pg-streaming`, `pg-logical`, `pg-birep`, `pgedge`, `bucardo`, `citus`, `cockroach`, `yugabyte` et benchmarks V2.
* **[Cluster Patroni](documentation/patroni_cluster.md)** : PostgreSQL 17 HA avec ETCD et failover automatique.
* **[Cluster PgPool-II](documentation/pgpool_cluster.md)** : Pooling de connexions + load balancing.
* **[InnoDB Cluster](documentation/innodb_cluster_fr.md)** : MySQL 8.4 LTS Group Replication + HAProxy.
* **[MongoDB ReplicaSet](documentation/mongo_replicaset_fr.md)** : MongoDB 7.0 & 8.0 ReplicaSet + HAProxy + TLS.
* **[Scénarios de Test](documentation/tests_fr.md)** : Cas de test spécifiques et rapports.
* **[Produits Supportés](documentation/supported_products_fr.md)** : Matrice complète des moteurs, versions et ports.
* **[Bootstrap Galera](documentation/galera_bootstrap.md)** : Étapes détaillées pour Galera.
* **[Setup Réplication](documentation/replication_setup.md)** : Guide de configuration Maître/Esclave.
* **[Gouvernance & Registres](AGENTS.md)** : Règles du projet, [Action Logbook](docs/ACTION_LOGBOOK.md) et [RCA Register](docs/RCA_REGISTER.md).

## 💡 Flux de Travail Typique

```mermaid
graph TD
    A[Début] --> B{Choisir Version DB};
    B --> C[Ex: make mysql84];
    C --> D{Lancement MySQL 8.4};
    D --> E[Travailler avec la DB];
    subgraph "Actions Possibles"
        direction LR
        F[Utiliser make client]
        G[Vérifier logs: make logs]
        H[Vérifier état: make status]
    end
    E --> F & G & H;
    H --> I[Arrêter l'Environnement];
    I --> J[make stop];
    J --> K[Fin];
```

1. **Choisissez et démarrez une version** :

    ```bash
    make mysql84
    ```

2. **(Optionnel mais recommandé)** Générez votre `~/.my.cnf` :

    ```bash
    make mycnf
    ```

3. **Connectez-vous** via `localhost:3306` ou via la commande Make :

    ```bash
    make client
    ```

4. **Développez et testez** contre la base de données.
5. **Vérifiez les logs** si nécessaire :

    ```bash
    make logs
    ```

6. **Changez de version** si besoin :

    ```bash
    make mariadb114
    ```

7. Une fois terminé, **arrêtez tout** :

    ```bash
    make stop
    ```

## 🚀 Pipeline de Release (GitHub Actions)

Les releases sont automatisées via [`.github/workflows/release.yml`](.github/workflows/release.yml) sur push de tag `v*.*.*` ou `workflow_dispatch` (mode dry-run par défaut ; `publish=true` pour publier) : validation `VERSION`/`Changelog` ([`scripts/release_notes.py`](scripts/release_notes.py)), tests Python/Go/config, cross-compilation de `cmd/mdb` (6 cibles + `SHA256SUMS.txt`), publication GitHub Release et push Docker Hub multi-arch conditionné aux secrets.

## 🔧 Dépannage & Notes de Performance

### Avertissement et repli `io_uring` EPERM

Lors du démarrage des conteneurs MySQL ou MariaDB sur des hôtes Linux avec des profils de sécurité noyau restreints (`kernel.io_uring_disabled=2`), les logs peuvent afficher :

```text
io_uring_queue_init() failed with EPERM — kernel has io_uring_disabled=2.
```

- **Impact** : Aucun dysfonctionnement. Le moteur de base de données bascule automatiquement et de manière transparente sur `libaio` pour l'I/O asynchrone.
- **Action requise** : Aucune pour les environnements de développement ou de test.
- **Optimisation des performances (Optionnelle)** : Si vous avez besoin des performances I/O maximales de `io_uring`, activez-le sur votre système hôte :

  ```bash
  sudo sysctl -w kernel.io_uring_disabled=0
  ```

  Pour rendre ce réglage persistant après redémarrage, ajoutez `kernel.io_uring_disabled = 0` dans `/etc/sysctl.conf`.

