# Documentation des Scripts Utilitaires 📜

Ce document décrit les différents scripts shell disponibles dans le répertoire `docker/mariadb` pour la gestion de l'environnement MariaDB.

## 💾 Sauvegarde & Restauration

### Sauvegarde Logique (`mariadb-dump`)

- **[backup_logical.sh](../backup_logical.sh)** : Effectue un dump SQL compressé.
  - Utilisation : `./backup_logical.sh <galera|repli> [nom_bdd]`
  - Caractéristiques : Utilise `pigz` pour une compression rapide, inclut les routines, triggers et événements.
- **[restore_logical.sh](../restore_logical.sh)** : Restaure une sauvegarde logique.
  - Utilisation : `./restore_logical.sh <galera|repli> <nom_fichier.sql.gz>`

### Sauvegarde Physique (MariaBackup)

- **[backup_physical.sh](../backup_physical.sh)** : Effectue une sauvegarde physique à chaud via MariaBackup.
  - Utilisation : `./backup_physical.sh <galera|repli>`
  - Caractéristiques : Crée un instantané cohérent sans verrouiller la base de données.
- **[restore_physical.sh](../restore_physical.sh)** : Restaure une sauvegarde physique.
  - Utilisation : `./restore_physical.sh <galera|repli> <filename.tar.gz>`
  - Fonctionne pour les deux types de clusters (Galera et Réplication).
  - **ATTENTION** : Ce script arrête MariaDB, remplace tout le répertoire de données et redémarre le service.

## 🔐 Sécurité & SSL

- **[gen_ssl.sh](../gen_ssl.sh)** : Génère une chaîne complète de certificats SSL (CA, Serveur et Client).
  - Les fichiers sont stockés dans le répertoire `ssl/`.
  - Les certificats sont automatiquement utilisés par les conteneurs via les montages de volumes.

## ⚙️ Configuration & Installation

- **[setup_repli.sh](../setup_repli.sh)** : Automatise la mise en place de la réplication Maître/Esclave.
  - Effectue la synchronisation initiale des données du Maître vers les Esclaves.
  - Configure la réplication basée sur le GTID.
- **[gen_profiles.sh](../gen_profiles.sh)** : Génère `profile_galera` et `profile_repli`.
  - Fournit des alias shell (ex : `mariadb-m1`, `mariadb-g1`) pour un accès rapide aux conteneurs.
- **[start-mariadb.sh](../start-mariadb.sh)** : Script d'entrée (entrypoint) personnalisé pour les conteneurs Docker MariaDB.
  - Gère l'initialisation de la base de données (`mariadb-install-db`).
  - Exécute les scripts présents dans `/docker-entrypoint-initdb.d/`.
  - Gère le "bootstrapping" Galera via la variable d'environnement `MARIADB_GALERA_BOOTSTRAP`.

## 🧪 Tests

- **[test_galera.sh](../test_galera.sh)** : Suite complète pour Galera (synchronisation, DDL, conflits).
- **[test_repli.sh](../test_repli.sh)** : Vérification pour la réplication Maître/Esclave.
- **[test_haproxy_galera.sh](../test_haproxy_galera.sh)** : Suite de validation avancée pour HAProxy.
  - Caractéristiques : Benchmarking de latence (LB vs Direct), détection du mode de répartition (Sticky/RR), simulation de panne réelle (failover) et génération de rapports HTML.
  - Utilisation : `./test_haproxy_galera.sh`
- **[test_perf_galera.sh](../test_perf_galera.sh)** / **[test_perf_repli.sh](../test_perf_repli.sh)** : Benchmarks de performance utilisant Sysbench.
