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

Une fonctionnalité clé est le **proxy inverse Traefik**, qui garantit que toutes les instances de base de données sont accessibles via des ports stables sur votre machine hôte (`localhost:3306` pour MySQL/MariaDB et `localhost:5432` pour PostgreSQL), quelle que soit la version spécifique de la base de données que vous choisissez d'exécuter.

> [!IMPORTANT]
> **Politique d'Anglais Uniquement** : Tous les commentaires techniques dans le code, les fichiers de configuration et la documentation de ce projet DOIVENT être en anglais UNIQUEMENT.

## 🛰️ État de Vérification

| Niveau | Nom du Niveau | Dernière Vérification | État |
| :--- | :--- | :--- | :--- |
| **T2** | **Matrice Standalone** | 2026-01-29 | ✅ 100% Réussi |
| **T3** | **Cluster & HA** | - | 🏗️ En cours |

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir installé les outils suivants :

* [Docker](https://docs.docker.com/get-docker/)
* [Docker Compose](https://docs.docker.com/compose/install/) (généralement inclus avec Docker Desktop)
* `make` (disponible sur la plupart des systèmes Linux/macOS. Pour Windows, vous pouvez utiliser Chocolatey : `choco install make`)

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
| `make start`                    | 🚀   | Démarre le service de base de données par défaut (MariaDB 11.8).            | `make start`                    |
| `make stop`                     | 🛑   | Arrête et supprime correctement tous les conteneurs et réseaux du projet.   | `make stop`                     |
| `make status`                   | 📊   | Affiche l'état des conteneurs actifs du projet (Traefik + DB).              | `make status`                   |
| `make info`                     | ℹ️   | Fournit des informations sur le service DB actif et les logs récents.       | `make info`                     |
| `make logs`                     | 📄   | Affiche les logs du service de base de données actuellement actif.          | `make logs`                     |
| `make mycnf`                    | 🔑   | Génère un fichier `~/.my.cnf` pour des connexions MySQL sans mot de passe.  | `make mycnf`                    |
| `make client`                   | 💻   | Démarre un client MySQL connecté à la base de données active.               | `make client`                   |
| `make pgpass`                   | 🔑   | Génère un fichier `~/.pgpass` pour des connexions PostgreSQL sans mot de passe. | `make pgpass`                 |
| `make pgclient`                 | 💻   | Démarre un client PostgreSQL connecté à la base de données active.           | `make pgclient`                 |
| `make verify`                   | ✅   | Exécute une validation complète de l'environnement (test-config).           | `make verify`                   |
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

| Command        | Icon | Description       |
| :------------- | :--- | :---------------- |
| `make mysql96` | 🐬   | Démarre MySQL 9.6 |
| `make mysql84` | 🐬   | Démarre MySQL 8.4 |
| `make mysql80` | 🐬   | Démarre MySQL 8.0 |
| `make mysql57` | 🐬   | Démarre MySQL 5.7 |

### <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/mariadb/mariadb-original.svg" alt="MariaDB" width="25" height="25"> MariaDB

| Command            | Icon | Description           |
| :----------------- | :--- | :-------------------- |
| `make mariadb118`  | 🐧   | Démarre MariaDB 11.8  |
| `make mariadb114`  | 🐧   | Démarre MariaDB 11.4  |
| `make mariadb1011` | 🐧   | Démarre MariaDB 10.11 |
| `make mariadb106`  | 🐧   | Démarre MariaDB 10.6  |

### <img src="https://raw.githubusercontent.com/simple-icons/simple-icons/develop/icons/percona.svg" alt="Percona" width="25" height="25"> Percona Server

| Command          | Icon | Description         |
| :--------------- | :--- | :------------------ |
| `make percona80` | ⚡   | Démarre Percona 8.0 |

### <img src="https://raw.githubusercontent.com/devicons/devicon/master/icons/postgresql/postgresql-original.svg" alt="PostgreSQL" width="25" height="25"> PostgreSQL

| Command            | Icon | Description             |
| :----------------- | :--- | :---------------------- |
| `make postgres17`  | 🐘   | Démarre PostgreSQL 17   |
| `make postgres16`  | 🐘   | Démarre PostgreSQL 16   |
| `make postgres15`  | 🐘   | Démarre PostgreSQL 15   |

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
| `make mongo-up`      | 🍃   | Démarre MongoDB ReplicaSet (3 nœuds + HAProxy)         |
| `make mongo-status`  | 📊   | Affiche le statut du ReplicaSet                        |
| `make test-mongo`    | 🧪   | Exécute les tests MongoDB ReplicaSet                   |
| `make mongo-down`    | 🛑   | Arrête MongoDB ReplicaSet                              |

> [!NOTE]
> MongoDB ReplicaSet utilise le port 27100 (RW) via HAProxy. Stats : 8408. Accès direct : 27411-27413.

**Exemple : Changer de Base de Données**

```bash
# 1. Vous travaillez avec MySQL 8.0
make mysql80

# 2. Vous voulez passer à Percona 8.4. Pas besoin d'arrêter manuellement.
make percona84
# Cela arrêtera mysql80 puis démarrera percona84.

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

* **[Index de la Documentation](documentation/INDEX.md)** : Point d'entrée principal.
* **[Architecture](documentation/architecture.md)** : Schéma réseau et topologie.
* **[Référence Makefile](documentation/makefile.md)** : Liste exhaustive des commandes.
* **[Scripts Utilitaires](documentation/scripts.md)** : Détails sur les scripts de backup, restauration et setup.
* **[Support PostgreSQL](documentation/postgresql_support_fr.md)** : Standalone, Patroni HA, et clusters PgPool-II.
* **[Cluster Patroni](documentation/patroni_cluster.md)** : PostgreSQL 17 HA avec ETCD et failover automatique.
* **[Cluster PgPool-II](documentation/pgpool_cluster.md)** : Pooling de connexions + load balancing.
* **[Scénarios de Test](documentation/tests.md)** : Cas de test spécifiques et rapports.
* **[Bootstrap Galera](documentation/galera_bootstrap.md)** : Étapes détaillées pour Galera.
* **[Setup Réplication](documentation/replication_setup.md)** : Guide de configuration Maître/Esclave.

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

## 🔧 Dépannage & Notes de Performance

### Avertissement et repli `io_uring` EPERM

Lors du démarrage des conteneurs MySQL ou MariaDB sur des hôtes Linux avec des profils de sécurité noyau restreints (`kernel.io_uring_disabled=2`), les logs peuvent afficher :

```text
io_uring_queue_init() failed with EPERM — kernel has io_uring_disabled=2.
```

- **Impact** : Aucun dysfonctionnement. Le moteur de base de données bascule automatiquement et de manière transparente sur `libaio` pour l'I/O asynchrone.
- **Action requise** : Aucune pour les environnements de développement ou de test.
- **Optimisation des performances (Optionnel)** : Si vous avez besoin des performances I/O maximales de `io_uring`, activez-le sur votre système hôte :

  ```bash
  sudo sysctl -w kernel.io_uring_disabled=0
  ```

  Pour rendre ce réglage persistant après redémarrage, ajoutez `kernel.io_uring_disabled = 0` dans `/etc/sysctl.conf`.

